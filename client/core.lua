-- client/core.lua
local playerData = {}
local hudVisible = true

-- Initialize
Citizen.CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Citizen.Wait(100)
    end
    
    TriggerServerEvent('dm:playerReady')
    DisplayRadar(true)
end)

-- Player data handling
RegisterNetEvent('dm:initPlayer')
AddEventHandler('dm:initPlayer', function(data)
    playerData = data
    
    -- Initialize HUD
    if Config.HUD.enabled then
        SendNUIMessage({
            type = "update",
            money = {
                cash = playerData.cash,
                bank = playerData.bank
            },
            stats = {
                kills = playerData.kills,
                deaths = playerData.deaths
            }
        })
        
        -- Show welcome notification
        TriggerEvent('dm:notify', 'Welcome to the server!', 'info')
    end
    
    -- Auto-spawn logic
    local spawnPoint = DM.GetRandomFromTable(Config.SpawnPoints)
    if spawnPoint then
        SpawnPlayer(spawnPoint)
    end
end)

RegisterNetEvent('dm:updateMoney')
AddEventHandler('dm:updateMoney', function(moneyType, amount)
    playerData[moneyType] = amount
    
    -- Update HUD
    if Config.HUD.enabled then
        SendNUIMessage({
            type = "update",
            money = {
                cash = playerData.cash,
                bank = playerData.bank
            }
        })
    end
end)

-- Death handling
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim = args[1]
        local killer = args[2]
        
        if victim == PlayerPedId() and IsEntityDead(victim) then
            local killerServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(killer))
            TriggerServerEvent('dm:playerKilled', killerServerId)
            
            -- Auto-respawn after delay
            Citizen.SetTimeout(5000, function()
                local spawnPoint = DM.GetRandomFromTable(Config.SpawnPoints)
                if spawnPoint then
                    SpawnPlayer(spawnPoint)
                end
            end)
        end
    end
end)

-- Skin saving
RegisterCommand('saveskin', function()
    exports['illenium-appearance']:getPedAppearance(PlayerPedId(), function(appearance)
        if appearance then
            TriggerServerEvent('dm:saveSkin', appearance)
            TriggerEvent('dm:notify', 'Skin saved successfully!', 'success')
        end
    end)
end)

-- HUD Functions
function SpawnPlayer(coords)
    local playerPed = PlayerPedId()
    
    SetEntityCoordsNoOffset(playerPed, coords.x, coords.y, coords.z, true, true, true)
    SetEntityHeading(playerPed, coords.heading)
    
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, coords.heading, true, false)
    SetPlayerInvincible(PlayerId(), false)
    ClearPedBloodDamage(playerPed)
    
    -- Give default weapons if needed
    GiveWeaponToPed(playerPed, GetHashKey("WEAPON_PISTOL"), 100, false, false)
    GiveWeaponToPed(playerPed, GetHashKey("WEAPON_KNIFE"), 1, false, false)
end

-- HUD update thread
Citizen.CreateThread(function()
    while true do
        if Config.HUD.enabled and hudVisible then
            -- Update location info
            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)
            local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
            local streetName = GetStreetNameFromHashKey(streetHash)
            local zoneName = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
            
            -- Update weapon info
            local _, weaponHash = GetCurrentPedWeapon(playerPed, true)
            local weaponName = GetWeaponName(weaponHash)
            local ammoCount = GetAmmoInPedWeapon(playerPed, weaponHash)
            local ammoMax = GetMaxAmmoInClip(playerPed, weaponHash, 1)
            
            SendNUIMessage({
                type = "update",
                location = {
                    street = streetName,
                    zone = zoneName
                },
                weapon = {
                    name = weaponName,
                    ammo = ammoCount,
                    ammoMax = ammoMax
                }
            })
        end
        
        Citizen.Wait(Config.HUD.updateInterval)
    end
end)

-- Get weapon name from hash
function GetWeaponName(weaponHash)
    local weapons = {
        [GetHashKey("WEAPON_UNARMED")] = "Unarmed",
        [GetHashKey("WEAPON_KNIFE")] = "Knife",
        [GetHashKey("WEAPON_NIGHTSTICK")] = "Nightstick",
        [GetHashKey("WEAPON_HAMMER")] = "Hammer",
        [GetHashKey("WEAPON_BAT")] = "Baseball Bat",
        [GetHashKey("WEAPON_PISTOL")] = "Pistol",
        [GetHashKey("WEAPON_COMBATPISTOL")] = "Combat Pistol",
        [GetHashKey("WEAPON_SMG")] = "SMG",
        [GetHashKey("WEAPON_CARBINERIFLE")] = "Carbine Rifle",
        [GetHashKey("WEAPON_PUMPSHOTGUN")] = "Pump Shotgun",
        [GetHashKey("WEAPON_STUNGUN")] = "Stun Gun",
        [GetHashKey("WEAPON_SNIPERRIFLE")] = "Sniper Rifle"
        -- Add more weapons as needed
    }
    
    return weapons[weaponHash] or "Unknown"
end

-- Notification system
RegisterNetEvent('dm:notify')
AddEventHandler('dm:notify', function(message, notificationType, duration)
    if not notificationType then notificationType = "info" end
    if not duration then duration = 5000 end
    
    SendNUIMessage({
        type = "notification",
        message = message,
        notificationType = notificationType,
        duration = duration
    })
end)

-- Toggle HUD with key binding
RegisterCommand('togglehud', function()
    hudVisible = not hudVisible
    
    SendNUIMessage({
        type = "toggle",
        show = hudVisible
    })
    
    TriggerEvent('dm:notify', hudVisible and 'HUD enabled' or 'HUD disabled', 'info', 2000)
end)

RegisterKeyMapping('togglehud', 'Toggle HUD Display', 'keyboard', 'h')

-- Exports
exports('getPlayerData', function()
    return playerData
end)