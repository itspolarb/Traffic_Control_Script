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
local previewProps = {}
local previewPropModels = {}
local previewModelHash = nil
local previewLayoutPieces = nil
local previewAnchor = nil
local previewCategory = nil
local previewIndex = nil
local previewDistance = Config.PropPlaceDistance
local previewHeading = 0.0
local propPlacementTypeDraft = 'single'
local propRowCountDraft = Config.PropRowDefaultCount
local propRowSpacingDraft = Config.PropRowDefaultSpacing
local propRowDirectionDraft = 'forward'
local propRowAngleDraft = Config.PropRowDefaultAngle
local propAnchorModeDraft = 'center'
local propHeadingOffsetDraft = 0.0
local propPatternAnchorModeDraft = 'centered'
local buildPlacementPoints

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


local function modelTuningFor(model)
    if not model then return {} end
    local hash = type(model) == 'number' and model or joaat(model)
    return (Config.PropModelTuning and (Config.PropModelTuning[hash] or Config.PropModelTuning[model])) or {}
end

local function presetGroupNames()
    local groups = {}
    for _, preset in ipairs(Config.PropPresets or {}) do
        local group = preset.group or 'Other'
        if not groups[group] then
            groups[group] = true
        end
    end

    local list = {}
    for group in pairs(groups) do
        list[#list + 1] = group
    end
    table.sort(list)
    return list
end

local function presetsByGroup(groupName)
    local list = {}
    for _, preset in ipairs(Config.PropPresets or {}) do
        local group = preset.group or 'Other'
        if group == groupName then
            list[#list + 1] = preset
        end
    end
    return list
end

local function stopPreview()
    for i = #previewProps, 1, -1 do
        local ent = previewProps[i]
        if ent and DoesEntityExist(ent) then
            DeleteEntity(ent)
        end
    end

    previewProps = {}
    previewPropModels = {}
    previewModelHash = nil
    previewLayoutPieces = nil
    previewAnchor = nil
    previewCategory = nil
    previewIndex = nil
    previewDistance = Config.PropPlaceDistance
    previewHeading = 0.0
end


local function forceCloseTrafficUI()
    stopPreview()
    menuOpen = false
    menuStack = { 'main' }
end

local function isPlayerUnavailable()
    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then return true end
    if IsEntityDead(ped) or IsPedFatallyInjured(ped) then return true end
    return false
end

local function previewDesiredCount()
    if propPlacementTypeDraft == 'row' then
        return math.max(1, propRowCountDraft or 1)
    end
    return 1
end

local function ensurePreviewProps(model)
    local desiredCount = previewDesiredCount()
    local needsRebuild = previewModelHash ~= model or #previewProps ~= desiredCount

    if not needsRebuild then
        return true
    end

    for i = #previewProps, 1, -1 do
        local ent = previewProps[i]
        if ent and DoesEntityExist(ent) then
            DeleteEntity(ent)
        end
    end
    previewProps = {}
    previewPropModels = {}
    previewModelHash = model

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    for i = 1, desiredCount do
        local ent = CreateObjectNoOffset(model, coords.x, coords.y, coords.z, false, false, false)
        if ent == 0 then
            notify('Failed to create preview prop.')
            stopPreview()
            return false
        end
        SetEntityCollision(ent, false, false)
        SetEntityAlpha(ent, 180, false)
        PlaceObjectOnGroundProperly(ent)
        FreezeEntityPosition(ent, true)
        previewProps[#previewProps + 1] = ent
        previewPropModels[#previewPropModels + 1] = model
    end

    return true
end

local function startPreview(category, index, anchorMode)
    if isPlayerUnavailable() then return end
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

    if not ensurePreviewProps(model) then
        return
    end

    previewCategory = category
    previewIndex = index
    previewHeading = GetEntityHeading(ped)
    previewDistance = Config.PropPlaceDistance
    propPatternAnchorModeDraft = anchorMode or 'centered'
end



local function ensureLayoutPreviewProps(pieces)
    for i = #previewProps, 1, -1 do
        local ent = previewProps[i]
        if ent and DoesEntityExist(ent) then
            DeleteEntity(ent)
        end
    end

    previewProps = {}
    previewPropModels = {}
    previewModelHash = nil

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    for i, piece in ipairs(pieces or {}) do
        local model = joaat(piece.model)
        RequestModel(model)
        local timeout = GetGameTimer() + 5000

        while not HasModelLoaded(model) and GetGameTimer() < timeout do
            Wait(0)
        end

        if not HasModelLoaded(model) then
            notify(('Failed to load layout model: %s'):format(piece.model or 'unknown'))
            stopPreview()
            return false
        end

        local ent = CreateObjectNoOffset(model, coords.x, coords.y, coords.z, false, false, false)
        if ent == 0 then
            notify('Failed to create preview prop.')
            stopPreview()
            return false
        end

        SetEntityCollision(ent, false, false)
        SetEntityAlpha(ent, 180, false)
        PlaceObjectOnGroundProperly(ent)
        FreezeEntityPosition(ent, true)

        previewProps[#previewProps + 1] = ent
        previewPropModels[#previewPropModels + 1] = piece.model
    end

    return true
end

local function startLayoutPreview(preset)
    if isPlayerUnavailable() then return end
    stopPreview()

    local layout = preset and preset.layout
    if type(layout) ~= 'table' or #layout == 0 then
        notify('Preset layout is empty.')
        return
    end

    if not ensureLayoutPreviewProps(layout) then
        return
    end

    previewLayoutPieces = deepCopy(layout)
    previewHeading = GetEntityHeading(PlayerPedId())
    previewDistance = Config.PropPlaceDistance
    previewCategory = nil
    previewIndex = nil
    propPatternAnchorModeDraft = preset.anchor or 'center'
end

local function currentRowBaseAngle()
    local baseAngle = previewHeading
    if propRowDirectionDraft == 'sideways' then
        baseAngle = baseAngle + 90.0
    end
    baseAngle = baseAngle + (propRowAngleDraft or 0.0)
    return baseAngle
end

local function updatePreview()
    if #previewProps == 0 then return end
    if isPlayerUnavailable() then
        stopPreview()
        return
    end

    local def = nil
    if not previewLayoutPieces then
        if not previewCategory or not previewIndex then return end
        def = propDefinition(previewCategory, previewIndex)
        if not def then return end

        local model = joaat(def.model)
        if not ensurePreviewProps(model) then
            return
        end
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local targetX = coords.x + (forward.x * previewDistance)
    local targetY = coords.y + (forward.y * previewDistance)
    local targetZ = coords.z + Config.PreviewVerticalOffset
    local found, groundZ = GetGroundZFor_3dCoord(targetX, targetY, targetZ + 5.0, false)
    if found then targetZ = groundZ end

    previewAnchor = { x = targetX, y = targetY, z = targetZ }

    if previewLayoutPieces then
        local headingRad = math.rad(previewHeading)
        local forwardX = -math.sin(headingRad)
        local forwardY = math.cos(headingRad)
        local rightX = math.cos(headingRad)
        local rightY = math.sin(headingRad)

        for i, ent in ipairs(previewProps) do
            local piece = previewLayoutPieces[i] or {}
            local px = targetX + (forwardX * (piece.forwardOffset or 0.0)) + (rightX * (piece.lateralOffset or 0.0))
            local py = targetY + (forwardY * (piece.forwardOffset or 0.0)) + (rightY * (piece.lateralOffset or 0.0))
            local pz = targetZ

            local okGround, objGroundZ = GetGroundZFor_3dCoord(px, py, targetZ + 5.0, false)
            if okGround then
                pz = objGroundZ
            end

            local tuning = modelTuningFor(piece.model)
            local headingOffset = (piece.headingOffset or 0.0) + (tuning.headingOffset or 0.0)

            SetEntityCoordsNoOffset(ent, px, py, pz, false, false, false)
            SetEntityHeading(ent, previewHeading + headingOffset)
        end

        return
    end

    local count = previewDesiredCount()
    local spacing = propRowSpacingDraft or Config.PropRowDefaultSpacing
    local rad = math.rad(currentRowBaseAngle())
    local dirX = -math.sin(rad)
    local dirY = math.cos(rad)
    local totalWidth = (count - 1) * spacing
    local startOffset = propPatternAnchorModeDraft == 'start' and 0.0 or -(totalWidth / 2.0)

    for i, ent in ipairs(previewProps) do
        local offset = startOffset + ((i - 1) * spacing)
        local px = targetX
        local py = targetY
        local pz = targetZ

        if count > 1 then
            px = targetX + (dirX * offset)
            py = targetY + (dirY * offset)
        end

        local okGround, objGroundZ = GetGroundZFor_3dCoord(px, py, targetZ + 5.0, false)
        if okGround then
            pz = objGroundZ
        end

        local tuning = modelTuningFor(def.model)
        SetEntityCoordsNoOffset(ent, px, py, pz, false, false, false)
        SetEntityHeading(ent, currentRowBaseAngle() + (tuning.headingOffset or 0.0) + (propHeadingOffsetDraft or 0.0))
    end
end

local function confirmPreview()
    if #previewProps == 0 or not previewAnchor then return end
    if isPlayerUnavailable() then
        forceCloseTrafficUI()
        return
    end

    local coords = previewAnchor
    local placements = buildPlacementPoints()

    if previewLayoutPieces then
        TriggerServerEvent(
            'traffic_control:placeProp',
            '__layout__',
            coords.x,
            coords.y,
            coords.z,
            previewHeading,
            'layout',
            #placements,
            propRowSpacingDraft,
            propRowDirectionDraft,
            propRowAngleDraft,
            placements
        )
        stopPreview()
        return
    end

    local def = propDefinition(previewCategory, previewIndex)
    if not def then
        stopPreview()
        return
    end

    TriggerServerEvent(
        'traffic_control:placeProp',
        def.model,
        coords.x,
        coords.y,
        coords.z,
        previewHeading,
        propPlacementTypeDraft,
        propRowCountDraft,
        propRowSpacingDraft,
        propRowDirectionDraft,
        propRowAngleDraft,
        placements
    )
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

local function drawSliderBar(x, y, w, h, value, minValue, maxValue)
    minValue = minValue or Config.SliderMin
    maxValue = maxValue or Config.SliderMax
    local pct = (value - minValue) / (maxValue - minValue)
    pct = clamp(pct, 0.0, 1.0)
    drawMenuRect(x, y, w, h, 25, 25, 25, 210)
    drawMenuRect(x, y, w * pct, h, 255, 255, 255, 220)
end

local function getMenuPath() return menuStack[#menuStack] end
local function setSelection(path, idx) selection[path] = idx end
local function getSelection(path) return selection[path] or 1 end

local function openMenu()
    if isPlayerUnavailable() then return end
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

local function propPlacementTypeLabel()
    return propPlacementTypeDraft == 'row' and 'Row' or 'Single'
end

local function propRowDirectionLabel()
    return propRowDirectionDraft == 'sideways' and 'Sideways' or 'Forward'
end

local function propRowAngleLabel()
    return string.format('%d°', math.floor((propRowAngleDraft or 0.0) + 0.5))
end


local function getPropSliderBounds(key)
    if key == 'localRadiusDraft' then
        return Config.LocalZoneMinRadius, Config.LocalZoneMaxRadius
    elseif key == 'propRowCountDraft' then
        return Config.PropRowMinCount, Config.PropRowMaxCount
    elseif key == 'propRowSpacingDraft' then
        return Config.PropRowMinSpacing, Config.PropRowMaxSpacing
    elseif key == 'propRowAngleDraft' then
        return Config.PropRowMinAngle, Config.PropRowMaxAngle
    end
    return Config.SliderMin, Config.SliderMax
end

buildPlacementPoints = function(model, baseX, baseY, baseZ, heading, placementType, rowCount, rowSpacing, rowDirection, rowAngle, anchorMode, headingOffset)
    local points = {}
    for i, ent in ipairs(previewProps) do
        if ent and DoesEntityExist(ent) then
            local coords = GetEntityCoords(ent)
            points[#points + 1] = {
                model = previewPropModels[i],
                x = coords.x,
                y = coords.y,
                z = coords.z,
                heading = GetEntityHeading(ent)
            }
        end
    end
    return points
end

local function applyPropPreset(preset)
    if not preset then return end

    if type(preset.layout) == 'table' and #preset.layout > 0 then
        propPlacementTypeDraft = 'layout'
        propRowCountDraft = #preset.layout
        propAnchorModeDraft = preset.anchor or 'center'
        propHeadingOffsetDraft = 0.0
        startLayoutPreview(preset)
        closeMenu()
        return
    end

    propPlacementTypeDraft = preset.placementType or 'row'
    propRowCountDraft = preset.rowCount or preset.count or Config.PropRowDefaultCount
    propRowSpacingDraft = preset.rowSpacing or preset.spacing or Config.PropRowDefaultSpacing
    propRowDirectionDraft = preset.rowDirection or preset.direction or 'forward'
    propRowAngleDraft = preset.rowAngle or preset.angle or Config.PropRowDefaultAngle
    propAnchorModeDraft = preset.anchorMode or preset.anchor or 'center'
    propHeadingOffsetDraft = preset.headingOffset or 0.0

    local category = preset.category
    local index = preset.index

    if (not category or not index) and preset.model then
        for catName, defs in pairs(Config.Props or {}) do
            for defIndex, def in ipairs(defs) do
                if def.model == preset.model then
                    category = catName
                    index = defIndex
                    break
                end
            end
            if category and index then
                break
            end
        end
    end

    if not category or not index then
        notify('Preset model not found in Config.Props.')
        return
    end

    startPreview(category, index, propAnchorModeDraft)
    closeMenu()
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
            rows[#rows + 1] = { type = 'submenu', left = 'Preset Scenes', right = '→', target = 'props:presets', desc = 'Quick preset traffic-control layouts, including multi-prop scenes.' }
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
            { type = 'cycle', key = 'propPlacementTypeDraft', left = 'Placement Type', right = propPlacementTypeLabel(), desc = 'Choose whether to place one prop or a full row.' },
        }

        if propPlacementTypeDraft == 'row' then
            rows[#rows + 1] = { type = 'slider_int', key = 'propRowCountDraft', left = 'Row Count', value = propRowCountDraft, desc = 'How many props to place in the row.' }
            rows[#rows + 1] = { type = 'slider', key = 'propRowSpacingDraft', left = 'Row Spacing', value = propRowSpacingDraft, desc = 'Spacing between each prop in the row.' }
            rows[#rows + 1] = { type = 'cycle', key = 'propRowDirectionDraft', left = 'Row Direction', right = propRowDirectionLabel(), desc = 'Direction the row extends from the preview point.' }
            rows[#rows + 1] = { type = 'slider', key = 'propRowAngleDraft', left = 'Row Angle', value = propRowAngleDraft, desc = 'Additional angle offset for the row pattern.' }
        end

        rows[#rows + 1] = { type = 'submenu', left = 'Cones', right = '→', target = 'props:cones', desc = 'Place traffic cones.' }
        rows[#rows + 1] = { type = 'submenu', left = 'Barriers', right = '→', target = 'props:barriers', desc = 'Place barriers.' }
        rows[#rows + 1] = { type = 'submenu', left = 'Lights', right = '→', target = 'props:lights', desc = 'Place warning and work lights.' }
        rows[#rows + 1] = { type = 'action', left = 'Remove Nearest Prop', desc = 'Remove the nearest prop you own. Managers can remove any prop.', action = function() TriggerServerEvent('traffic_control:removeNearestProp') end }
        rows[#rows + 1] = { type = 'action', left = 'Clear My Props', desc = 'Remove every prop you own.', action = function() TriggerServerEvent('traffic_control:clearMyProps') end }
    elseif path == 'props:presets' then
        local groups = presetGroupNames()
        for _, groupName in ipairs(groups) do
            rows[#rows + 1] = {
                type = 'submenu',
                left = groupName,
                right = '→',
                target = ('presetgroup:%s'):format(groupName),
                desc = ('Browse %s presets.'):format(groupName)
            }
        end
    elseif path:sub(1, 12) == 'presetgroup:' then
        local groupName = path:sub(13)
        local list = presetsByGroup(groupName)
        for _, preset in ipairs(list) do
            rows[#rows + 1] = {
                type = 'action',
                left = preset.label or 'Preset',
                desc = preset.description or ('Places %s in a preset layout.'):format(preset.label or 'Preset'),
                action = function()
                    applyPropPreset(preset)
                end
            }
        end
    elseif path:sub(1, 6) == 'props:' then
        local category = path:sub(7)
        local list = (Config.Props and Config.Props[category]) or {}
        for i, def in ipairs(list) do
            rows[#rows + 1] = {
                type = 'action',
                left = ('Place %s'):format(def.label),
                desc = ('Preview and place %s.'):format(def.label),
                action = function()
                    propAnchorModeDraft = 'center'
                    propHeadingOffsetDraft = 0.0
                    startPreview(category, i, propAnchorModeDraft)
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

    if row.key == 'propRowCountDraft' then
        propRowCountDraft = math.floor(clamp(propRowCountDraft + delta, Config.PropRowMinCount, Config.PropRowMaxCount))
        return
    end

    if row.key == 'propRowSpacingDraft' then
        propRowSpacingDraft = clamp(round2(propRowSpacingDraft + delta), Config.PropRowMinSpacing, Config.PropRowMaxSpacing)
        return
    end

    if row.key == 'propRowAngleDraft' then
        propRowAngleDraft = clamp(round2(propRowAngleDraft + delta), Config.PropRowMinAngle, Config.PropRowMaxAngle)
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

    if row.key == 'propPlacementTypeDraft' then
        propPlacementTypeDraft = propPlacementTypeDraft == 'single' and 'row' or 'single'
        return
    end

    if row.key == 'propRowDirectionDraft' then
        propRowDirectionDraft = propRowDirectionDraft == 'forward' and 'sideways' or 'forward'
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

        if row.type == 'slider' or row.type == 'slider_int' then
            local value = row.value or 0.0
            if row.key == 'localRadiusDraft' then
                value = localRadiusDraft
            elseif row.key == 'propRowCountDraft' then
                value = propRowCountDraft
            elseif row.key == 'propRowSpacingDraft' then
                value = propRowSpacingDraft
            elseif row.key == 'propRowAngleDraft' then
                value = propRowAngleDraft
            else
                value = ((customDraft and customDraft[row.key]) or row.value or 0.0)
            end
            right = row.type == 'slider_int' and string.format('%d', value) or string.format('%.2f', value)
            if row.key == 'propRowAngleDraft' then
                right = string.format('%d°', math.floor(value + 0.5))
            end
            local barX = x + w - 0.126
            local barY = ry + 0.022
            local minValue, maxValue = getPropSliderBounds(row.key)
            drawSliderBar(barX, barY, 0.078, 0.006, value, minValue, maxValue)
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

AddEventHandler('baseevents:onPlayerDied', function()
    forceCloseTrafficUI()
end)

AddEventHandler('baseevents:onPlayerKilled', function()
    forceCloseTrafficUI()
end)

RegisterCommand('+trafficmenu', function()
    if isPlayerUnavailable() then return end
    if #previewProps > 0 then return end
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

        if isPlayerUnavailable() then
            if #previewProps > 0 or menuOpen then
                forceCloseTrafficUI()
            end
        else
            for _, scene in ipairs(state.scenes) do
                suppressScene(scene)
            end

            if #previewProps > 0 then
            disablePlacementBlockingControls()

            updatePreview()
            drawTextRaw(0.40, 0.86, 0.30, 'Preview Placement', 0, 255, 255, 255, 255, 1)
            local previewMode = propPlacementTypeLabel()
            local previewInfo
            if previewLayoutPieces then
                previewInfo = ('Mode: Layout | Pieces: %d | Rotate whole scene with [/]'):format(#previewProps)
            else
                previewInfo = ('Mode: %s | Count: %d | Spacing: %.2f | Direction: %s | Angle: %d°'):format(previewMode, propRowCountDraft, propRowSpacingDraft, propRowDirectionLabel(), math.floor(propRowAngleDraft + 0.5))
            end
            drawTextRaw(0.40, 0.89, 0.24, previewInfo, 0, 255, 255, 255, 255, 1)
            drawTextRaw(0.40, 0.92, 0.25, '[/]: Rotate  PageUp/PageDown: Distance  Enter/A: Place  Backspace/B: Cancel', 0, 255, 255, 255, 255, 1)

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
                if row and (row.type == 'slider' or row.type == 'slider_int' or row.type == 'cycle') then
                    local delta
                    if row.key == 'localRadiusDraft' then
                        delta = -Config.LocalZoneStep
                    elseif row.key == 'propRowCountDraft' then
                        delta = -1
                    elseif row.type == 'cycle' then
                        delta = -1
                    elseif row.key == 'propRowSpacingDraft' then
                        delta = -Config.PropRowSpacingStep
                    elseif row.key == 'propRowAngleDraft' then
                        delta = -Config.PropRowAngleStep
                    else
                        delta = -Config.SliderStep
                    end
                    adjustSlider(row, delta)
                end
            elseif IsDisabledControlJustPressed(0, 175) or IsDisabledControlJustPressed(0, 190) then
                local row = rows[idx]
                if row and (row.type == 'slider' or row.type == 'slider_int' or row.type == 'cycle') then
                    local delta
                    if row.key == 'localRadiusDraft' then
                        delta = Config.LocalZoneStep
                    elseif row.key == 'propRowCountDraft' then
                        delta = 1
                    elseif row.type == 'cycle' then
                        delta = 1
                    elseif row.key == 'propRowSpacingDraft' then
                        delta = Config.PropRowSpacingStep
                    elseif row.key == 'propRowAngleDraft' then
                        delta = Config.PropRowAngleStep
                    else
                        delta = Config.SliderStep
                    end
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
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    stopPreview()
    for _, scene in ipairs(state.scenes) do
        restoreSceneRoads(scene)
    end
end)