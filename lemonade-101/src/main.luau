-- Lemonade 101 is the first behavior-first example. The manifest owns the
-- tiny park and generic interaction zones; this module owns the shift, order,
-- recipe, cash, feedback, and result rules.

local Game = {}

local SHIFT_SECONDS = 180
local GOAL_SERVES = 10
local GOAL_CASH = 30
local INTRO_SECONDS = 2

local CUSTOMERS = {
    { id = "customer-maya", name = "MAYA" },
    { id = "customer-jun", name = "JUN" },
    { id = "customer-priya", name = "PRIYA" },
    { id = "customer-theo", name = "THEO" },
}

local RECIPES = {
    { name = "SWEET LEMONADE", lemons = 1, sugar = 2, ice = true, price = 4 },
    { name = "CLASSIC LEMONADE", lemons = 2, sugar = 1, ice = false, price = 3 },
    { name = "TART LEMONADE", lemons = 3, sugar = 1, ice = false, price = 3 },
}

local GameState = {
    phase = "intro",
    intro_elapsed = 0,
    elapsed = 0,
    served = 0,
    cash = 0,
    mistakes = 0,
    nearby_zone = nil,
    status = "THE STAND OPENS IN A MOMENT",
    cup = { lemons = 0, sugar = 0, ice = false },
}

