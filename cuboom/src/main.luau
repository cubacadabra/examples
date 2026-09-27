local SharedState = require("@cubacadabra/shared-state")
local Config = require("./config")
local Rules = require("./rules")
local View = require("./view")
local Letters = require("./letters")
local Game = {}
local state = Rules.initial()
local side, store, spatial = "", nil, nil
local online, joined = false, false
local age, observeTimer, effectTimer = 0, 0, 0
local flight, flightCooldown = 0, 0
local context = nil
local lastStatus, lastAction, lastBeacon = "", "", ""
local painted = {}
local localTime = 0

local function now()
    return state.clock + (online and store and store.hasSnapshot and store.ageSeconds or age)
end
local function playable()
    return not joined or (online and store and store.hasSnapshot)
end
local function current() return state end
local function accept(api, value, previous, snapshotAge, feedback)
    state, age = value, snapshotAge or 0
    Letters.project(api, state, previous)
    if feedback and previous then
        if state.burstSerial ~= previous.burstSerial then
            api.effects:play("cuboom-pop", { position = state.burst })
            if spatial then
                local dx, dz = spatial.player[1] - state.burst[1], spatial.player[3] - state.burst[3]
                local d = math.sqrt(dx * dx + dz * dz)
                if d < 6 and math.abs(spatial.player[2] - state.burst[2]) < 5 then
                    api.player:impulse({ dx / math.max(d, 1) * 9, 12, dz / math.max(d, 1) * 9 })
                end
            end
        end
        if state.phase ~= previous.phase and (state.phase == "rest" or state.phase == "complete") then
            api.effects:play("round-win", { position = { 0, 1, state.winner == "mint" and 7 or -15 } })
        end
    end
    if previous and state.epoch ~= previous.epoch then painted = {} end
    observeTimer = 0
end
local function dispatch(api, kind, data)
    if not playable() then return end
    local intent = data or {}
    intent.kind, intent.epoch, intent.round, intent.at = kind, state.epoch, state.round, now()
    intent.revision = state.revision
    if online then
        if kind == "line" or #store.pending == 0 then store:dispatch(api, intent) end
    else
        local next = Rules.reduce(state, intent)
        if next then accept(api, next, state, 0, true) end
    end
end
local function connect(api)
    store = SharedState.create({
        channel = "cuboom-playground-v1", initial = Rules.initial, validate = Rules.validate, reduce = Rules.reduce,
        intentExpired = function(value, intent)
            return intent.epoch ~= value.epoch or (intent.kind ~= "line" and intent.round ~= value.round)
        end,
        onChange = function(api, value, previous, event)
            if event.bootstrap then return end
            local snapshotAge = math.max(0, (event.ageMs or 0) / 1000)
            accept(api, value, previous, snapshotAge, previous ~= nil and snapshotAge < 1)
        end,
    })
    store:start(api)
end
local function nearest_pair(at)
    if not spatial or state.round < 2 then return nil end
    local nearest, distance = nil, 12
    for index = 1, state.released do
        local entry = spatial.blocks[Config.ids[index]]
        if entry and not Rules.moving(state, index, at) then
            local p = entry.position
            local d = (p[1] - spatial.player[1]) ^ 2 + (p[3] - spatial.player[3]) ^ 2
            if d < distance and math.abs(p[2] - spatial.player[2]) < 3 then nearest, distance = index, d end
        end
    end
    if not nearest then return nil end
    local onto, best = nil, 25
    local a = spatial.blocks[Config.ids[nearest]].position
    for index = 1, state.released do
        local entry = spatial.blocks[Config.ids[index]]
        if entry and index ~= nearest and entry.position[2] <= 7 and not Rules.moving(state, index, at) then
            local b = entry.position
            local d = (a[1] - b[1]) ^ 2 + (a[3] - b[3]) ^ 2
            if d < best then
                local probe = { kind = "lift", epoch = state.epoch, round = state.round, at = at,
                    revision = state.revision, positions = spatial.blocks, player = spatial.player, index = nearest, onto = index }
                if Rules.reduce(state, probe) then onto, best = index, d end
            end
        end
    end
    return onto and { kind = "lift", index = nearest, onto = onto } or nil
end
local function present(api, at)
    local text
    if not playable() then
        text = online and "Joining the playground..." or "Connection lost. Waiting to rejoin the round..."
    elseif state.round == 0 then
        text = "Collect the loose letters. Step onto MINT or VIOLET to play."
    elseif side == "" then
        text = "Pick a side: step onto MINT or VIOLET. Everyone can push."
    elseif state.phase == "rest" then
        text = Config.names[state.winner] .. " takes round " .. state.round .. ". More cubes in " .. math.max(0, math.ceil(state.nextRound - at)) .. "..."
    elseif state.phase == "complete" then
        local winner = state.wins.mint > state.wins.violet and "Mint" or "Violet"
        text = winner .. " wins " .. math.max(state.wins.mint, state.wins.violet) .. "–" .. math.min(state.wins.mint, state.wins.violet) .. ". The playground is yours."
    elseif state.hold ~= "" then
        text = Config.names[state.hold] .. " has enough! Break the hold: " .. math.max(0, math.ceil(Config.hold - (at - state.since)))
    elseif state.round == 5 then
        text = "5 / Touch the sky. Climb the ladder, then FLY to the C."
    else
        local counts = spatial and Rules.counts(state, spatial.blocks, at) or { mint = 0, violet = 0 }
        local round = Config.rounds[state.round]
        text = state.round .. " / " .. Config.names[side] .. " " .. counts[side] .. "/" .. round.goal .. ". " .. round.hint
        if state.charged > 0 then text = "CUBOOM in " .. math.max(0, math.ceil(state.fuse - at)) .. "! Move the ticking cube; clear the pile." end
    end
    if text ~= lastStatus then
        lastStatus = text
        api.lobby:set_status(text)
        api.ui:set_text("round-status", text)
    end
    context = playable() and nearest_pair(at) or nil
    if playable() and state.round >= 5 and not context and localTime >= flightCooldown then context = { kind = "fly" } end
    if state.phase == "complete" and spatial and spatial.player[3] > 12 then context = { kind = "replay" } end
    local label = context and (context.kind == "lift" and "LIFT" or context.kind == "fly" and "FLY" or "AGAIN") or ""
    if label ~= lastAction then
        lastAction = label
        api.ui:set_text("context-action", label)
        api.ui:set_visible("context-action", label ~= "")
    end
    local beacon = state.round == 5 and "open" or "closed"
    if beacon ~= lastBeacon then api.effects:set_state("sky-beacon", beacon); lastBeacon = beacon end
