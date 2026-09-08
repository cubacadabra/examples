-- Survival 101 is a small stormline expedition. The manifest owns the
-- physical rules; this script owns the mission, status feedback, and the
-- shelter objective.

-- @include "@cubacadabra/survival-v1.luau"

local Game = {}

local survival = CubaSurvival.create({})
local shelter_seconds = 0
local in_shelter = false
local shelter_secured = false
local status = "CROSS THE HEAT FLATS"
local remote_survivors = {}

local function player_controls()
    return {
        nodes = {
            {
                id = "survival-title",
                kind = "text",
                text = "STORMLINE",
                layout = { anchor = "topLeft", width = 300, height = 30, offset = { 26, 122 } },
                style = { color = "#F7F5E9", fontSize = 20 },
            },
            {
                id = "survival-status",
                kind = "text",
                text = status,
                layout = { anchor = "topLeft", width = 390, height = 26, offset = { 26, 158 } },
                style = { color = "#57E5D0", fontSize = 14 },
            },
            {
                id = "survival-health",
                kind = "text",
                text = "HEALTH  -- / --",
                layout = { anchor = "topLeft", width = 250, height = 22, offset = { 26, 190 } },
                style = { color = "#FF8A3D", fontSize = 12 },
            },
            {
                id = "survival-deaths",
                kind = "text",
                text = "DEATHS  0",
                layout = { anchor = "topLeft", width = 250, height = 22, offset = { 26, 218 } },
                style = { color = "#F7F5E9", fontSize = 12 },
            },
            {
                id = "survival-help",
                kind = "text",
                text = "WASD / JOYSTICK  MOVE   SPACE / JUMP   CLIMB TO THE SIGNAL",
                layout = { anchor = "bottom", width = "90%", maxWidth = 620, height = 24, offset = { 0, -24 } },
                style = { color = "#F7F5E9B8", fontSize = 11, textAlign = "center" },
            },
            {
                id = "player-joystick",
                kind = "joystick",
                action = "player.move",
                layout = { anchor = "bottomLeft", width = 120, height = 120, offset = { 20, -24 } },
                style = {
                    background = "#0B102BC9",
                    borderColor = "#57E5D055",
                    borderWidth = 2,
                    cornerRadius = 60,
                    accent = "#57E5D0",
                },
            },
            {
                id = "player-jump",
                kind = "button",
                text = "JUMP",
                action = "player.jump",
                layout = { anchor = "bottomRight", width = 86, height = 44, offset = { -22, -84 } },
                style = {
                    background = "#0B102BF5",
                    borderColor = "#57E5D0",
                    borderWidth = 2,
                    cornerRadius = 17,
                    foreground = "#F7F5E9",
                    accent = "#57E5D0",
                    textAlign = "center",
                    fontSize = 14,
                },
            },
            {
                id = "player-climb",
                kind = "button",
                text = "CLIMB",
                action = "player.climb",
                layout = { anchor = "bottomRight", width = 86, height = 44, offset = { -22, -138 } },
                style = {
                    background = "#0B102BF5",
                    borderColor = "#F1E95B",
                    borderWidth = 2,
                    cornerRadius = 17,
                    foreground = "#F7F5E9",
                    accent = "#F1E95B",
                    textAlign = "center",
                    fontSize = 14,
                },
            },
            {
                id = "player-run",
                kind = "button",
                text = "RUN",
                action = "player.run",
                layout = { anchor = "bottomRight", width = 86, height = 44, offset = { -22, -30 } },
                style = {
                    background = "#0B102BF5",
                    borderColor = "#57E5D0",
                    borderWidth = 2,
                    cornerRadius = 17,
                    foreground = "#F7F5E9",
                    accent = "#57E5D0",
                    textAlign = "center",
                    fontSize = 14,
                },
            },
        },
    }
end

local function update_hud(api)
    local snapshot = survival:status()
    api.ui:set_text("survival-status", status)
    if snapshot.maxHealth > 0 then
        api.ui:set_text("survival-health", "HEALTH  " .. tostring(math.floor(snapshot.health)) .. " / " .. tostring(math.floor(snapshot.maxHealth)))
    else
        api.ui:set_text("survival-health", "HEALTH  -- / --")
    end
    api.ui:set_text("survival-deaths", "DEATHS  " .. tostring(snapshot.deaths))
end

function Game.on_start(api)
    api.lobby:set_enabled(false)
    api.lobby:set_status("Cross the stormline and reach the signal shelter.")
    api.session:start("survival-101", { mode = "preview" })
    api.ui:set_document(player_controls())
    update_hud(api)
end

function Game.on_interaction(api, event)
    if event.id ~= "shelter" then
        return
    end
    in_shelter = event.phase == "enter"
    if in_shelter and not shelter_secured then
        status = "SHELTER REACHED  •  HOLD POSITION"
    end
    update_hud(api)
end

function Game.on_player_event(api, event)
    survival:handle(api, event)
    if event.kind == "spawn" then
        status = "CROSS THE HEAT FLATS"
    elseif event.kind == "damage" then
        if survival.health < 35 then
            status = "CRITICAL  •  REACH THE SHELTER"
        end
    elseif event.kind == "death" then
        status = "STORM TOOK YOU  •  RETURNING TO BASE"
    elseif event.kind == "respawn" then
        status = "TRY AGAIN  •  WATCH THE NEXT GAP"
    end
    update_hud(api)
end

function Game.on_network_message(api, event)
    if type(event) ~= "table"
        or event.type ~= "player_state"
        or type(event.id) ~= "string"
        or type(event.state) ~= "table"
        or event.state.kind ~= "survival" then
        return
    end
    remote_survivors[event.id] = event.state
end

function Game.on_tick(api, delta)
    if in_shelter and not shelter_secured then
        shelter_seconds = shelter_seconds + delta
        if shelter_seconds >= 8 then
            shelter_secured = true
            status = "SHELTER SECURED  •  YOU SURVIVED"
            api.lobby:set_status("Shelter secured. The stormline is survivable.")
        elseif math.floor(shelter_seconds) ~= math.floor(shelter_seconds - delta) then
            status = "SHELTER STABILIZING  " .. tostring(math.floor(shelter_seconds)) .. " / 8"
        end
        update_hud(api)
    end
end

return Game
