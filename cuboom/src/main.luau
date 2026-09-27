-- Welcome to Cubacadabra. Restore every loose letter line to the wall.
local Game = {}

local line_count = 21
local completed = {}
local moving = {}
local target_positions = { { -9.500, 1.000, -2.970 }, { -7.850, 1.550, -2.970 }, { -6.000, 1.400, -2.970 }, { -6.000, 0.600, -2.970 }, { -5.150, 1.000, -2.970 }, { -4.000, 1.400, -2.970 }, { -4.000, 0.250, -2.970 }, { -1.500, 1.000, -2.970 }, { 0.000, 1.400, -2.970 }, { 0.000, 0.250, -2.970 }, { 2.000, 1.000, -2.970 }, { 4.000, 1.400, -2.970 }, { 4.000, 0.250, -2.970 }, { 6.000, 1.400, -2.970 }, { 6.000, 0.600, -2.970 }, { 6.850, 1.000, -2.970 }, { 8.000, 1.400, -2.970 }, { 8.850, 1.000, -2.970 }, { 8.060, 0.380, -2.970 }, { 10.000, 1.400, -2.970 }, { 10.000, 0.250, -2.970 } }

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

function Game.on_start(api)
    api.lobby:set_enabled(false)
    api.session:start("heavy2", { mode = "preview" })
    api.ui:set_document(player_controls())
    for index = 1, line_count do
        api.effects:set_state(interaction_id(index), "available")
    end
    update_status(api)
end

function Game.on_interaction(api, event)
    if event.phase ~= "enter" then
        return
    end
    local index = tonumber(string.match(event.id, "^loose%-line%-(%d+)$"))
    if not index or completed[index] or moving[index] then
        return
    end
    moving[index] = true
    api.effects:set_state(interaction_id(index), "carried")
    api.effects:play(effect_id(index), { position = event.position })
    api.lobby:set_status("Line " .. index .. " is snapping into place…")
    api.task:delay(1.15, function()
        moving[index] = nil
        completed[index] = true
        api.effects:set_state(interaction_id(index), "complete")
        api.effects:play("line-settle-" .. index, { position = target_positions[index] })
        update_status(api)
    end)
end

return Game
