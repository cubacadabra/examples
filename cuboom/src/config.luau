local Config = {}
Config.teams = { "mint", "violet" }
Config.names = { mint = "Mint", violet = "Violet" }
Config.rounds = {
    { name = "Bring it home", goal = 6, hint = "Push six letter cubes past your home line." },
    { name = "More to play with", goal = 6, hint = "Eleven new cubes! Stack nearby cubes with LIFT." },
    { name = "A little higher", goal = 3, hint = "Keep three cubes stacked above your home line." },
    { name = "Cuboom!", goal = 6, hint = "The ticking cube will scatter the pile. Push it away!" },
    { name = "Touch the sky", goal = 1, hint = "Climb the ladder, then FLY to the floating letter." },
}
Config.ids = {}
for index = 1, 55 do
    Config.ids[index] = index <= 11 and "starter-cube-" .. index or "extra-cube-" .. index
end
Config.home_z = { mint = 4, violet = -12 }
Config.crown = { 8, 16, -22 }
Config.hold = 5
Config.intermission = 8
return Config
