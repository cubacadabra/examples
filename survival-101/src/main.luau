-- Stormline Outpost is a cooperative survival loop, not a platform route.
-- The manifest owns the physical world, safe beacon, and hazards. This script
-- owns gathering, the shared camp objective, the day/night pressure, and HUD.

-- @include "@cubacadabra/survival-v1.luau"
-- @include "@cubacadabra/cycle-v1.luau"
-- @include "@cubacadabra/shared-state-v1.luau"

local Game = {}

local survival = CubaSurvival.create({})
local cycle = CubaCycle.create({
    daySeconds = 42,
    nightSeconds = 28,
})

local status = "LEAVE THE BEACON  •  GATHER BEFORE DARK"
local nearby_zone = nil
local clock_seconds = 0
local resource_cooldowns = {}
local inventory = {
    wood = 0,
    scrap = 0,
    crystals = 0,
}
local remote_survivors = {}

local function copy_state(value)
    local result = {}
    for key, item in pairs(value) do
        result[key] = item
    end
    return result
end

local function initial_camp()
    return {
        version = 1,
        day = 1,
        phase = "day",
        fuel = 60,
        beacon = 1,
        radio = 0,
    }
end

local function validate_camp(value)
    if type(value) ~= "table"
        or type(value.day) ~= "number"
        or (value.phase ~= "day" and value.phase ~= "night")
        or type(value.fuel) ~= "number"
        or type(value.beacon) ~= "number"
        or type(value.radio) ~= "number" then
        return nil
    end
    return {
        version = 1,
        day = math.max(1, math.floor(value.day)),
        phase = value.phase,
        fuel = math.max(0, math.floor(value.fuel)),
        beacon = math.max(1, math.floor(value.beacon)),
        radio = math.min(100, math.max(0, math.floor(value.radio))),
    }
end

local function reduce_camp(state, intent)
    if type(intent) ~= "table" then
        return nil
    end
    local next_state = copy_state(state)
    if intent.kind == "phase" then
        local day = math.max(1, math.floor(intent.day or state.day))
        if day < state.day or (day == state.day and intent.phase == state.phase) then
            return nil
        end
        next_state.day = day
        next_state.phase = intent.phase == "night" and "night" or "day"
        return next_state
    elseif intent.kind == "burn" then
        local target = math.max(0, math.floor(intent.target or state.fuel))
        if state.fuel <= target then
            return nil
        end
        next_state.fuel = target
        return next_state
    elseif intent.kind == "fuel" then
        local target = math.min(100, math.floor(intent.target or state.fuel))
        if state.fuel >= target then
            return nil
        end
        next_state.fuel = target
        return next_state
    elseif intent.kind == "repair" then
        local target = math.min(100, math.floor(intent.target or state.radio))
        if state.radio >= target then
            return nil
        end
        next_state.radio = target
        return next_state
    end
    return nil
end

local camp = CubaSharedState.create({
    channel = "stormline-outpost",
    initial = initial_camp,
    validate = validate_camp,
    reduce = reduce_camp,
    onChange = function(_api, state)
        cycle:sync(state.phase, state.day)
        if state.radio >= 100 then
            status = "RESCUE RADIO READY  •  HOLD THE OUTPOST"
        elseif state.phase == "night" then
            status = state.fuel > 0
                and "NIGHT  •  STAY NEAR THE BEACON"
                or "BEACON OUT  •  RUN FOR COVER"
        end
    end,
})

local function camp_value()
    return camp.value or initial_camp()
end

local function phase_status(state)
    if state.phase == "night" then
        if state.fuel > 0 then
            return "NIGHT  •  STAY NEAR THE BEACON"
        end
        return "BEACON OUT  •  RUN FOR COVER"
    end
    return "DAYLIGHT  •  GATHER SUPPLIES"
end

local function inventory_text()
    return "WOOD " .. tostring(inventory.wood)
        .. "   SCRAP " .. tostring(inventory.scrap)
        .. "   CRYSTALS " .. tostring(inventory.crystals)
end

