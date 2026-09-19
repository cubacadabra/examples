-- Vegas 101 layers a small, deterministic local casino loop over the
-- source-imported Vegas floor. The imported mesh is visual and collision
-- authority; this module owns only the player-facing table session.

local Game = {}

local WORLD = "vegas-floor"
local STARTING_CREDITS = 46248
local STARTING_TICKETS = 3504
local MAX_BET = 2500
local MIN_BET = 25

local TABLES = {
    ["table-texas"] = { name = "TEXAS HOLD'EM", short = "TEXAS", payout = 2, ticket_rate = 3 },
    ["table-blackjack"] = { name = "BLACKJACK", short = "BLACKJACK", payout = 2, ticket_rate = 2 },
    ["table-baccarat"] = { name = "BACCARAT", short = "BACCARAT", payout = 2, ticket_rate = 2 },
    ["table-roulette"] = { name = "ROULETTE", short = "ROULETTE", payout = 3, ticket_rate = 4 },
    ["table-slots"] = { name = "SLOTS", short = "SLOTS", payout = 4, ticket_rate = 1 },
    ["table-plinko"] = { name = "PLINKO", short = "PLINKO", payout = 3, ticket_rate = 5 },
    ["table-cashwheel"] = { name = "CASH WHEEL", short = "CASH WHEEL", payout = 5, ticket_rate = 6 },
}

local credits = STARTING_CREDITS
local tickets = STARTING_TICKETS
local playtime = 0
local bet = 100
local active_table = nil
local round_state = "explore"
local round_elapsed = 0
local rounds_played = 0
local status = "FIND A TABLE"
local result = ""

local function format_number(value)
    local text = tostring(math.floor(value))
    local output = ""
    while #text > 3 do
        output = "," .. string.sub(text, -3) .. output
        text = string.sub(text, 1, -4)
    end
    return text .. output
end

local function format_time(seconds)
    local whole = math.floor(seconds)
    local hours = math.floor(whole / 3600)
    local minutes = math.floor((whole % 3600) / 60)
    local secs = whole % 60
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

local function visible(node)
    node.visibleIn = { WORLD }
    return node
end