local function customer()
    return CUSTOMERS[GameState.served % #CUSTOMERS + 1]
end

local function recipe()
    return RECIPES[GameState.served % #RECIPES + 1]
end

local function format_time(seconds)
    local whole = math.max(0, math.floor(seconds))
    return string.format("%02d:%02d", math.floor(whole / 60), whole % 60)
end

local function reset_cup()
    GameState.cup = { lemons = 0, sugar = 0, ice = false }
end

local function cup_text()
    return "CUP  LEMON " .. tostring(GameState.cup.lemons)
        .. "   SUGAR " .. tostring(GameState.cup.sugar)
        .. "   ICE " .. (GameState.cup.ice and "YES" or "NO")
end

local function order_text()
    local wanted = recipe()
    return customer().name .. " WANTS  " .. wanted.name
        .. "  •  " .. tostring(wanted.lemons) .. " LEMON"
        .. "  •  " .. tostring(wanted.sugar) .. " SUGAR"
        .. (wanted.ice and "  •  ICE" or "")
end

local function is_open()
    return GameState.phase == "open" or GameState.phase == "last_call"
end

local function player_controls()
    return {
        nodes = {
            {
                id = "lemonade-title",
                kind = "text",
                text = "LEMONADE 101",
                layout = { anchor = "topLeft", width = 300, height = 30, offset = { 26, 122 } },
                style = { color = "#19343A", fontSize = 20 },
            },
            {
                id = "lemonade-status",
                kind = "text",
                text = GameState.status,
                layout = { anchor = "topLeft", width = 650, height = 26, offset = { 26, 158 } },
                style = { color = "#EF846B", fontSize = 14 },
            },
            {
                id = "lemonade-order",
                kind = "text",
                text = order_text(),
                layout = { anchor = "topLeft", width = 760, height = 24, offset = { 26, 190 } },
                style = { color = "#19343A", fontSize = 12 },
            },
            {
                id = "lemonade-cup",
                kind = "text",
                text = cup_text(),
                layout = { anchor = "topLeft", width = 520, height = 22, offset = { 26, 218 } },
                style = { color = "#4E9A5B", fontSize = 12 },
            },
            {
                id = "lemonade-score",
                kind = "text",
                text = "SHIFT 03:00   CASH $0   SERVED 0 / 10",
                layout = { anchor = "topRight", width = 360, height = 22, offset = { -26, 122 } },
                style = { color = "#19343A", fontSize = 12, textAlign = "end" },
            },
            {
                id = "lemonade-help",
                kind = "text",
                text = "MOVE TO A STATION OR CUSTOMER  •  USE THE ACTION BELOW",
                layout = { anchor = "bottom", width = "90%", maxWidth = 660, height = 24, offset = { 0, -24 } },
                style = { color = "#19343AB8", fontSize = 11, textAlign = "center" },
            },
            {
                id = "player-joystick",
                kind = "joystick",
                action = "player.move",
                layout = { anchor = "bottomLeft", width = 120, height = 120, offset = { 20, -24 } },
                style = { background = "#FFFDF1D9", borderColor = "#19343A55", borderWidth = 2, cornerRadius = 60, accent = "#4E9A5B" },
            },
            {
                id = "player-jump",
                kind = "button",
                text = "JUMP",
                action = "player.jump",
                layout = { anchor = "bottomRight", width = 86, height = 44, offset = { -22, -30 } },
                style = { background = "#FFFDF1F5", borderColor = "#19343A", borderWidth = 2, cornerRadius = 17, foreground = "#19343A", accent = "#4E9A5B", textAlign = "center", fontSize = 14 },
            },
            {
                id = "lemonade-action",
                kind = "button",
                text = "ACTION",
                action = "lemonade.action",
                visible = false,
                layout = { anchor = "bottomRight", width = 126, height = 44, offset = { -22, -84 } },
                style = { background = "#EF846B", borderColor = "#19343A", borderWidth = 2, cornerRadius = 17, foreground = "#FFFDF1", accent = "#F8D94E", textAlign = "center", fontSize = 13 },
            },
            {
                id = "lemonade-dump",
                kind = "button",
                text = "DUMP CUP",
                action = "lemonade.dump",
                visible = false,
                layout = { anchor = "bottomRight", width = 126, height = 44, offset = { -22, -138 } },
                style = { background = "#19343AEF", borderColor = "#FFFDF1", borderWidth = 2, cornerRadius = 17, foreground = "#FFFDF1", accent = "#9BE3F1", textAlign = "center", fontSize = 12 },
            },
            {
                id = "lemonade-play-again",
                kind = "button",
                text = "PLAY AGAIN",
                action = "lemonade.play_again",
                visible = false,
                layout = { anchor = "bottom", width = 140, height = 44, offset = { 0, -56 } },
                style = { background = "#EF846B", borderColor = "#19343A", borderWidth = 2, cornerRadius = 17, foreground = "#FFFDF1", accent = "#F8D94E", textAlign = "center", fontSize = 13 },
            },
        },
    }
end

local function update_hud(api)
    local remaining = SHIFT_SECONDS - GameState.elapsed
    api.ui:set_text("lemonade-status", GameState.status)
    api.ui:set_text("lemonade-order", GameState.phase == "results" and GameState.status or order_text())
    api.ui:set_text("lemonade-cup", cup_text())
    api.ui:set_text("lemonade-score", "SHIFT " .. format_time(remaining)
        .. "   CASH $" .. tostring(GameState.cash)
        .. "   SERVED " .. tostring(GameState.served) .. " / " .. tostring(GOAL_SERVES))

    local action_text = ""
    local action_visible = false
    if is_open() then
        if GameState.nearby_zone == "station-lemons" then
            action_text, action_visible = "ADD LEMON", true
        elseif GameState.nearby_zone == "station-sugar" then
            action_text, action_visible = "ADD SUGAR", true
        elseif GameState.nearby_zone == "station-ice" then
            action_text, action_visible = "ADD ICE", true
        elseif GameState.nearby_zone == customer().id then
            action_text, action_visible = "SERVE " .. customer().name, true
        end
    end
    api.ui:set_text("lemonade-action", action_text)
    api.ui:set_visible("lemonade-action", action_visible)
    api.ui:set_visible("lemonade-dump", is_open() and GameState.nearby_zone == "station-trash" and (GameState.cup.lemons > 0 or GameState.cup.sugar > 0 or GameState.cup.ice))
    api.ui:set_visible("lemonade-play-again", GameState.phase == "results")
end

local function add_lemon(api)
    if GameState.nearby_zone ~= "station-lemons" then return end
    GameState.cup.lemons = math.min(3, GameState.cup.lemons + 1)
    GameState.status = "LEMON ADDED  •  BUILD THE ORDER"
end

local function add_sugar(api)
    if GameState.nearby_zone ~= "station-sugar" then return end
    GameState.cup.sugar = math.min(2, GameState.cup.sugar + 1)
    GameState.status = "SUGAR ADDED  •  BUILD THE ORDER"
end

local function add_ice(api)
    if GameState.nearby_zone ~= "station-ice" then return end
    GameState.cup.ice = true
    GameState.status = "ICE ADDED  •  KEEP IT COOL"
end

local function dump_cup()
    if GameState.nearby_zone ~= "station-trash" then return end
    reset_cup()
    GameState.status = "CUP DUMPED  •  TRY THE ORDER AGAIN"
end

local function serve(api)
    if GameState.nearby_zone ~= customer().id then
        GameState.status = "FIND " .. customer().name .. " TO SERVE THIS ORDER"
        return
    end
    local wanted = recipe()
    local matches = GameState.cup.lemons == wanted.lemons
        and GameState.cup.sugar == wanted.sugar
        and GameState.cup.ice == wanted.ice
    if not matches then
        GameState.mistakes += 1
        GameState.status = customer().name .. ": THAT TASTES WRONG!"
        api.effects:play("serve-wrong", { position = { 0, 1, 0 } })
        return
    end

    GameState.cash += wanted.price
    GameState.served += 1
    reset_cup()
    api.effects:play("serve-success", { position = { 0, 1, 0 } })
    GameState.status = customer().name .. ": PERFECT!  +$" .. tostring(wanted.price)
    if GameState.served >= GOAL_SERVES then
        GameState.phase = "results"
        GameState.status = "STAND SAVED!  YOU MADE $" .. tostring(GameState.cash)
    end
end

local function start_shift(api)
    GameState.phase = "open"
    GameState.elapsed = 0
    GameState.served = 0
    GameState.cash = 0
    GameState.mistakes = 0
    GameState.nearby_zone = nil
    reset_cup()
    GameState.status = "SHIFT OPEN  •  MAYA WANTS SWEET LEMONADE"
    api.lobby:set_status("Serve ten customers and earn $30 before sunset.")
end

function Game.on_start(api)
    api.lobby:set_enabled(false)
    api.lobby:set_status("Open the stand, follow the orders, and save the park shift.")
    api.session:start("lemonade-101", { mode = "preview" })
    api.ui:set_document(player_controls())
    update_hud(api)
end

function Game.on_interaction(api, event)
    if event.phase == "enter" then
        GameState.nearby_zone = event.id
        if is_open() then
            if event.id == customer().id then
                GameState.status = customer().name .. " IS READY  •  SERVE THE ORDER"
            elseif event.id == "station-trash" then
                GameState.status = "DUMP A WRONG CUP HERE"
            elseif event.id == "station-lemons" or event.id == "station-sugar" or event.id == "station-ice" then
                GameState.status = "USE THE ACTION BUTTON TO PREPARE THE CUP"
            end
        end
    elseif event.phase == "exit" and GameState.nearby_zone == event.id then
        GameState.nearby_zone = nil
    end
    update_hud(api)
end

function Game.on_ui_event(api, event)
    if event.phase ~= "activate" then return end
    if event.action == "lemonade.action" then
        if GameState.nearby_zone == "station-lemons" then
            add_lemon(api)
        elseif GameState.nearby_zone == "station-sugar" then
            add_sugar(api)
        elseif GameState.nearby_zone == "station-ice" then
            add_ice(api)
        elseif GameState.nearby_zone == customer().id then
            serve(api)
        end
    elseif event.action == "lemonade.dump" then
        dump_cup()
    elseif event.action == "lemonade.play_again" then
        start_shift(api)
    end
    update_hud(api)
end

function Game.on_tick(api, delta_seconds)
    if GameState.phase == "intro" then
        GameState.intro_elapsed += delta_seconds
        if GameState.intro_elapsed >= INTRO_SECONDS then
            start_shift(api)
        end
    elseif is_open() then
        GameState.elapsed += delta_seconds
        if GameState.elapsed >= SHIFT_SECONDS then
            GameState.phase = "results"
            GameState.status = "STAND CLOSED  •  $" .. tostring(GameState.cash) .. " / $" .. tostring(GOAL_CASH)
        elseif GameState.phase == "open" and GameState.elapsed >= SHIFT_SECONDS - 30 then
            GameState.phase = "last_call"
            GameState.status = "LAST CALL  •  SERVE " .. customer().name
        end
    end
    update_hud(api)
end

return Game
