-- Whispering Wilds is the exploration/adventure reference game.
-- The manifest owns terrain, climbing, gravity, checkpoints, and hazards.
-- This script owns the shared discovery trail and the compact adventure HUD.
-- Wolves are world-owned ambient NPCs from the platform presence layer.

-- @include "@cubacadabra/survival-v1.luau"
-- @include "@cubacadabra/shared-state-v1.luau"

local Game = {}

local survival = CubaSurvival.create({})
local status = "FOLLOW THE TRAIL  •  FIND THE WATCHTOWER"
local nearby_zone = nil
local elapsed = 0

local LANDMARKS = {
    { id = "trailhead", label = "TRAILHEAD" },
    { id = "creek", label = "CREEK" },
    { id = "watchtower", label = "WATCHTOWER" },
    { id = "hollow", label = "HOLLOW" },
    { id = "relic", label = "RELIC" },
}

local function initial_trail()
    return {
        version = 1,
        discovered = {},
        relic = false,
    }
end

local function copy_discovered(value)
    local result = {}
    for key, item in pairs(value or {}) do
        result[key] = item == true
    end
    return result
end

local function validate_trail(value)
    if type(value) ~= "table" or type(value.discovered) ~= "table" then
        return nil
    end
    return {
        version = 1,
        discovered = copy_discovered(value.discovered),
        relic = value.relic == true,
    }
end

local function reduce_trail(state, intent)
    if type(intent) ~= "table" or intent.kind ~= "discover" then
        return nil
    end
    local id = intent.id
    if type(id) ~= "string" then
        return nil
    end
    local known = false
    for _, landmark in ipairs(LANDMARKS) do
        if landmark.id == id then
            known = true
            break
        end
    end
    if not known or state.discovered[id] == true then
        return nil
    end
    local next_state = {
        version = 1,
        discovered = copy_discovered(state.discovered),
        relic = state.relic,
    }
    next_state.discovered[id] = true
    next_state.relic = id == "relic" or state.relic
    return next_state
end

local trail = CubaSharedState.create({
    channel = "whispering-wilds-trail",
    initial = initial_trail,
    validate = validate_trail,
    reduce = reduce_trail,
})

local function trail_value()
    return trail.value or initial_trail()
end

local function discovery_count(state)
    local count = 0
    for _, landmark in ipairs(LANDMARKS) do
        if state.discovered[landmark.id] == true then
            count = count + 1
        end
    end
    return count
end

local function landmark_text(state)
    local result = ""
    for index, landmark in ipairs(LANDMARKS) do
        if index > 1 then
            result = result .. "  •  "
        end
        result = result .. (state.discovered[landmark.id] and "✓ " or "○ ") .. landmark.label
    end
    return result
end

local function player_controls()
    return {
        nodes = {
            {
                id = "adventure-title",
                kind = "text",
                text = "WHISPERING WILDS",
                layout = { anchor = "topLeft", width = 420, height = 30, offset = { 26, 122 } },
                style = { color = "#F4F0DF", fontSize = 20 },
            },
            {
                id = "adventure-status",
                kind = "text",
                text = status,
                layout = { anchor = "topLeft", width = 620, height = 26, offset = { 26, 158 } },
                style = { color = "#F2C86B", fontSize = 14 },
            },
            {
                id = "adventure-discoveries",
                kind = "text",
                text = "DISCOVERIES 0 / 5",
                layout = { anchor = "topLeft", width = 520, height = 22, offset = { 26, 190 } },
                style = { color = "#86A9A0", fontSize = 12 },
            },
            {
                id = "adventure-landmarks",
                kind = "text",
                text = "○ TRAILHEAD  •  ○ CREEK  •  ○ WATCHTOWER",
                layout = { anchor = "topLeft", width = 760, height = 22, offset = { 26, 218 } },
                style = { color = "#F4F0DF", fontSize = 11 },
            },
            {
                id = "adventure-health",
                kind = "text",
                text = "HEALTH  -- / --   WILDLIFE  ACTIVE",
                layout = { anchor = "topLeft", width = 420, height = 22, offset = { 26, 246 } },
                style = { color = "#E77A62", fontSize = 12 },
            },
            {
                id = "adventure-help",
                kind = "text",
                text = "MOVE  •  JUMP  •  CLIMB THE WATCHTOWER  •  SEARCH THE LANDMARKS",
                layout = { anchor = "bottom", width = "90%", maxWidth = 760, height = 24, offset = { 0, -24 } },
                style = { color = "#F4F0DFB8", fontSize = 11, textAlign = "center" },
            },
            {
                id = "player-joystick",
                kind = "joystick",
                action = "player.move",
                layout = { anchor = "bottomLeft", width = 120, height = 120, offset = { 20, -24 } },
                style = { background = "#101A22D9", borderColor = "#F2C86B55", borderWidth = 2, cornerRadius = 60, accent = "#F2C86B" },
            },
            {
                id = "player-jump",
                kind = "button",
                text = "JUMP",
                action = "player.jump",
                layout = { anchor = "bottomRight", width = 86, height = 44, offset = { -22, -84 } },
                style = { background = "#101A22F5", borderColor = "#86A9A0", borderWidth = 2, cornerRadius = 17, foreground = "#F4F0DF", accent = "#86A9A0", textAlign = "center", fontSize = 14 },
            },
            {
                id = "player-run",
                kind = "button",
                text = "RUN",
                action = "player.run",
                layout = { anchor = "bottomRight", width = 86, height = 44, offset = { -22, -30 } },
                style = { background = "#101A22F5", borderColor = "#86A9A0", borderWidth = 2, cornerRadius = 17, foreground = "#F4F0DF", accent = "#86A9A0", textAlign = "center", fontSize = 14 },
            },
        },
    }
