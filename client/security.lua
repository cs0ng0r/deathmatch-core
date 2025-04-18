-- Client-side security and anti-cheat
local securityCheckTimerMin = 10000 -- 10 seconds
local securityCheckTimerMax = 20000 -- 20 seconds
local lastPosition = vector3(0, 0, 0)
local blipData = {}
local blacklistedEntities = {}

-- Anti cheat checks thread (randomized timing to make it harder to bypass)
Citizen.CreateThread(function()
    while true do
        local randomWait = math.random(securityCheckTimerMin, securityCheckTimerMax)
        Citizen.Wait(randomWait)
        
        -- Only run checks if we have a security token (ensures we're properly connected)
        if DMSecurity.GetToken() then
            RunSecurityChecks()
        end
    end
end)

-- Anti-speedhack check
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        local ped = PlayerPedId()
        
        -- Only check if player is on foot
        if IsPedOnFoot(ped) and not IsPedFalling(ped) and not IsPedRagdoll(ped) 
           and not IsPedJumping(ped) and not IsPedClimbing(ped) then
            
            local currentPos = GetEntityCoords(ped)
            
            -- If we have a previous position
            if lastPosition ~= vector3(0, 0, 0) then
                local distance = #(currentPos - lastPosition)
                
                -- If moved more than 30 units in 1 second while on foot (potential speedhack)
                if distance > 30.0 then
                    TriggerServerEvent('dm:potentialCheat', 'SPEEDHACK', 
                        string.format("Distance: %.2f m/s", distance), 
                        DMSecurity.GetToken())
                end
            end
            
            lastPosition = currentPos
        else
            -- Reset position tracking when not on foot
            lastPosition = vector3(0, 0, 0)
        end
    end
end)

-- Run various security checks
function RunSecurityChecks()
    local playerPed = PlayerPedId()
    local playerId = PlayerId()
    
    -- God mode detection
    if GetPlayerInvincible(playerId) or GetPlayerInvincible_2(playerId) then
        -- Report potential god mode
        TriggerServerEvent('dm:potentialCheat', 'GODMODE', "Player invincible flag detected", DMSecurity.GetToken())
        -- Reset invincibility - attempt to force disable it
        SetPlayerInvincible(playerId, false)
    end
    
    -- Health above normal max detection
    local maxHealth = GetEntityMaxHealth(playerPed)
    local health = GetEntityHealth(playerPed)
    if health > maxHealth then
        -- Report health modification
        TriggerServerEvent('dm:potentialCheat', 'HEALTH_HACK', 
            string.format("Health: %d/%d", health, maxHealth), 
            DMSecurity.GetToken())
        -- Try to reset health to normal max
        SetEntityHealth(playerPed, maxHealth)
    end
    
    -- Check for blacklisted weapons
    local _, currentWeapon = GetCurrentPedWeapon(playerPed, true)
    if currentWeapon and DM.TableContains(Config.BlacklistedWeapons, currentWeapon) then
        RemoveWeaponFromPed(playerPed, currentWeapon)
        TriggerServerEvent('dm:weaponViolation', currentWeapon, DMSecurity.GetToken())
    end
    
    -- Check for suspicious vehicle spawns
    local playerCoords = GetEntityCoords(playerPed)
    local vehicles = GetGamePool('CVehicle')
    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) and not NetworkGetEntityIsNetworked(vehicle) then
            -- Vehicle exists but isn't networked (could be spawned by a mod menu)
            local vehicleCoords = GetEntityCoords(vehicle)
            local distance = #(playerCoords - vehicleCoords)
            
            -- If it's close to the player and not a naturally spawned ambient vehicle
            if distance < 20.0 and not blacklistedEntities[vehicle] then
                blacklistedEntities[vehicle] = true
                -- Report and delete
                TriggerServerEvent('dm:potentialCheat', 'VEHICLE_SPAWN', 
                    string.format("Non-networked vehicle: %s", GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))), 
                    DMSecurity.GetToken())
                SetEntityAsMissionEntity(vehicle, true, true)
                DeleteEntity(vehicle)
            end
        end
    end
    
    -- Detect suspicious blips (mod menus often add player blips)
    local currentBlipCount = 0
    for i = 1, 1000 do -- Check a reasonable number of blip IDs
        if DoesBlipExist(i) then
            currentBlipCount = currentBlipCount + 1
            local blipSprite = GetBlipSprite(i)
            
            -- Track new blips that could be player blips
            if blipSprite == 1 and not blipData[i] then
                blipData[i] = true
            end
        end
    end
    
    -- If we suddenly have a lot more blips (like player blips added by mod menu)
    if currentBlipCount > 100 then -- Arbitrary threshold
        TriggerServerEvent('dm:potentialCheat', 'BLIP_HACK', 
            string.format("Unusual number of blips: %d", currentBlipCount), 
            DMSecurity.GetToken())
    end
end

-- Register event for receiving server challenges
RegisterNetEvent('dm:securityChallenge')
AddEventHandler('dm:securityChallenge', function(challengeId)
    -- Respond with the token to verify we're legitimate
    TriggerServerEvent('dm:securityResponse', challengeId, DMSecurity.GetToken())
end)