end
function Game.on_start(api)
    api.lobby:set_enabled(false)
    api.session:start("cuboom", { mode = "playground" })
    api.world:watch_blocks(Config.ids)
    api.ui:set_document(View.document())
    Letters.reset(api, state)
    present(api, now())
end
function Game.on_tick(api, delta)
    localTime += delta
    local connected = api.network:is_connected()
    if connected ~= online then
        online = connected
        if online then joined = true; connect(api) end
    end
    if online then store:update(api, delta) elseif not joined then age += delta end
    spatial = api.world:get_positions()
    if spatial and spatial.worldId ~= "starter-world" then spatial = nil end
    local at = now()
    if spatial then
        -- Apply only changed game shifts. Ordinary player pushes stay on their native network lane.
        for index, id in ipairs(Config.ids) do
            local shift = Rules.shift(state, index, at)
            local previous = painted[index]
            if not previous or previous[1] ~= shift[1] or previous[2] ~= shift[2] or previous[3] ~= shift[3] then
                if api.world:set_block_shift(id, shift) then painted[index] = { shift[1], shift[2], shift[3] } end
            end
        end
        if flight > 0 and playable() then
            flight = math.max(0, flight - delta)
            if spatial.player[2] < 19 then api.player:impulse({ 0, delta * 38, 0 }) end
        end
    end
    observeTimer -= delta
    effectTimer -= delta
    if observeTimer <= 0 then
        if spatial and playable() then
            dispatch(api, "observe", { positions = spatial.blocks, player = spatial.player, side = side })
        end
        present(api, now())
        observeTimer = 0.15
    end
    if effectTimer <= 0 and spatial then
        if state.round >= 2 and state.phase == "play" then
            for index = (state.round - 1) * 11 + 1, state.released do
                local entry = spatial.blocks[Config.ids[index]]
                if entry then api.effects:play("live-letter", { position = entry.position }) end
            end
        end
        if state.charged > 0 then
            local entry = spatial.blocks[Config.ids[state.charged]]
            if entry then api.effects:play("fuse-tick", { position = entry.position }) end
        end
        effectTimer = 0.35
    end
end
function Game.on_interaction(api, event)
    local index = Letters.collect(api, event, state, current)
    if index then dispatch(api, "line", { index = index }) end
    if event.phase == "enter" then
        local chosen = string.match(event.id, "^join%-(%a+)$")
        if chosen == "mint" or chosen == "violet" then
            side = chosen
            if state.round == 0 then dispatch(api, "start") end
            present(api, now())
        end
    end
end
function Game.on_ui_event(api, event)
    if event.action ~= "cuboom.context" or event.phase ~= "activate" or not context or not playable() then return end
    if context.kind == "fly" then
        flight, flightCooldown = 2.5, localTime + 7
        api.player:impulse({ 0, 9, 0 })
    elseif spatial then
        dispatch(api, context.kind, { index = context.index, onto = context.onto, positions = spatial.blocks, player = spatial.player })
    end
    present(api, now())
end
function Game.on_network_message(api, event)
    if store and online then store:receive(api, event) end
end
function Game.on_save()
    return { state = state, age = now() - state.clock, side = side, flight = flight,
        flightCooldown = math.max(0, flightCooldown - localTime) }
end
function Game.on_restore(api, saved)
    local restored = type(saved) == "table" and Rules.validate(saved.state)
    if not restored or type(saved.age) ~= "number" or saved.age < 0 or saved.age > 10000000
        or saved.age ~= saved.age or not ({ [""] = true, mint = true, violet = true })[saved.side]
        or type(saved.flight) ~= "number" or saved.flight < 0 or saved.flight > 2.5
        or type(saved.flightCooldown) ~= "number" or saved.flightCooldown < 0 or saved.flightCooldown > 7 then error("Invalid Cuboom save") end
    state, age, side = restored, saved.age, saved.side
    store, online, joined = nil, false, false
    flight, flightCooldown, localTime = saved.flight, saved.flightCooldown, 0
    spatial, painted, context = nil, {}, nil
    lastStatus, lastAction, lastBeacon = "", "", ""
    api.world:watch_blocks(Config.ids)
    Letters.reset(api, state)
    present(api, now())
end
return Game
