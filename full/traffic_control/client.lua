local state = {
    mode = Config.DefaultMode,
    custom = nil,
    scenes = {},
    actorName = 'system',
    props = {}
}

local permissions = {
    hasAccess = false,
    isAdmin = false,
    menu = false,
    global = false,
    localZone = false,
    manage = false,
    admin = false
}

local players = {}
local menuOpen = false
local menuStack = { 'main' }
local selection = {}
local sceneModeDraft = 'hard_closure'
local localRadiusDraft = Config.LocalZoneDefaultRadius
local customDraft = nil
local previousSceneMap = {}
local previousPropMap = {}
local previewProp = nil
local previewCategory = nil
local previewIndex = nil
local previewDistance = Config.PropPlaceDistance
local previewHeading = 0.0

local function notify(msg)
    if not Config.Notifications then return end
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, false)
end

local function deepCopy(tbl)
    local out = {}
    for k, v in pairs(tbl or {}) do
        if type(v) == 'table' then
            out[k] = deepCopy(v)
        else
            out[k] = v
        end
    end
    return out
end

local function currentGlobalSettings()
    if state.mode == 'custom' and state.custom then
        return state.custom
    end
    return Config.Modes[state.mode] or Config.Modes.normal
end

local function round2(v)
    return math.floor((v + 0.0001) * 100 + 0.5) / 100
end

local function clamp(v, minV, maxV)
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

local function applyGlobalTraffic()
    local settings = currentGlobalSettings()
    SetVehicleDensityMultiplierThisFrame(settings.vehicleDensity)
    SetRandomVehicleDensityMultiplierThisFrame(settings.randomVehicleDensity)
    SetParkedVehicleDensityMultiplierThisFrame(settings.parkedVehicleDensity)
    SetPedDensityMultiplierThisFrame(settings.pedDensity)
    SetScenarioPedDensityMultiplierThisFrame(settings.scenarioPedDensity, settings.scenarioPedDensity)
end

local function isAmbientAiVehicle(veh)
    if veh == 0 or not DoesEntityExist(veh) then return false end

    for seat = -1, GetVehicleModelNumberOfSeats(GetEntityModel(veh)) - 2 do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped ~= 0 and DoesEntityExist(ped) and IsPedAPlayer(ped) then
            return false
        end
    end

    if NetworkGetEntityIsNetworked(veh) then return false end

    local driver = GetPedInVehicleSeat(veh, -1)
    if driver ~= 0 and DoesEntityExist(driver) and not IsPedAPlayer(driver) then
        return true
    end
    return false
end

local function restoreSceneRoads(scene)
    local r = scene.radius
    SetRoadsBackToOriginal(
        scene.x - r,
        scene.y - r,
        scene.z - 100.0,
        scene.x + r,
        scene.y + r,
        scene.z + 100.0
    )
end

