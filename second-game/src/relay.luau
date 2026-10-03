local CubaSharedState = require("@cubacadabra/shared-state")

local SignalRelay = {}
SignalRelay.__index = SignalRelay

local STATE_CHANNEL = "signal-run-round"
local OVERDRIVE_SECONDS = 5.5
local NODE_IDS = { "node-1", "node-2", "node-3", "node-4" }
local NODE_POSITIONS = {
    { -15, 0, 10 },
    { 15, 0, 1 },
    { -15, 0, -8 },
    { 15, 0, -17 },
}
local UPLINK_POSITION = { 0, 0, -31 }
local INTERACTION_ZONE_SCHEMA = "cuba:interaction-zone.v1"

local function initial_state(round, links)
    return {
        version = 1,
        round = round or 1,
        phase = "running",
        nextNode = 1,
        links = links or 0,
        lastAction = { type = "round_reset", round = round or 1 },
    }
end

local function validate_state(payload)
    if type(payload) ~= "table"
        or payload.version ~= 1
        or type(payload.round) ~= "number"
        or payload.round < 1
        or type(payload.nextNode) ~= "number"
        or payload.nextNode < 1
        or payload.nextNode > #NODE_IDS + 1
        or (payload.phase ~= "running"
            and payload.phase ~= "uplink"
            and payload.phase ~= "overdrive")
    then
        return nil
    end
    if payload.phase == "running" and payload.nextNode > #NODE_IDS then
        return nil
    end
    if payload.phase ~= "running" and payload.nextNode ~= #NODE_IDS + 1 then
        return nil
    end

    return {
        version = 1,
        round = payload.round,
        phase = payload.phase,
        nextNode = payload.nextNode,
        links = type(payload.links) == "number" and math.max(0, payload.links) or 0,
        lastAction = type(payload.lastAction) == "table" and payload.lastAction or {},
    }
end

local function reduce_state(state, intent)
    if intent.type == "capture"
        and state.phase == "running"
        and intent.round == state.round
        and intent.node == state.nextNode
    then
        local next_node = state.nextNode + 1
        return {
            version = 1,
            round = state.round,
            phase = next_node > #NODE_IDS and "uplink" or "running",
            nextNode = next_node,
            links = state.links,
            lastAction = { type = "capture", node = intent.node },
        }
    end

    if intent.type == "uplink"
        and state.phase == "uplink"
        and intent.round == state.round
    then
        return {
            version = 1,
            round = state.round,
            phase = "overdrive",
            nextNode = state.nextNode,
            links = state.links + 1,
            lastAction = { type = "uplink" },
        }
    end

    if intent.type == "reset"
        and state.phase == "overdrive"
        and intent.round == state.round
    then
        return initial_state(state.round + 1, state.links)
    end

    -- A nil result also makes repeated or remotely-completed intents
    -- idempotent; the SDK removes them from its queue.
    return nil
end

local function node_index(id)
    for index, node_id in ipairs(NODE_IDS) do
        if id == node_id then
            return index
        end
    end
    return nil
end

function SignalRelay.create()
    local relay = setmetatable({
        fallbackState = initial_state(),
        message = "Follow the pulsing gate. The relay is shared.",
        resetQueued = false,
        schema = nil,
    }, SignalRelay)

    relay.shared = CubaSharedState.create({
        channel = STATE_CHANNEL,
        initial = function()
            return initial_state()
        end,
        validate = validate_state,
        reduce = reduce_state,
        intentExpired = function(state, intent)
            return intent.round ~= state.round
        end,
        onChange = function(api, state, previous, event)
            relay:on_change(api, state, previous, event)
        end,
    })
    relay.shared:subscribe(function(api, state)
        -- Effects are a DataModel consumer. They react to accepted snapshots
        -- instead of being pushed from interaction or tick code.
        relay:sync_effects(api, state)
    end)
    return relay
end

function SignalRelay:state()
    return self.shared.value or self.fallbackState
end

