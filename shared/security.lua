-- Security module
DMSecurity = {}

-- Client-side security
if not IsDuplicityVersion() then -- Client side code
    local clientToken = nil
    local lastValidation = 0
    
    -- Register to receive security token from server
    RegisterNetEvent('dm:securityToken')
    AddEventHandler('dm:securityToken', function(token)
        clientToken = token
        lastValidation = GetGameTimer()
        print("[DM] Security token received")
    end)
    
    -- Function to get the current security token
    function DMSecurity.GetToken()
        return clientToken
    end
    
    -- Validate client is using token properly
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(30000) -- Check token every 30 seconds
            
            if clientToken then
                -- If token is older than expiration time, request a new one
                local currentTime = GetGameTimer()
                if currentTime - lastValidation > (Config.SecurityToken.lifetime * 1000) then
                    TriggerServerEvent('dm:requestSecurityToken')
                end
            else
                -- No token yet, request one
                TriggerServerEvent('dm:requestSecurityToken')
            end
        end
    end)
    
    -- Anti-cheat protection - Weapon check
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(5000) -- Check every 5 seconds
            
            local playerPed = PlayerPedId()
            local _, currentWeapon = GetCurrentPedWeapon(playerPed, true)
            
            if currentWeapon and DM.TableContains(Config.BlacklistedWeapons, currentWeapon) then
                -- Player has a blacklisted weapon, remove it
                RemoveWeaponFromPed(playerPed, currentWeapon)
                -- Notify server about potential cheater
                TriggerServerEvent('dm:weaponViolation', currentWeapon, clientToken)
                -- Notify player
                TriggerEvent('dm:notify', 'Restricted weapon removed', 'error')
            end
        end
    end)
end

