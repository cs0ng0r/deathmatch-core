Config = {}

-- Money settings
Config.StartingMoney = {
    cash = 5000,
    bank = 15000
}
Config.KillReward = 1000
Config.DeathPenalty = 500

-- Security settings
Config.SecurityToken = {
    enabled = true,
    lifetime = 3600 -- in seconds (1 hour)
}

-- Weapon blacklist
Config.BlacklistedWeapons = {
    "WEAPON_RAILGUN",
    "WEAPON_STICKYBOMB",
    "WEAPON_GRENADELAUNCHER",
    "WEAPON_RPG",
    "WEAPON_MINIGUN",
    "WEAPON_FIREWORK",
    "WEAPON_HOMINGLAUNCHER",
    "WEAPON_PROXMINE",
    "WEAPON_RAYMINIGUN"
}

-- HUD settings
Config.HUD = {
    enabled = true,
    showMoney = true,
    showStats = true,
    showWeapon = true,
    showLocation = true,
    updateInterval = 1000 -- Update HUD every second
}

-- Spawn settings
Config.SpawnPoints = {
    {x = -275.522, y = 6635.835, z = 7.425, heading = 269.5},
    {x = -214.786, y = 6178.749, z = 31.2, heading = 45.0},
    {x = 1644.339, y = 3559.698, z = 35.0, heading = 56.0},
    {x = 2029.3, y = 4747.3, z = 41.1, heading = 124.9},
    {x = -103.6, y = -969.7, z = 296.0, heading = 112.6},
    {x = -773.7, y = 311.0, z = 85.7, heading = 360.0},
    {x = 408.8, y = -998.7, z = 29.3, heading = 182.2},
    {x = -1038.0, y = -2738.0, z = 20.2, heading = 328.3},
}

-- Discord webhook for logs (security events)
Config.DiscordWebhook = ""  -- Add your webhook URL here

