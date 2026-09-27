local Letters = {}
local moving = {}
local target_positions = { { -9.500, 1.000, -2.970 }, { -7.850, 1.550, -2.970 }, { -6.000, 1.400, -2.970 }, { -6.000, 0.600, -2.970 }, { -5.150, 1.000, -2.970 }, { -4.000, 1.400, -2.970 }, { -4.000, 0.250, -2.970 }, { -1.500, 1.000, -2.970 }, { 0.000, 1.400, -2.970 }, { 0.000, 0.250, -2.970 }, { 2.000, 1.000, -2.970 }, { 4.000, 1.400, -2.970 }, { 4.000, 0.250, -2.970 }, { 6.000, 1.400, -2.970 }, { 6.000, 0.600, -2.970 }, { 6.850, 1.000, -2.970 }, { 8.000, 1.400, -2.970 }, { 8.850, 1.000, -2.970 }, { 8.060, 0.380, -2.970 }, { 10.000, 1.400, -2.970 }, { 10.000, 0.250, -2.970 } }
function Letters.reset(api, state)
    moving = {}
    for index = 1, 21 do
        api.effects:set_state("loose-line-" .. index, state.lines[index] and "complete" or "available")
    end
end
function Letters.project(api, state, previous)
    for index = 1, 21 do
        if not moving[index] and (not previous or previous.lines[index] ~= state.lines[index]) then
            api.effects:set_state("loose-line-" .. index, state.lines[index] and "complete" or "available")
        end
    end
end
function Letters.collect(api, event, state, current)
    if event.phase ~= "enter" then return nil end
    local index = tonumber(string.match(event.id, "^loose%-line%-(%d+)$"))
    if not index or index < 1 or index > 21 or state.lines[index] or moving[index] then return nil end
    moving[index] = true
    api.effects:set_state(event.id, "carried")
    api.effects:play("letter-line-" .. index, { position = event.position })
    api.task:delay(1.15, function()
        moving[index] = nil
        local accepted = current().lines[index]
        api.effects:set_state(event.id, accepted and "complete" or "available")
        if accepted then api.effects:play("line-settle-" .. index, { position = target_positions[index] }) end
    end)
    return index
end
return Letters
