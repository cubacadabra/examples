-- Maze 101 ports Maze World's core loop into Cubacadabra primitives:
-- generated walls live in the manifest, while this script owns the timed run,
-- per-player coins, checkpoints, finish feedback, and the compact HUD.

local Game = {}

local ISLANDS = {
    { name = "SUNSHORE", time_limit = 150, coin_count = 8 },
    { name = "CORAL CAY", time_limit = 180, coin_count = 12 },
    { name = "CLOUDPEAK", time_limit = 210, coin_count = 16 },
}

local FINISH_POSITIONS = {
    { 28, 0, 28 },
    { 36, 0, 36 },
    { 44, 0, 44 },
}

local current_island = 0
local in_hub = true
local hub_spawn_seen = false
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
local debug_build = false

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
    current_island = 0
    in_hub = true
    hub_spawn_seen = false
    pending_island_advance = false
    reset_island_state()
    status = "CROSS THE BRIDGE TO SUNSHORE"
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
                style = { foreground = "#F7F5E9E8", fontSize = 13, textAlign = "center" },
            },
            {
                id = "maze-progress",
                kind = "text",
                text = "02:30",
                layout = { anchor = "top", width = 180, height = 18, offset = { 0, 92 } },
                style = { foreground = "#F7F5E9B8", fontSize = 11, textAlign = "center" },
            },
        },
    }

    -- Studio uses DEBUG for its creator preview. Keyboard input remains
    -- available there, while the release package keeps its mobile controls.
    if not debug_build then
        table.insert(document.nodes, {
            id = "player-joystick",
            kind = "joystick",
            action = "player.move",
            layout = { anchor = "bottomLeft", width = 96, height = 96, offset = { 18, -22 } },
            style = {
                background = "#0B102B96",
                borderColor = "#F7F5E940",
                borderWidth = 1,
                cornerRadius = 48,
                accent = "#F7F5E9CC",
            },
        })
        table.insert(document.nodes, {
            id = "player-jump",
            kind = "button",
            text = "JUMP",
            action = "player.jump",
            layout = { anchor = "bottomRight", width = 68, height = 44, offset = { -18, -76 } },
            style = {
                background = "#0B102BB8",
                borderColor = "#F7F5E955",
                borderWidth = 1,
                cornerRadius = 16,
                foreground = "#F7F5E9",
                accent = "#F7F5E9",
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
                background = "#0B102BB8",
                borderColor = "#F7F5E955",
                borderWidth = 1,
                cornerRadius = 16,
                foreground = "#F7F5E9",
                accent = "#F7F5E9",
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
                background = "#0B102B8C",
                borderColor = "#F7F5E955",
                borderWidth = 1,
                cornerRadius = 12,
                foreground = "#F7F5E9",
                accent = "#F7F5E9",
                textAlign = "center",
                fontSize = 10,
            },
        })
    end

    return document
end

local function update_hud(api)
    if in_hub then
        if debug_build then
            api.ui:set_visible("maze-debug-end", false)
        end
        api.ui:set_text("maze-status", status)
        api.ui:set_text("maze-progress", "SUNSHORE  •  CORAL CAY  •  CLOUDPEAK")
        return
    end

    local island = island_config()
    if debug_build then
        api.ui:set_visible("maze-debug-end", true)
    end
    local time_left = completed and finish_time or math.max(0, island.time_limit - elapsed)
    api.ui:set_text("maze-status", status)
    api.ui:set_text(
        "maze-progress",
        format_time(time_left) .. "  •  " .. tostring(collected) .. "/" .. tostring(island.coin_count) .. " COINS"
    )
end

local function set_coin_states(api)
    for index = 1, island_config().coin_count do
        local id = string.format("maze-coin-%02d", index)
        api.effects:set_state(id, collected_coins[id] and "collected" or "available")
    end
    api.effects:set_state("maze-finish", completed and "reached" or "available")
end

local function skip_to_end(api)
    if not debug_build or in_hub then
        return
    end

    in_hub = false
    -- The teleport enters the finish portal immediately. Keep the same
    -- progression flag that manual finish uses so the following spawn event
    -- advances the Lua state to the destination island.
    pending_island_advance = current_island < #ISLANDS
    reset_island_state()

    local island = island_config()
    collected = island.coin_count
    for index = 1, island.coin_count do
        collected_coins[string.format("maze-coin-%02d", index)] = true
    end
    status = "DEBUG SKIP  •  ALL COINS FOUND  •  FIND THE EXIT"
    api.lobby:set_status("DEBUG: all " .. island.name .. " items collected. Reach the exit to continue.")
    if api.debug ~= nil then
        api.debug:teleport_to(
            "island-" .. tostring(current_island),
            FINISH_POSITIONS[current_island],
            0
        )
    end
    set_coin_states(api)
    update_hud(api)
end

function Game.on_start(api)
    debug_build = api.build_mode == "DEBUG"
    reset_state()
    api.lobby:set_enabled(false)
    api.lobby:set_status("Clear Sunshore, Coral Cay, and Cloudpeak in one run.")
    api.session:start("maze-101", { mode = "cooperative", islands = #ISLANDS })
    api.ui:set_document(player_controls())
    update_hud(api)
end

function Game.on_tick(api, delta_seconds)
    if in_hub then
        return
    end

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

    if in_hub then
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
    if event.kind == "spawn" and in_hub then
        if not hub_spawn_seen then
            hub_spawn_seen = true
        else
            in_hub = false
            current_island = 1
            reset_island_state()
            status = island_config().name .. "  •  FIND THE EXIT"
            api.lobby:set_status("Island 1 of " .. tostring(#ISLANDS) .. ": " .. island_config().name)
            set_coin_states(api)
        end
    elseif event.kind == "spawn" and pending_island_advance then
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
    elseif event.kind == "respawn" and not in_hub and not completed then
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
