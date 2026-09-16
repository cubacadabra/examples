-- Trusted Maze 101 rules. The host supplies this module with a state snapshot
-- whose player positions come from its authoritative simulation, never from
-- the command payload. Round state is per player; profile rewards are separate
-- and are intentionally not written by this module yet.

local Rules = {}

local function finite_number(value)
    return type(value) == "number" and value == value and math.abs(value) < 1e12
end

local function distance_squared(a, b)
    if type(a) ~= "table" or type(b) ~= "table"
        or not finite_number(a.x) or not finite_number(a.y) or not finite_number(a.z)
        or not finite_number(b.x) or not finite_number(b.y) or not finite_number(b.z) then
        return nil
    end
    local x = a.x - b.x
    local y = a.y - b.y
    local z = a.z - b.z
    return x * x + y * y + z * z
end

local function active_player(state, command)
    if type(state.round) ~= "table" or state.round.phase ~= "active" then
        return nil, "round_not_active"
    end
    if not finite_number(state.round.elapsedSeconds)
        or not finite_number(state.round.timeLimitSeconds)
        or state.round.elapsedSeconds >= state.round.timeLimitSeconds then
        return nil, "round_timed_out"
    end
    local player = type(state.players) == "table" and state.players[command.actorId]
    if type(player) ~= "table" then
        return nil, "player_not_in_round"
    end
    if player.status ~= "running" then
        return nil, "player_run_not_active"
    end
    return player
end

local function is_near(position, target, radius)
    if not finite_number(radius) or radius <= 0 then
        return false
    end
    local distance = distance_squared(position, target)
    return distance ~= nil and distance <= radius * radius
end

function Rules.validate_command(state, command)
    if type(state) ~= "table" or type(command) ~= "table"
        or type(command.actorId) ~= "string" then
        return "invalid_command"
    end

    -- Only the host binds this internal actor to its trusted clock.
    if command.name == "advance_time" then
        if command.actorId ~= "system:clock" then
            return "forbidden_system_command"
        end
        if type(state.round) ~= "table" or state.round.phase ~= "active"
            or type(command.payload) ~= "table" then
            return "round_not_active"
        end
        local elapsed = command.payload.elapsedSeconds
        if not finite_number(elapsed) or elapsed < state.round.elapsedSeconds then
            return "invalid_round_time"
        end
        return nil
    end

    if type(command.payload) ~= "table" then
        return "invalid_command"
    end

    local player, player_error = active_player(state, command)
    if player == nil then
        return player_error
    end

    if command.name == "collect_coin" then
        local coin_id = command.payload and command.payload.coinId
        local coin = type(coin_id) == "string"
            and type(state.maze) == "table"
            and type(state.maze.coins) == "table"
            and state.maze.coins[coin_id]
        if type(coin) ~= "table" then
            return "unknown_coin"
        end
        if player.collectedCoins[coin_id] then
            return "already_collected"
        end
        if not is_near(player.position, coin.position, coin.radius or state.maze.coinRadius) then
            return "outside_pickup_radius"
        end
        return nil
    end

    if command.name == "finish" then
        local finish = type(state.maze) == "table" and state.maze.finish
        if type(finish) ~= "table" then
            return "finish_missing"
        end
        if not is_near(player.position, finish.position, finish.radius) then
            return "outside_finish_radius"
        end
        return nil
    end

    return "unsupported_command"
end

function Rules.simulate_command(state, command)
    local next_state = table.clone(state)
    local events = {}

    if command.name == "advance_time" then
        next_state.round = table.clone(state.round)
        next_state.round.elapsedSeconds = math.min(
            command.payload.elapsedSeconds,
            state.round.timeLimitSeconds
        )
        if next_state.round.elapsedSeconds >= state.round.timeLimitSeconds then
            next_state.round.phase = "timed_out"
            table.insert(events, {
                name = "round_timed_out",
                payload = { elapsedSeconds = next_state.round.elapsedSeconds },
            })
        end
        return { state = next_state, events = events }
    end

    next_state.players = table.clone(state.players)
    local player = table.clone(state.players[command.actorId])
    next_state.players[command.actorId] = player

    if command.name == "collect_coin" then
        local coin_id = command.payload.coinId
        player.collectedCoins = table.clone(player.collectedCoins)
        player.collectedCoins[coin_id] = true
        player.coinCount += 1
        table.insert(events, {
            name = "coin_collected",
            payload = { coinId = coin_id, coinCount = player.coinCount },
        })
    elseif command.name == "finish" then
        player.status = "completed"
        player.finishedAtSeconds = state.round.elapsedSeconds
        table.insert(events, {
            name = "player_finished",
            payload = {
                finishedAtSeconds = player.finishedAtSeconds,
                coinCount = player.coinCount,
            },
        })
    end

    return { state = next_state, events = events }
end

return Rules