end

local function update_hud(api)
    local state = trail_value()
    local snapshot = survival:status()
    api.ui:set_text("adventure-status", status)
    api.ui:set_text("adventure-discoveries", "DISCOVERIES " .. tostring(discovery_count(state)) .. " / 5")
    api.ui:set_text("adventure-landmarks", landmark_text(state))
    if snapshot.maxHealth > 0 then
        api.ui:set_text("adventure-health", "HEALTH  " .. tostring(math.floor(snapshot.health))
            .. " / " .. tostring(math.floor(snapshot.maxHealth)) .. "   WILDLIFE  ACTIVE")
    else
        api.ui:set_text("adventure-health", "HEALTH  -- / --   WILDLIFE  ACTIVE")
    end
end

local function discover(api, id)
    local state = trail_value()
    if state.discovered[id] == true then
        return
    end
    trail:dispatch(api, { kind = "discover", id = id })
    if id == "watchtower" then
        status = "HIGH GROUND  •  THE FOREST OPENS BELOW"
    elseif id == "relic" then
        status = "THE RELIC REMEMBERS  •  KEEP EXPLORING"
    else
        status = "DISCOVERED  " .. string.upper(id) .. "  •  FOLLOW THE NEXT CLUE"
    end
end

function Game.on_start(api)
    Game.api = api
    api.lobby:set_enabled(false)
    api.lobby:set_status("Explore the wilds, discover landmarks, and find the old watchtower.")
    api.session:start("adventure-101", { mode = "preview" })
    api.ui:set_document(player_controls())
    trail:start(api)
    update_hud(api)
end

function Game.on_interaction(api, event)
    if event.phase == "enter" then
        nearby_zone = event.id
        discover(api, event.id)
        if event.id == "watchtower" then
            status = "CLIMB THE LADDER  •  SEE THE WHOLE WILDS"
        elseif event.id == "relic" then
            status = "A HIDDEN RELIC  •  PRESS INTO THE HOLLOW"
        end
    elseif event.phase == "exit" and nearby_zone == event.id then
        nearby_zone = nil
    end
    update_hud(api)
end

function Game.on_player_event(api, event)
    survival:handle(api, event)
    if event.kind == "death" then
        status = "THE RAVINE TOOK YOU  •  TRY THE TRAIL AGAIN"
    elseif event.kind == "respawn" then
        status = "BACK AT THE TRAILHEAD  •  WATCH YOUR STEP"
    elseif event.kind == "damage" and survival.health < 35 then
        status = "HURT  •  GET BACK TO THE TRAILHEAD"
    end
    update_hud(api)
end

function Game.on_network_message(api, event)
    if trail:receive(api, event) then
        update_hud(api)
    end
end

function Game.on_tick(api, delta)
    Game.api = api
    elapsed = elapsed + delta
    trail:update(api, delta)
    update_hud(api)
end

return Game