local function hud_document()
    return {
        nodes = {
            visible({
                id = "vegas-brand", kind = "text", text = "VEGAS 101",
                layout = { anchor = "topLeft", width = 220, height = 30, offset = { 22, 18 } },
                style = { foreground = "#F8F2DF", fontSize = 18, fontWeight = "bold" },
            }),
            visible({
                id = "vegas-eyebrow", kind = "text", text = "THE HIGH ROLLER FLOOR",
                layout = { anchor = "topLeft", width = 220, height = 18, offset = { 24, 45 } },
                style = { foreground = "#E5B94E", fontSize = 9 },
            }),
            visible({
                id = "vegas-stats", kind = "text", text = "",
                layout = { anchor = "topRight", width = 430, height = 24, offset = { -24, 23 } },
                style = { foreground = "#F8F2DFE6", fontSize = 11, textAlign = "end" },
            }),
            visible({
                id = "vegas-server", kind = "text", text = "2 PLAYERS IN SERVER\nGamerOkami     CrayQuick",
                layout = { anchor = "topRight", width = 230, height = 34, offset = { -24, 48 } },
                style = { foreground = "#F8F2DFB8", fontSize = 9, textAlign = "end" },
            }),
            visible({
                id = "vegas-status", kind = "text", text = status,
                layout = { anchor = "top", width = 360, height = 28, offset = { 0, 74 } },
                style = { background = "#17121BD9", foreground = "#F8F2DF", cornerRadius = 4, fontSize = 12, textAlign = "center" },
            }),
            visible({
                id = "vegas-wallet", kind = "text", text = "",
                layout = { anchor = "bottomLeft", width = 236, height = 126, offset = { 22, -184 } },
                style = { background = "#17121BC7", foreground = "#F8F2DF", cornerRadius = 4, fontSize = 12 },
            }),
            visible({
                id = "poker-cards-label", kind = "text", text = "YOUR CARDS:",
                layout = { anchor = "bottomLeft", width = 160, height = 20, offset = { 282, -278 } },
                style = { foreground = "#F8F2DF", fontSize = 12, fontWeight = "bold" },
            }),
            visible({
                id = "poker-card-left", kind = "text", text = "♦\n✦\n♦",
                layout = { anchor = "bottomLeft", width = 76, height = 108, offset = { 282, -158 } },
                style = { background = "#C83D4D", borderColor = "#F8F2DF", borderWidth = 2, cornerRadius = 4, foreground = "#F8F2DF", fontSize = 20, textAlign = "center" },
            }),
            visible({
                id = "poker-card-right", kind = "text", text = "♦\n✦\n♦",
                layout = { anchor = "bottomLeft", width = 76, height = 108, offset = { 366, -158 } },
                style = { background = "#C83D4D", borderColor = "#F8F2DF", borderWidth = 2, cornerRadius = 4, foreground = "#F8F2DF", fontSize = 20, textAlign = "center" },
            }),
            visible({
                id = "poker-panel", kind = "text", text = "",
                layout = { anchor = "bottom", width = 520, height = 190, offset = { 0, -92 } },
                style = { background = "#09080DE8", borderColor = "#F8F2DF24", borderWidth = 1, cornerRadius = 5, foreground = "#F8F2DF", fontSize = 12, textAlign = "center" },
            }),
            visible({
                id = "poker-status", kind = "text", text = "WAITING ON DEALER...",
                layout = { anchor = "bottom", width = 350, height = 44, offset = { 0, -176 } },
                style = { foreground = "#F8F2DF", fontSize = 18, textAlign = "center" },
            }),
            visible({
                id = "poker-call", kind = "button", text = "R\nCALL", action = "casino.call",
                layout = { anchor = "bottom", width = 84, height = 52, offset = { -190, -110 } },
                style = { foreground = "#F8F2DFB8", fontSize = 11, textAlign = "center" },
            }),
            visible({
                id = "poker-raise", kind = "button", text = "T\nRAISE", action = "casino.raise",
                layout = { anchor = "bottom", width = 84, height = 52, offset = { -95, -110 } },
                style = { foreground = "#F8F2DFB8", fontSize = 11, textAlign = "center" },
            }),
            visible({
                id = "poker-bet", kind = "button", text = "Y\nBET", action = "casino.bet",
                layout = { anchor = "bottom", width = 84, height = 52, offset = { 0, -110 } },
                style = { foreground = "#F8F2DFB8", fontSize = 11, textAlign = "center" },
            }),
            visible({
                id = "poker-check", kind = "button", text = "F\nCHECK", action = "casino.check",
                layout = { anchor = "bottom", width = 84, height = 52, offset = { -95, -46 } },
                style = { foreground = "#F8F2DFB8", fontSize = 11, textAlign = "center" },
            }),
            visible({
                id = "poker-fold", kind = "button", text = "G\nFOLD", action = "casino.fold",
                layout = { anchor = "bottom", width = 84, height = 52, offset = { 0, -46 } },
                style = { foreground = "#F8F2DFB8", fontSize = 11, textAlign = "center" },
            }),
            visible({
                id = "vegas-play", kind = "button", text = "PLAY ROUND", action = "casino.play",
                layout = { anchor = "bottomRight", width = 136, height = 42, offset = { -24, -92 } },
                style = { background = "#E5B94E", borderColor = "#F8F2DF", borderWidth = 1, cornerRadius = 4, foreground = "#17121B", fontSize = 11, textAlign = "center" },
            }),
            visible({
                id = "vegas-bet-down", kind = "button", text = "−", action = "casino.bet.down",
                layout = { anchor = "bottomRight", width = 42, height = 42, offset = { -210, -92 } },
                style = { background = "#17121BEA", borderColor = "#F8F2DF55", borderWidth = 1, cornerRadius = 4, foreground = "#F8F2DF", fontSize = 18, textAlign = "center" },
            }),
            visible({
                id = "vegas-bet-up", kind = "button", text = "+", action = "casino.bet.up",
                layout = { anchor = "bottomRight", width = 42, height = 42, offset = { -162, -92 } },
                style = { background = "#17121BEA", borderColor = "#F8F2DF55", borderWidth = 1, cornerRadius = 4, foreground = "#F8F2DF", fontSize = 18, textAlign = "center" },
            }),
            visible({
                id = "vegas-help", kind = "text", text = "WASD / ARROWS MOVE   •   SHIFT RUN   •   SPACE JUMP   •   WALK TO A TABLE",
                layout = { anchor = "bottomLeft", width = 520, height = 20, offset = { 22, -22 } },
                style = { foreground = "#F8F2DFB8", fontSize = 9 },
            }),
        },
    }
end

local function update_hud(api)
    local table = active_table and TABLES[active_table] or nil
    api.ui:set_text("vegas-stats", "CREDITS  " .. format_number(credits) .. "    TICKETS  " .. format_number(tickets) .. "    PLAYTIME  " .. format_time(playtime))
    api.ui:set_text("vegas-status", status)
    api.ui:set_text("vegas-wallet", "◉  " .. format_number(credits) .. "\n◇  " .. format_number(tickets) .. "\n▰  " .. format_number(math.max(0, credits - bet)))
    local table_text = table ~= nil and (table.name .. "\nBET  " .. format_number(bet)) or "WALK TO A TABLE TO PLAY\nBET  " .. format_number(bet)
    api.ui:set_text("poker-panel", table_text)
    api.ui:set_text("poker-status", table ~= nil and (result ~= "" and result or "WAITING ON DEALER...") or "WALK TO A TABLE")
    local poker_visible = table ~= nil
    api.ui:set_visible("poker-cards-label", poker_visible)
    api.ui:set_visible("poker-card-left", poker_visible)
    api.ui:set_visible("poker-card-right", poker_visible)
    api.ui:set_visible("poker-panel", poker_visible)
    api.ui:set_visible("poker-status", poker_visible)
    api.ui:set_visible("poker-call", poker_visible and round_state ~= "dealing")
    api.ui:set_visible("poker-raise", poker_visible and round_state ~= "dealing")
    api.ui:set_visible("poker-bet", poker_visible and round_state ~= "dealing")
    api.ui:set_visible("poker-check", poker_visible and round_state ~= "dealing")
    api.ui:set_visible("poker-fold", poker_visible and round_state ~= "dealing")
    api.ui:set_visible("vegas-play", table ~= nil and round_state ~= "dealing" and credits >= bet)
    api.ui:set_visible("vegas-bet-down", table ~= nil and round_state ~= "dealing")
    api.ui:set_visible("vegas-bet-up", table ~= nil and round_state ~= "dealing")
