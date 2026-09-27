-- Cuboom owns the rules; engine bodies retain their ordinary push motion.
local Config = require("./config")
local Rules = {}
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, entry in pairs(value) do result[key] = copy(entry) end
    return result
end
local function finite(value, low, high)
    return type(value) == "number" and value == value and value >= low and value <= high
end
local function integer(value, low, high)
    return finite(value, low, high) and value == math.floor(value)
end
local function vector(value)
    return type(value) == "table" and #value == 3 and finite(value[1], -512, 512)
        and finite(value[2], -512, 512) and finite(value[3], -512, 512)
end
function Rules.initial()
    local shifts, lines = {}, {}
    for index = 1, 55 do shifts[index] = { 0, 0, 0 } end
    for index = 1, 21 do lines[index] = false end
    return { version = 1, epoch = 1, revision = 0, round = 0, phase = "play", clock = 0,
        released = 11, wins = { mint = 0, violet = 0 }, winner = "", hold = "", since = 0,
        nextRound = 0, nextCharge = 0, charged = 0, fuse = 0, burstSerial = 0,
        burst = { 0, 0, 0 }, shifts = shifts, motions = {}, lines = lines }
end
function Rules.validate(value)
    if type(value) ~= "table" or value.version ~= 1 or not integer(value.epoch, 1, 100000)
        or not integer(value.revision, 0, 100000000) or not integer(value.round, 0, 5)
        or not ({ play = true, rest = true, complete = true })[value.phase]
        or not integer(value.released, 11, 55) or type(value.wins) ~= "table"
        or not integer(value.wins.mint, 0, 5) or not integer(value.wins.violet, 0, 5)
        or not ({ [""] = true, mint = true, violet = true })[value.winner]
        or not ({ [""] = true, mint = true, violet = true })[value.hold]
        or not integer(value.charged, 0, value.released) or not integer(value.burstSerial, 0, 10000000)
        or not vector(value.burst) or type(value.shifts) ~= "table" or #value.shifts ~= 55
        or type(value.lines) ~= "table" or #value.lines ~= 21 or type(value.motions) ~= "table" then return nil end
    for _, key in ipairs({ "clock", "since", "nextRound", "nextCharge", "fuse" }) do
        if not finite(value[key], 0, 10000000) then return nil end
    end
    for _, shift in ipairs(value.shifts) do if not vector(shift) then return nil end end
    for _, line in ipairs(value.lines) do if type(line) ~= "boolean" then return nil end end
    local count = 0
    for key, motion in pairs(value.motions) do
        local index = tonumber(key)
        if type(key) ~= "string" or not integer(index, 1, value.released) or type(motion) ~= "table"
            or not vector(motion.from) or not finite(motion.at, 0, 10000000)
            or not finite(motion.duration, 0.1, 3) or not finite(motion.arc, 0, 12) then return nil end
        count += 1
    end
    if count > 55 then return nil end
    if value.released ~= math.max(1, value.round) * 11 then return nil end
    return copy(value)
end
function Rules.shift(state, index, at)
    local target, motion = state.shifts[index], state.motions[tostring(index)]
    if not motion then return target end
    local t = math.clamp((at - motion.at) / motion.duration, 0, 1)
    local ease = t * t * (3 - 2 * t)
    return { motion.from[1] + (target[1] - motion.from[1]) * ease,
        motion.from[2] + (target[2] - motion.from[2]) * ease + math.sin(t * math.pi) * motion.arc,
        motion.from[3] + (target[3] - motion.from[3]) * ease }
end
function Rules.moving(state, index, at)
    local motion = state.motions[tostring(index)]
    return motion ~= nil and at < motion.at + motion.duration
end
local function body(positions, index)
    local value = positions and positions[Config.ids[index]]
    return type(value) == "table" and vector(value.position) and vector(value.shift) and value or nil
