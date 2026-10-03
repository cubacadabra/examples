-- Welcome to Cubacadabra. Restore every loose letter line to the wall.
local Game = {}
local CubaSharedState = require("@cubacadabra/shared-state")

local line_count = 21
local cube_count = 11
local max_layers = 31 -- Runtime build blocks are bounded to 2,048; a layer uses at most 66.
local layer_height = 2
local cube_color = 0xF7F5E9
local ink_color = 0x0B102B
local layer = 1
local completed = {}
local moving = {}
local blocks_dirty = false
local advance_scheduled = false
local network_connected = false
local target_positions = { { -9.500, 1.000, -2.970 }, { -7.850, 1.550, -2.970 }, { -6.000, 1.400, -2.970 }, { -6.000, 0.600, -2.970 }, { -5.150, 1.000, -2.970 }, { -4.000, 1.400, -2.970 }, { -4.000, 0.250, -2.970 }, { -1.500, 1.000, -2.970 }, { 0.000, 1.400, -2.970 }, { 0.000, 0.250, -2.970 }, { 2.000, 1.000, -2.970 }, { 4.000, 1.400, -2.970 }, { 4.000, 0.250, -2.970 }, { 6.000, 1.400, -2.970 }, { 6.000, 0.600, -2.970 }, { 6.850, 1.000, -2.970 }, { 8.000, 1.400, -2.970 }, { 8.850, 1.000, -2.970 }, { 8.060, 0.380, -2.970 }, { 10.000, 1.400, -2.970 }, { 10.000, 0.250, -2.970 } }
local loose_positions = { { -8.400, 0.000, 13.000 }, { -5.600, 0.000, 13.000 }, { -2.800, 0.000, 13.000 }, { 0.000, 0.000, 13.000 }, { 2.800, 0.000, 13.000 }, { 5.600, 0.000, 13.000 }, { 8.400, 0.000, 13.000 }, { -8.400, 0.000, 10.000 }, { -5.600, 0.000, 10.000 }, { -2.800, 0.000, 10.000 }, { 0.000, 0.000, 10.000 }, { 2.800, 0.000, 10.000 }, { 5.600, 0.000, 10.000 }, { 8.400, 0.000, 10.000 }, { -8.400, 0.000, 7.000 }, { -5.600, 0.000, 7.000 }, { -2.800, 0.000, 7.000 }, { 0.000, 0.000, 7.000 }, { 2.800, 0.000, 7.000 }, { 5.600, 0.000, 7.000 }, { 8.400, 0.000, 7.000 } }
local cube_for_line = { 1, 2, 3, 3, 3, 4, 4, 5, 6, 6, 7, 8, 8, 9, 9, 9, 10, 10, 10, 11, 11 }
local line_sizes = {
    { 1, 0.08, 0.06 }, { 0.08, 0.9, 0.06 }, { 0.3, 0.08, 0.06 },
    { 0.3, 0.08, 0.06 }, { 0.3, 0.08, 0.06 }, { 0.08, 0.65, 0.06 },
    { 0.08, 0.5, 0.06 }, { 1, 0.08, 0.06 }, { 0.08, 0.65, 0.06 },
    { 0.08, 0.5, 0.06 }, { 0.08, 0.85, 0.06 }, { 0.08, 0.65, 0.06 },
    { 0.08, 0.5, 0.06 }, { 0.3, 0.08, 0.06 }, { 0.3, 0.08, 0.06 },
    { 0.3, 0.08, 0.06 }, { 0.3, 0.08, 0.06 }, { 0.3, 0.08, 0.06 },
    { 0.08, 0.78, 0.06 }, { 0.08, 0.65, 0.06 }, { 0.08, 0.5, 0.06 },
}
local bot_roam_clock = 0
local bot_roam_for = 0
local bot_roam_target = nil

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
                id = "cuboom-objective",
                kind = "text",
                text = "Walk over dark lines to rebuild the wall.",
                layout = { anchor = "topLeft", width = "92%", maxWidth = 460, height = 22, offset = { 16, 74 } },
                style = { foreground = "#F7F5E9", fontSize = 14 },
            },
            {
                id = "cuboom-progress",
                kind = "text",
                text = "Layer 1 · 0/21 lines · local preview",
                layout = { anchor = "topLeft", width = "92%", maxWidth = 460, height = 22, offset = { 16, 98 } },
                style = { foreground = "#F7F5E9", fontSize = 12 },
            },
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
    local connection = api.network:is_connected() and "" or " · local preview"
    api.ui:set_text("cuboom-progress", "Layer " .. layer .. " · " .. count .. "/" .. line_count .. " lines" .. connection)
    if count == line_count and layer == max_layers then
        api.lobby:set_status("Tower complete — all " .. max_layers .. " layers restored!")
    elseif count == line_count then
        api.lobby:set_status("Layer " .. layer .. " complete — building the next layer…")
    elseif count == 0 then
        api.lobby:set_status("Layer " .. layer .. " — walk over a dark line.")
    else
        api.lobby:set_status("Layer " .. layer .. " — " .. count .. "/" .. line_count .. " lines restored.")
    end
