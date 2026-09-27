-- Welcome to Cubacadabra. Restore every loose letter line to the wall.
local Game = {}
local CubaSharedState = require("@cubacadabra/shared-state")

local line_count = 21
local completed = {}
local moving = {}
local target_positions = { { -9.500, 1.000, -2.970 }, { -7.850, 1.550, -2.970 }, { -6.000, 1.400, -2.970 }, { -6.000, 0.600, -2.970 }, { -5.150, 1.000, -2.970 }, { -4.000, 1.400, -2.970 }, { -4.000, 0.250, -2.970 }, { -1.500, 1.000, -2.970 }, { 0.000, 1.400, -2.970 }, { 0.000, 0.250, -2.970 }, { 2.000, 1.000, -2.970 }, { 4.000, 1.400, -2.970 }, { 4.000, 0.250, -2.970 }, { 6.000, 1.400, -2.970 }, { 6.000, 0.600, -2.970 }, { 6.850, 1.000, -2.970 }, { 8.000, 1.400, -2.970 }, { 8.850, 1.000, -2.970 }, { 8.060, 0.380, -2.970 }, { 10.000, 1.400, -2.970 }, { 10.000, 0.250, -2.970 } }
local loose_positions = { { -8.400, 0.000, 13.000 }, { -5.600, 0.000, 13.000 }, { -2.800, 0.000, 13.000 }, { 0.000, 0.000, 13.000 }, { 2.800, 0.000, 13.000 }, { 5.600, 0.000, 13.000 }, { 8.400, 0.000, 13.000 }, { -8.400, 0.000, 10.000 }, { -5.600, 0.000, 10.000 }, { -2.800, 0.000, 10.000 }, { 0.000, 0.000, 10.000 }, { 2.800, 0.000, 10.000 }, { 5.600, 0.000, 10.000 }, { 8.400, 0.000, 10.000 }, { -8.400, 0.000, 7.000 }, { -5.600, 0.000, 7.000 }, { -2.800, 0.000, 7.000 }, { 0.000, 0.000, 7.000 }, { 2.800, 0.000, 7.000 }, { 5.600, 0.000, 7.000 }, { 8.400, 0.000, 7.000 } }

local function effect_id(index)
    return "letter-line-" .. index
end

local function interaction_id(index)
    return "loose-line-" .. index
end

local function player_controls()
    return {
        nodes = {
            {
                id = "player-joystick",
                kind = "joystick",
                action = "player.move",
                layout = { anchor = "bottomLeft", width = 120, height = 120, offset = { 20, -24 } },
                style = { background = "#0B102BC9", borderColor = "#57E5D055", borderWidth = 2, cornerRadius = 60, accent = "#57E5D0" },
            },
            {
                id = "player-jump",
                kind = "button",
                text = "JUMP",
                action = "player.jump",
                layout = { anchor = "bottomRight", width = 86, height = 44, offset = { -22, -84 } },
                style = { background = "#0B102BF5", borderColor = "#57E5D0", borderWidth = 2, cornerRadius = 17, foreground = "#F7F5E9", fontSize = 14, textAlign = "center" },
            },
            {
                id = "player-run",
                kind = "button",
                text = "RUN",
                action = "player.run",
                layout = { anchor = "bottomRight", width = 86, height = 44, offset = { -22, -30 } },
                style = { background = "#0B102BF5", borderColor = "#57E5D0", borderWidth = 2, cornerRadius = 17, foreground = "#F7F5E9", fontSize = 14, textAlign = "center" },
            },
        },
    }
end

local function completed_count()
    local count = 0
    for index = 1, line_count do
        if completed[index] then
            count += 1
        end
    end
    return count
end

local function update_status(api)
    local count = completed_count()
    if count == line_count then
        api.lobby:set_status("All 21 lines are back on the cubes!")
    elseif count == 0 then
        api.lobby:set_status("heavy2" .. " — walk over a dark line.")
    else
        api.lobby:set_status(tostring(count) .. "/" .. line_count .. " lines restored — find another dark line.")
    end
end

local lines = CubaSharedState.create({
    channel = "starter-lines-v1",
    initial = function()
        return { version = 1, completed = {} }
    end,
    validate = function(value)
        if type(value) ~= "table" or value.version ~= 1 or type(value.completed) ~= "table" then
            return nil
        end
        local accepted = {}
        for key, done in pairs(value.completed) do
            local index = tonumber(key)
            if type(key) ~= "string" or not index or tostring(index) ~= key
                or index < 1 or index > line_count or done ~= true then
                return nil
            end
            accepted[key] = true
        end
        return { version = 1, completed = accepted }
    end,
    reduce = function(state, intent)
        if intent.type ~= "restore" or type(intent.index) ~= "number"
            or intent.index < 1 or intent.index > line_count
            or intent.index % 1 ~= 0 or state.completed[tostring(intent.index)] then
            return nil
        end
        local accepted = {}
        for key, done in pairs(state.completed) do
            accepted[key] = done
        end
        accepted[tostring(intent.index)] = true
        return { version = 1, completed = accepted }
    end,
    onChange = function(api, state, previous)
        for index = 1, line_count do
            if state.completed[tostring(index)] and not completed[index] then
                completed[index] = true
                moving[index] = nil
                if previous then
                    api.effects:set_state(interaction_id(index), "carried")
                    api.effects:play(effect_id(index), { position = loose_positions[index] })
                    api.task:delay(1.15, function()
                        api.effects:set_state(interaction_id(index), "complete")
                        api.effects:play("line-settle-" .. index, { position = target_positions[index] })
                    end)
                else
                    api.effects:set_state(interaction_id(index), "complete")
                end
            elseif not completed[index] and not moving[index] then
                api.effects:set_state(interaction_id(index), "available")
            end
        end
        update_status(api)
    end,
})

function Game.on_start(api)
    api.lobby:set_enabled(false)
    api.session:start("heavy2", { mode = "preview" })
    api.ui:set_document(player_controls())
    lines:start(api)
end

function Game.on_network_message(api, event)
    lines:receive(api, event)
end

function Game.on_tick(api, delta)
    if api.network:is_connected() then
        lines:update(api, delta)
    end
end

function Game.on_interaction(api, event)
    if event.phase ~= "enter" then
        return
    end
    local index = tonumber(string.match(event.id, "^loose%-line%-(%d+)$"))
    if not index or index < 1 or index > line_count or completed[index] or moving[index] then
        return
    end
    if lines:dispatch(api, { type = "restore", index = index }) then
        moving[index] = true
        completed[index] = true
        api.effects:set_state(interaction_id(index), "carried")
        api.effects:play(effect_id(index), { position = loose_positions[index] })
        api.lobby:set_status("Line " .. index .. " is snapping into place…")
        api.task:delay(1.15, function()
            moving[index] = nil
            api.effects:set_state(interaction_id(index), "complete")
            api.effects:play("line-settle-" .. index, { position = target_positions[index] })
            update_status(api)
        end)
    end
end

return Game
