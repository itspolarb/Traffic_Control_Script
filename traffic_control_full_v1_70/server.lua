local globalState = {
    mode = Config.DefaultMode,
    custom = nil,
    actorName = 'system'
}

local scenes = {}
local nextSceneId = 1
local authData = {
    admins = {},
    operators = {}
}

local function debugPrint(...)
    if Config.Debug then
        print('[traffic_control]', ...)
    end
end

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
    ExecuteCommand(('add_ace "%s" "%s" allow'):format(Config.OperatorPrincipal, Config.Permissions.localZone))

    ExecuteCommand(('add_ace "%s" "%s" allow'):format(Config.AdminPrincipal, Config.Permissions.menu))
    ExecuteCommand(('add_ace "%s" "%s" allow'):format(Config.AdminPrincipal, Config.Permissions.global))
    ExecuteCommand(('add_ace "%s" "%s" allow'):format(Config.AdminPrincipal, Config.Permissions.localZone))
    ExecuteCommand(('add_ace "%s" "%s" allow'):format(Config.AdminPrincipal, Config.Permissions.manage))
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
        localZone = playerHas(source, Config.Permissions.localZone),
        manage = playerHas(source, Config.Permissions.manage),
        admin = playerHas(source, Config.Permissions.admin)
    }
end

local function sceneList()
    local out = {}
    for _, scene in pairs(scenes) do
        out[#out + 1] = scene
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

local function syncState(actorName)
    globalState.actorName = actorName or globalState.actorName or 'system'
    TriggerClientEvent('traffic_control:setState', -1, {
        mode = globalState.mode,
        custom = globalState.custom,
        actorName = globalState.actorName,
        scenes = sceneList()
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

local function canManageScene(source, scene)
    if not scene then return false end
    if playerHas(source, Config.Permissions.manage) then return true end
    local principal = getPreferredIdentifier(source)
    return principal and principal == scene.ownerIdentifier
end

RegisterNetEvent('traffic_control:requestState', function()
    TriggerClientEvent('traffic_control:setState', source, {
        mode = globalState.mode,
        custom = globalState.custom,
        actorName = globalState.actorName,
        scenes = sceneList()
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

RegisterNetEvent('traffic_control:createScene', function(mode, radius)
    if not playerHas(source, Config.Permissions.localZone) then return end
    if not Config.SceneModes[mode] then return end

    local ped = GetPlayerPed(source)
    if ped == 0 then return end
    local coords = GetEntityCoords(ped)
    local principal = getPreferredIdentifier(source)
    local scene = {
        id = nextSceneId,
        ownerIdentifier = principal or ('source:' .. tostring(source)),
        ownerName = GetPlayerName(source) or 'unknown',
        x = coords.x,
        y = coords.y,
        z = coords.z,
        radius = math.max(Config.LocalZoneMinRadius, math.min(Config.LocalZoneMaxRadius, tonumber(radius) or Config.LocalZoneDefaultRadius)),
        mode = mode,
        active = true,
        createdAt = os.time()
    }
    nextSceneId = nextSceneId + 1
    scenes[scene.id] = scene

    syncState(GetPlayerName(source) or 'system')
    sendNotify(source, ('Created %s scene #%s.'):format(Config.SceneModes[mode].label, scene.id))
end)

RegisterNetEvent('traffic_control:removeScene', function(sceneId)
    local scene = scenes[tonumber(sceneId)]
    if not scene then return end
    if not canManageScene(source, scene) then return end

    scenes[scene.id] = nil
    syncState(GetPlayerName(source) or 'system')
    sendNotify(source, ('Removed scene #%s.'):format(scene.id))
end)

RegisterNetEvent('traffic_control:clearMyScenes', function()
    if not playerHas(source, Config.Permissions.localZone) then return end
    local principal = getPreferredIdentifier(source)
    if not principal then return end

    local removed = 0
    for id, scene in pairs(scenes) do
        if scene.ownerIdentifier == principal or playerHas(source, Config.Permissions.manage) then
            scenes[id] = nil
            removed = removed + 1
        end
    end

    syncState(GetPlayerName(source) or 'system')
    sendNotify(source, ('Cleared %s scene(s).'):format(removed))
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
    else
        if not arrayContains(authData.operators, principal) and not arrayContains(authData.admins, principal) then
            table.insert(authData.operators, principal)
            applyAclForIdentifier(principal, false)
        end
    end

    saveDataFile()
    buildPlayerList(source)
    TriggerClientEvent('traffic_control:setPermissions', tonumber(targetId), buildPermissionPayload(tonumber(targetId)))
    sendNotify(source, ('Updated access for %s.'):format(GetPlayerName(tonumber(targetId)) or principal))
end)

RegisterNetEvent('traffic_control:revokeByPlayerId', function(targetId, adminMode)
    if not playerHas(source, Config.Permissions.admin) then return end
    local principal = getPreferredIdentifier(tonumber(targetId))
    if not principal then return end

    if adminMode then
        removeFromArray(authData.admins, principal)
        removeAclForIdentifier(principal, true)
    else
        removeFromArray(authData.operators, principal)
        removeAclForIdentifier(principal, false)
    end

    saveDataFile()
    buildPlayerList(source)
    TriggerClientEvent('traffic_control:setPermissions', tonumber(targetId), buildPermissionPayload(tonumber(targetId)))
    sendNotify(source, ('Updated access for %s.'):format(GetPlayerName(tonumber(targetId)) or principal))
end)

RegisterCommand('trafficmenu', function(source)
    if source == 0 then return end
    if not playerHas(source, Config.Permissions.menu) then
        sendNotify(source, 'You do not have traffic control access.')
        return
    end
    TriggerClientEvent('traffic_control:openMenu', source)
end, false)

RegisterCommand('traffic', function(source, args)
    if source == 0 then return end
    if not playerHas(source, Config.Permissions.menu) then
        sendNotify(source, 'You do not have traffic control access.')
        return
    end

    local sub = args[1] and string.lower(args[1]) or 'status'
    if sub == 'status' then
        sendNotify(source, ('Global mode: %s | Active scenes: %s'):format(globalState.mode, tostring(#sceneList())))
        return
    end

    if sub == 'menu' then
        TriggerClientEvent('traffic_control:openMenu', source)
        return
    end

    if Config.Modes[sub] and playerHas(source, Config.Permissions.global) then
        globalState.mode = sub
        globalState.custom = nil
        syncState(GetPlayerName(source) or 'system')
        sendNotify(source, ('Global traffic preset set to %s.'):format(string.upper(sub)))
        return
    end

    sendNotify(source, 'Usage: /traffic [off|low|normal|high|status|menu]')
end, false)

AddEventHandler('playerJoining', function()
    local src = source
    SetTimeout(1500, function()
        TriggerClientEvent('traffic_control:setPermissions', src, buildPermissionPayload(src))
        TriggerClientEvent('traffic_control:setState', src, {
            mode = globalState.mode,
            custom = globalState.custom,
            actorName = globalState.actorName,
            scenes = sceneList()
        })
    end)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    authData = readDataFile()
    reapplyStoredAcl()
    debugPrint('Resource started. Scenes:', tostring(#sceneList()))
end)
