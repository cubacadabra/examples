-- Maze 101 is a small source-authored hub feeding a finite set of baked maze
-- rooms. The hub mesh/collision is the reference export; maze worlds are the
-- generic bounded runtime declaration expanded by the native builder.

local Rooms = require("./rooms")

local Game = {}

local HUB = "maze-world"
local QUEUE_SECONDS_DEBUG = 4
local QUEUE_SECONDS_RELEASE = 20
local ROOM_COOLDOWN = 10
local INITIAL_WALLET = 100

local MAZE_WORLDS = {
    ["maze-very-easy-1"] = true,
    ["maze-very-easy-2"] = true,
    ["easy-room"] = true,
    ["maze-easy-2"] = true,
    ["maze-normal-1"] = true,
    ["maze-hard-1"] = true,
}

local ZONE_ROOMS = {
    ["room-very-easy"] = "maze-very-easy-1",
    ["room-easy"] = "easy-room",
    ["room-normal"] = "maze-normal-1",
    ["room-hard"] = "maze-hard-1",
}
local TIER_VARIANTS = {
    ["very-easy"] = { "maze-very-easy-1", "maze-very-easy-2" },
    ["easy"] = { "easy-room", "maze-easy-2" },
    ["normal"] = { "maze-normal-1" },
    ["hard"] = { "maze-hard-1" },
}
local MAZE_WORLD_IDS = {
    "maze-very-easy-1", "maze-very-easy-2", "easy-room", "maze-easy-2",
    "maze-normal-1", "maze-hard-1",
}

local active_world = HUB
local active_room = nil
local queue_room = nil
local queue_zone = nil
local queue_elapsed = 0
local cooldown = 0
local elapsed = 0
local collected = 0
local collected_coins = {}
local wallet = INITIAL_WALLET
local status = "CHOOSE A ROOM"
local result_message = nil
local transitioning = false
local debug_build = false
local unlocked_tiers = { ["very-easy"] = true }
local variant_indices = { ["very-easy"] = 1, ["easy"] = 1, ["normal"] = 1, ["hard"] = 1 }

local function all_maze_worlds()
    return MAZE_WORLD_IDS
end

local function all_worlds()
    local worlds = { HUB }
    for _, world_id in all_maze_worlds() do table.insert(worlds, world_id) end
    return worlds
end

local function format_time(seconds)
    local whole = math.max(0, math.floor(seconds))
    return string.format("%02d:%02d", math.floor(whole / 60), whole % 60)
end

local function current_room()
    return active_room and Rooms[active_room] or nil
end

local function reset_maze()
    elapsed = 0
    collected = 0
    collected_coins = {}
    status = "FIND THE EXIT"
end

local function sync_coin_effects(api)
    local room = current_room()
    if room == nil then return end
    for index = 1, room.coin_count do
        local id = string.format("maze-coin-%02d", index)
        api.effects:set_state(id, collected_coins[id] and "collected" or "available")
    end
    api.effects:set_state("maze-finish", "available")
end

local function reset_hub()
    queue_room = nil
    queue_zone = nil
    queue_elapsed = 0
    active_room = nil
    status = result_message or "CHOOSE A ROOM"
    result_message = nil
end

local function visible_worlds(node, worlds)
    node.visibleIn = worlds
    return node
end

