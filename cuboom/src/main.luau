local SharedState = require("@cubacadabra/shared-state")
local Rules = require("./rules")
local Hud = require("./hud")
local Game = {}
local state = Rules.initial()
local store = nil
local online = false
local hasBeenOnline = false
local localAge = 0
local refresh = 0
local positions = nil
local visualStates = {}
local uiText = {}
local notice, noticeTime = "", 0

local function set_text(api, id, text)
    if uiText[id] ~= text then
        uiText[id] = text
        api.ui:set_text(id, text)
    end
end
local function effect_state(api, id, value)
    if visualStates[id] ~= value then
        visualStates[id] = value
        api.effects:set_state(id, value)
    end
end
local function elapsed()
    return state.clock + (online and store and store.hasSnapshot and store.ageSeconds or localAge)
end
local function can_play()
    return (not hasBeenOnline) or (online and store ~= nil and store.hasSnapshot)
end
local function accept(api, next, previous, age, feedback)
    state, localAge = next, age or 0
    if feedback and previous and next.revision ~= previous.revision then
        for _, blast in ipairs(next.blasts) do
            api.effects:play(blast.safe and "contained-burst" or "loose-burst", { position = blast.position })
            if not blast.safe and positions then
                local player = positions.player
                if (player[1] - blast.position[1]) ^ 2 + (player[3] - blast.position[3]) ^ 2 <= Rules.radius ^ 2 then
                    notice, noticeTime = "Too close! The reactor took the hit. Clear the fuse rings.", 3
                end
            end
        end
    end
    refresh = 0
end
local function dispatch(api, kind, extra)
    if not can_play() then return end
    local intent = extra or {}
    intent.kind, intent.run, intent.round, intent.revision = kind, state.run, state.round, state.revision
    if online then
        if #store.pending == 0 then store:dispatch(api, intent) end
    else
        local next = Rules.reduce(state, intent)
        if next then accept(api, next, state, 0, true) end
    end
end
local function connect(api)
    store = SharedState.create({
        channel = "cuboom-campaign-v1",
        initial = Rules.initial,
        validate = Rules.validate,
        reduce = Rules.reduce,
        intentExpired = function(value, intent)
            return intent.run ~= value.run or intent.round ~= value.round or intent.revision ~= value.revision
        end,
        onChange = function(context, value, previous, event)
            if event.bootstrap then return end
            local age = math.max(0, (event.ageMs or 0) / 1000)
            accept(context, value, previous, age, previous ~= nil and age < 1)
        end,
    })
    store:start(api)
end
local function present(api)
    local level = Rules.levels[state.round]
    local bay = Rules.bays[Rules.bay(state)]
    local running = state.phase == "running"
    set_text(api, "title", "CUBOOM / " .. state.round .. " OF 5 / " .. level.name)
    set_text(api, "objective", "Push bombs into the " .. bay .. " bay.")
    set_text(api, "score", "REACTOR " .. state.charge .. "/5   SCORE " .. state.score .. "   SAVED " .. state.saved .. "/" .. level.quota)
    local message = "Walk into cubes to push. Jump to escape a trap."
    local fuse = "Save at least " .. level.quota .. " of " .. level.count .. " bombs."
    local nextIndex, remaining = nil, math.huge
    if running then
        for index, status in ipairs(state.bombs) do
            if status == "armed" and Rules.deadline(state, index) - elapsed() < remaining then
                nextIndex, remaining = index, Rules.deadline(state, index) - elapsed()
            end
        end
        if nextIndex then fuse = "BOMB " .. nextIndex .. "  /  " .. math.max(0, math.ceil(remaining)) .. "s  /  " .. bay end
        message = "Stripes contain blasts. Loose bombs chain together."
    elseif state.phase == "clear" then
        fuse = "ROUND CLEAR / +1 reactor charge"
        message = "Next bay changes. Reuse the cubes; plan your route."
    elseif state.phase == "won" then
        fuse = "YOU SAVED THE REACTOR!"
        message = "Five rounds cleared. Play again for a higher score."
    elseif state.phase == "lost" then
        fuse = state.charge == 0 and "REACTOR DOWN" or "CONTAINMENT QUOTA MISSED"
        message = "Try again. Split up and keep loose bombs apart."
    end
    if not can_play() then
        fuse = online and "Joining the shared round..." or "Reconnecting / round paused locally"
    elseif noticeTime > 0 then message = notice end
    set_text(api, "fuse", fuse)
    set_text(api, "message", message)
    set_text(api, "round-action", state.phase == "ready" and "START ROUND"
        or state.phase == "clear" and "NEXT ROUND" or "PLAY AGAIN")
    api.ui:set_visible("round-action", not running and can_play())
    api.ui:set_visible("cash-in", running and can_play() and positions ~= nil and Rules.all_parked(state, positions.blocks))
    for index, id in ipairs(Rules.ids) do
        local status = state.bombs[index]
        local value = "idle"
        if running and status == "armed" then
            value = positions and Rules.contained(state, positions.blocks[id]) and "safe"
                or (Rules.deadline(state, index) - elapsed() <= 6 and "urgent" or "armed")
        elseif status == "saved" then value = "spent" end
        effect_state(api, "signal-" .. id, value)
    end
    for index, direction in ipairs(Rules.bays) do
        effect_state(api, "bay-" .. string.lower(direction), index == Rules.bay(state) and "active" or "idle")
    end
    effect_state(api, "reactor-status", state.charge == 0 and "broken" or state.charge <= 2 and "weak" or "healthy")
end

function Game.on_start(api)
    api.lobby:set_enabled(false)
    api.session:start("cuboom", { mode = "cooperative" })
    api.world:watch_positions(Rules.ids)
    api.ui:set_document(Hud.document())
    present(api)
end

function Game.on_tick(api, delta)
    local connected = api.network:is_connected()
    if connected ~= online then
        online = connected
        if online then hasBeenOnline = true; connect(api) end
    end
    if online then store:update(api, delta) elseif not hasBeenOnline then localAge += delta end
    positions = api.world:get_positions()
    if positions and positions.worldId ~= "starter-world" then positions = nil end
    noticeTime = math.max(0, noticeTime - delta)
    refresh -= delta
    if refresh > 0 then return end
    if state.phase == "running" and positions and can_play() then
        dispatch(api, "resolve", { positions = positions.blocks, at = elapsed() })
    end
    present(api)
    refresh = 0.1
end

function Game.on_network_message(api, event)
    if online and store then store:receive(api, event) end
end

function Game.on_ui_event(api, event)
    if event.phase ~= "activate" then return end
    if event.action == "cuboom.advance" then
        dispatch(api, (state.phase == "won" or state.phase == "lost") and "replay" or "start")
    elseif event.action == "cuboom.cash" and positions then
        dispatch(api, "resolve", { positions = positions.blocks, at = elapsed(), cashIn = true })
    end
    present(api)
end

function Game.on_save()
    return { state = state, age = elapsed() - state.clock }
end
function Game.on_restore(api, saved)
    local restored = type(saved) == "table" and Rules.validate(saved.state)
    if not restored or type(saved.age) ~= "number" or saved.age ~= saved.age or saved.age < 0 or saved.age > 3600 then
        error("Invalid Cuboom save")
    end
    store, online, hasBeenOnline = nil, false, false
    positions, visualStates, uiText = nil, {}, {}
    accept(api, restored, nil, saved.age, false)
    api.world:watch_positions(Rules.ids)
    present(api)
end
return Game
