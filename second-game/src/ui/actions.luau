local SignalUI = {}

local function route_text(state, node_count)
    local parts = {}
    for index = 1, node_count do
        local label = string.format("%02d", index)
        if index < state.nextNode then
            parts[index] = "X" .. label
        elseif state.phase == "running" and state.nextNode == index then
            parts[index] = ">" .. label .. "<"
        else
            parts[index] = label
        end
    end

    local uplink = "UPLINK"
    if state.phase == "uplink" then
        uplink = ">UPLINK<"
    elseif state.phase == "overdrive" then
        uplink = "XUPLINK"
    end
    return table.concat(parts, "  ") .. "  " .. uplink
end

function SignalUI.update(api, relay, state)
    local status
    local help = relay.message
    if state.phase == "overdrive" then
        status = "OVERDRIVE"
        help = "Relay linked! The whole relay is live."
    elseif state.phase == "uplink" then
        status = "UPLINK OPEN"
    else
        status = string.format("NODE %02d / %02d", state.nextNode, relay:node_count())
    end

    api.ui:set_text("signal-kicker", string.format("SIGNAL RUN • %d LINKS", state.links))
    api.ui:set_text("signal-status", status)
    api.ui:set_text("signal-route", route_text(state, relay:node_count()))
    api.ui:set_text("signal-help", help)
    api.ui:set_text("signal-schema", relay:schema_summary())
end

function SignalUI.bind(relay)
    relay:subscribe(function(api, state)
        SignalUI.update(api, relay, state)
    end)
end

return SignalUI