end
function Rules.counts(state, positions, at)
    local counts = { mint = 0, violet = 0 }
    local first = math.max(0, state.round - 1) * 11 + 1
    for index = first, state.released do
        local entry = body(positions, index)
        if entry and not Rules.moving(state, index, at) then
            local p = entry.position
            if math.abs(p[1]) <= 20 and p[2] >= (state.round == 3 and 2.9 or 0.9) then
                if p[3] >= 5 then counts.mint += 1 end
                if p[3] <= -13 then counts.violet += 1 end
            end
        end
    end
    return counts
end
local function move(state, index, target, at, duration, arc)
    local from = Rules.shift(state, index, at)
    state.shifts[index] = target
    state.motions[tostring(index)] = { from = copy(from), at = at, duration = duration, arc = arc }
end
local function award(state, side, at)
    state.wins[side] += 1
    state.winner, state.hold, state.charged = side, "", 0
    state.phase = state.round == 5 and "complete" or "rest"
    state.nextRound = at + Config.intermission
end
local function release(state, positions, at)
    local occupied = {}
    for index = 1, state.released do
        local entry = body(positions, index)
        if entry then table.insert(occupied, entry.position) end
    end
    local first = state.released + 1
    for index = first, first + 10 do
        local entry = body(positions, index)
        if not entry then return false end
        local target = nil
        for row = 0, 6 do
            for column = 0, 12 do
                local candidate = { -18 + column * 3, 1, -10 + row * 2.1 }
                local free = true
                for _, p in ipairs(occupied) do
                    if math.abs(p[1] - candidate[1]) < 2.1 and math.abs(p[3] - candidate[3]) < 2.1 then free = false; break end
                end
                if free then target = candidate; break end
            end
            if target then break end
        end
        if not target then return false end
        table.insert(occupied, target)
        local shift = {}
        for axis = 1, 3 do shift[axis] = entry.shift[axis] + target[axis] - entry.position[axis] end
        -- Begin above the playground so each new letter arrives with a readable drop.
        state.shifts[index] = { shift[1], shift[2] + 9, shift[3] }
        move(state, index, shift, at + (index - first) * 0.07, 1.2, 0)
    end
    state.released += 11
    return true
end
local function burst(state, positions, at)
    local source = body(positions, state.charged)
    if not source then return false end
    state.burst, state.burstSerial = copy(source.position), state.burstSerial + 1
    for index = 1, state.released do
        local entry = body(positions, index)
        if entry then
            local dx, dz = entry.position[1] - source.position[1], entry.position[3] - source.position[3]
            local distance = math.sqrt(dx * dx + dz * dz)
            if distance < 6 then
                if distance < 0.1 then dx, dz, distance = math.cos(index * 2.4), math.sin(index * 2.4), 1 end
                local travel = 2.5 + (6 - math.min(distance, 6)) * 0.4
                local tx = math.clamp(entry.position[1] + dx / distance * travel, -28, 28)
                local tz = math.clamp(entry.position[3] + dz / distance * travel, -28, 28)
                local target = { entry.shift[1] + tx - entry.position[1], entry.shift[2] + 1 - entry.position[2], entry.shift[3] + tz - entry.position[3] }
                move(state, index, target, at, 0.9, 2 + (index % 3) * 0.4)
            end
        end
    end
    state.charged, state.nextCharge = 0, at + 14
    return true
