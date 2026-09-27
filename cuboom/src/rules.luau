-- Pure cooperative rules. No runtime or transport side effects.
local Rules = {}
Rules.levels = {
    { name = "First catch", count = 2, fuse = 36, stagger = 10, quota = 1 },
    { name = "Side hustle", count = 3, fuse = 34, stagger = 8, quota = 2 },
    { name = "Crowd control", count = 4, fuse = 32, stagger = 7, quota = 3 },
    { name = "Chain panic", count = 5, fuse = 30, stagger = 6, quota = 4 },
    { name = "The big Cuboom", count = 6, fuse = 28, stagger = 5, quota = 5 },
}
Rules.bays = { "NORTH", "EAST", "SOUTH", "WEST" }
Rules.radius = 3.8
Rules.ids = { "bomb-1", "bomb-2", "bomb-3", "bomb-4", "bomb-5", "bomb-6" }

local function integer(value, low, high)
    return type(value) == "number" and value == math.floor(value) and value >= low and value <= high
end

function Rules.initial()
    return { version = 1, run = 1, round = 1, revision = 0, phase = "ready", clock = 0,
        charge = 5, score = 0, combo = 0, saved = 0, bombs = {}, blasts = {} }
end

function Rules.bay(state)
    return (state.round + state.run - 2) % 4 + 1
end

function Rules.position(value)
    if type(value) ~= "table" then return false end
    for index = 1, 3 do
        if type(value[index]) ~= "number" or value[index] ~= value[index] or math.abs(value[index]) > 100 then return false end
    end
    return true
end

function Rules.contained(state, position)
    if not Rules.position(position) then return false end
    local bay = Rules.bay(state)
    local across = (bay == 1 or bay == 3) and position[1] or position[3]
    local along = (bay == 1 or bay == 3) and position[3] or position[1]
    if bay == 1 or bay == 4 then along = -along end
    -- The whole 1.6m cube must sit inside the 12 x 5m striped bay.
    return math.abs(across) <= 5.2 and along >= 7.8 and along <= 11.2
end

function Rules.deadline(state, index)
    local level = Rules.levels[state.round]
    return level.fuse + (index - 1) * level.stagger
end

function Rules.validate(value)
    if type(value) ~= "table" or value.version ~= 1
        or not integer(value.run, 1, 1000000) or not integer(value.round, 1, #Rules.levels)
        or not integer(value.revision, 0, 100000000) or not integer(value.charge, 0, 5)
        or not integer(value.score, 0, 100000000) or not integer(value.combo, 0, 20)
        or not integer(value.saved, 0, 6) or type(value.clock) ~= "number"
        or value.clock ~= value.clock or value.clock < 0 or value.clock > 3600
        or not ({ ready = true, running = true, clear = true, lost = true, won = true })[value.phase]
        or type(value.bombs) ~= "table" or type(value.blasts) ~= "table" then return nil end
    local result = {}
    for _, key in ipairs({ "version", "run", "round", "revision", "phase", "clock", "charge", "score", "combo", "saved" }) do
        result[key] = value[key]
    end
    result.bombs = {}
    local count = Rules.levels[value.round].count
    if #value.bombs ~= (value.phase == "ready" and 0 or count) then return nil end
    for index, status in ipairs(value.bombs) do
        if status ~= "armed" and status ~= "saved" and status ~= "burst" then return nil end
        result.bombs[index] = status
    end
    result.blasts = {}
    if #value.blasts > count then return nil end
    for _, blast in ipairs(value.blasts) do
        if type(blast) ~= "table" or not integer(blast.index, 1, count)
            or type(blast.safe) ~= "boolean" or not Rules.position(blast.position) then return nil end
        table.insert(result.blasts, { index = blast.index, safe = blast.safe, position = table.clone(blast.position) })
    end
    return result
end

function Rules.all_parked(state, positions)
    if state.phase ~= "running" then return false end
    for index, status in ipairs(state.bombs) do
        if status == "armed" and not Rules.contained(state, positions[Rules.ids[index]]) then return false end
    end
    return true
end

function Rules.reduce(state, intent)
    if type(intent) ~= "table" or intent.run ~= state.run or intent.round ~= state.round
        or intent.revision ~= state.revision then return nil end
    local next = Rules.validate(state)
    next.revision += 1
    next.blasts = {}
    if intent.kind == "start" and (state.phase == "ready" or state.phase == "clear") then
        if state.phase == "clear" then next.round += 1 end
        next.phase, next.clock, next.saved = "running", 0, 0
        next.bombs = {}
        for index = 1, Rules.levels[next.round].count do next.bombs[index] = "armed" end
        return next
    elseif intent.kind == "replay" and (state.phase == "lost" or state.phase == "won") then
        local fresh = Rules.initial()
        fresh.run, fresh.revision = state.run + 1, next.revision
        return fresh
    elseif intent.kind ~= "resolve" or state.phase ~= "running" then return nil end

    if type(intent.positions) ~= "table" or type(intent.at) ~= "number"
        or intent.at ~= intent.at or intent.at < state.clock or intent.at > 3600 then return nil end
    for index = 1, #state.bombs do
        if not Rules.position(intent.positions[Rules.ids[index]]) then return nil end
    end
    local cash_in = intent.cashIn == true
    if cash_in and not Rules.all_parked(state, intent.positions) then return nil end
    next.clock = intent.at
    local queue = {}
    for index, status in ipairs(state.bombs) do
        if status == "armed" and (cash_in or intent.at >= Rules.deadline(state, index)) then
            table.insert(queue, index)
        end
    end
    if #queue == 0 then return nil end
    local cursor = 1
    while cursor <= #queue do
        local index = queue[cursor]
        cursor += 1
        if next.bombs[index] ~= "armed" then continue end
        local position = intent.positions[Rules.ids[index]]
        local safe = Rules.contained(state, position)
        next.bombs[index] = safe and "saved" or "burst"
        table.insert(next.blasts, { index = index, safe = safe, position = table.clone(position) })
        if safe then
            next.saved += 1
            next.combo += 1
            next.score += 100 + math.min(4, next.combo - 1) * 25
            if cash_in then next.score += math.floor(math.max(0, Rules.deadline(state, index) - intent.at)) * 2 end
        else
            next.charge = math.max(0, next.charge - 1)
            next.combo = 0
            -- Containment shields other bombs. Loose neighbours chain immediately.
            for other, status in ipairs(next.bombs) do
                local target = intent.positions[Rules.ids[other]]
                if status == "armed" and not Rules.contained(state, target)
                    and (position[1] - target[1]) ^ 2 + (position[3] - target[3]) ^ 2 <= Rules.radius ^ 2 then
                    table.insert(queue, other)
                end
            end
        end
    end
    local remaining = 0
    for _, status in ipairs(next.bombs) do if status == "armed" then remaining += 1 end end
    if next.charge == 0 or (remaining == 0 and next.saved < Rules.levels[next.round].quota) then
        next.phase = "lost"
    elseif remaining == 0 then
        next.phase = next.round == #Rules.levels and "won" or "clear"
        next.charge = math.min(5, next.charge + 1)
    end
    return next
end

return Rules
