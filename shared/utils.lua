-- Shared utility functions
DM = {}

-- Format money values with commas
DM.FormatMoney = function(amount)
    local formatted = tostring(amount)
    while true do  
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k==0) then break end
    end
    return formatted
end

-- Check if value exists in a table
DM.TableContains = function(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

-- Get random element from table
DM.GetRandomFromTable = function(table)
    if #table <= 0 then return nil end
    return table[math.random(1, #table)]
end

-- Get closest player
DM.GetClosestPlayer = function(coords, radius)
    local players = GetActivePlayers()
    local closestDistance = radius or -1
    local closestPlayer = -1
    
    for _, playerId in ipairs(players) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed ~= PlayerPedId() then
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(coords - targetCoords)
            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = playerId
                closestDistance = distance
            end
        end
    end
    return closestPlayer, closestDistance
end

-- Generate a random string for tokens
DM.GenerateRandomString = function(length)
    local charset = {}
    for i = 48, 57 do table.insert(charset, string.char(i)) end  -- 0-9
    for i = 65, 90 do table.insert(charset, string.char(i)) end  -- A-Z
    for i = 97, 122 do table.insert(charset, string.char(i)) end -- a-z
    
    math.randomseed(os.time())
    
    local result = ""
    for i = 1, length do
        local index = math.random(1, #charset)
        result = result .. charset[index]
    end
    
    return result
end

-- Draw text on screen (client-side only)
if not IsDuplicityVersion() then -- Client side only
    DM.DrawText3D = function(x, y, z, text)
        local onScreen, _x, _y = World3dToScreen2d(x, y, z)
        local px, py, pz = table.unpack(GetGameplayCamCoord())
        local dist = GetDistanceBetweenCoords(px, py, pz, x, y, z, true)
        
        local scale = (1 / dist) * 0.5
        local fov = (1 / GetGameplayCamFov()) * 100
        local scale = scale * fov
        
        if onScreen then
            SetTextScale(0.0, 0.35 * scale)
            SetTextFont(4)
            SetTextProportional(1)
            SetTextColour(255, 255, 255, 255)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 150)
            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")
            SetTextCentre(1)
            AddTextComponentString(text)
            DrawText(_x, _y)
        end
    end
end