end
function Rules.reduce(state, intent)
    if type(intent) ~= "table" or intent.epoch ~= state.epoch then return nil end
    if intent.kind == "line" then
        if not integer(intent.index, 1, 21) or state.lines[intent.index] then return nil end
        local next = copy(state); next.lines[intent.index] = true; next.revision += 1
        -- Do not reset elapsed time when an independent pickup is accepted.
        next.clock = math.max(state.clock, intent.at or state.clock)
        return next
    end
    if intent.round ~= state.round or not finite(intent.at, state.clock, 10000000) then return nil end
    local next, at = copy(state), intent.at
    next.clock, next.revision = at, state.revision + 1
    for key, motion in pairs(next.motions) do
        if at >= motion.at + motion.duration then next.motions[key] = nil end
    end
    if intent.kind == "start" and state.round == 0 then
        next.round, next.nextCharge = 1, at + 18
        return next
    elseif intent.kind == "lift" and state.round >= 2 and state.phase == "play" then
        if intent.revision ~= state.revision or not integer(intent.index, 1, state.released)
            or not integer(intent.onto, 1, state.released) or intent.index == intent.onto then return nil end
        local a, b = body(intent.positions, intent.index), body(intent.positions, intent.onto)
        if not a or not b or not vector(intent.player) or Rules.moving(state, intent.index, at)
            or Rules.moving(state, intent.onto, at) or b.position[2] > 7
            or (a.position[1] - b.position[1]) ^ 2 + (a.position[3] - b.position[3]) ^ 2 > 25
            or (a.position[1] - intent.player[1]) ^ 2 + (a.position[3] - intent.player[3]) ^ 2 > 12
            or math.abs(a.position[2] - intent.player[2]) > 3 then return nil end
        -- Require a clear landing; never merge an existing tower into itself.
        for index = 1, state.released do
            local other = body(intent.positions, index)
            if other and index ~= intent.index and index ~= intent.onto
                and math.abs(other.position[1] - b.position[1]) < 1.95
                and math.abs(other.position[3] - b.position[3]) < 1.95
                and math.abs(other.position[2] - (b.position[2] + 2)) < 1.95 then return nil end
        end
        move(next, intent.index, { a.shift[1] + b.position[1] - a.position[1],
            a.shift[2] + b.position[2] + 2 - a.position[2], a.shift[3] + b.position[3] - a.position[3] }, at, 0.7, 2.2)
        return next
    elseif intent.kind ~= "observe" then return nil end
    if state.phase == "rest" and at >= state.nextRound then
        if not release(next, intent.positions, at) then return nil end
        next.round += 1
        next.phase, next.hold, next.since = "play", "", 0
        next.nextCharge = at + 18
        return next
    end
    if state.phase ~= "play" or state.round == 0 then return nil end
    -- Unsupported cubes settle when the block below gets stolen.
    for index = 1, state.released do
        local entry = body(intent.positions, index)
        if entry and entry.position[2] > 1.05 and not Rules.moving(state, index, at) then
            local support = 1
            for other = 1, state.released do
                local lower = body(intent.positions, other)
                if lower and other ~= index and lower.position[2] < entry.position[2] - 1.9
                    and math.abs(lower.position[1] - entry.position[1]) < 1.95
                    and math.abs(lower.position[3] - entry.position[3]) < 1.95 then
                    support = math.max(support, lower.position[2] + 2)
                end
            end
            if entry.position[2] - support > 0.1 then
                move(next, index, { entry.shift[1], entry.shift[2] + support - entry.position[2], entry.shift[3] }, at, 0.45, 0)
                return next
            end
        end
    end
    if state.round >= 4 then
        if state.charged > 0 and at >= state.fuse then
            if burst(next, intent.positions, at) then return next end
        elseif state.charged == 0 and at >= state.nextCharge then
            next.charged = (state.burstSerial * 7) % state.released + 1
            next.fuse = at + 7
            return next
        end
    end
    if state.round == 5 then
        if vector(intent.player) and (intent.side == "mint" or intent.side == "violet") then
            local p, target = intent.player, Config.crown
            if math.abs(p[1] - target[1]) <= 2 and math.abs(p[3] - target[3]) <= 2 and p[2] >= 15.8 and p[2] <= 19 then
                award(next, intent.side, at); return next
            end
        end
        return nil
    end
    local counts, side = Rules.counts(state, intent.positions, at), ""
    for _, team in ipairs(Config.teams) do if counts[team] >= Config.rounds[state.round].goal then side = team end end
    if side ~= state.hold then
        next.hold, next.since = side, at
        return next
    elseif side ~= "" and at - state.since >= Config.hold then
        award(next, side, at)
        return next
    end
    return nil
end
return Rules
