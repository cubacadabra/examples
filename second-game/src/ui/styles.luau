local GameUIStyles = {}

GameUIStyles.colors = {
    ink = "#0B102BF0",
    paper = "#F7F5E9FF",
    quiet = "#B9C3E4FF",
    signal = "#57E5D0FF",
    hot = "#FF5B85FF",
    keyline = "#57E5D070",
}

function GameUIStyles.panel_style()
    return {
        background = GameUIStyles.colors.ink,
        borderColor = GameUIStyles.colors.keyline,
        borderWidth = 2,
        cornerRadius = 14,
        foreground = GameUIStyles.colors.paper,
    }
end

function GameUIStyles.control_style()
    return {
        background = "#151A3FE8",
        borderColor = GameUIStyles.colors.signal,
        borderWidth = 2,
        cornerRadius = 12,
        foreground = GameUIStyles.colors.paper,
        accent = GameUIStyles.colors.signal,
        textAlign = "center",
        fontSize = 14,
    }
end

return GameUIStyles
