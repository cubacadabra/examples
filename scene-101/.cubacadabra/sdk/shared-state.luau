-- Cubacadabra shared-state SDK v1.
--
-- This client-side helper keeps the backend contract generic: the server
-- orders opaque snapshots, while each game owns validation and reduction.

local CubaSharedState = {}
CubaSharedState.__index = CubaSharedState

local MAX_PENDING_INTENTS = 32
local DEFAULT_RETRY_SECONDS = 0.75
local DEFAULT_MODE = "coalescing"
local DISTINCT_MODE = "distinct"
local OPERATION_STATUSES = {
    pending = true,
    accepted = true,
    rejected = true,
    expired = true,
}

local function require_function(config, key)
    if type(config[key]) ~= "function" then
        error("CubaSharedState config." .. key .. " must be a function")
    end
end

local function require_listener(listener)
    if type(listener) ~= "function" then
        error("CubaSharedState listener must be a function")
    end
end

function CubaSharedState.create(config)
    if type(config) ~= "table" then
        error("CubaSharedState.create requires a config table")
    end
    if type(config.channel) ~= "string" or #config.channel < 1 or #config.channel > 64 then
        error("CubaSharedState config.channel must be 1-64 bytes")
    end
    require_function(config, "initial")
    require_function(config, "validate")
    require_function(config, "reduce")
    local mode = config.mode or DEFAULT_MODE
    if mode ~= DEFAULT_MODE and mode ~= DISTINCT_MODE then
        error("CubaSharedState config.mode must be coalescing or distinct")
    end
    if mode == DISTINCT_MODE then
        require_function(config, "operationStatus")
    elseif config.operationStatus ~= nil then
        error("CubaSharedState config.operationStatus requires distinct mode")
    end
    if config.intentExpired ~= nil and type(config.intentExpired) ~= "function" then
        error("CubaSharedState config.intentExpired must be a function")
    end
    if config.onChange ~= nil and type(config.onChange) ~= "function" then
        error("CubaSharedState config.onChange must be a function")
    end

    local retry_seconds = config.retrySeconds or DEFAULT_RETRY_SECONDS
    if type(retry_seconds) ~= "number" or retry_seconds <= 0 then
        error("CubaSharedState config.retrySeconds must be positive")
    end

    return setmetatable({
        channel = config.channel,
        initial = config.initial,
        validate = config.validate,
        reduce = config.reduce,
        mode = mode,
        operationStatus = config.operationStatus,
        intentExpired = config.intentExpired,
        onChange = config.onChange,
        listeners = {},
        retrySeconds = retry_seconds,
        value = nil,
        sequence = 0,
        ageSeconds = 0,
        started = false,
        hasSnapshot = false,
        bootstrapValue = nil,
        bootstrapSeconds = 0,
        pending = {},
        inflight = nil,
        inflightSeconds = 0,
    }, CubaSharedState)
end

function CubaSharedState:_operation_status(state, intent)
    if self.mode == DISTINCT_MODE then
        local status = self.operationStatus(state, intent)
        if not OPERATION_STATUSES[status] then
            error("CubaSharedState operationStatus must return pending, accepted, rejected, or expired")
        end
        return status
    end
    if self.intentExpired ~= nil then
        local expired = self.intentExpired(state, intent)
        if type(expired) ~= "boolean" then
            error("CubaSharedState intentExpired must return a boolean")
        end
        if expired then
            return "expired"
        end
    end
    return nil
end

function CubaSharedState:_has_operation_id(operation_id)
    for _, queued in ipairs(self.pending) do
        if queued.operationId == operation_id then
            return true
        end
    end
    return false
end