local function player_controls()
    return {
        nodes = {
            {
                id = "survival-title",
                kind = "text",
                text = "STORMLINE OUTPOST",
                layout = { anchor = "topLeft", width = 360, height = 30, offset = { 26, 122 } },
                style = { color = "#F4F0DF", fontSize = 20 },
            },
            {
                id = "survival-status",
                kind = "text",
                text = status,
                layout = { anchor = "topLeft", width = 500, height = 26, offset = { 26, 158 } },
                style = { color = "#F2C86B", fontSize = 14 },
            },
            {
                id = "survival-cycle",
                kind = "text",
                text = "DAY 1  •  DAYLIGHT",
                layout = { anchor = "topLeft", width = 300, height = 22, offset = { 26, 190 } },
                style = { color = "#7FA6A2", fontSize = 12 },
            },
            {
                id = "survival-health",
                kind = "text",
                text = "HEALTH  -- / --",
                layout = { anchor = "topLeft", width = 250, height = 22, offset = { 26, 218 } },
                style = { color = "#F07859", fontSize = 12 },
            },
            {
                id = "survival-inventory",
                kind = "text",
                text = "WOOD 0   SCRAP 0   CRYSTALS 0",
                layout = { anchor = "topLeft", width = 440, height = 22, offset = { 26, 246 } },
                style = { color = "#F4F0DF", fontSize = 12 },
            },
            {
                id = "survival-beacon",
                kind = "text",
                text = "BEACON  1   FUEL 60   RADIO 0%",
                layout = { anchor = "topLeft", width = 420, height = 22, offset = { 26, 274 } },
                style = { color = "#F2C86B", fontSize = 12 },
            },
            {
                id = "survival-help",
                kind = "text",
                text = "MOVE  SPACE / JUMP   FIND A RESOURCE NODE   GATHER BEFORE NIGHT",
                layout = { anchor = "bottom", width = "90%", maxWidth = 700, height = 24, offset = { 0, -24 } },
                style = { color = "#F4F0DFB8", fontSize = 11, textAlign = "center" },
            },
            {
                id = "player-joystick",
                kind = "joystick",
                action = "player.move",
                layout = { anchor = "bottomLeft", width = 120, height = 120, offset = { 20, -24 } },
                style = {
                    background = "#101A22D9",
                    borderColor = "#F2C86B55",
                    borderWidth = 2,
                    cornerRadius = 60,
                    accent = "#F2C86B",
                },
            },
            {
                id = "player-jump",
                kind = "button",
                text = "JUMP",
                action = "player.jump",
                layout = { anchor = "bottomRight", width = 86, height = 44, offset = { -22, -84 } },
                style = {
                    background = "#101A22F5",
                    borderColor = "#7FA6A2",
                    borderWidth = 2,
                    cornerRadius = 17,
                    foreground = "#F4F0DF",
                    accent = "#7FA6A2",
                    textAlign = "center",
                    fontSize = 14,
                },
            },
            {
                id = "survival-gather",
                kind = "button",
                text = "GATHER",
                action = "survival.gather",
                layout = { anchor = "bottomRight", width = 98, height = 44, offset = { -22, -138 } },
                style = {
                    background = "#101A22F5",
                    borderColor = "#F2C86B",
                    borderWidth = 2,
                    cornerRadius = 17,
                    foreground = "#F4F0DF",
                    accent = "#F2C86B",
                    textAlign = "center",
                    fontSize = 13,
                },
            },
            {
                id = "survival-action",
                kind = "button",
                text = "FEED BEACON",
                action = "survival.action",
                layout = { anchor = "bottomRight", width = 98, height = 44, offset = { -22, -192 } },
                style = {
                    background = "#101A22F5",
                    borderColor = "#F07859",
                    borderWidth = 2,
                    cornerRadius = 17,
                    foreground = "#F4F0DF",
                    accent = "#F07859",
                    textAlign = "center",
                    fontSize = 11,
                },
            },
            {
                id = "player-run",
                kind = "button",
                text = "RUN",
                action = "player.run",
                layout = { anchor = "bottomRight", width = 86, height = 44, offset = { -22, -30 } },
                style = {
                    background = "#101A22F5",
                    borderColor = "#7FA6A2",
                    borderWidth = 2,
                    cornerRadius = 17,
                    foreground = "#F4F0DF",
                    accent = "#7FA6A2",
                    textAlign = "center",
                    fontSize = 14,
                },
            },
        },
    }
end

local function update_hud(api)
    local snapshot = survival:status()
    local state = camp_value()
    local cycle_snapshot = cycle:status()
    api.ui:set_text("survival-status", status)
    api.ui:set_text("survival-cycle", "DAY " .. tostring(state.day)
        .. "  •  " .. string.upper(cycle_snapshot.phase)
        .. "  " .. tostring(math.ceil(cycle_snapshot.remaining)) .. "s")
    if snapshot.maxHealth > 0 then
        api.ui:set_text("survival-health", "HEALTH  " .. tostring(math.floor(snapshot.health))
            .. " / " .. tostring(math.floor(snapshot.maxHealth))
            .. "   DEATHS " .. tostring(snapshot.deaths))
    else
        api.ui:set_text("survival-health", "HEALTH  -- / --")
    end
    api.ui:set_text("survival-inventory", inventory_text())
    api.ui:set_text("survival-beacon", "BEACON  " .. tostring(state.beacon)
        .. "   FUEL " .. tostring(state.fuel)
        .. "   RADIO " .. tostring(state.radio) .. "%")
    api.ui:set_text("survival-action", nearby_zone == "radio"
        and "REPAIR RADIO"
        or "FEED BEACON")
end

local function interaction_state(api, id)
    local state = api.interactions:get_state()
    local zone = state.zones[id]
    return zone ~= nil and zone.nearby == true
end

local function resource_kind(id)
    if id == "wood-grove" then
        return "wood", 2
    elseif id == "scrap-field" then
        return "scrap", 1
    elseif id == "crystal-ridge" then
        return "crystals", 1
    end
    return nil, 0
end

