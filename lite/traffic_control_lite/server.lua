local globalState = {
    mode = Config.DefaultMode,
    custom = nil,
    actorName = 'system'
}

local authData = {
    admins = {},
    operators = {}
}

local function readDataFile()
    local raw = LoadResourceFile(GetCurrentResourceName(), Config.DataFile)
    if not raw or raw == '' then
        return { admins = {}, operators = {} }
    end

    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then
        return { admins = {}, operators = {} }
    end

    decoded.admins = decoded.admins or {}
    decoded.operators = decoded.operators or {}
    return decoded
end

local function saveDataFile()
    SaveResourceFile(GetCurrentResourceName(), Config.DataFile, json.encode(authData, { indent = true }), -1)
end

local function arrayContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then return true end
    end
    return false
end

local function removeFromArray(tbl, value)
    for i = #tbl, 1, -1 do
        if tbl[i] == value then
            table.remove(tbl, i)
        end
    end
end

local function applyAclForIdentifier(principal, asAdmin)
    if asAdmin then
        ExecuteCommand(('add_principal "%s" "%s"'):format(principal, Config.AdminPrincipal))
    else
        ExecuteCommand(('add_principal "%s" "%s"'):format(principal, Config.OperatorPrincipal))
    end
end

local function removeAclForIdentifier(principal, asAdmin)
    if asAdmin then
        ExecuteCommand(('remove_principal "%s" "%s"'):format(principal, Config.AdminPrincipal))
    else
        ExecuteCommand(('remove_principal "%s" "%s"'):format(principal, Config.OperatorPrincipal))
    end
end

local function ensureBaseAces()
    ExecuteCommand(('add_ace "%s" "%s" allow'):format(Config.OperatorPrincipal, Config.Permissions.menu))

    ExecuteCommand(('add_ace "%s" "%s" allow'):format(Config.AdminPrincipal, Config.Permissions.menu))
    ExecuteCommand(('add_ace "%s" "%s" allow'):format(Config.AdminPrincipal, Config.Permissions.global))
    ExecuteCommand(('add_ace "%s" "%s" allow'):format(Config.AdminPrincipal, Config.Permissions.admin))
end

local function reapplyStoredAcl()
    ensureBaseAces()

    for _, principal in ipairs(Config.BootstrapIdentifiers) do
        if not arrayContains(authData.admins, principal) then
            table.insert(authData.admins, principal)
        end
    end

    for _, principal in ipairs(authData.admins) do
        applyAclForIdentifier(principal, true)
    end

    for _, principal in ipairs(authData.operators) do
        if not arrayContains(authData.admins, principal) then
            applyAclForIdentifier(principal, false)
        end
    end

    saveDataFile()
end

