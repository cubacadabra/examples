-- Cubacadabra cycle SDK v1.
--
-- A small reusable day/night (or calm/storm) clock for worlds with repeating
-- phases. The game can mirror phase changes into shared state when a session
-- needs one common clock; this helper itself is intentionally deterministic
-- and local.

local CubaCycle = {}
CubaCycle.__index = CubaCycle

local function positive(value, fallback)
    if type(value) ~= "number" or value <= 0 then
        return fallback
    end
    return value
end

function CubaCycle.create(config)
    if type(config) ~= "table" then
        error("CubaCycle.create requires a config table")
    end
    return setmetatable({
        day_seconds = positive(config.daySeconds, 45),
        night_seconds = positive(config.nightSeconds, 30),
        day = math.max(1, math.floor(config.startDay or 1)),
        phase = config.startPhase == "night" and "night" or "day",
        elapsed = 0,
        onPhase = config.onPhase,
    }, CubaCycle)
end

function CubaCycle:update(api, delta_seconds)
    local remaining = math.max(0, delta_seconds)
    local changed = false
    while remaining > 0 do
        local duration = self.phase == "night" and self.night_seconds or self.day_seconds
        local step = math.min(remaining, duration - self.elapsed)
        self.elapsed = self.elapsed + step
        remaining = remaining - step
        if self.elapsed >= duration - 0.0001 then
            self.elapsed = 0
            if self.phase == "day" then
                self.phase = "night"
            else
                self.phase = "day"
                self.day = self.day + 1
            end
            changed = true
            if type(self.onPhase) == "function" then
                self.onPhase(api, self.phase, self.day, self)
            end
        end
        if step <= 0 then
            break
        end
    end
    return changed
end

function CubaCycle:status()
    local duration = self.phase == "night" and self.night_seconds or self.day_seconds
    return {
        phase = self.phase,
        day = self.day,
        elapsed = self.elapsed,
        remaining = math.max(0, duration - self.elapsed),
    }
end

function CubaCycle:sync(phase, day, elapsed)
    if phase == "day" or phase == "night" then
        self.phase = phase
    end
    if type(day) == "number" then
        self.day = math.max(1, math.floor(day))
    end
    if type(elapsed) == "number" then
        self.elapsed = math.max(0, elapsed)
    end
end

return CubaCycle
