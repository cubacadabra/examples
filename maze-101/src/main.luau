-- Maze 101 keeps the first visual milestone deliberately small: one
-- EasyRoom-style generated maze, one fixed presentation target, and the
-- gameplay loop needed to evaluate it. Difficulty progression comes later.

local Game = {}

local MAZE = {
    name = "EASY ROOM",
    time_limit = 150,
    coin_count = 8,
    finish_position = { 28, 0, 28 },
}

local elapsed = 0
local refresh_elapsed = 0
local falls = 0
local collected = 0
local completed = false
local timed_out = false
local finish_time = 0
local status = "FIND THE EXIT"
local checkpoint = "START"
local collected_coins = {}
local debug_build = false

local function reset_state()
    elapsed = 0
    refresh_elapsed = 0
    falls = 0
    collected = 0
    completed = false
    timed_out = false
    finish_time = 0
    status = "FIND THE EXIT"
    checkpoint = "START"
    collected_coins = {}
end

local function format_time(seconds)
    local whole = math.max(0, math.floor(seconds))
    local minutes = math.floor(whole / 60)
    local remainder = whole % 60
    return string.format("%02d:%02d", minutes, remainder)
end

local function player_controls()
    local document = {
        nodes = {
            {
                id = "maze-status",
                kind = "text",
                text = status,
                layout = { anchor = "top", width = 260, height = 20, offset = { 0, 72 } },
                style = { foreground = "#F4F0D8E8", fontSize = 13, textAlign = "center" },
            },
            {
                id = "maze-progress",
                kind = "text",
                text = "02:30  •  0/8 COINS",
                layout = { anchor = "top", width = 220, height = 18, offset = { 0, 92 } },
                style = { foreground = "#F4F0D8B8", fontSize = 11, textAlign = "center" },
            },
        },
    }

    if not debug_build then
        table.insert(document.nodes, {
            id = "player-joystick",
            kind = "joystick",
            action = "player.move",
            layout = { anchor = "bottomLeft", width = 96, height = 96, offset = { 18, -22 } },
            style = {
                background = "#172A2496",
                borderColor = "#F4F0D840",
                borderWidth = 1,
                cornerRadius = 48,
                accent = "#F4F0D8CC",
            },
        })
        table.insert(document.nodes, {
            id = "player-jump",
            kind = "button",
            text = "JUMP",
            action = "player.jump",
            layout = { anchor = "bottomRight", width = 68, height = 44, offset = { -18, -76 } },
            style = {
                background = "#172A24B8",
                borderColor = "#F4F0D855",
                borderWidth = 1,
                cornerRadius = 16,
                foreground = "#F4F0D8",
                accent = "#F4F0D8",
                textAlign = "center",
                fontSize = 12,
            },
        })
        table.insert(document.nodes, {
            id = "player-run",
            kind = "button",
            text = "RUN",
            action = "player.run",
            layout = { anchor = "bottomRight", width = 68, height = 44, offset = { -18, -22 } },
            style = {
                background = "#172A24B8",
                borderColor = "#F4F0D855",
                borderWidth = 1,
                cornerRadius = 16,
                foreground = "#F4F0D8",
                accent = "#F4F0D8",
                textAlign = "center",
                fontSize = 12,
            },
        })
    end

    if debug_build then
        table.insert(document.nodes, {
            id = "maze-debug-end",
            kind = "button",
            text = "SKIP TO END",
            action = "maze.debug.skip_to_end",
            visible = false,
            layout = { anchor = "topRight", width = 84, height = 32, offset = { -18, 72 } },
            style = {
                background = "#172A248C",
                borderColor = "#F4F0D855",
                borderWidth = 1,
                cornerRadius = 12,
                foreground = "#F4F0D8",
                accent = "#F4F0D8",
                textAlign = "center",
                fontSize = 10,
            },
        })
    end

    return document
end