local function gather(api)
    if cycle.phase ~= "day" then
        status = "TOO DARK  •  RETURN TO THE BEACON"
        return
    end
    local resource, amount = resource_kind(nearby_zone)
    if resource == nil then
        status = "MOVE CLOSER TO A RESOURCE NODE"
        return
    end
    local ready_at = resource_cooldowns[nearby_zone] or 0
    if clock_seconds < ready_at then
        status = "THIS NODE IS RESTING  •  " .. tostring(math.ceil(ready_at - clock_seconds)) .. "s"
        return
    end
    inventory[resource] = inventory[resource] + amount
    resource_cooldowns[nearby_zone] = clock_seconds + 7
    status = "GATHERED " .. string.upper(resource) .. "  •  RETURN TO CAMP"
end

local function feed_beacon()
    if not interaction_state(Game.api, "beacon") then
        status = "BRING WOOD TO THE BEACON"
        return
    end
    if inventory.wood < 1 then
        status = "NO WOOD  •  SEARCH THE GROVE"
        return
    end
    inventory.wood = inventory.wood - 1
    camp:dispatch(Game.api, { kind = "fuel", target = math.min(100, camp_value().fuel + 8) })
    status = "BEACON FED  •  THE OUTPOST HOLDS"
end

local function repair_radio()
    if not interaction_state(Game.api, "radio") then
        status = "TAKE SUPPLIES TO THE RESCUE RADIO"
        return
    end
    if inventory.scrap < 2 or inventory.crystals < 1 then
        status = "RADIO NEEDS 2 SCRAP + 1 CRYSTAL"
        return
    end
    inventory.scrap = inventory.scrap - 2
    inventory.crystals = inventory.crystals - 1
    camp:dispatch(Game.api, { kind = "repair", target = math.min(100, camp_value().radio + 20) })
    status = "RADIO REPAIRED  •  KEEP THE BEACON ALIVE"
end

function Game.on_start(api)
    Game.api = api
    api.lobby:set_enabled(false)
    api.lobby:set_status("Gather supplies, fuel the beacon, repair the radio.")
    api.session:start("survival-101", { mode = "preview" })
    api.ui:set_document(player_controls())
    camp:start(api)
    update_hud(api)
end

function Game.on_interaction(api, event)
    if event.phase == "enter" then
        nearby_zone = event.id
        if event.id == "beacon" then
            status = phase_status(camp_value())
        elseif resource_kind(event.id) ~= nil then
            status = "PRESS GATHER  •  " .. string.upper(event.id)
        elseif event.id == "radio" then
            status = "PRESS FEED BEACON TO REPAIR THE RADIO"
        end
    elseif event.phase == "exit" and nearby_zone == event.id then
        nearby_zone = nil
    end
    update_hud(api)
end

function Game.on_ui_event(api, event)
    if event.phase ~= "activate" then
        return
    end
    if event.action == "survival.gather" then
        gather(api)
    elseif event.action == "survival.action" then
        if nearby_zone == "radio" then
            repair_radio()
        else
            feed_beacon()
        end
    end
    update_hud(api)
end

function Game.on_player_event(api, event)
    survival:handle(api, event)
    if event.kind == "spawn" then
        status = "LEAVE THE BEACON  •  GATHER BEFORE DARK"
    elseif event.kind == "damage" then
        if survival.health < 35 then
            status = "CRITICAL  •  RETURN TO THE BEACON"
        end
    elseif event.kind == "heal" then
        status = "BEACON LIGHT  •  HEALTH RESTORING"
    elseif event.kind == "death" then
        status = "THE STORM TOOK YOU  •  REGROUP AT THE OUTPOST"
    elseif event.kind == "respawn" then
        status = "BACK AT BASE  •  GATHER AND TRY AGAIN"
    end
    update_hud(api)
end

function Game.on_network_message(api, event)
    if type(event) == "table" and event.type == "player_state"
        and type(event.id) == "string"
        and type(event.state) == "table"
        and event.state.kind == "survival" then
        remote_survivors[event.id] = event.state
        return
    end
    if camp:receive(api, event) then
        local state = camp_value()
        cycle:sync(state.phase, state.day)
        if state.radio >= 100 then
            status = "RESCUE RADIO READY  •  HOLD THE OUTPOST"
        end
        update_hud(api)
    end
end

function Game.on_tick(api, delta)
    Game.api = api
    clock_seconds = clock_seconds + delta
    cycle:update(api, delta)
    camp:update(api, delta)
    if cycle.phase == "night" and cycle.elapsed < delta + 0.001 then
        camp:dispatch(api, {
            kind = "phase",
            phase = "night",
            day = cycle.day,
        })
        camp:dispatch(api, { kind = "burn", target = math.max(0, camp_value().fuel - 12) })
        status = "NIGHTFALL  •  THE BEACON MUST LAST"
    elseif cycle.phase == "day" and cycle.elapsed < delta + 0.001 then
        camp:dispatch(api, {
            kind = "phase",
            phase = "day",
            day = cycle.day,
        })
        status = "DAWN  •  SCAVENGE THE OUTPOST"
    end
    update_hud(api)
end

return Game