-- Add a consumer to the ordered state-change feed. Consumers receive the same
-- snapshot that onChange receives, after it has passed validation and after
-- the local model has advanced. This keeps presentation and other sinks from
-- having to poll or be called by the game lifecycle.
function CubaSharedState:subscribe(listener)
    require_listener(listener)
    self.listeners[#self.listeners + 1] = listener
    return listener
end

function CubaSharedState:_publish(api, state, previous, event, context)
    if self.onChange ~= nil then
        self.onChange(api, state, previous, event, context)
    end

    -- Snapshot the listener list so a consumer can subscribe while handling a
    -- change without changing the current publication's ordering.
    local listeners = {}
    for index, listener in ipairs(self.listeners) do
        listeners[index] = listener
    end
    for _, listener in ipairs(listeners) do
        listener(api, state, previous, event, context)
    end
end

function CubaSharedState:_drop_head()
    table.remove(self.pending, 1)
end

function CubaSharedState:_drop_expired_pending()
    local expired = {}
    if self.mode == DISTINCT_MODE or self.intentExpired == nil then
        return expired
    end
    while #self.pending > 0 do
        local intent = self.pending[1]
        if self:_operation_status(self.value, intent) ~= "expired" then
            break
        end
        expired[#expired + 1] = {
            intent = intent,
            status = "expired",
        }
        self:_drop_head()
    end
    return expired
end

function CubaSharedState:_submit_next(api)
    if not self.hasSnapshot or self.inflight ~= nil then
        return
    end

    while #self.pending > 0 do
        local intent = self.pending[1]
        local operation_status = self:_operation_status(self.value, intent)
        if operation_status ~= nil and operation_status ~= "pending" then
            self:_drop_head()
            -- A caller may dispatch an operation after its snapshot has
            -- already arrived. It is complete without another CAS proposal.
        else
            local next_value = self.reduce(self.value, intent)
            if next_value == nil then
                if self.mode == DISTINCT_MODE then
                    error("CubaSharedState distinct reducer returned nil for a pending operation")
                end
                self:_drop_head()
            else
                local validated = self.validate(next_value)
                if validated == nil then
                    error("CubaSharedState reducer returned an invalid state")
                end
                self.inflight = {
                    intent = intent,
                    expectedSequence = self.sequence,
                }
                self.inflightSeconds = 0
                api.network:compare_set_state(
                    self.channel,
                    self.sequence,
                    validated
                )
                return
            end
        end
    end
end

function CubaSharedState:start(api)
    if self.started then
        return
    end
    local initial_value = self.validate(self.initial())
    if initial_value == nil then
        error("CubaSharedState initial state is invalid")
    end
    self.started = true
    self.bootstrapValue = initial_value
    self.bootstrapSeconds = 0
    -- Prime every projection from the model's initial proposal. This is
    -- local presentation only; the retained network snapshot remains the
    -- authority and will be published through the same feed when it arrives.
    self:_publish(api, initial_value, nil, {
        type = "game_state",
        channel = self.channel,
        sequence = 0,
        payload = initial_value,
        bootstrap = true,
    }, {
        initialized = false,
        completedIntent = nil,
        completedStatus = nil,
        expiredIntents = {},
        source = "initial",
    })
    api.network:compare_set_state(self.channel, 0, initial_value)
end

function CubaSharedState:dispatch(api, intent)
    if type(intent) ~= "table" then
        error("CubaSharedState intents must be tables")
    end
    if self.mode == DISTINCT_MODE then
        if type(intent.operationId) ~= "string"
            or #intent.operationId < 1
            or #intent.operationId > 128
        then
            error("CubaSharedState distinct intents require a 1-128 byte operationId")
        end
        if self:_has_operation_id(intent.operationId) then
            return true
        end
    end
    if #self.pending >= MAX_PENDING_INTENTS then
        return false
    end
    self.pending[#self.pending + 1] = intent
    self:_submit_next(api)
    return true
end

function CubaSharedState:receive(api, event)
    if type(event) ~= "table"
        or event.type ~= "game_state"
        or event.channel ~= self.channel
    then
        return false
    end
    if type(event.sequence) ~= "number" or event.sequence < 0 then
        return true
    end

    local next_value = self.validate(event.payload)
    if next_value == nil or event.sequence < self.sequence then
        return true
    end

    if self.hasSnapshot and event.sequence == self.sequence then
        if event.conflict == true and self.inflight ~= nil then
            self.inflight = nil
            self.inflightSeconds = 0
            self:_submit_next(api)
        end
        return true
    end

    local previous_value = self.value
    local was_initialized = self.hasSnapshot
    self.value = next_value
    self.sequence = event.sequence
    self.ageSeconds = type(event.ageMs) == "number"
        and math.max(0, event.ageMs / 1000)
        or 0
    self.hasSnapshot = true
    self.bootstrapValue = nil
    self.bootstrapSeconds = 0

    local completed_intent = nil
    local completed_status = nil
    if self.inflight ~= nil then
        local operation_status = self:_operation_status(self.value, self.inflight.intent)
        local complete = operation_status ~= nil
            and operation_status ~= "pending"
        if operation_status == nil then
            complete = self.reduce(self.value, self.inflight.intent) == nil
        end
        if complete then
            completed_intent = self.inflight.intent
            completed_status = operation_status or "accepted"
            self:_drop_head()
        end
        self.inflight = nil
        self.inflightSeconds = 0
    end
    local expired_intents = self:_drop_expired_pending()

    self:_publish(api, self.value, previous_value, event, {
        initialized = was_initialized,
        completedIntent = completed_intent,
        completedStatus = completed_status,
        expiredIntents = expired_intents,
        source = "network",
    })
    self:_submit_next(api)
    return true
end

function CubaSharedState:update(api, delta_seconds)
    local elapsed = math.max(0, delta_seconds)
    self.ageSeconds = self.ageSeconds + elapsed
    if self.started and not self.hasSnapshot then
        self.bootstrapSeconds = self.bootstrapSeconds + elapsed
        if self.bootstrapSeconds >= self.retrySeconds then
            self.bootstrapSeconds = 0
            api.network:compare_set_state(self.channel, 0, self.bootstrapValue)
        end
        return
    end
    if self.inflight == nil then
        self:_submit_next(api)
        return
    end

    self.inflightSeconds = self.inflightSeconds + elapsed
    if self.inflightSeconds < self.retrySeconds then
        return
    end
    self.inflight = nil
    self.inflightSeconds = 0
    self:_submit_next(api)
end

return CubaSharedState
