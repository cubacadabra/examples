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
local hud_dirty = true
local next_clock_update = 0

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
                style = { foreground = "#F8F2DF", fontSize = 18 },
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
                id = "poker-shell", kind = "panel",
                layout = { anchor = "bottom", width = "92%", maxWidth = 720, height = 190, offset = { 0, -24 }, padding = 10, direction = "row", gap = 10, align = "stretch" },
                style = { background = "#09080DE8", borderColor = "#F8F2DF24", borderWidth = 1, cornerRadius = 5 },
                children = {
                    {
                        id = "poker-cards", kind = "panel",
                        layout = { width = "30%", maxWidth = 184, height = "fill", padding = 2, direction = "column", gap = 6 },
                        style = { foreground = "#F8F2DF" },
                        children = {
                            {
                                id = "poker-cards-label", kind = "text", text = "YOUR CARDS",
                                layout = { width = "fill", height = 20 },
                                style = { foreground = "#F8F2DF", fontSize = 12, textAlign = "center" },
                            },
                            {
                                id = "poker-card-row", kind = "panel",
                                layout = { width = "fill", height = "fill", direction = "row", gap = 8, align = "stretch" },
                                children = {
                                    {
                                        id = "poker-card-left", kind = "text", text = "♦\n✦\n♦",
                                        layout = { width = "fill", height = "fill" },
                                        style = { background = "#C83D4D", borderColor = "#F8F2DF", borderWidth = 2, cornerRadius = 4, foreground = "#F8F2DF", fontSize = 20, textAlign = "center" },
                                    },
                                    {
                                        id = "poker-card-right", kind = "text", text = "♦\n✦\n♦",
                                        layout = { width = "fill", height = "fill" },
                                        style = { background = "#C83D4D", borderColor = "#F8F2DF", borderWidth = 2, cornerRadius = 4, foreground = "#F8F2DF", fontSize = 20, textAlign = "center" },
                                    },
                                },
                            },
                        },
                    },
                    {
                        id = "poker-panel", kind = "panel", layout = { width = "fill", height = "fill", padding = 8, direction = "column", gap = 6, align = "stretch" },
                        style = { background = "#17121BD9", cornerRadius = 4 },
                        children = {
                            {
                                id = "poker-info", kind = "text", text = "",
                                layout = { width = "fill", height = 28 },
                                style = { foreground = "#F8F2DF", fontSize = 12, textAlign = "center" },
                            },
                            {
                                id = "poker-status", kind = "text", text = "WAITING ON DEALER...",
                                layout = { width = "fill", height = 34 },
                                style = { foreground = "#F8F2DF", fontSize = 16, textAlign = "center" },
                            },
                            {
                                id = "poker-actions", kind = "panel", layout = { width = "fill", height = "fill", direction = "column", gap = 4, align = "stretch" },
                                children = {
                                    {
                                        id = "poker-actions-primary", kind = "panel", layout = { width = "fill", height = "fill", direction = "row", gap = 4, align = "stretch" },
                                        children = {
                                            { id = "poker-call", kind = "button", text = "R\nCALL", action = "casino.call", layout = { width = "fill", height = "fill" }, style = { foreground = "#F8F2DFB8", fontSize = 11, textAlign = "center" } },
                                            { id = "poker-raise", kind = "button", text = "T\nRAISE", action = "casino.raise", layout = { width = "fill", height = "fill" }, style = { foreground = "#F8F2DFB8", fontSize = 11, textAlign = "center" } },
                                            { id = "poker-bet", kind = "button", text = "Y\nBET", action = "casino.bet", layout = { width = "fill", height = "fill" }, style = { foreground = "#F8F2DFB8", fontSize = 11, textAlign = "center" } },
                                        },
                                    },
                                    {
                                        id = "poker-actions-secondary", kind = "panel", layout = { width = "fill", height = "fill", direction = "row", gap = 4, align = "stretch" },
                                        children = {
                                            { id = "poker-check", kind = "button", text = "F\nCHECK", action = "casino.check", layout = { width = "fill", height = "fill" }, style = { foreground = "#F8F2DFB8", fontSize = 11, textAlign = "center" } },
                                            { id = "poker-fold", kind = "button", text = "G\nFOLD", action = "casino.fold", layout = { width = "fill", height = "fill" }, style = { foreground = "#F8F2DFB8", fontSize = 11, textAlign = "center" } },
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            }),
            visible({
                id = "vegas-table", kind = "text", text = "",
                layout = { anchor = "bottom", width = "90%", maxWidth = 460, height = 62, offset = { 0, -226 } },
                style = { background = "#09080DD9", borderColor = "#F8F2DF24", borderWidth = 1, cornerRadius = 5, foreground = "#F8F2DF", fontSize = 13, textAlign = "center" },
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
                id = "vegas-help", kind = "text", text = "WASD / JOYSTICK MOVE   •   SHIFT / RUN   •   SPACE / JUMP   •   WALK TO A TABLE",
                layout = { anchor = "bottom", width = "90%", maxWidth = 520, height = 20, offset = { 0, -8 } },
                style = { foreground = "#F8F2DFB8", fontSize = 9 },
            }),
            visible({
                id = "player-joystick", kind = "joystick", action = "player.move",
                layout = { anchor = "bottomLeft", width = 120, height = 120, offset = { 20, -24 } },
                style = { background = "#17121BD9", borderColor = "#E5B94E66", borderWidth = 2, cornerRadius = 60, accent = "#E5B94E" },
            }),
            visible({
                id = "player-jump", kind = "button", text = "JUMP", action = "player.jump",
                layout = { anchor = "bottomRight", width = 86, height = 44, offset = { -22, -84 } },
                style = { background = "#17121BF5", borderColor = "#F8F2DF99", borderWidth = 2, cornerRadius = 17, foreground = "#F8F2DF", accent = "#E5B94E", textAlign = "center", fontSize = 14 },
            }),
            visible({
                id = "player-run", kind = "button", text = "RUN", action = "player.run",
                layout = { anchor = "bottomRight", width = 86, height = 44, offset = { -22, -30 } },
                style = { background = "#17121BF5", borderColor = "#F8F2DF99", borderWidth = 2, cornerRadius = 17, foreground = "#F8F2DF", accent = "#E5B94E", textAlign = "center", fontSize = 14 },
            }),
        },
    }
end

local function mark_hud_dirty()
    hud_dirty = true
end

local function update_hud(api, force)
    local clock_due = playtime >= next_clock_update
    if not force and not hud_dirty and not clock_due then return end
    local table = active_table and TABLES[active_table] or nil
    local poker_visible = active_table == "table-texas"
    if hud_dirty or clock_due then
        api.ui:set_text("vegas-stats", "CREDITS  " .. format_number(credits) .. "    TICKETS  " .. format_number(tickets) .. "    PLAYTIME  " .. format_time(playtime))
    end
    if hud_dirty then
        api.ui:set_text("vegas-status", status)
        api.ui:set_text("vegas-wallet", "◉  " .. format_number(credits) .. "\n◇  " .. format_number(tickets))
        local table_text = table ~= nil and (table.name .. "\nBET  " .. format_number(bet)) or "WALK TO A TABLE TO PLAY\nBET  " .. format_number(bet)
        api.ui:set_text("vegas-table", table_text)
        api.ui:set_text("poker-info", poker_visible and ("TEXAS HOLD'EM\nBET  " .. format_number(bet)) or "")
        api.ui:set_text("poker-status", poker_visible and (result ~= "" and result or "WAITING ON DEALER...") or "")
        api.ui:set_visible("poker-shell", poker_visible)
        api.ui:set_visible("vegas-table", table ~= nil and not poker_visible)
        api.ui:set_visible("vegas-play", table ~= nil and not poker_visible and round_state ~= "dealing" and credits >= bet)
        api.ui:set_visible("vegas-bet-down", table ~= nil and not poker_visible and round_state ~= "dealing")
        api.ui:set_visible("vegas-bet-up", table ~= nil and not poker_visible and round_state ~= "dealing")
        hud_dirty = false
    end
    if clock_due then next_clock_update = math.floor(playtime) + 1 end
end

local function set_table(api, id)
    active_table = id
    round_state = "ready"
    round_elapsed = 0
    result = ""
    status = TABLES[id].name .. "  •  WAITING ON DEALER"
    mark_hud_dirty()
    update_hud(api)
end

local function leave_table(api)
    active_table = nil
    round_state = "explore"
    round_elapsed = 0
    result = ""
    status = "FIND A TABLE"
    mark_hud_dirty()
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
    mark_hud_dirty()
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
    mark_hud_dirty()
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
    hud_dirty = true
    next_clock_update = 0
    api.lobby:set_enabled(false)
    api.session:start("vegas-101", { mode = "cooperative", difficulty = "source-floor" })
    api.ui:set_document(hud_document())
    -- The spawn is inside the first Texas Hold'em zone, so the interaction
    -- runtime owns the initial table state and emits a normal enter event.
    update_hud(api, true)
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
        mark_hud_dirty()
        update_hud(api)
    elseif event.action == "casino.fold" then
        result = "FOLD"
        status = "ROUND FOLDED  •  FIND A TABLE"
        mark_hud_dirty()
        update_hud(api)
    elseif event.action == "casino.bet.down" then
        bet = math.max(MIN_BET, bet - 25)
        mark_hud_dirty()
        update_hud(api)
    elseif event.action == "casino.bet.up" then
        bet = math.min(MAX_BET, bet + 25)
        mark_hud_dirty()
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
        mark_hud_dirty()
        update_hud(api)
    end
end

return Game