local function getPreferredIdentifier(source)
    local identifiers = GetPlayerIdentifiers(source)
    for _, prefix in ipairs(Config.PreferredIdentifierTypes) do
        for _, identifier in ipairs(identifiers) do
            if identifier:sub(1, #prefix) == prefix then
                return 'identifier.' .. identifier
            end
        end
    end
    if identifiers[1] then
        return 'identifier.' .. identifiers[1]
    end
    return nil
end

local function playerHas(source, ace)
    if source == 0 then return true end
    return IsPlayerAceAllowed(source, ace)
end

local function sendNotify(target, msg)
    TriggerClientEvent('traffic_control:notify', target, msg)
end

local function buildPermissionPayload(source)
    return {
        hasAccess = playerHas(source, Config.Permissions.menu),
        isAdmin = playerHas(source, Config.Permissions.admin),
        menu = playerHas(source, Config.Permissions.menu),
        global = playerHas(source, Config.Permissions.global),
        admin = playerHas(source, Config.Permissions.admin)
    }
end

local function syncState(actorName)
    globalState.actorName = actorName or globalState.actorName or 'system'
    TriggerClientEvent('traffic_control:setState', -1, {
        mode = globalState.mode,
        custom = globalState.custom,
        actorName = globalState.actorName
    })
end

local function buildPlayerList(source)
    local out = {}
    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        out[#out + 1] = {
            id = pid,
            name = GetPlayerName(pid),
            identifier = getPreferredIdentifier(pid) or 'unknown',
            hasAccess = playerHas(pid, Config.Permissions.menu),
            isAdmin = playerHas(pid, Config.Permissions.admin)
        }
    end
    TriggerClientEvent('traffic_control:updatePlayerList', source, out)
end

RegisterNetEvent('traffic_control:requestState', function()
    TriggerClientEvent('traffic_control:setState', source, {
        mode = globalState.mode,
        custom = globalState.custom,
        actorName = globalState.actorName
    })
    TriggerClientEvent('traffic_control:setPermissions', source, buildPermissionPayload(source))
end)

RegisterNetEvent('traffic_control:requestPlayerList', function()
    if not playerHas(source, Config.Permissions.admin) then return end
    buildPlayerList(source)
end)

RegisterNetEvent('traffic_control:setPreset', function(mode)
    if not playerHas(source, Config.Permissions.global) then return end
    if not Config.Modes[mode] then return end

    globalState.mode = mode
    globalState.custom = nil
    syncState(GetPlayerName(source) or 'system')

    if Config.BroadcastGlobalChanges then
        sendNotify(-1, ('Global traffic preset set to %s.'):format(string.upper(mode)))
    else
        sendNotify(source, ('Global traffic preset set to %s.'):format(string.upper(mode)))
    end
end)

RegisterNetEvent('traffic_control:setCustom', function(custom)
    if not playerHas(source, Config.Permissions.global) then return end
    if type(custom) ~= 'table' then return end

    globalState.mode = 'custom'
    globalState.custom = {
        vehicleDensity = tonumber(custom.vehicleDensity) or 1.0,
        randomVehicleDensity = tonumber(custom.randomVehicleDensity) or 1.0,
        parkedVehicleDensity = tonumber(custom.parkedVehicleDensity) or 1.0,
        pedDensity = tonumber(custom.pedDensity) or 1.0,
        scenarioPedDensity = tonumber(custom.scenarioPedDensity) or 1.0
    }

    syncState(GetPlayerName(source) or 'system')
    if Config.BroadcastGlobalChanges then
        sendNotify(-1, 'Custom global traffic densities applied.')
    else
        sendNotify(source, 'Custom global traffic densities applied.')
    end
end)

RegisterNetEvent('traffic_control:grantByPlayerId', function(targetId, adminMode)
    if not playerHas(source, Config.Permissions.admin) then return end
    local principal = getPreferredIdentifier(tonumber(targetId))
    if not principal then return end

    if adminMode then
        if not arrayContains(authData.admins, principal) then
            table.insert(authData.admins, principal)
        end
        removeFromArray(authData.operators, principal)
        applyAclForIdentifier(principal, true)
        removeAclForIdentifier(principal, false)
        sendNotify(source, ('Granted admin access to %s.'):format(principal))
    else
        if not arrayContains(authData.admins, principal) and not arrayContains(authData.operators, principal) then
            table.insert(authData.operators, principal)
        end
        if not arrayContains(authData.admins, principal) then
            applyAclForIdentifier(principal, false)
        end
        sendNotify(source, ('Granted operator access to %s.'):format(principal))
    end

    saveDataFile()
    buildPlayerList(source)
end)

RegisterNetEvent('traffic_control:revokeByPlayerId', function(targetId, adminMode)
    if not playerHas(source, Config.Permissions.admin) then return end
    local principal = getPreferredIdentifier(tonumber(targetId))
    if not principal then return end

    if adminMode then
        removeFromArray(authData.admins, principal)
        removeAclForIdentifier(principal, true)
        sendNotify(source, ('Revoked admin access from %s.'):format(principal))
    else
        removeFromArray(authData.operators, principal)
        removeAclForIdentifier(principal, false)
        sendNotify(source, ('Revoked operator access from %s.'):format(principal))
    end

    saveDataFile()
    buildPlayerList(source)
end)

RegisterCommand('traffic', function(source, args)
    local sub = args[1] and string.lower(args[1]) or 'status'

    if sub == 'menu' then
        if source == 0 then
            print('[traffic_control_lite] /traffic menu can only be used by a player.')
            return
        end
        if not playerHas(source, Config.Permissions.menu) then
            sendNotify(source, 'You do not have traffic control access.')
            return
        end
        TriggerClientEvent('traffic_control:openMenu', source)
        return
    end

    if sub == 'status' then
        if not playerHas(source, Config.Permissions.menu) then
            sendNotify(source, 'You do not have traffic control access.')
            return
        end
        sendNotify(source, ('Current global mode: %s'):format(string.upper(globalState.mode)))
        return
    end

    if sub == 'off' or sub == 'low' or sub == 'normal' or sub == 'high' then
        if not playerHas(source, Config.Permissions.global) then
            sendNotify(source, 'You do not have permission to change global traffic.')
            return
        end
        globalState.mode = sub
        globalState.custom = nil
        syncState(source == 0 and 'console' or (GetPlayerName(source) or 'system'))
        if source == 0 or Config.BroadcastGlobalChanges then
            sendNotify(-1, ('Global traffic preset set to %s.'):format(string.upper(sub)))
        else
            sendNotify(source, ('Global traffic preset set to %s.'):format(string.upper(sub)))
        end
        return
    end

    sendNotify(source, 'Usage: /traffic [off|low|normal|high|status|menu]')
end, false)

RegisterCommand('trafficmenu', function(source)
    if source == 0 then
        print('[traffic_control_lite] /trafficmenu can only be used by a player.')
        return
    end
    if not playerHas(source, Config.Permissions.menu) then
        sendNotify(source, 'You do not have traffic control access.')
        return
    end
    TriggerClientEvent('traffic_control:openMenu', source)
end, false)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    authData = readDataFile()
    reapplyStoredAcl()
    syncState('system')
    print('[traffic_control_lite] Started successfully.')
end)
