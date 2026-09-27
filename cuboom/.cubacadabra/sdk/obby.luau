-- Cubacadabra obby SDK v1.
--
-- The runtime owns physics, ladder volumes, checkpoints, fall detection, and
-- respawn. This helper keeps the small amount of game-owned course state and
-- gives packages one place to react to the player lifecycle.

local CubaObby = {}
CubaObby.__index = CubaObby
local LIVE_STATE_CHANNEL = "__player_state"

local function publish_state(api, obby)
    if type(api) ~= "table"
        or type(api.network) ~= "table"
        or type(api.network.publish) ~= "function" then
        return
    end
    api.network:publish(LIVE_STATE_CHANNEL, {
        kind = "obby",
        checkpoint = obby.checkpoint,
        deaths = obby.deaths,
        alive = obby.state ~= "dead",
    })
end

function CubaObby.create(config)
    if type(config) ~= "table" then
        error("CubaObby.create requires a config table")
    end
    return setmetatable({
        checkpoint = "start",
        deaths = 0,
        state = "ready",
        onSpawn = config.onSpawn,
        onCheckpoint = config.onCheckpoint,
        onDeath = config.onDeath,
        onRespawn = config.onRespawn,
    }, CubaObby)
end

function CubaObby:handle(api, event)
    if type(event) ~= "table" or type(event.kind) ~= "string" then
        return false
    end
    if event.kind == "spawn" then
        self.deaths = event.deaths or self.deaths
        self.state = "running"
        if type(self.onSpawn) == "function" then
            self.onSpawn(api, event, self)
        end
        publish_state(api, self)
        return true
    elseif event.kind == "checkpoint" then
        self.checkpoint = event.id or self.checkpoint
        self.state = "running"
        if type(self.onCheckpoint) == "function" then
            self.onCheckpoint(api, event, self)
        end
        publish_state(api, self)
        return true
    elseif event.kind == "death" then
        self.deaths = event.deaths or self.deaths
        self.state = "dead"
        if type(self.onDeath) == "function" then
            self.onDeath(api, event, self)
        end
        publish_state(api, self)
        return true
    elseif event.kind == "respawn" then
        self.checkpoint = event.checkpoint or self.checkpoint
        self.deaths = event.deaths or self.deaths
        self.state = "running"
        if type(self.onRespawn) == "function" then
            self.onRespawn(api, event, self)
        end
        publish_state(api, self)
        return true
    end
    return false
end

function CubaObby:status()
    return {
        state = self.state,
        checkpoint = self.checkpoint,
        deaths = self.deaths,
    }
end

return CubaObby
