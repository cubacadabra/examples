-- Cubacadabra disclosure SDK v1.
--
-- Keeps optional game-owned UI collapsed behind one action without imposing
-- any layout, wording, or game rules on the document.

local CubaDisclosure = {}
CubaDisclosure.__index = CubaDisclosure

local function require_name(config, key)
    local value = config[key]
    if type(value) ~= "string" or #value < 1 or #value > 64 then
        error("CubaDisclosure config." .. key .. " must be 1-64 bytes")
    end
    return value
end

function CubaDisclosure.create(config)
    if type(config) ~= "table" then
        error("CubaDisclosure.create requires a config table")
    end

    local node_ids = config.nodeIds
    if type(node_ids) ~= "table" or #node_ids < 1 or #node_ids > 32 then
        error("CubaDisclosure config.nodeIds must contain 1-32 node ids")
    end

    local copied_ids = {}
    for index, node_id in ipairs(node_ids) do
        if type(node_id) ~= "string" or #node_id < 1 or #node_id > 64 then
            error("CubaDisclosure config.nodeIds[" .. index .. "] must be 1-64 bytes")
        end
        copied_ids[index] = node_id
    end

    if config.open ~= nil and type(config.open) ~= "boolean" then
        error("CubaDisclosure config.open must be a boolean")
    end

    local trigger_id = nil
    if config.triggerId ~= nil then
        trigger_id = require_name(config, "triggerId")
    end

    return setmetatable({
        action = require_name(config, "action"),
        triggerId = trigger_id,
        nodeIds = copied_ids,
        open = config.open == true,
    }, CubaDisclosure)
end

function CubaDisclosure:set_open(api, open)
    self.open = open == true
    for _, node_id in ipairs(self.nodeIds) do
        api.ui:set_visible(node_id, self.open)
    end
    if self.triggerId ~= nil then
        api.ui:set_checked(self.triggerId, self.open)
    end
end

function CubaDisclosure:sync(api)
    self:set_open(api, self.open)
end

function CubaDisclosure:handle(api, event)
    if type(event) ~= "table"
        or event.phase ~= "activate"
        or event.action ~= self.action
    then
        return false
    end

    self:set_open(api, not self.open)
    return true
end

return CubaDisclosure