end

local last_offsets = {}

local function read_cube_offsets(api)
    local positions = api.world:get_positions()
    if not positions then
        return
    end
    for index = 1, cube_count do
        local body = positions.blocks["starter-cube-" .. index]
        last_offsets[index] = body and { body.position[1] - (-12 + 2 * index), body.position[3] + 4 } or { 0, 0 }
    end
end

local function add_block(blocks, position, size, color, collidable, cube_index)
    blocks[#blocks + 1] = {
        position = position,
        size = size,
        color = color,
        collidable = collidable,
        outline = false,
        attachedTo = "starter-cube-" .. cube_index,
    }
end

local function line_position(index, line_layer)
    local target = target_positions[index]
    local offset = last_offsets[cube_for_line[index]] or { 0, 0 }
    return { target[1] + offset[1], target[2] + layer_height * (line_layer - 1), target[3] + offset[2] }
end

local function add_line(blocks, index, line_layer)
    local target = line_position(index, line_layer)
    local size = line_sizes[index]
    add_block(blocks, target, size, ink_color, false, cube_for_line[index])
end

local function start_line_animation(api, index, line_layer)
    local start = loose_positions[index]
    local base = target_positions[index]
    local target = { base[1], base[2] + layer_height * (line_layer - 1), base[3] }
    api.effects:play(effect_id(index), {
        position = start,
        travelTo = {
            target[1] - start[1],
            target[2] - start[2],
            target[3] - start[3],
        },
    })
    api.task:delay(1.15, function()
        if layer == line_layer then
            moving[index] = nil
            api.effects:set_state(interaction_id(index), "complete")
            api.effects:play("line-settle-" .. index, { position = target })
            if line_layer > 1 then
                blocks_dirty = true
            end
            update_status(api)
        end
    end)
end

local function refresh_blocks(api)
    blocks_dirty = false
    -- Attachments follow pushes in the engine. Read current offsets only when
    -- constructing new geometry for a layer or settled line.
    read_cube_offsets(api)
    local blocks = {}
    -- The first row is authored in scene.json. After its pickup visuals are rearmed,
    -- retain its restored lines as runtime blocks so the finished row stays visible.
    if layer > 1 then
        for index = 1, line_count do
            add_line(blocks, index, 1)
        end
    end
    for row = 2, layer do
        local y = 1 + layer_height * (row - 1)
        for index = 1, cube_count do
            local offset = last_offsets[index] or { 0, 0 }
            local x = -12 + 2 * index + offset[1]
            local z = -4 + offset[2]
            add_block(blocks, { x, y, z }, { 2, 2, 2 }, cube_color, true, index)
            add_block(blocks, { x, y + 0.96, z + 1.03 }, { 2, 0.08, 0.06 }, ink_color, false, index)
            add_block(blocks, { x, y - 0.96, z + 1.03 }, { 2, 0.08, 0.06 }, ink_color, false, index)
            add_block(blocks, { x + 0.96, y, z + 1.03 }, { 0.08, 2, 0.06 }, ink_color, false, index)
            if index == 1 then
                add_block(blocks, { x - 0.96, y, z + 1.03 }, { 0.08, 2, 0.06 }, ink_color, false, index)
            end
        end
        if row < layer then
            for index = 1, line_count do
                add_line(blocks, index, row)
            end
        else
            for index = 1, line_count do
                if completed[index] and not moving[index] then
                    add_line(blocks, index, row)
                end
            end
        end
    end
    api.world:set_build_blocks(blocks)
end