local function suppressScene(scene)
    local modeData = Config.SceneModes[scene.mode]
    if not modeData then return end

    local r = scene.radius
    local px, py, pz = table.unpack(GetEntityCoords(PlayerPedId()))
    local dx, dy, dz = px - scene.x, py - scene.y, pz - scene.z
    local activationRadius = r + 200.0
    if (dx * dx + dy * dy + dz * dz) > (activationRadius * activationRadius) then return end

    if modeData.roadBlock then
        SetRoadsInArea(scene.x - r, scene.y - r, scene.z - 100.0, scene.x + r, scene.y + r, scene.z + 100.0, false, false)
        RemoveVehiclesFromGeneratorsInArea(scene.x - r, scene.y - r, scene.z - 100.0, scene.x + r, scene.y + r, scene.z + 100.0, false)
    end

    local localFactor = 1.0
    if scene.mode == 'soft_closure' then localFactor = 0.30 end
    if scene.mode == 'reduced_flow' then localFactor = 0.55 end
    if scene.mode == 'ped_suppression' then localFactor = 0.85 end

    if (dx * dx + dy * dy + dz * dz) <= ((r + 90.0) * (r + 90.0)) then
        SetVehicleDensityMultiplierThisFrame(math.min(currentGlobalSettings().vehicleDensity, localFactor))
        SetRandomVehicleDensityMultiplierThisFrame(math.min(currentGlobalSettings().randomVehicleDensity, localFactor))
        SetParkedVehicleDensityMultiplierThisFrame(math.min(currentGlobalSettings().parkedVehicleDensity, localFactor))
        SetPedDensityMultiplierThisFrame(math.min(currentGlobalSettings().pedDensity, modeData.pedScale or 1.0))
        SetScenarioPedDensityMultiplierThisFrame(math.min(currentGlobalSettings().scenarioPedDensity, modeData.pedScale or 1.0), math.min(currentGlobalSettings().scenarioPedDensity, modeData.pedScale or 1.0))
    end

    if modeData.clearAmbient then
        local vehicles = GetGamePool('CVehicle')
        for _, veh in ipairs(vehicles) do
            if isAmbientAiVehicle(veh) then
                local vx, vy, vz = table.unpack(GetEntityCoords(veh))
                local ddx, ddy, ddz = vx - scene.x, vy - scene.y, vz - scene.z
                if (ddx * ddx + ddy * ddy + ddz * ddz) <= ((r * 0.75) * (r * 0.75)) then
                    local speed = GetEntitySpeed(veh)
                    if speed < 3.0 then
                        SetEntityAsMissionEntity(veh, true, true)
                        DeleteVehicle(veh)
                    end
                end
            end
        end
    end
end

local function propDefinition(category, index)
    local list = Config.Props and Config.Props[category]
    if not list then return nil end
    return list[index]
end

local function stopPreview()
    if previewProp and DoesEntityExist(previewProp) then
        DeleteEntity(previewProp)
    end
    previewProp = nil
    previewCategory = nil
    previewIndex = nil
    previewDistance = Config.PropPlaceDistance
    previewHeading = 0.0
end

local function startPreview(category, index)
    stopPreview()
    local def = propDefinition(category, index)
    if not def then return end

    local model = joaat(def.model)
    RequestModel(model)
    local timeout = GetGameTimer() + 5000

    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(0)
    end

    if not HasModelLoaded(model) then
        notify('Failed to load prop model.')
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    previewProp = CreateObjectNoOffset(model, coords.x, coords.y, coords.z, false, false, false)
    if previewProp == 0 then
        notify('Failed to create preview prop.')
        return
    end

    SetEntityCollision(previewProp, false, false)
    SetEntityAlpha(previewProp, 180, false)
    PlaceObjectOnGroundProperly(previewProp)
    FreezeEntityPosition(previewProp, true)

    previewCategory = category
    previewIndex = index
    previewHeading = GetEntityHeading(ped)
    previewDistance = Config.PropPlaceDistance
end

local function updatePreview()
    if not previewProp or not DoesEntityExist(previewProp) then return end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local targetX = coords.x + (forward.x * previewDistance)
    local targetY = coords.y + (forward.y * previewDistance)
    local targetZ = coords.z + Config.PreviewVerticalOffset
    local found, groundZ = GetGroundZFor_3dCoord(targetX, targetY, targetZ + 5.0, false)
    if found then targetZ = groundZ end
    SetEntityCoordsNoOffset(previewProp, targetX, targetY, targetZ, false, false, false)
    SetEntityHeading(previewProp, previewHeading)
end

local function confirmPreview()
    if not previewProp or not DoesEntityExist(previewProp) then return end
    local def = propDefinition(previewCategory, previewIndex)
    if not def then
        stopPreview()
        return
    end
    local coords = GetEntityCoords(previewProp)
    TriggerServerEvent('traffic_control:placeProp', def.model, coords.x, coords.y, coords.z, previewHeading)
    stopPreview()
end