local function update_hud(api)
    if debug_build then
        api.ui:set_visible("maze-debug-end", not completed)
    end
    local time_left = completed and finish_time or math.max(0, MAZE.time_limit - elapsed)
    api.ui:set_text("maze-status", status)
    api.ui:set_text(
        "maze-progress",
        format_time(time_left) .. "  •  " .. tostring(collected) .. "/" .. tostring(MAZE.coin_count) .. " COINS"
    )
end

local function set_coin_states(api)
    for index = 1, MAZE.coin_count do
        local id = string.format("maze-coin-%02d", index)
        api.effects:set_state(id, collected_coins[id] and "collected" or "available")
    end
    api.effects:set_state("maze-finish", completed and "reached" or "available")
end

local function skip_to_end(api)
    if not debug_build or completed then
        return
    end

    elapsed = 0
    completed = false
    collected = MAZE.coin_count
    for index = 1, MAZE.coin_count do
        collected_coins[string.format("maze-coin-%02d", index)] = true
    end
    status = "DEBUG SKIP  •  ALL COINS FOUND  •  FIND THE EXIT"
    api.lobby:set_status("Debug: all coins found. Reach the exit.")
    if api.debug ~= nil then
        api.debug:teleport_to("easy-room", MAZE.finish_position, 0)
    end
    set_coin_states(api)
    update_hud(api)
end

function Game.on_start(api)
    debug_build = api.build_mode == "DEBUG"
    reset_state()
    api.lobby:set_enabled(false)
    api.lobby:set_status("Easy Room: find the exit before the timer runs out.")
    api.session:start("maze-101", { mode = "cooperative", difficulty = "easy" })
    api.ui:set_document(player_controls())
    update_hud(api)
end

function Game.on_tick(api, delta_seconds)
    if not completed and not timed_out then
        elapsed += delta_seconds
        if elapsed >= MAZE.time_limit then
            timed_out = true
            status = "TIME EXPIRED  •  THE EXIT IS STILL OPEN"
            api.lobby:set_status("Time expired, but the exit is still open.")
        end
    end

    refresh_elapsed += delta_seconds
    if refresh_elapsed >= 0.1 then
        refresh_elapsed = 0
        update_hud(api)
    end
end

function Game.on_ui_event(api, event)
    if type(event) == "table"
        and event.action == "maze.debug.skip_to_end"
        and event.phase ~= "release" then
        skip_to_end(api)
    end
end

function Game.on_interaction(api, event)
    if type(event) ~= "table" or event.phase ~= "enter" or type(event.id) ~= "string" then
        return
    end

    if not completed
        and string.sub(event.id, 1, 10) == "maze-coin-"
        and not collected_coins[event.id] then
        collected_coins[event.id] = true
        collected += 1
        status = collected == MAZE.coin_count
            and "ALL COINS FOUND  •  NOW FIND THE EXIT"
            or "COIN FOUND  •  KEEP MOVING"
        api.effects:set_state(event.id, "collected")
        api.effects:play("maze-finish-burst", { position = event.position })
        api.network:publish("maze-events", { type = "coin", id = event.id })
        update_hud(api)
        return
    end

    if event.id == "maze-finish" and not completed then
        completed = true
        finish_time = elapsed
        status = "MAZE CLEARED  •  EASY ROOM COMPLETE"
        api.lobby:set_status("Easy Room cleared in " .. format_time(finish_time) .. ".")
        api.effects:set_state("maze-finish", "reached")
        api.effects:play("maze-finish-burst", { position = event.position })
        api.network:publish("maze-events", {
            type = "finish",
            difficulty = "easy",
            seconds = math.floor(finish_time),
            coins = collected,
        })
        update_hud(api)
    end
end

function Game.on_player_event(api, event)
    if type(event) ~= "table" then
        return
    end
    if event.kind == "checkpoint" then
        checkpoint = string.upper(event.id or "checkpoint")
        status = "CHECKPOINT SAVED  " .. checkpoint
    elseif event.kind == "death" then
        falls = event.deaths or falls + 1
        status = "YOU FELL  •  RETURNING TO " .. checkpoint
    elseif event.kind == "respawn" and not completed then
        status = "TRY AGAIN  •  FOLLOW THE WALLS"
    end
    update_hud(api)
end

return Game