local lines
lines = CubaSharedState.create({
    channel = "starter-lines-v2",
    initial = function()
        return { version = 2, layer = 1, completed = {} }
    end,
    validate = function(value)
        if type(value) ~= "table" or value.version ~= 2
            or type(value.layer) ~= "number" or value.layer % 1 ~= 0
            or value.layer < 1 or value.layer > max_layers
            or type(value.completed) ~= "table" then
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
        return { version = 2, layer = value.layer, completed = accepted }
    end,
    reduce = function(state, intent)
        if type(intent) ~= "table" or intent.layer ~= state.layer then
            return nil
        end
        if intent.type == "advance" then
            if state.layer >= max_layers then
                return nil
            end
            for index = 1, line_count do
                if not state.completed[tostring(index)] then
                    return nil
                end
            end
            return { version = 2, layer = state.layer + 1, completed = {} }
        end
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
        return { version = 2, layer = state.layer, completed = accepted }
    end,
    intentExpired = function(state, intent)
        return intent.layer ~= state.layer
    end,
    onChange = function(api, state, previous, _, context)
        local rebuild = previous == nil or state.layer ~= layer
        if state.layer ~= layer then
            layer = state.layer
            completed = {}
            moving = {}
            advance_scheduled = false
        end
        for index = 1, line_count do
            if state.completed[tostring(index)] and not completed[index] then
                completed[index] = true
                if previous and previous.layer == layer and context.initialized then
                    moving[index] = true
                    api.effects:set_state(interaction_id(index), "carried")
                    start_line_animation(api, index, layer)
                else
                    api.effects:set_state(interaction_id(index), "complete")
                    rebuild = true
                end
            elseif not completed[index] then
                api.effects:set_state(interaction_id(index), "available")
            end
        end
        if rebuild then
            refresh_blocks(api)
        end
        update_status(api)
        if state.layer < max_layers and not advance_scheduled then
            local all_done = true
            for index = 1, line_count do
                if not state.completed[tostring(index)] then
                    all_done = false
                    break
                end
            end
            if all_done then
                advance_scheduled = true
                local finished_layer = state.layer
                api.task:delay(previous and 1.25 or 0, function()
                    if layer == finished_layer then
                        lines:dispatch(api, { type = "advance", layer = finished_layer })
                    end
                end)
            end
        end
    end,
})

function Game.on_start(api)
    api.lobby:set_enabled(false)
    api.session:start("heavy2", { mode = "preview" })
    api.ui:set_document(player_controls())
    local ids = {}
    for index = 1, cube_count do
        ids[index] = "starter-cube-" .. index
    end
    api.world:watch_blocks(ids)
    lines:start(api)
end

function Game.on_network_message(api, event)
    lines:receive(api, event)
end

function Game.on_tick(api, delta)
    local connected = api.network:is_connected()
    if connected ~= network_connected then
        network_connected = connected
        update_status(api)
    end
    if connected then
        lines:update(api, delta)
    end
    if blocks_dirty then
        refresh_blocks(api)
    end
end

function Game.on_test_player(api, delta)
    local position = api.test_player:get_position()
    local yaw = api.test_player:get_yaw()
    if not position or not yaw then
        return
    end

    bot_roam_clock += delta
    bot_roam_for = math.max(0, bot_roam_for - delta)
    if bot_roam_for == 0 and bot_roam_clock >= 13 then
        bot_roam_clock = 0
        bot_roam_for = 2.5
        bot_roam_target = {
            math.random(-14, 14),
            0,
            math.random(-8, 15),
        }
    end

    local target
    if bot_roam_for > 0 then
        target = bot_roam_target
    else
        local best_distance = math.huge
        for index = 1, line_count do
            if not completed[index] and not moving[index] then
                local candidate = loose_positions[index]
                local dx = candidate[1] - position[1]
                local dz = candidate[3] - position[3]
                local distance = dx * dx + dz * dz
                if distance < best_distance then
                    best_distance = distance
                    target = candidate
                end
            end
        end
    end

    if not target then
        api.test_player:set_input(0, 0, false, false, 0)
        return
    end

    local dx = target[1] - position[1]
    local dz = target[3] - position[3]
    local distance = math.sqrt(dx * dx + dz * dz)
    if distance <= 0.8 then
        api.test_player:set_input(0, 0, false, false, 0)
        return
    end
    local forward = (-dx * math.sin(yaw) - dz * math.cos(yaw)) / distance
    local strafe = (dx * math.cos(yaw) - dz * math.sin(yaw)) / distance
    api.test_player:set_input(forward, strafe, false, false, 0)
end

function Game.on_interaction(api, event)
    if event.phase ~= "enter" then
        return
    end
    local index = tonumber(string.match(event.id, "^loose%-line%-(%d+)$"))
    if not index or index < 1 or index > line_count or completed[index] or moving[index] then
        return
    end
    if lines:dispatch(api, { type = "restore", layer = layer, index = index }) then
        completed[index] = true
        moving[index] = true
        api.effects:set_state(interaction_id(index), "carried")
        start_line_animation(api, index, layer)
        update_status(api)
        api.lobby:set_status("Line " .. index .. " is snapping into place…")
    end
end

return Game