end

local function set_table(api, id)
    active_table = id
    round_state = "ready"
    round_elapsed = 0
    result = ""
    status = TABLES[id].name .. "  •  WAITING ON DEALER"
    update_hud(api)
end

local function leave_table(api)
    active_table = nil
    round_state = "explore"
    round_elapsed = 0
    result = ""
    status = "FIND A TABLE"
    update_hud(api)
end

local function play_round(api)
    if active_table == nil or round_state == "dealing" or credits < bet then return end
    credits -= bet
    rounds_played += 1
    round_state = "dealing"
    round_elapsed = 0
    result = "DEALING..."
    status = TABLES[active_table].name .. "  •  DEALING"
    update_hud(api)
end

local function settle_round(api)
    local table = TABLES[active_table]
    -- A predictable local rhythm keeps screenshots and headless runs stable.
    local won = rounds_played % 3 ~= 0
    if won then
        local payout = bet * table.payout
        credits += payout
        tickets += bet * table.ticket_rate
        result = "WIN  +" .. format_number(payout) .. " CREDITS"
        status = "WINNER  •  " .. table.name
    else
        result = "NO WIN  •  TRY AGAIN"
        status = "ROUND COMPLETE  •  " .. table.name
    end
    round_state = "ready"
    round_elapsed = 0
    update_hud(api)
end

function Game.on_start(api)
    credits = STARTING_CREDITS
    tickets = STARTING_TICKETS
    playtime = 0
    bet = 100
    active_table = nil
    round_state = "explore"
    rounds_played = 0
    status = "FIND A TABLE"
    result = ""
    api.lobby:set_enabled(false)
    api.session:start("vegas-101", { mode = "cooperative", difficulty = "source-floor" })
    api.ui:set_document(hud_document())
    -- The first imported Texas Hold'em table is the visual benchmark for this
    -- example. Starting just beyond the near-side chairs makes the reference
    -- room and its poker HUD appear immediately, while leaving the floor fully
    -- explorable once the player walks away.
    active_table = "table-texas"
    round_state = "ready"
    status = "TEXAS HOLD'EM  •  WAITING ON DEALER"
    update_hud(api)
end

function Game.on_tick(api, delta_seconds)
    playtime += delta_seconds
    if round_state == "dealing" then
        round_elapsed += delta_seconds
        if round_elapsed >= 1.2 then settle_round(api) end
    end
    update_hud(api)
end

function Game.on_ui_event(api, event)
    if type(event) ~= "table" or event.phase == "release" then return end
    if event.action == "casino.play" then
        play_round(api)
    elseif event.action == "casino.call" then
        play_round(api)
    elseif event.action == "casino.raise" then
        bet = math.min(MAX_BET, bet + 25)
        play_round(api)
    elseif event.action == "casino.bet" then
        play_round(api)
    elseif event.action == "casino.check" then
        result = "CHECK"
        status = active_table and (TABLES[active_table].name .. "  •  CHECKED") or "FIND A TABLE"
        update_hud(api)
    elseif event.action == "casino.fold" then
        result = "FOLD"
        status = "ROUND FOLDED  •  FIND A TABLE"
        update_hud(api)
    elseif event.action == "casino.bet.down" then
        bet = math.max(MIN_BET, bet - 25)
        update_hud(api)
    elseif event.action == "casino.bet.up" then
        bet = math.min(MAX_BET, bet + 25)
        update_hud(api)
    end
end

function Game.on_interaction(api, event)
    if type(event) ~= "table" or type(event.id) ~= "string" then return end
    local table = TABLES[event.id]
    if table == nil then return end
    if event.phase == "enter" then
        set_table(api, event.id)
    elseif (event.phase == "leave" or event.phase == "exit") and active_table == event.id then
        leave_table(api)
    end
end

function Game.on_player_event(api, event)
    if type(event) == "table" and event.kind == "death" then
        active_table = nil
        round_state = "explore"
        status = "RETURNING TO THE FLOOR"
        result = ""
        update_hud(api)
    end
end

return Game