function SignalRelay:node_count()
    return #NODE_IDS
end

function SignalRelay:node_id(index)
    return NODE_IDS[index]
end

function SignalRelay:schema_summary()
    if self.schema == nil then
        return "ENGINE SCHEMA UNAVAILABLE"
    end

    local fields = {}
    for _, property in ipairs(self.schema.properties) do
        if property.id == "cuba:interaction-zone.label"
            or property.id == "cuba:interaction-zone.radius"
        then
            fields[#fields + 1] = property.name
        end
    end
    return string.format(
        "ENGINE %s • %s",
        self.schema.name,
        table.concat(fields, " / ")
    )
end

function SignalRelay:remaining_seconds()
    if self:state().phase ~= "overdrive" then
        return 0
    end
    return math.max(0, OVERDRIVE_SECONDS - self.shared.ageSeconds)
end

function SignalRelay:sync_effects(api, state)
    for index, id in ipairs(NODE_IDS) do
        local effect_state = "locked"
        if index < state.nextNode then
            effect_state = "captured"
        elseif state.phase == "running" and state.nextNode == index then
            effect_state = "active"
        end
        api.effects:set_state(id, effect_state)
    end

    local uplink_state = "locked"
    if state.phase == "uplink" then
        uplink_state = "active"
    elseif state.phase == "overdrive" then
        uplink_state = "overdrive"
    end
    api.effects:set_state("uplink", uplink_state)
end

function SignalRelay:on_change(api, state, previous, _event)
    if previous ~= nil then
        local captured_node = state.nextNode > previous.nextNode
            and state.nextNode - 1
            or nil
        if captured_node ~= nil and NODE_IDS[captured_node] ~= nil then
            if captured_node == 2 then
                api.audio:play("relay-chain")
            elseif captured_node == 4 then
                api.audio:play("uplink-ready")
            else
                api.audio:play("relay-hit")
            end
            api.effects:play(
                "relay-capture",
                { position = NODE_POSITIONS[captured_node] }
            )
        end
        if state.phase == "overdrive" and previous.phase ~= "overdrive" then
            api.audio:play("relay-overdrive")
            api.effects:play("overdrive-burst", { position = UPLINK_POSITION })
        end
    end

    if state.round ~= (previous and previous.round or state.round) then
        self.resetQueued = false
        self.message = "New relay! Follow node 01."
    elseif state.phase == "overdrive" then
        self.message = "Signal locked! The whole relay is live."
    elseif state.phase == "uplink" and (previous == nil or previous.phase ~= "uplink") then
        self.message = "All nodes linked! Sprint to the uplink."
    elseif state.lastAction.type == "capture"
        and type(state.lastAction.node) == "number"
    then
        self.message = string.format(
            "Node %02d linked • next node %02d",
            state.lastAction.node,
            state.nextNode
        )
    end
end

function SignalRelay:initialize(api)
    self.schema = api.interactions:get_schema(INTERACTION_ZONE_SCHEMA)
    self.shared:start(api)
end

function SignalRelay:subscribe(listener)
    return self.shared:subscribe(listener)
end

function SignalRelay:request_interaction(api, id)
    local state = self:state()
    if id == "uplink" then
        if state.phase == "uplink" then
            self.shared:dispatch(api, { type = "uplink", round = state.round })
        end
        return
    end

    local index = node_index(id)
    if index == nil or state.phase ~= "running" then
        return
    end
    if index ~= state.nextNode then
        return
    end

    self.shared:dispatch(api, { type = "capture", node = index, round = state.round })
end

function SignalRelay:receive(api, event)
    return self.shared:receive(api, event)
end

function SignalRelay:tick(api, delta_seconds)
    self.shared:update(api, delta_seconds)
    local state = self:state()
    if state.phase == "overdrive"
        and self:remaining_seconds() <= 0
        and not self.resetQueued
    then
        self.resetQueued = true
        self.shared:dispatch(api, { type = "reset", round = state.round })
    end
end

return SignalRelay
