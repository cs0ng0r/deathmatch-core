-- server/core.lua
local players = {}

-- Database setup
local function setupDatabase()
    local query = [[
        CREATE TABLE IF NOT EXISTS `players` (
            `identifier` VARCHAR(60) NOT NULL,
            `name` VARCHAR(100) NOT NULL,
            `cash` INT NOT NULL DEFAULT 5000,
            `bank` INT NOT NULL DEFAULT 15000,
            `kills` INT NOT NULL DEFAULT 0,
            `deaths` INT NOT NULL DEFAULT 0,
            `skin` LONGTEXT NULL,
            `last_login` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `ban_reason` VARCHAR(255) NULL DEFAULT NULL,
            `ban_until` TIMESTAMP NULL DEFAULT NULL,
            PRIMARY KEY (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        
        CREATE TABLE IF NOT EXISTS `dm_logs` (
            `id` INT AUTO_INCREMENT,
            `identifier` VARCHAR(60) NOT NULL,
            `action` VARCHAR(50) NOT NULL,
            `details` TEXT NULL,
            `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]

    MySQL.query(query, {}, function()
        print("[DM Core] Database tables initialized")
    end)
end

-- Player management
local function loadPlayer(source, identifier, name, cb)
    -- Check for banned players
    MySQL.query('SELECT * FROM players WHERE identifier = ?', { identifier }, function(result)
        if result and result[1] then
            -- Check for active ban
            if result[1].ban_until and result[1].ban_until > os.date() then
                DropPlayer(source, "You are banned: " .. (result[1].ban_reason or "No reason specified"))
                return
            end
            
            players[source] = result[1]
            players[source].source = source
            print(("[DM Core] Player %s loaded"):format(identifier))
            
            -- Update last login
            MySQL.update('UPDATE players SET last_login = CURRENT_TIMESTAMP, name = ? WHERE identifier = ?', 
                { name, identifier })
        else
            -- New player
            local newPlayer = {
                identifier = identifier,
                name = name,
                cash = Config.StartingMoney.cash,
                bank = Config.StartingMoney.bank,
                kills = 0,
                deaths = 0,
                skin = nil,
                source = source
            }

            local insert = 'INSERT INTO players (identifier, name, cash, bank) VALUES (?, ?, ?, ?)'
            MySQL.insert(insert, {
                identifier,
                name,
                Config.StartingMoney.cash,
                Config.StartingMoney.bank
            }, function()
                players[source] = newPlayer
                print(("[DM Core] New player %s created"):format(identifier))
                
                -- Log new player
                logPlayerAction(identifier, "REGISTER", "New player registered")
            end)
        end

        if cb then cb(players[source]) end
    end)
end

-- Money functions
local function updateMoney(source, amount, moneyType)
    if not players[source] then return false end

    moneyType = moneyType or 'cash'
    local oldAmount = players[source][moneyType]
    players[source][moneyType] = players[source][moneyType] + amount

    -- Prevent negative money
    if players[source][moneyType] < 0 then
        players[source][moneyType] = 0
    end

    local update = 'UPDATE players SET ' .. moneyType .. ' = ? WHERE identifier = ?'
    MySQL.update(update, { players[source][moneyType], players[source].identifier })

    TriggerClientEvent('dm:updateMoney', source, moneyType, players[source][moneyType])
    
    -- Log significant money changes (more than 5000)
    if math.abs(amount) >= 5000 then
        logPlayerAction(players[source].identifier, "MONEY_CHANGE", 
            string.format("%s changed by $%s from $%s to $%s", 
            moneyType, amount, oldAmount, players[source][moneyType]))
    end
    
    return true
end

-- Banking commands
RegisterCommand('withdraw', function(source, args)
    local amount = tonumber(args[1])
    if not amount or amount <= 0 then
        TriggerClientEvent('dm:notify', source, 'Invalid amount', 'error')
        return
    end
    
    if not players[source] or players[source].bank < amount then
        TriggerClientEvent('dm:notify', source, 'Not enough money in bank', 'error')
        return
    end
    
    -- Remove from bank, add to cash
    updateMoney(source, -amount, 'bank')
    updateMoney(source, amount, 'cash')
    
    TriggerClientEvent('dm:notify', source, 'Withdrew $' .. amount, 'success')
end)

RegisterCommand('deposit', function(source, args)
    local amount = tonumber(args[1])
    if not amount or amount <= 0 then
        TriggerClientEvent('dm:notify', source, 'Invalid amount', 'error')
        return
    end
    
    if not players[source] or players[source].cash < amount then
        TriggerClientEvent('dm:notify', source, 'Not enough cash', 'error')
        return
    end
    
    -- Remove from cash, add to bank
    updateMoney(source, -amount, 'cash')
    updateMoney(source, amount, 'bank')
    
    TriggerClientEvent('dm:notify', source, 'Deposited $' .. amount, 'success')
end)

-- Kills/Deaths tracking
local function addKill(source)
    if not players[source] then return end

    players[source].kills = players[source].kills + 1
    updateMoney(source, Config.KillReward, 'cash')

    MySQL.update('UPDATE players SET kills = ? WHERE identifier = ?',
        { players[source].kills, players[source].identifier })
        
    TriggerClientEvent('dm:notify', source, 'Kill confirmed! +$' .. Config.KillReward, 'success')
end

local function addDeath(source)
    if not players[source] then return end

    players[source].deaths = players[source].deaths + 1
    updateMoney(source, -Config.DeathPenalty, 'cash')

    MySQL.update('UPDATE players SET deaths = ? WHERE identifier = ?',
        { players[source].deaths, players[source].identifier })
end

-- Skin handling
local function saveSkin(source, skin)
    if not players[source] then return end

    players[source].skin = json.encode(skin)
    MySQL.update('UPDATE players SET skin = ? WHERE identifier = ?',
        { players[source].skin, players[source].identifier })
end

local function loadSkin(source)
    if not players[source] then return nil end
    return players[source].skin and json.decode(players[source].skin) or nil
end

-- Log player actions
function logPlayerAction(identifier, action, details)
    MySQL.insert('INSERT INTO dm_logs (identifier, action, details) VALUES (?, ?, ?)',
        { identifier, action, details })
end

-- Admin commands
RegisterCommand('ban', function(source, args)
    -- Check if source is console (0) or has admin permissions
    if source ~= 0 and not IsPlayerAceAllowed(source, "command.ban") then
        if source > 0 then
            TriggerClientEvent('dm:notify', source, 'No permission', 'error')
        end
        return
    end
    
    local targetId = tonumber(args[1])
    if not targetId then return end
    
    local days = tonumber(args[2]) or 7 -- Default 7 days
    table.remove(args, 1)
    table.remove(args, 1)
    local reason = table.concat(args, " ") or "No reason specified"
    
    if players[targetId] then
        local identifier = players[targetId].identifier
        local banUntil = os.date("%Y-%m-%d %H:%M:%S", os.time() + (days * 86400))
        
        MySQL.update('UPDATE players SET ban_reason = ?, ban_until = ? WHERE identifier = ?',
            { reason, banUntil, identifier })
        
        -- Log ban
        logPlayerAction(identifier, "BAN", string.format("Banned until %s for: %s", banUntil, reason))
        
        -- Kick player
        DropPlayer(targetId, "You have been banned: " .. reason)
        
        if source > 0 then
            TriggerClientEvent('dm:notify', source, 'Player banned successfully', 'success')
        end
        print(("[DM Core] Player %s banned by %s for %s days. Reason: %s"):format(
            GetPlayerName(targetId), 
            source > 0 and GetPlayerName(source) or "Console", 
            days, 
            reason
        ))
    else
        if source > 0 then
            TriggerClientEvent('dm:notify', source, 'Player not found', 'error')
        end
    end
end, false)

RegisterCommand('unban', function(source, args)
    -- Check if source is console (0) or has admin permissions
    if source ~= 0 and not IsPlayerAceAllowed(source, "command.unban") then
        if source > 0 then
            TriggerClientEvent('dm:notify', source, 'No permission', 'error')
        end
        return
    end
    
    local identifier = args[1]
    if not identifier then return end
    
    MySQL.update('UPDATE players SET ban_reason = NULL, ban_until = NULL WHERE identifier = ?',
        { identifier })
    
    -- Log unban
    logPlayerAction(identifier, "UNBAN", "Unbanned by " .. (source > 0 and GetPlayerName(source) or "Console"))
    
    if source > 0 then
        TriggerClientEvent('dm:notify', source, 'Player unbanned successfully', 'success')
    end
end, false)

-- Events
RegisterNetEvent('dm:playerReady')
AddEventHandler('dm:playerReady', function()
    local source = source
    local identifier = GetPlayerIdentifier(source, 0)
    local name = GetPlayerName(source)

    if not identifier then
        DropPlayer(source, 'Failed to load your identifier')
        return
    end

    loadPlayer(source, identifier, name, function(player)
        TriggerClientEvent('dm:initPlayer', source, {
            cash = player.cash,
            bank = player.bank,
            kills = player.kills,
            deaths = player.deaths
        })

        -- Load skin if exists
        if player.skin then
            TriggerClientEvent('illenium-appearance:setPlayerAppearance', source, json.decode(player.skin))
        end
        
        -- Generate security token for player
        TriggerEvent('dm:requestSecurityToken', source)
    end)
end)

RegisterNetEvent('dm:playerKilled')
AddEventHandler('dm:playerKilled', function(killerId)
    local victim = source
    local killer = tonumber(killerId)

    if killer and killer > 0 then
        addKill(killer)
        
        -- Log kill
        if players[victim] and players[killer] then
            logPlayerAction(players[killer].identifier, "KILL", 
                "Killed " .. players[victim].name .. " (" .. players[victim].identifier .. ")")
        end
    end

    addDeath(victim)
end)

RegisterNetEvent('dm:saveSkin')
AddEventHandler('dm:saveSkin', function(skin)
    saveSkin(source, skin)
end)

-- Chat functions
AddEventHandler('chatMessage', function(source, name, message)
    -- Basic chat filtering/spam prevention could go here
    
    -- Log chat messages
    if players[source] then
        logPlayerAction(players[source].identifier, "CHAT", message)
    end
end)

-- Exports
exports('getPlayer', function(source)
    return players[source]
end)

exports('updateMoney', updateMoney)

-- Initialize
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    setupDatabase()
end)

AddEventHandler('playerDropped', function(reason)
    local source = source
    if players[source] then
        -- Log player disconnect
        logPlayerAction(players[source].identifier, "DISCONNECT", "Reason: " .. reason)
        players[source] = nil
    end
end)
