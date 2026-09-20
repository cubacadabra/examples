-- Welcome to Cubacadabra. Add your game rules and UI here.
local Game = {}

function Game.on_start(api)
    api.lobby:set_enabled(false)
    api.lobby:set_status("Scratch" .. " is ready")
    api.session:start("scratch", { mode = "preview" })
end

return Game
