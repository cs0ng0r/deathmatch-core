-- Client-side leaderboard functionality
local leaderboardVisible = false
local leaderboardData = {}

-- Register event to receive leaderboard data
RegisterNetEvent('dm:showLeaderboard')
AddEventHandler('dm:showLeaderboard', function(data)
    leaderboardData = data
    leaderboardVisible = true
    
    -- Auto-hide after a few seconds
    Citizen.SetTimeout(10000, function()
        leaderboardVisible = false
    end)
end)

-- Register event for leaderboard updates
RegisterNetEvent('dm:leaderboardUpdated')
AddEventHandler('dm:leaderboardUpdated', function()
    TriggerEvent('dm:notify', 'Leaderboard has been updated', 'info')
end)

-- Toggle leaderboard visibility with key binding
RegisterCommand('toggleleaderboard', function()
    if leaderboardVisible then
        leaderboardVisible = false
    else
        -- Request fresh data from server
        TriggerServerEvent('leaderboard')
    end
end)

RegisterKeyMapping('toggleleaderboard', 'Toggle Leaderboard Display', 'keyboard', 'f10')

-- Handle force respawn from server (anti-cheat response)
RegisterNetEvent('dm:forceRespawn')
AddEventHandler('dm:forceRespawn', function(spawnPoint)
    local playerPed = PlayerPedId()
    
    -- Clear weapons
    RemoveAllPedWeapons(playerPed, true)
    
    -- Teleport to spawn
    SetEntityCoordsNoOffset(playerPed, spawnPoint.x, spawnPoint.y, spawnPoint.z, true, true, true)
    SetEntityHeading(playerPed, spawnPoint.heading)
    
    -- Resurrect if dead
    if IsEntityDead(playerPed) then
        NetworkResurrectLocalPlayer(spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.heading, true, false)
    end
    
    -- Give default weapons
    GiveWeaponToPed(playerPed, GetHashKey("WEAPON_PISTOL"), 100, false, false)
    GiveWeaponToPed(playerPed, GetHashKey("WEAPON_KNIFE"), 1, false, false)
end)

-- Draw leaderboard on screen
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if leaderboardVisible and leaderboardData and #leaderboardData > 0 then
            -- Background
            DrawRect(0.5, 0.5, 0.35, 0.6, 0, 0, 0, 180)
            
            -- Title
            SetTextFont(4)
            SetTextScale(0.5, 0.5)
            SetTextColour(255, 255, 255, 255)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(1, 0, 0, 0, 255)
            SetTextDropShadow()
            SetTextOutline()
            BeginTextCommandDisplayText("STRING")
            AddTextComponentSubstringPlayerName("LEADERBOARD")
            EndTextCommandDisplayText(0.5, 0.25)
            
            -- Column headers
            SetTextFont(4)
            SetTextScale(0.35, 0.35)
            SetTextColour(255, 255, 255, 255)
            BeginTextCommandDisplayText("STRING")
            AddTextComponentSubstringPlayerName("Rank")
            EndTextCommandDisplayText(0.35, 0.3)
            
            BeginTextCommandDisplayText("STRING")
            AddTextComponentSubstringPlayerName("Name")
            EndTextCommandDisplayText(0.425, 0.3)
            
            BeginTextCommandDisplayText("STRING")
            AddTextComponentSubstringPlayerName("Kills")
            EndTextCommandDisplayText(0.525, 0.3)
            
            BeginTextCommandDisplayText("STRING")
            AddTextComponentSubstringPlayerName("Deaths")
            EndTextCommandDisplayText(0.585, 0.3)
            
            BeginTextCommandDisplayText("STRING")
            AddTextComponentSubstringPlayerName("K/D")
            EndTextCommandDisplayText(0.645, 0.3)
            
            -- Player data
            SetTextFont(4)
            SetTextScale(0.3, 0.3)
            
            local y = 0.33
            for i=1, math.min(15, #leaderboardData) do
                local player = leaderboardData[i]
                
                -- Rank
                SetTextColour(255, 255, 255, 255)
                BeginTextCommandDisplayText("STRING")
                AddTextComponentSubstringPlayerName(tostring(i))
                EndTextCommandDisplayText(0.35, y)
                
                -- Name (truncated if necessary)
                local displayName = player.name
                if #displayName > 15 then
                    displayName = string.sub(displayName, 1, 15) .. "..."
                end
                BeginTextCommandDisplayText("STRING")
                AddTextComponentSubstringPlayerName(displayName)
                EndTextCommandDisplayText(0.425, y)
                
                -- Kills
                BeginTextCommandDisplayText("STRING")
                AddTextComponentSubstringPlayerName(tostring(player.kills))
                EndTextCommandDisplayText(0.525, y)
                
                -- Deaths
                BeginTextCommandDisplayText("STRING")
                AddTextComponentSubstringPlayerName(tostring(player.deaths))
                EndTextCommandDisplayText(0.585, y)
                
                -- K/D ratio
                local kdColor = {255, 255, 255} -- White by default
                local kd = player.kd_ratio
                
                if kd >= 2.0 then
                    kdColor = {0, 255, 0} -- Green for good K/D
                elseif kd < 1.0 then
                    kdColor = {255, 150, 0} -- Orange for poor K/D
                end
                
                SetTextColour(kdColor[1], kdColor[2], kdColor[3], 255)
                BeginTextCommandDisplayText("STRING")
                AddTextComponentSubstringPlayerName(string.format("%.2f", kd))
                EndTextCommandDisplayText(0.645, y)
                
                y = y + 0.025
            end
            
            -- Instructions
            SetTextFont(4)
            SetTextScale(0.25, 0.25)
            SetTextColour(170, 170, 170, 255)
            BeginTextCommandDisplayText("STRING")
            AddTextComponentSubstringPlayerName("Press F10 to toggle leaderboard")
            EndTextCommandDisplayText(0.5, 0.75)
        end
    end
end)