-- Server-side security
if IsDuplicityVersion() then -- Server side code
    local playerTokens = {}
    local securityChallenges = {}
    local suspiciousActivity = {}
    
    -- Generate a new security token for a player
    function DMSecurity.GenerateToken(playerId)
        local token = DM.GenerateRandomString(32)
        playerTokens[playerId] = {
            token = token,
            timestamp = os.time()
        }
        return token
    end
    
    -- Verify if a token is valid for a player
    function DMSecurity.VerifyToken(playerId, token)
        if not Config.SecurityToken.enabled then return true end
        
        local playerToken = playerTokens[playerId]
        if not playerToken then 
            return false
        end
        
        -- Check if token matches
        if playerToken.token ~= token then
            return false
        end
        
        -- Check if token is expired
        local currentTime = os.time()
        if currentTime - playerToken.timestamp > Config.SecurityToken.lifetime then
            return false
        end
        
        return true
    end
    
    -- Handle security token requests
    RegisterNetEvent('dm:requestSecurityToken')
    AddEventHandler('dm:requestSecurityToken', function()
        local source = source
        local token = DMSecurity.GenerateToken(source)
        TriggerClientEvent('dm:securityToken', source, token)
    end)
    
    -- Handle weapon violation reports
    RegisterNetEvent('dm:weaponViolation')
    AddEventHandler('dm:weaponViolation', function(weapon, token)
        local source = source
        local name = GetPlayerName(source)
        local steamID = GetPlayerIdentifier(source, 0)
        
        -- Verify token to prevent fake reports
        if not DMSecurity.VerifyToken(source, token) then
            -- Invalid token, possible injection attack
            logSecurityEvent("INVALID TOKEN", name, steamID, "Weapon: " .. weapon)
            -- Take action based on severity
            TakeActionAgainstCheater(source, "INVALID_TOKEN", "severe")
            return
        end
        
        -- Log the weapon violation
        logSecurityEvent("BLACKLISTED WEAPON", name, steamID, "Weapon: " .. weapon)
        -- Take moderate action
        TakeActionAgainstCheater(source, "BLACKLISTED_WEAPON", "moderate")
    end)
    
    -- Handle potential cheat reports
    RegisterNetEvent('dm:potentialCheat')
    AddEventHandler('dm:potentialCheat', function(cheatType, details, token)
        local source = source
        local name = GetPlayerName(source)
        local steamID = GetPlayerIdentifier(source, 0)
        
        -- Verify token to prevent fake reports
        if not DMSecurity.VerifyToken(source, token) then
            logSecurityEvent("INVALID TOKEN", name, steamID, "Cheat report without valid token")
            TakeActionAgainstCheater(source, "INVALID_TOKEN", "severe")
            return
        end
        
        -- Initialize suspicious activity counter for this player
        if not suspiciousActivity[source] then
            suspiciousActivity[source] = {}
        end
        
        -- Increment the specific cheat type counter
        if not suspiciousActivity[source][cheatType] then
            suspiciousActivity[source][cheatType] = 1
        else
            suspiciousActivity[source][cheatType] = suspiciousActivity[source][cheatType] + 1
        end
        
        -- Log the security event
        logSecurityEvent(cheatType, name, steamID, details)
        
        -- Determine severity and take action
        local severity = GetCheatSeverity(cheatType)
        if suspiciousActivity[source][cheatType] >= 3 then
            -- Multiple detections, increase severity
            if severity == "low" then 
                severity = "moderate"
            elseif severity == "moderate" then
                severity = "severe"
            end
        end
        
        TakeActionAgainstCheater(source, cheatType, severity)
    end)
    
    -- Handle security challenge responses
    RegisterNetEvent('dm:securityResponse')
    AddEventHandler('dm:securityResponse', function(challengeId, token)
        local source = source
        
        -- Check if this challenge exists and is for this player
        if securityChallenges[challengeId] and securityChallenges[challengeId].player == source then
            local challenge = securityChallenges[challengeId]
            
            -- Check if the token is valid
            if not DMSecurity.VerifyToken(source, token) then
                -- Failed security check
                logSecurityEvent("FAILED SECURITY CHALLENGE", GetPlayerName(source), 
                    GetPlayerIdentifier(source, 0), "Challenge ID: " .. challengeId)
                
                TakeActionAgainstCheater(source, "FAILED_CHALLENGE", "severe")
            end
            
            -- Clean up the challenge
            securityChallenges[challengeId] = nil
        end
    end)
    
    -- Send a security challenge to a player
    function DMSecurity.ChallengePlayer(playerId)
        if not playerId then return end
        
        local challengeId = DM.GenerateRandomString(16)
        securityChallenges[challengeId] = {
            player = playerId,
            timestamp = os.time()
        }
        
        TriggerClientEvent('dm:securityChallenge', playerId, challengeId)
        
        -- Set timeout to check if player responded
        Citizen.SetTimeout(10000, function() -- 10 seconds
            if securityChallenges[challengeId] then
                -- Player didn't respond in time
                logSecurityEvent("CHALLENGE TIMEOUT", GetPlayerName(playerId), 
                    GetPlayerIdentifier(playerId, 0), "Challenge ID: " .. challengeId)
                
                TakeActionAgainstCheater(playerId, "TIMEOUT_CHALLENGE", "severe")
                securityChallenges[challengeId] = nil
            end
        end)
    end
    
    -- Determine the severity of different cheat types
    function GetCheatSeverity(cheatType)
        local severityMap = {
            ["GODMODE"] = "severe",
            ["SPEEDHACK"] = "severe",
            ["HEALTH_HACK"] = "moderate",
            ["BLACKLISTED_WEAPON"] = "moderate",
            ["VEHICLE_SPAWN"] = "moderate",
            ["BLIP_HACK"] = "low",
            ["INVALID_TOKEN"] = "severe",
            ["FAILED_CHALLENGE"] = "severe",
            ["TIMEOUT_CHALLENGE"] = "severe"
        }
        
        return severityMap[cheatType] or "low"
    end
    
    -- Take action against a suspected cheater based on severity
    function TakeActionAgainstCheater(playerId, cheatType, severity)
        if not playerId then return end
        
        -- Get player info for logs
        local playerName = GetPlayerName(playerId)
        local steamID = GetPlayerIdentifier(playerId, 0)
        
        if severity == "low" then
            -- Just warn the player
            TriggerClientEvent('dm:notify', playerId, 'Suspicious activity detected. This has been logged.', 'error')
        elseif severity == "moderate" then
            -- Reset player position to a spawn point
            local randomSpawn = DM.GetRandomFromTable(Config.SpawnPoints)
            if randomSpawn then
                -- Set position and remove weapons
                TriggerClientEvent('dm:forceRespawn', playerId, randomSpawn)
                TriggerClientEvent('dm:notify', playerId, 'Suspicious activity detected. You have been respawned.', 'error')
            end
        elseif severity == "severe" then
            -- Kick or ban the player
            if cheatType == "FAILED_CHALLENGE" or cheatType == "TIMEOUT_CHALLENGE" or 
               cheatType == "INVALID_TOKEN" or cheatType == "GODMODE" then
                -- These are serious enough for a temporary ban
                local banReason = "Cheating detected: " .. cheatType
                local banDays = 1 -- 1 day temporary ban
                
                -- Use the admin ban function to add a ban record
                local banUntil = os.date("%Y-%m-%d %H:%M:%S", os.time() + (banDays * 86400))
                MySQL.update('UPDATE players SET ban_reason = ?, ban_until = ? WHERE identifier = ?',
                    { banReason, banUntil, steamID })
                
                -- Log the ban
                logSecurityEvent("AUTO_BAN", playerName, steamID, 
                    string.format("Banned until %s for: %s", banUntil, banReason))
                
                -- Kick the player
                DropPlayer(playerId, "You have been banned: " .. banReason)
            else
                -- Just kick for other severe violations
                DropPlayer(playerId, "You have been kicked: Suspicious activity detected")
            end
        end
    end
    
    -- Log security events
    function logSecurityEvent(type, playerName, steamID, details)
        local message = string.format("[SECURITY ALERT] Type: %s, Player: %s (%s), Details: %s", 
                                    type, playerName, steamID, details)
        print(message)
        
        -- Send to Discord if webhook is configured
        if Config.DiscordWebhook and Config.DiscordWebhook ~= "" then
            local embeds = {
                {
                    ["title"] = "Security Alert: " .. type,
                    ["description"] = details,
                    ["color"] = 15158332, -- Red
                    ["fields"] = {
                        {
                            ["name"] = "Player",
                            ["value"] = playerName,
                            ["inline"] = true
                        },
                        {
                            ["name"] = "Identifier",
                            ["value"] = steamID,
                            ["inline"] = true
                        },
                        {
                            ["name"] = "Timestamp",
                            ["value"] = os.date("%Y-%m-%d %H:%M:%S"),
                            ["inline"] = false
                        }
                    },
                    ["footer"] = {
                        ["text"] = "DM Core Security System"
                    }
                }
            }
            
            PerformHttpRequest(Config.DiscordWebhook, function(err, text, headers) end, 'POST', json.encode({
                username = "DM Security",
                embeds = embeds
            }), { ['Content-Type'] = 'application/json' })
        end
        
        -- Log to the database for admin review
        if steamID then
            MySQL.insert('INSERT INTO dm_logs (identifier, action, details) VALUES (?, ?, ?)',
                { steamID, "SECURITY_" .. type, details })
        end
    end
    
    -- Periodic security checks
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(60000) -- Every minute
            
            -- Challenge random players for security verification
            local players = GetPlayers()
            if #players > 0 then
                local randomPlayer = tonumber(players[math.random(1, #players)])
                if randomPlayer then
                    DMSecurity.ChallengePlayer(randomPlayer)
                end
            end
            
            -- Clean up expired tokens
            local currentTime = os.time()
            for playerId, data in pairs(playerTokens) do
                if currentTime - data.timestamp > Config.SecurityToken.lifetime then
                    playerTokens[playerId] = nil
                end
            end
        end
    end)
end