local function sceneModeKeys()
    local out = {}
    for key, _ in pairs(Config.SceneModes) do
        out[#out + 1] = key
    end
    table.sort(out)
    return out
end

local function drawMenuRect(x, y, w, h, r, g, b, a)
    DrawRect(x + (w / 2.0), y + (h / 2.0), w, h, r, g, b, a)
end

local function drawTextRaw(x, y, scale, text, font, r, g, b, a, justify, wrapX)
    SetTextFont(font or 0)
    SetTextScale(scale, scale)
    SetTextColour(r or 255, g or 255, b or 255, a or 255)
    SetTextOutline()
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextJustification(justify or 1)
    if wrapX then SetTextWrap(0.0, wrapX) end
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

local function disableMenuGameplayControls()
    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)

    EnableControlAction(0, 172, true)
    EnableControlAction(0, 173, true)
    EnableControlAction(0, 174, true)
    EnableControlAction(0, 175, true)
    EnableControlAction(0, 176, true)
    EnableControlAction(0, 177, true)
    EnableControlAction(0, 188, true)
    EnableControlAction(0, 187, true)
    EnableControlAction(0, 189, true)
    EnableControlAction(0, 190, true)
    EnableControlAction(0, 201, true)
    EnableControlAction(0, 202, true)

    DisablePlayerFiring(PlayerPedId(), true)
end

local function disablePlacementBlockingControls()
    DisableControlAction(0, 24, true)
    DisableControlAction(0, 25, true)
    DisableControlAction(0, 45, true)
    DisableControlAction(0, 140, true)
    DisableControlAction(0, 141, true)
    DisableControlAction(0, 142, true)
    DisableControlAction(0, 257, true)
    DisableControlAction(0, 263, true)
    DisableControlAction(0, 264, true)
    DisableControlAction(0, 37, true)
    DisableControlAction(0, 23, true)
    DisableControlAction(0, 75, true)

    DisablePlayerFiring(PlayerPedId(), true)
end

local function drawSliderBar(x, y, w, h, value)
    local pct = (value - Config.SliderMin) / (Config.SliderMax - Config.SliderMin)
    pct = clamp(pct, 0.0, 1.0)
    drawMenuRect(x, y, w, h, 25, 25, 25, 210)
    drawMenuRect(x, y, w * pct, h, 255, 255, 255, 220)
end

