-- Maze 101 ports Maze World's core loop into Cubacadabra primitives:
-- generated walls live in the manifest, while this script owns the timed run,
-- per-player coins, checkpoints, finish feedback, and the compact HUD.

local Game = {}

local ISLANDS = {
    { name = "SUNSHORE", time_limit = 150, coin_count = 8 },
    { name = "CORAL CAY", time_limit = 180, coin_count = 12 },
    { name = "CLOUDPEAK", time_limit = 210, coin_count = 16 },
}

local current_island = 1
local elapsed = 0
local refresh_elapsed = 0
local falls = 0
local collected = 0
local completed = false
local timed_out = false
local finish_time = 0
local status = "FIND THE EXIT"
local checkpoint = "START"
local remote_runners = {}
local collected_coins = {}
local pending_island_advance = false

local function island_config()
    return ISLANDS[current_island]
end

local function reset_island_state()
    elapsed = 0
    refresh_elapsed = 0
    falls = 0
    collected = 0
    completed = false
    timed_out = false
    finish_time = 0
    status = "FIND THE EXIT"
    checkpoint = "START"
    remote_runners = {}
    collected_coins = {}
end

local function reset_state()
    current_island = 1
    pending_island_advance = false
    reset_island_state()
end

local function format_time(seconds)
    local whole = math.max(0, math.floor(seconds))
    local minutes = math.floor(whole / 60)
    local remainder = whole % 60
    return string.format("%02d:%02d", minutes, remainder)
end

local function player_controls()
    return {
        nodes = {
            {
                id = "maze-title",
                kind = "text",
                text = "MAZE 101  •  ISLAND 1/3",
                layout = { anchor = "topLeft", width = "86%", maxWidth = 420, height = 30, offset = { 26, 122 } },
                style = { color = "#F7F5E9", fontSize = 20 },
            },
            {
                id = "maze-status",
                kind = "text",
                text = status,
                layout = { anchor = "topLeft", width = "86%", maxWidth = 420, height = 26, offset = { 26, 158 } },
                style = { color = "#57E5D0", fontSize = 14 },
            },
            {
                id = "maze-time",
                kind = "text",
                text = "TIME 02:30",
                layout = { anchor = "topLeft", width = 220, height = 22, offset = { 26, 190 } },
                style = { color = "#F1E95B", fontSize = 12 },
            },
            {
                id = "maze-coins",
                kind = "text",
                text = "COINS 0/8",
                layout = { anchor = "topLeft", width = 220, height = 22, offset = { 26, 218 } },
                style = { color = "#F7F5E9", fontSize = 12 },
            },
            {
                id = "maze-checkpoint",
                kind = "text",
                text = "CHECKPOINT  START",
                layout = { anchor = "topLeft", width = 300, height = 22, offset = { 26, 246 } },
                style = { color = "#9F7BFF", fontSize = 12 },
            },
            {
                id = "maze-runners",
                kind = "text",
                text = "RUNNERS 1",
                layout = { anchor = "topLeft", width = 220, height = 22, offset = { 26, 274 } },
                style = { color = "#F7F5E9B8", fontSize = 12 },
            },
            {
                id = "maze-help",
                kind = "text",
                text = "MOVE  WASD / JOYSTICK   SPACE / JUMP   CLEAR ALL 3 ISLANDS",
                layout = { anchor = "bottom", width = "90%", maxWidth = 700, height = 24, offset = { 0, -24 } },
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
    local island = island_config()
    local time_left = completed and finish_time or math.max(0, island.time_limit - elapsed)
    api.ui:set_text(
        "maze-title",
        "MAZE 101  •  ISLAND " .. tostring(current_island) .. "/" .. tostring(#ISLANDS)
    )
    api.ui:set_text("maze-status", status)
    api.ui:set_text("maze-time", "TIME " .. format_time(time_left))
    api.ui:set_text("maze-coins", "COINS " .. tostring(collected) .. "/" .. tostring(island.coin_count))
    api.ui:set_text("maze-checkpoint", "CHECKPOINT  " .. checkpoint)
    local remote_count = 0
    for _ in pairs(remote_runners) do
        remote_count += 1
    end
    api.ui:set_text("maze-runners", "RUNNERS " .. tostring(1 + remote_count) .. "   FALLS " .. tostring(falls))
end

local function set_coin_states(api)
    for index = 1, island_config().coin_count do
        local id = string.format("maze-coin-%02d", index)
        api.effects:set_state(id, collected_coins[id] and "collected" or "available")
    end
    api.effects:set_state("maze-finish", completed and "reached" or "available")
end

function Game.on_start(api)
    reset_state()
    api.lobby:set_enabled(false)
    api.lobby:set_status("Clear Sunshore, Coral Cay, and Cloudpeak in one run.")
    api.session:start("maze-101", { mode = "cooperative", islands = #ISLANDS })
    api.ui:set_document(player_controls())
    set_coin_states(api)
    update_hud(api)
end

function Game.on_tick(api, delta_seconds)
    local island = island_config()
    if not completed and not timed_out then
        elapsed += delta_seconds
        if elapsed >= island.time_limit then
            timed_out = true
            status = "TIME EXPIRED  •  THE EXIT IS STILL OPEN"
            api.lobby:set_status("Time expired on " .. island.name .. ", but you can still reach the exit.")
        end
    end

    refresh_elapsed += delta_seconds
    if refresh_elapsed >= 0.1 then
        refresh_elapsed = 0
        update_hud(api)
    end
end

function Game.on_interaction(api, event)
    if type(event) ~= "table" or event.phase ~= "enter" or type(event.id) ~= "string" then
        return
    end

    local island = island_config()

    if not completed
        and string.sub(event.id, 1, 10) == "maze-coin-"
        and not collected_coins[event.id] then
        collected_coins[event.id] = true
        collected += 1
        status = collected == island.coin_count
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
        if current_island < #ISLANDS then
            pending_island_advance = true
            status = island.name .. " CLEAR  •  NEXT ISLAND"
            api.lobby:set_status(
                island.name .. " cleared in " .. format_time(finish_time) .. ". Travelling to the next island."
            )
        else
            status = "ARCHIPELAGO CLEARED  •  ALL 3 ISLANDS COMPLETE"
            api.lobby:set_status(
                "All three islands cleared. Cloudpeak took " .. format_time(finish_time) .. "."
            )
        end
        api.effects:set_state("maze-finish", "reached")
        api.effects:play("maze-finish-burst", { position = event.position })
        api.network:publish("maze-events", {
            type = "finish",
            island = current_island,
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
    if event.kind == "spawn" and pending_island_advance then
        current_island += 1
        pending_island_advance = false
        reset_island_state()
        status = island_config().name .. "  •  FIND THE EXIT"
        api.lobby:set_status(
            "Island " .. tostring(current_island) .. " of " .. tostring(#ISLANDS) .. ": " .. island_config().name
        )
        set_coin_states(api)
    elseif event.kind == "checkpoint" then
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

function Game.on_network_message(_api, event)
    if type(event) ~= "table"
        or event.type ~= "player_state"
        or type(event.id) ~= "string"
        or type(event.state) ~= "table" then
        return
    end
    remote_runners[event.id] = event.state
end

return Game
