local Hud = {}
local ink, paper, mint = "#101B2EF2", "#F4F5EA", "#73E0BE"
local function text(id, value, size, height)
    return { id = id, kind = "text", text = value, layout = { width = "fill", height = height },
        style = { foreground = paper, fontSize = size } }
end
local function button(id, label, action, layout)
    return { id = id, kind = "button", text = label, action = action, layout = layout,
        style = { background = ink, foreground = paper, borderColor = mint, borderWidth = 1, cornerRadius = 10, fontSize = 14, textAlign = "center" } }
end
function Hud.document()
    return { nodes = {
        { id = "scoreboard", kind = "panel",
            layout = { anchor = "topLeft", width = "92%", maxWidth = 360, height = 132, offset = { 16, 80 }, padding = 12, gap = 4 },
            style = { background = ink, cornerRadius = 10 }, children = {
                text("title", "CUBOOM / 1 OF 5", 18, 24),
                text("objective", "Push bombs into the NORTH bay.", 14, 22),
                text("score", "REACTOR 5/5   SCORE 0", 13, 20),
                text("fuse", "Ready when you are.", 14, 30),
            } },
        { id = "message", kind = "text", text = "Walk into cubes to push. Jump to escape a trap.",
            layout = { anchor = "topLeft", width = "92%", maxWidth = 360, height = 64, offset = { 16, 220 } },
            style = { foreground = paper, background = ink, fontSize = 14, cornerRadius = 8 } },
        button("round-action", "START ROUND", "cuboom.advance", { anchor = "bottom", width = 154, height = 48, offset = { 0, -174 } }),
        button("cash-in", "DETONATE SAFELY", "cuboom.cash", { anchor = "bottom", width = 178, height = 48, offset = { 0, -174 } }),
        { id = "player-joystick", kind = "joystick", action = "player.move",
            layout = { anchor = "bottomLeft", width = 112, height = 112, offset = { 20, -24 } },
            style = { background = ink, borderColor = mint, borderWidth = 1, cornerRadius = 56, accent = mint } },
        button("player-jump", "JUMP / FREE", "player.jump", { anchor = "bottomRight", width = 102, height = 48, offset = { -20, -82 } }),
        button("player-run", "RUN", "player.run", { anchor = "bottomRight", width = 102, height = 48, offset = { -20, -24 } }),
    } }
end
return Hud