local function player_controls()
    local document = {
        nodes = {
            visible_worlds({
                id = "maze-status", kind = "text", text = status,
                layout = { anchor = "top", width = 300, height = 22, offset = { 0, 72 } },
                style = { foreground = "#F4F0D8E8", fontSize = 13, textAlign = "center" },
            }, all_worlds()),
            visible_worlds({
                id = "maze-wallet", kind = "text", text = "COINS  " .. tostring(wallet),
                layout = { anchor = "topRight", width = 150, height = 20, offset = { -18, 72 } },
                style = { foreground = "#F4F0D8D8", fontSize = 12, textAlign = "end" },
            }, all_worlds()),
            visible_worlds({
                id = "maze-queue", kind = "text", text = "",
                layout = { anchor = "top", width = 360, height = 20, offset = { 0, 94 } },
                style = { foreground = "#F4F0D8B8", fontSize = 11, textAlign = "center" },
            }, { HUB }),
            visible_worlds({
                id = "maze-queue-action", kind = "button", text = "JOIN QUEUE", action = "maze.queue.confirm",
                layout = { anchor = "bottom", width = 124, height = 38, offset = { 0, -22 } },
                style = {
                    background = "#172A24C0", borderColor = "#F4F0D855", borderWidth = 1,
                    cornerRadius = 12, foreground = "#F4F0D8", accent = "#F4C84A", textAlign = "center", fontSize = 11,
                },
            }, { HUB }),
            visible_worlds({
                id = "maze-progress", kind = "text", text = "",
                layout = { anchor = "top", width = 260, height = 20, offset = { 0, 94 } },
                style = { foreground = "#F4F0D8B8", fontSize = 11, textAlign = "center" },
            }, all_maze_worlds()),
            visible_worlds({
                id = "player-joystick", kind = "joystick", action = "player.move",
                layout = { anchor = "bottomLeft", width = 96, height = 96, offset = { 18, -22 } },
                style = { background = "#172A2496", borderColor = "#F4F0D840", borderWidth = 1, cornerRadius = 48, accent = "#F4F0D8CC" },
            }, all_maze_worlds()),
            visible_worlds({
                id = "player-jump", kind = "button", text = "JUMP", action = "player.jump",
                layout = { anchor = "bottomRight", width = 68, height = 44, offset = { -18, -76 } },
                style = { background = "#172A24B8", borderColor = "#F4F0D855", borderWidth = 1, cornerRadius = 16, foreground = "#F4F0D8", accent = "#F4F0D8", textAlign = "center", fontSize = 12 },
            }, all_maze_worlds()),
            visible_worlds({
                id = "player-run", kind = "button", text = "RUN", action = "player.run",
                layout = { anchor = "bottomRight", width = 68, height = 44, offset = { -18, -22 } },
                style = { background = "#172A24B8", borderColor = "#F4F0D855", borderWidth = 1, cornerRadius = 16, foreground = "#F4F0D8", accent = "#F4F0D8", textAlign = "center", fontSize = 12 },
            }, all_maze_worlds()),
        },
    }
    if debug_build then
        table.insert(document.nodes, visible_worlds({
            id = "maze-debug-end", kind = "button", text = "SKIP TO EXIT", action = "maze.debug.skip_to_end",
            layout = { anchor = "topRight", width = 104, height = 32, offset = { -18, 96 } },
            style = { background = "#172A248C", borderColor = "#F4F0D855", borderWidth = 1, cornerRadius = 12, foreground = "#F4F0D8", accent = "#F4F0D8", textAlign = "center", fontSize = 10 },
        }, all_maze_worlds()))
    end
    return document
end

local function update_hud(api)
    api.ui:set_text("maze-status", status)
    api.ui:set_text("maze-wallet", "COINS  " .. tostring(wallet))
    if active_world == HUB then
        local queue_text = ""
        if queue_room ~= nil then
            local room = Rooms[queue_room]
            if room ~= nil and not unlocked_tiers[room.tier] then
                queue_text = room.name .. "  UNLOCK " .. tostring(room.cost) .. " COINS"
            elseif room ~= nil then
                queue_text = room.name .. " QUEUE  " .. format_time((debug_build and QUEUE_SECONDS_DEBUG or QUEUE_SECONDS_RELEASE) - queue_elapsed)
            end
        end
        api.ui:set_text("maze-queue", queue_text)
        local queued = queue_room ~= nil
        local room = queued and Rooms[queue_room] or nil
        local locked = room ~= nil and not unlocked_tiers[room.tier]
        api.ui:set_visible("maze-queue-action", locked and room.cost <= wallet)
        api.ui:set_text("maze-queue-action", locked and "UNLOCK ROOM" or "")
    else
        local room = current_room()
        if room ~= nil then
            local remaining = math.max(0, room.time_limit - elapsed)
            api.ui:set_text("maze-progress", format_time(remaining) .. "  •  " .. tostring(collected) .. "/" .. tostring(room.coin_count) .. " COINS")
        end
        if debug_build then
            api.ui:set_visible("maze-debug-end", true)
        end
    end
end

local function return_to_hub(api, message)
    if transitioning then
        return
    end
    transitioning = true
    cooldown = ROOM_COOLDOWN
    result_message = message
    api.lobby:set_status(message)
    api.world:enter(HUB)
end

local function request_room(api, world_id)
    local room = Rooms[world_id]
    if room == nil then return end
    if cooldown > 0 then
        queue_zone = world_id
        queue_room = nil
        queue_elapsed = 0
        status = "ROOM COOLDOWN  " .. format_time(cooldown)
        update_hud(api)
        return
    end
    if not unlocked_tiers[room.tier] and room.cost > wallet then
        status = room.name .. " NEEDS " .. tostring(room.cost) .. " COINS"
        queue_room = nil
        queue_zone = world_id
        queue_elapsed = 0
        update_hud(api)
        return
    end
    local variants = TIER_VARIANTS[room.tier] or { world_id }
    local variant_index = variant_indices[room.tier] or 1
    queue_room = variants[variant_index] or world_id
    queue_zone = world_id
    queue_elapsed = 0
    status = "QUEUE READY  " .. room.name
    api.lobby:set_status("Queued for " .. room.name .. ".")
    update_hud(api)
end

local function confirm_queue(api)
    if queue_room == nil then return end
    local room = Rooms[queue_room]
    if room == nil then
        status = "NOT ENOUGH COINS"
        return
    end
    if not unlocked_tiers[room.tier] then
        if room.cost > wallet then
            status = "NOT ENOUGH COINS"
            return
        end
        wallet -= room.cost
        unlocked_tiers[room.tier] = true
        status = "ROOM UNLOCKED  •  QUEUE READY"
    end
    queue_elapsed = 0
end