local function getMenuPath() return menuStack[#menuStack] end
local function setSelection(path, idx) selection[path] = idx end
local function getSelection(path) return selection[path] or 1 end

local function openMenu()
    menuOpen = true
    menuStack = { 'main' }
    TriggerServerEvent('traffic_control:requestState')
    TriggerServerEvent('traffic_control:requestPlayerList')
end

local function closeMenu() menuOpen = false end
local function pushMenu(path) menuStack[#menuStack + 1] = path end
local function popMenu()
    if #menuStack > 1 then table.remove(menuStack, #menuStack) else closeMenu() end
end

local function sceneRecommendation(mode)
    local data = Config.SceneModes[mode]
    return data and data.recommendation or 'Recommended sizes vary by use.'
end

local function findClosestWorldObjectForProp(prop)
    local closest = 0
    local closestDist = 999999.0
    local targetModel = joaat(prop.model)

    local objects = GetGamePool('CObject')
    for _, obj in ipairs(objects) do
        if DoesEntityExist(obj) and GetEntityModel(obj) == targetModel then
            local coords = GetEntityCoords(obj)
            local dx = coords.x - prop.x
            local dy = coords.y - prop.y
            local dz = coords.z - prop.z
            local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

            if dist < closestDist then
                closestDist = dist
                closest = obj
            end
        end
    end

    if closest ~= 0 and closestDist <= 5.0 then
        return closest
    end

    return 0
end

local function cleanupRemovedProp(prop)
    local obj = findClosestWorldObjectForProp(prop)
    if obj ~= 0 and DoesEntityExist(obj) then
        SetEntityAsMissionEntity(obj, true, true)
        DeleteObject(obj)

        if DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
    end
end

local function menuRows()
    local path = getMenuPath()
    local rows = {}

    if path == 'main' then
        if permissions.global then
            rows[#rows + 1] = { type = 'submenu', left = 'Global Traffic', right = '→', target = 'global', desc = 'Manage server-wide traffic presets and custom sliders.' }
        end
        if permissions.localZone then
            rows[#rows + 1] = { type = 'submenu', left = 'Local Traffic Control', right = '→', target = 'local', desc = 'Create and manage local traffic control scenes.' }
            rows[#rows + 1] = { type = 'submenu', left = 'Scene Equipment', right = '→', target = 'props', desc = 'Place cones, barriers, and lights.' }
            rows[#rows + 1] = { type = 'submenu', left = 'Active Scenes', right = tostring(#state.scenes), target = 'scenes', desc = 'Review and remove active local scenes.' }
        end
        if permissions.admin then
            rows[#rows + 1] = { type = 'submenu', left = 'Access Management', right = '→', target = 'players', desc = 'Grant or revoke traffic control access.' }
        end
        rows[#rows + 1] = { type = 'action', left = 'Refresh', desc = 'Refresh state and permissions.', action = function()
            TriggerServerEvent('traffic_control:requestState')
            TriggerServerEvent('traffic_control:requestPlayerList')
        end }
    elseif path == 'global' then
        rows = {
            { type = 'label', left = 'Current Preset', right = string.upper(state.mode), desc = 'Shows the current global traffic mode.' },
            { type = 'action', left = 'Preset: OFF', desc = 'Disable global traffic and peds.', action = function() TriggerServerEvent('traffic_control:setPreset', 'off') end },
            { type = 'action', left = 'Preset: LOW', desc = 'Set a light global traffic population.', action = function() TriggerServerEvent('traffic_control:setPreset', 'low') end },
            { type = 'action', left = 'Preset: NORMAL', desc = 'Restore the default global traffic population.', action = function() TriggerServerEvent('traffic_control:setPreset', 'normal') end },
            { type = 'action', left = 'Preset: HIGH', desc = 'Increase global traffic and pedestrians.', action = function() TriggerServerEvent('traffic_control:setPreset', 'high') end },
            { type = 'submenu', left = 'Custom Density Sliders', right = '→', target = 'sliders', desc = 'Adjust density values manually while keeping presets available.' },
        }
    elseif path == 'sliders' then
        local current = customDraft or deepCopy(currentGlobalSettings())
        customDraft = current
        rows = {
            { type = 'slider', key = 'vehicleDensity', left = 'Vehicle Density', value = current.vehicleDensity, desc = 'Controls active street vehicle density.' },
            { type = 'slider', key = 'randomVehicleDensity', left = 'Random Vehicle Density', value = current.randomVehicleDensity, desc = 'Controls random spawned traffic density.' },
            { type = 'slider', key = 'parkedVehicleDensity', left = 'Parked Vehicle Density', value = current.parkedVehicleDensity, desc = 'Controls parked vehicle density.' },
            { type = 'slider', key = 'pedDensity', left = 'Ped Density', value = current.pedDensity, desc = 'Controls walking pedestrian density.' },
            { type = 'slider', key = 'scenarioPedDensity', left = 'Scenario Peds', value = current.scenarioPedDensity, desc = 'Controls scenario and ambient peds.' },
            { type = 'action', left = 'Apply Custom Sliders', desc = 'Apply these custom density values globally.', action = function() TriggerServerEvent('traffic_control:setCustom', customDraft) end },
            { type = 'action', left = 'Reset Sliders to NORMAL', desc = 'Reset all custom sliders to normal values.', action = function() customDraft = deepCopy(Config.Modes.normal) end },
        }
    elseif path == 'local' then
        local data = Config.SceneModes[sceneModeDraft]
        rows = {
            { type = 'cycle', key = 'sceneModeDraft', left = 'Scene Mode', right = data and data.label or sceneModeDraft, desc = (data and data.description or '') .. ' ' .. sceneRecommendation(sceneModeDraft) },
            { type = 'slider', key = 'localRadiusDraft', left = 'Scene Radius', value = localRadiusDraft, desc = sceneRecommendation(sceneModeDraft) },
            { type = 'action', left = 'Create Scene At My Position', desc = 'Create a local traffic control scene at your current position.', action = function() TriggerServerEvent('traffic_control:createScene', sceneModeDraft, localRadiusDraft) end },
            { type = 'action', left = 'Clear My Scenes', desc = 'Remove every scene you own.', action = function() TriggerServerEvent('traffic_control:clearMyScenes') end },
        }
    elseif path == 'props' then
        rows = {
            { type = 'submenu', left = 'Cones', right = '→', target = 'props:cones', desc = 'Place traffic cones.' },
            { type = 'submenu', left = 'Barriers', right = '→', target = 'props:barriers', desc = 'Place barriers.' },
            { type = 'submenu', left = 'Lights', right = '→', target = 'props:lights', desc = 'Place warning and work lights.' },
            { type = 'action', left = 'Remove Nearest Prop', desc = 'Remove the nearest prop you own. Managers can remove any prop.', action = function() TriggerServerEvent('traffic_control:removeNearestProp') end },
            { type = 'action', left = 'Clear My Props', desc = 'Remove every prop you own.', action = function() TriggerServerEvent('traffic_control:clearMyProps') end },
        }
    elseif path:sub(1, 6) == 'props:' then
        local category = path:sub(7)
        local list = (Config.Props and Config.Props[category]) or {}
        for i, def in ipairs(list) do
            rows[#rows + 1] = {
                type = 'action',
                left = ('Place %s'):format(def.label),
                desc = ('Preview and place %s.'):format(def.label),
                action = function()
                    startPreview(category, i)
                    closeMenu()
                end
            }
        end
    elseif path == 'scenes' then
        rows[#rows + 1] = { type = 'label', left = 'Active Scenes', right = tostring(#state.scenes), desc = 'Lists all active local traffic scenes.' }
        for _, scene in ipairs(state.scenes) do
            local label = Config.SceneModes[scene.mode] and Config.SceneModes[scene.mode].label or scene.mode
            rows[#rows + 1] = {
                type = 'submenu',
                left = ('Scene #%s'):format(scene.id),
                right = label,
                target = ('scene:%s'):format(scene.id),
                desc = ('%s | Radius %sm | Owner %s'):format(label, math.floor(scene.radius), scene.ownerName or 'unknown')
            }
        end
    elseif path:sub(1, 6) == 'scene:' then
        local sceneId = tonumber(path:sub(7))
        local target = nil
        for _, scene in ipairs(state.scenes) do
            if scene.id == sceneId then target = scene break end
        end
        if target then
            local label = Config.SceneModes[target.mode] and Config.SceneModes[target.mode].label or target.mode
            rows = {
                { type = 'label', left = label, right = ('%sm'):format(math.floor(target.radius)), desc = ('Owner: %s'):format(target.ownerName or 'unknown') },
                { type = 'action', left = 'Remove Scene', desc = 'Delete this scene and restore normal road behavior.', action = function() TriggerServerEvent('traffic_control:removeScene', target.id) end },
            }
        else
            rows = {{ type = 'label', left = 'Scene not found', right = '', desc = 'This scene no longer exists.' }}
        end
    elseif path == 'players' then
        rows[#rows + 1] = { type = 'action', left = 'Refresh Player List', desc = 'Refresh online players and permission states.', action = function() TriggerServerEvent('traffic_control:requestPlayerList') end }
        for _, p in ipairs(players) do
            rows[#rows + 1] = {
                type = 'submenu',
                left = ('[%s] %s'):format(p.id, p.name),
                right = p.isAdmin and 'ADMIN' or (p.hasAccess and 'USER' or 'NONE'),
                target = ('player:%s'):format(p.id),
                desc = p.identifier or 'unknown'
            }
        end
    elseif path:sub(1, 7) == 'player:' then
        local targetId = tonumber(path:sub(8))
        local target = nil
        for _, p in ipairs(players) do
            if p.id == targetId then target = p break end
        end
        if target then
            rows = {
                { type = 'label', left = target.name, right = target.identifier or 'unknown', desc = 'Persistent identifier for this player.' },
                { type = 'action', left = 'Grant Operator Access', desc = 'Grant menu and local traffic control access.', action = function() TriggerServerEvent('traffic_control:grantByPlayerId', target.id, false) end },
                { type = 'action', left = 'Revoke Operator Access', desc = 'Remove operator access.', action = function() TriggerServerEvent('traffic_control:revokeByPlayerId', target.id, false) end },
                { type = 'action', left = 'Grant Admin Access', desc = 'Grant full traffic control admin access.', action = function() TriggerServerEvent('traffic_control:grantByPlayerId', target.id, true) end },
                { type = 'action', left = 'Revoke Admin Access', desc = 'Remove traffic control admin access.', action = function() TriggerServerEvent('traffic_control:revokeByPlayerId', target.id, true) end },
            }
        else
            rows = {{ type = 'label', left = 'Player not found', right = '', desc = 'This player is no longer online.' }}
        end
    end

    return rows
end

local function adjustSlider(row, delta)
    if row.key == 'localRadiusDraft' then
        localRadiusDraft = clamp(round2(localRadiusDraft + delta), Config.LocalZoneMinRadius, Config.LocalZoneMaxRadius)
        return
    end
    if row.key == 'sceneModeDraft' then
        local keys = sceneModeKeys()
        local currentIndex = 1
        for i, key in ipairs(keys) do if key == sceneModeDraft then currentIndex = i break end end
        currentIndex = currentIndex + delta
        if currentIndex < 1 then currentIndex = #keys end
        if currentIndex > #keys then currentIndex = 1 end
        sceneModeDraft = keys[currentIndex]
        return
    end
    if not customDraft then customDraft = deepCopy(currentGlobalSettings()) end
    customDraft[row.key] = clamp(round2((customDraft[row.key] or 1.0) + delta), Config.SliderMin, Config.SliderMax)
end

local function activateRow(row)
    if row.type == 'action' and row.action then row.action()
    elseif row.type == 'submenu' then pushMenu(row.target) end
end

local function drawMenu()
    local rows = menuRows()
    local path = getMenuPath()
    local idx = getSelection(path)
    if idx > #rows then idx = #rows end
    if idx < 1 then idx = 1 end
    setSelection(path, idx)
    local selectedRow = rows[idx] or {}

    local x = 0.018
    local y = 0.062
    local w = 0.315
    local topBlueH = 0.070
    local headerH = 0.032
    local rowH = 0.036
    local footerH = 0.090

    drawMenuRect(x, y, w, topBlueH, 61, 111, 181, 235)
    drawMenuRect(x, y, w, 0.010, 103, 152, 227, 255)
    drawTextRaw(x + 0.010, y + 0.012, 0.48, Config.MenuTitle:upper(), 0, 255, 255, 255, 255, 1)

    local headerY = y + topBlueH
    drawMenuRect(x, headerY, w, headerH, 0, 0, 0, 235)
    drawTextRaw(x + 0.010, headerY + 0.006, 0.34, 'INTERACTION MENU', 0, 255, 255, 255, 255, 1)
    drawTextRaw(x + w - 0.060, headerY + 0.006, 0.34, string.format('%d / %d', idx, math.max(#rows, 1)), 0, 255, 255, 255, 255, 2, x + w - 0.010)

    for i, row in ipairs(rows) do
        local ry = headerY + headerH + ((i - 1) * rowH)
        local selected = (i == idx)
        drawMenuRect(x, ry, w, rowH, 0, 0, 0, selected and 210 or 150)
        if selected then
            drawMenuRect(x, ry, w, rowH, 255, 255, 255, 235)
            drawTextRaw(x + 0.010, ry + 0.007, 0.33, row.left or '', 0, 15, 15, 15, 255, 1)
        else
            drawTextRaw(x + 0.010, ry + 0.007, 0.33, row.left or '', 0, 255, 255, 255, 255, 1)
        end

        local right = row.right or ''
        local rightColor = selected and 15 or 255

        if row.type == 'slider' then
            local value = row.key == 'localRadiusDraft' and localRadiusDraft or ((customDraft and customDraft[row.key]) or row.value or 0.0)
            right = string.format('%.2f', value)
            local barX = x + w - 0.126
            local barY = ry + 0.022
            drawSliderBar(barX, barY, 0.078, 0.006, value)
            drawTextRaw(barX - 0.014, ry + 0.004, 0.26, '<', 0, rightColor, rightColor, rightColor, 255, 1)
            drawTextRaw(barX + 0.081, ry + 0.004, 0.26, '>', 0, rightColor, rightColor, rightColor, 255, 1)
            drawTextRaw(x + w - 0.010, ry + 0.007, 0.30, right, 0, rightColor, rightColor, rightColor, 255, 2, x + w - 0.010)
        elseif row.type == 'cycle' then
            drawTextRaw(x + w - 0.010, ry + 0.007, 0.30, right, 0, rightColor, rightColor, rightColor, 255, 2, x + w - 0.010)
            drawTextRaw(x + w - 0.110, ry + 0.004, 0.26, '<', 0, rightColor, rightColor, rightColor, 255, 1)
            drawTextRaw(x + w - 0.020, ry + 0.004, 0.26, '>', 0, rightColor, rightColor, rightColor, 255, 1)
        else
            drawTextRaw(x + w - 0.010, ry + 0.007, 0.30, right, 0, rightColor, rightColor, rightColor, 255, 2, x + w - 0.010)
        end
    end

    local footerY = headerY + headerH + (#rows * rowH)
    drawMenuRect(x, footerY, w, 0.028, 0, 0, 0, 220)
    drawTextRaw(x + (w / 2.0) - 0.006, footerY + 0.001, 0.31, '↕', 0, 255, 255, 255, 255, 1)
    drawMenuRect(x, footerY + 0.028, w, footerH, 0, 0, 0, 180)
    drawTextRaw(x + 0.010, footerY + 0.040, 0.28, selectedRow.desc or 'Select an option.', 0, 255, 255, 255, 255, 1, x + w - 0.010)
end

RegisterNetEvent('traffic_control:notify', function(msg)
    notify(msg)
end)

RegisterNetEvent('traffic_control:setState', function(payload)
    local oldScenes = previousSceneMap
    previousSceneMap = {}

    local oldProps = previousPropMap
    previousPropMap = {}

    state.mode = payload.mode or Config.DefaultMode
    state.custom = payload.custom
    state.scenes = payload.scenes or {}
    state.actorName = payload.actorName or 'system'
    state.props = payload.props or {}

    for _, scene in ipairs(state.scenes) do
        previousSceneMap[scene.id] = scene
        oldScenes[scene.id] = nil
    end

    for _, removedScene in pairs(oldScenes) do
        restoreSceneRoads(removedScene)
    end

    for _, prop in ipairs(state.props) do
        previousPropMap[prop.id] = prop
        oldProps[prop.id] = nil
    end

    for _, removedProp in pairs(oldProps) do
        cleanupRemovedProp(removedProp)
    end
end)

RegisterNetEvent('traffic_control:updatePlayerList', function(payload)
    players = payload or {}
end)

RegisterNetEvent('traffic_control:setPermissions', function(payload)
    permissions = payload or permissions
end)

RegisterNetEvent('traffic_control:openMenu', function()
    if permissions.menu or permissions.hasAccess then openMenu() end
end)

RegisterCommand('+trafficmenu', function()
    if previewProp then return end
    if permissions.menu or permissions.hasAccess then
        if menuOpen then closeMenu() else openMenu() end
    else
        notify('You do not have traffic control access.')
    end
end, false)

RegisterCommand('-trafficmenu', function() end, false)
RegisterKeyMapping('+trafficmenu', 'Traffic Control Menu', 'keyboard', Config.MenuKey)

CreateThread(function()
    TriggerServerEvent('traffic_control:requestState')

    while true do
        Wait(0)
        applyGlobalTraffic()

        for _, scene in ipairs(state.scenes) do
            suppressScene(scene)
        end

        if previewProp then
            disablePlacementBlockingControls()

            updatePreview()
            drawTextRaw(0.40, 0.88, 0.30, 'Preview Placement', 0, 255, 255, 255, 255, 1)
            drawTextRaw(0.40, 0.91, 0.25, '[/]: Rotate  PageUp/PageDown: Distance  Enter/A: Place  Backspace/B: Cancel', 0, 255, 255, 255, 255, 1)

            if IsControlJustPressed(0, 39) then
                previewHeading = previewHeading - Config.PropRotateStep
            elseif IsControlJustPressed(0, 40) then
                previewHeading = previewHeading + Config.PropRotateStep
            elseif IsControlJustPressed(0, 10) then
                previewDistance = clamp(previewDistance + Config.PropMoveStep, 1.0, 10.0)
            elseif IsControlJustPressed(0, 11) then
                previewDistance = clamp(previewDistance - Config.PropMoveStep, 1.0, 10.0)
            elseif IsDisabledControlJustPressed(0, 189) then
                previewHeading = previewHeading - Config.PropRotateStep
            elseif IsDisabledControlJustPressed(0, 190) then
                previewHeading = previewHeading + Config.PropRotateStep
            elseif IsDisabledControlJustPressed(0, 188) then
                previewDistance = clamp(previewDistance + Config.PropMoveStep, 1.0, 10.0)
            elseif IsDisabledControlJustPressed(0, 187) then
                previewDistance = clamp(previewDistance - Config.PropMoveStep, 1.0, 10.0)
            elseif IsControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 201) then
                confirmPreview()
            elseif IsControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 202) then
                stopPreview()
                openMenu()
            end
        elseif menuOpen then
            drawMenu()
            disableMenuGameplayControls()

            local rows = menuRows()
            local path = getMenuPath()
            local idx = getSelection(path)

            if IsDisabledControlJustPressed(0, 172) or IsDisabledControlJustPressed(0, 188) then
                idx = idx - 1
                if idx < 1 then idx = #rows end
                setSelection(path, idx)
            elseif IsDisabledControlJustPressed(0, 173) or IsDisabledControlJustPressed(0, 187) then
                idx = idx + 1
                if idx > #rows then idx = 1 end
                setSelection(path, idx)
            elseif IsDisabledControlJustPressed(0, 174) or IsDisabledControlJustPressed(0, 189) then
                local row = rows[idx]
                if row and (row.type == 'slider' or row.type == 'cycle') then
                    local delta = row.key == 'localRadiusDraft' and -Config.LocalZoneStep or (row.type == 'cycle' and -1 or -Config.SliderStep)
                    adjustSlider(row, delta)
                end
            elseif IsDisabledControlJustPressed(0, 175) or IsDisabledControlJustPressed(0, 190) then
                local row = rows[idx]
                if row and (row.type == 'slider' or row.type == 'cycle') then
                    local delta = row.key == 'localRadiusDraft' and Config.LocalZoneStep or (row.type == 'cycle' and 1 or Config.SliderStep)
                    adjustSlider(row, delta)
                end
            elseif IsDisabledControlJustPressed(0, 176) or IsDisabledControlJustPressed(0, 201) then
                local row = rows[idx]
                if row then activateRow(row) end
            elseif IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 202) then
                popMenu()
            end
        end
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    stopPreview()
    for _, scene in ipairs(state.scenes) do
        restoreSceneRoads(scene)
    end
end)