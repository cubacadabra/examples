-- The Wild West is a small course built around the platform's obby primitives.
-- The manifest owns the physical route; this script owns feedback and the
-- summit goal.

-- @include "@cubacadabra/obby-v1.luau"

local Game = {}
local obby = CubaObby.create({})
local summit_reached = false
local status = "REACH THE WATER TOWER"

local function document()
    return {
        nodes = {
            {
                id = "course-title",
                kind = "text",
                text = "THE CANYON RUN",
                layout = { anchor = "topLeft", width = 300, height = 30, offset = { 26, 122 } },
                style = { color = "#F7F5E9", fontSize = 20 },
            },
            {
                id = "course-status",
                kind = "text",
                text = status,
                layout = { anchor = "topLeft", width = 360, height = 26, offset = { 26, 158 } },
                style = { color = "#57E5D0", fontSize = 14 },
            },
            {
                id = "course-checkpoint",
                kind = "text",
                text = "CHECKPOINT  TRAILHEAD",
                layout = { anchor = "topLeft", width = 300, height = 22, offset = { 26, 190 } },
                style = { color = "#F1E95B", fontSize = 12 },
            },
            {
                id = "course-deaths",
                kind = "text",
                text = "FALLS  0",
                layout = { anchor = "topLeft", width = 200, height = 22, offset = { 26, 218 } },
                style = { color = "#F7F5E9", fontSize = 12 },
            },
            {
                id = "course-help",
                kind = "text",
                text = "WASD / JOYSTICK  MOVE   SPACE / JUMP   FORWARD / BACK CLIMBS LADDERS",
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
    local state, checkpoint, deaths = obby:status()
    api.ui:set_text("course-status", status)
    api.ui:set_text("course-checkpoint", "CHECKPOINT  " .. string.upper(checkpoint))
    api.ui:set_text("course-deaths", "FALLS  " .. tostring(deaths) .. "   " .. string.upper(state))
end

function Game.on_start(api)
    api.lobby:set_enabled(false)
    api.lobby:set_status("Climb the water tower, cross the canyon, reach the summit.")
    api.session:start("the-wild-west", { mode = "preview" })
    api.ui:set_document(document())
    update_hud(api)
end

function Game.on_player_event(api, event)
    obby:handle(api, event)
    if event.kind == "checkpoint" and event.id == "summit" and not summit_reached then
        summit_reached = true
        status = "SUMMIT REACHED  •  CANYON CONQUERED"
        api.lobby:set_status("The summit is yours. Try the route again with fewer falls.")
    elseif event.kind == "checkpoint" then
        status = "CHECKPOINT SAVED  " .. string.upper(event.id)
    elseif event.kind == "death" then
        status = "YOU FELL  •  RETURNING TO " .. string.upper(event.checkpoint or "TRAILHEAD")
    elseif event.kind == "respawn" then
        status = "TRY AGAIN  •  WATCH THE NEXT GAP"
    end
    update_hud(api)
end

return Game