local function enter_world(api, world_id)
    active_world = world_id
    transitioning = false
    if world_id == HUB then
        reset_hub()
        api.lobby:set_status(status)
    elseif MAZE_WORLDS[world_id] then
        active_room = world_id
        reset_maze()
        sync_coin_effects(api)
        api.lobby:set_status(Rooms[world_id].name .. " ROOM  •  FIND THE EXIT")
    else
        active_room = nil
    end
    update_hud(api)
end

local function skip_to_exit(api)
    if not debug_build or active_world == HUB or active_room == nil then return end
    local room = Rooms[active_room]
    if room == nil or api.debug == nil then return end
    collected = room.coin_count
    for index = 1, room.coin_count do
        collected_coins[string.format("maze-coin-%02d", index)] = true
    end
    status = "DEBUG  •  EXIT READY"
    api.debug:teleport_to(active_world, room.finish_position, 0)
    sync_coin_effects(api)
    update_hud(api)
end

function Game.on_start(api)
    debug_build = api.build_mode == "DEBUG"
    wallet = INITIAL_WALLET
    unlocked_tiers = { ["very-easy"] = true }
    variant_indices = { ["very-easy"] = 1, ["easy"] = 1, ["normal"] = 1, ["hard"] = 1 }
    api.lobby:set_enabled(false)
    api.session:start("maze-101", { mode = "cooperative", difficulty = "source-hub" })
    api.ui:set_document(player_controls())
    enter_world(api, api.world:get_id())
end

function Game.on_tick(api, delta_seconds)
    local world_id = api.world:get_id()
    if world_id ~= active_world then enter_world(api, world_id) end
    if active_world == HUB then
        cooldown = math.max(0, cooldown - delta_seconds)
        if queue_room == nil and queue_zone ~= nil and cooldown <= 0 then
            request_room(api, queue_zone)
        end
        if queue_room ~= nil then
            local wait = debug_build and QUEUE_SECONDS_DEBUG or QUEUE_SECONDS_RELEASE
            local room = Rooms[queue_room]
            if room ~= nil and unlocked_tiers[room.tier] then
                queue_elapsed += delta_seconds
            end
            if room ~= nil and unlocked_tiers[room.tier] and queue_elapsed >= wait then
                local destination = queue_room
                queue_room = nil
                queue_zone = nil
                local tier = room.tier
                local variants = TIER_VARIANTS[tier] or { destination }
                variant_indices[tier] = (variant_indices[tier] or 1) % #variants + 1
                api.world:enter(destination)
            end
        end
    elseif active_room ~= nil then
        local room = current_room()
        elapsed += delta_seconds
        if room ~= nil and elapsed >= room.time_limit then
            return_to_hub(api, room.name .. " TIMED OUT  •  TRY AGAIN")
        end
    end
    update_hud(api)
end

function Game.on_ui_event(api, event)
    if type(event) ~= "table" or event.phase == "release" then return end
    if event.action == "maze.queue.confirm" then
        confirm_queue(api)
    elseif event.action == "maze.debug.skip_to_end" then
        skip_to_exit(api)
    end
end

function Game.on_interaction(api, event)
    if type(event) ~= "table" or type(event.id) ~= "string" then return end
    if event.phase == "enter" and active_world == HUB then
        local destination = ZONE_ROOMS[event.id]
        if destination ~= nil then request_room(api, destination) end
        return
    end
    if (event.phase == "leave" or event.phase == "exit") and active_world == HUB and queue_zone ~= nil then
        if ZONE_ROOMS[event.id] == queue_zone then
            queue_room = nil
            queue_zone = nil
            queue_elapsed = 0
            status = "QUEUE CANCELLED  •  STAY IN A ROOM ZONE"
            update_hud(api)
        end
        return
    end
    if active_world == HUB or active_room == nil or event.phase ~= "enter" then return end
    local room = current_room()
    if string.sub(event.id, 1, 10) == "maze-coin-" and not collected_coins[event.id] then
        collected_coins[event.id] = true
        collected += 1
        wallet += 1
        api.effects:set_state(event.id, "collected")
        api.effects:play("maze-finish-burst", { position = event.position })
        status = collected == room.coin_count and "ALL COINS FOUND  •  FIND THE EXIT" or "COIN FOUND  •  KEEP MOVING"
        api.network:publish("maze-wallet", { type = "coin", world = active_room, id = event.id, amount = 1, wallet = wallet })
        update_hud(api)
        return
    end
    if event.id == "maze-finish" then
        wallet += room.solo_reward
        status = room.name .. " CLEARED  •  +" .. tostring(room.solo_reward) .. " COINS"
        api.network:publish("maze-wallet", { type = "finish", world = active_room, amount = room.solo_reward, coins = collected, wallet = wallet })
        return_to_hub(api, status)
    end
end

function Game.on_player_event(api, event)
    if type(event) ~= "table" or active_world == HUB then return end
    if event.kind == "death" then return_to_hub(api, "YOU FELL  •  RETURNING TO HUB") end
end

return Game
