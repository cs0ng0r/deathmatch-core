-- Leaderboard System
local leaderboardCache = {}
local leaderboardLastUpdate = 0
local leaderboardUpdateInterval = 300 -- 5 minutes

-- Get leaderboard data, with caching to avoid excessive database queries
function GetLeaderboard(cb)
    local currentTime = os.time()
    
    -- If we have a recent cached version, use that
    if leaderboardCache and #leaderboardCache > 0 and 
       (currentTime - leaderboardLastUpdate) < leaderboardUpdateInterval then
        if cb then cb(leaderboardCache) end
        return leaderboardCache
    end
    
    -- Otherwise, fetch fresh data
    MySQL.query([[
        SELECT name, kills, deaths, 
               CASE WHEN deaths = 0 THEN kills ELSE ROUND(kills / deaths, 2) END as kd_ratio
        FROM players
        ORDER BY kills DESC
        LIMIT 25
    ]], {}, function(results)
        if results then
            leaderboardCache = results
            leaderboardLastUpdate = currentTime
            if cb then cb(results) end
        else
            if cb then cb({}) end
        end
    end)
end

-- Command to show leaderboard
RegisterCommand('leaderboard', function(source)
    if source == 0 then -- Console can't see UI
        GetLeaderboard(function(data)
            for i, player in ipairs(data) do
                print(string.format("%d. %s - Kills: %d, Deaths: %d, K/D: %.2f", 
                    i, player.name, player.kills, player.deaths, player.kd_ratio))
            end
        end)
        return
    end
    
    GetLeaderboard(function(data)
        TriggerClientEvent('dm:showLeaderboard', source, data)
    end)
end, false)

-- Register export to get leaderboard data
exports('getLeaderboard', GetLeaderboard)

-- Send leaderboard updates to all players
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(leaderboardUpdateInterval * 1000)
        
        -- Update leaderboard cache
        GetLeaderboard(function(data)
            -- Broadcast to all players that leaderboard was updated
            TriggerClientEvent('dm:leaderboardUpdated', -1)
        end)
    end
end)

-- Force refresh leaderboard command for admins
RegisterCommand('refreshleaderboard', function(source)
    -- Check if source is console (0) or has admin permissions
    if source ~= 0 and not IsPlayerAceAllowed(source, "command.refreshleaderboard") then
        if source > 0 then
            TriggerClientEvent('dm:notify', source, 'No permission', 'error')
        end
        return
    end
    
    -- Reset leaderboard last update time to force refresh
    leaderboardLastUpdate = 0
    
    -- Refresh the leaderboard
    GetLeaderboard(function(data)
        if source > 0 then
            TriggerClientEvent('dm:notify', source, 'Leaderboard refreshed', 'success')
            TriggerClientEvent('dm:showLeaderboard', source, data)
        else
            print("[DM Core] Leaderboard refreshed by console")
        end
        
        -- Notify all players of update
        TriggerClientEvent('dm:leaderboardUpdated', -1)
    end)
end, false)
