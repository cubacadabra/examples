local Config = require("./config")
local Rules = require("./rules")
local View = {}
function View.document()
    return {
        nodes = {
            { id = "round-status", kind = "text", text = "",
                layout = { anchor = "bottom", width = "92%", maxWidth = 780, height = 44, offset = { 0, -162 } },
                style = { foreground = "#F7F5E9", background = "#0B102BB0", fontSize = 15, textAlign = "center", cornerRadius = 8 } },
            { id = "context-action", kind = "button", text = "LIFT", action = "cuboom.context", visible = false,
                layout = { anchor = "bottom", width = 100, height = 44, offset = { 0, -28 } },
                style = { background = "#0B102BF5", foreground = "#F7F5E9", borderColor = "#57E5D0", borderWidth = 1, cornerRadius = 17, fontSize = 14, textAlign = "center" } },
            {
                id = "player-joystick",
                kind = "joystick",
                action = "player.move",
                layout = { anchor = "bottomLeft", width = 120, height = 120, offset = { 20, -24 } },
                style = { background = "#0B102BC9", borderColor = "#57E5D055", borderWidth = 2, cornerRadius = 60, accent = "#57E5D0" },
            },
            {
                id = "player-jump",
                kind = "button",
                text = "JUMP",
                action = "player.jump",
                layout = { anchor = "bottomRight", width = 86, height = 44, offset = { -22, -84 } },
                style = { background = "#0B102BF5", borderColor = "#57E5D0", borderWidth = 2, cornerRadius = 17, foreground = "#F7F5E9", fontSize = 14, textAlign = "center" },
            },
            {
                id = "player-run",
                kind = "button",
                text = "RUN",
                action = "player.run",
                layout = { anchor = "bottomRight", width = 86, height = 44, offset = { -22, -30 } },
                style = { background = "#0B102BF5", borderColor = "#57E5D0", borderWidth = 2, cornerRadius = 17, foreground = "#F7F5E9", fontSize = 14, textAlign = "center" },
            },
        },
    }
end

return View
