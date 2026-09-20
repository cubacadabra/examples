-- Cubacadabra survival SDK v1.
--
-- The runtime owns health, hazards, fall detection, and respawn. This helper
-- keeps the small amount of game-owned lifecycle state that most survival
-- games need without prescribing a particular objective or HUD.

local CubaSurvival = {}
CubaSurvival.__index = CubaSurvival
local LIVE_STATE_CHANNEL = "__player_state"

local function publish_state(api, survival)
    if type(api) ~= "table"
        or type(api.network) ~= "table"
        or type(api.network.publish) ~= "function" then
        return
    end
    api.network:publish(LIVE_STATE_CHANNEL, {
        kind = "survival",
        health = survival.health,
        maxHealth = survival.max_health,
        deaths = survival.deaths,
        alive = survival.state ~= "dead",
    })
end

function CubaSurvival.create(config)
    if type(config) ~= "table" then
        error("CubaSurvival.create requires a config table")
    end
    return setmetatable({
        health = 0,
        max_health = 0,
        deaths = 0,
        state = "waiting",
        source = nil,
        onSpawn = config.onSpawn,
        onDamage = config.onDamage,
        onHeal = config.onHeal,
        onDeath = config.onDeath,
        onRespawn = config.onRespawn,
    }, CubaSurvival)
end

function CubaSurvival:handle(api, event)
    if type(event) ~= "table" or type(event.kind) ~= "string" then
        return false
    end
    if event.kind == "spawn" then
        self.health = event.health or self.health
        self.max_health = event.maxHealth or self.max_health
        self.deaths = event.deaths or self.deaths
        self.source = nil
        self.state = "running"
        if type(self.onSpawn) == "function" then
            self.onSpawn(api, event, self)
        end
        publish_state(api, self)
        return true
    elseif event.kind == "damage" then
        self.health = event.health or self.health
        self.max_health = event.maxHealth or self.max_health
        self.source = event.source or self.source
        self.state = "running"
        if type(self.onDamage) == "function" then
            self.onDamage(api, event, self)
        end
        publish_state(api, self)
        return true
    elseif event.kind == "heal" then
        self.health = event.health or self.health
        self.max_health = event.maxHealth or self.max_health
        self.source = event.source or self.source
        self.state = "running"
        if type(self.onHeal) == "function" then
            self.onHeal(api, event, self)
        end
        publish_state(api, self)
        return true
    elseif event.kind == "death" then
        self.health = event.health or 0
        self.max_health = event.maxHealth or self.max_health
        self.deaths = event.deaths or self.deaths
        self.state = "dead"
        if type(self.onDeath) == "function" then
            self.onDeath(api, event, self)
        end
        publish_state(api, self)
        return true
    elseif event.kind == "respawn" then
        self.health = event.health or self.max_health
        self.max_health = event.maxHealth or self.max_health
        self.deaths = event.deaths or self.deaths
        self.source = nil
        self.state = "running"
        if type(self.onRespawn) == "function" then
            self.onRespawn(api, event, self)
        end
        publish_state(api, self)
        return true
    end
    return false
end

function CubaSurvival:status()
    return {
        state = self.state,
        health = self.health,
        maxHealth = self.max_health,
        deaths = self.deaths,
        source = self.source,
    }
end

return CubaSurvival
