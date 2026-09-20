local CubaObby = require("@cubacadabra/obby")

local Game = {}
local obby = CubaObby.create({})
local status = "REACH THE FINISH"

local function document()
    return {
        nodes = {
            {
                id = "course-title",
                kind = "text",
                text = "scene-101",
                layout = { anchor = "topLeft", width = 420, height = 30, offset = { 26, 122 } },
                style = { color = "#F7F5E9", fontSize = 20 },
            },
            {
                id = "course-status",
                kind = "text",
                text = status,
                layout = { anchor = "topLeft", width = 420, height = 26, offset = { 26, 158 } },
                style = { color = "#57E5D0", fontSize = 14 },
            },
            {
                id = "course-checkpoint",
                kind = "text",
                text = "CHECKPOINT  START",
                layout = { anchor = "topLeft", width = 320, height = 22, offset = { 26, 190 } },
                style = { color = "#F1E95B", fontSize = 12 },
            },
            {
                id = "course-help",
                kind = "text",
                text = "MOVE  •  JUMP  •  REACH THE FINISH",
                layout = { anchor = "bottom", width = "90%", maxWidth = 620, height = 24, offset = { 0, -24 } },
                style = { color = "#F7F5E9B8", fontSize = 11, textAlign = "center" },
            },
            {
                id = "player-joystick",
                kind = "joystick",
                action = "player.move",
                layout = { anchor = "bottomLeft", width = 120, height = 120, offset = { 20, -24 } },
                style = {
                    background = "#0B102BC9",
                    borderColor = "#57E5D055",
                    borderWidth = 2,
                    cornerRadius = 60,
                    accent = "#57E5D0",
                },
            },
            {
                id = "player-jump",
                kind = "button",
                text = "JUMP",
                action = "player.jump",
                layout = { anchor = "bottomRight", width = 86, height = 44, offset = { -22, -84 } },
                style = {
                    background = "#0B102BF5",
                    borderColor = "#57E5D0",
                    borderWidth = 2,
                    cornerRadius = 17,
                    foreground = "#F7F5E9",
                    accent = "#57E5D0",
                    textAlign = "center",
                    fontSize = 14,
                },
            },
            {
                id = "player-run",
                kind = "button",
                text = "RUN",
                action = "player.run",
                layout = { anchor = "bottomRight", width = 86, height = 44, offset = { -22, -30 } },
                style = {
                    background = "#0B102BF5",
                    borderColor = "#57E5D0",
                    borderWidth = 2,
                    cornerRadius = 17,
                    foreground = "#F7F5E9",
                    accent = "#57E5D0",
                    textAlign = "center",
                    fontSize = 14,
                },
            },
        },
    }
end

local function update_hud(api)
    local snapshot = obby:status()
    api.ui:set_text("course-status", status)
    api.ui:set_text("course-checkpoint", "CHECKPOINT  " .. string.upper(snapshot.checkpoint))
end

function Game.on_start(api)
    api.lobby:set_enabled(false)
    api.lobby:set_status("Jump across the platforms and reach the finish.")
    api.session:start("scene-101", { mode = "preview" })
    api.ui:set_document(document())
    update_hud(api)
end

function Game.on_player_event(api, event)
    obby:handle(api, event)
    if event.kind == "checkpoint" and event.id == "finish" then
        status = "COURSE COMPLETE  •  PLAY IT AGAIN"
    elseif event.kind == "checkpoint" then
        status = "CHECKPOINT SAVED  •  KEEP GOING"
    elseif event.kind == "death" then
        status = "YOU FELL  •  TRY THE NEXT JUMP"
    elseif event.kind == "respawn" then
        status = "BACK IN  •  YOU CAN DO THIS"
    end
    update_hud(api)
end

return Game
