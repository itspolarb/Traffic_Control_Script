local state = {
    mode = Config.DefaultMode,
    custom = nil,
    actorName = 'system'
}

local permissions = {
    hasAccess = false,
    isAdmin = false,
    menu = false,
    global = false,
    admin = false
}

local players = {}
local menuOpen = false
local menuStack = { 'main' }
local selection = {}
local customDraft = nil

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

local function drawMenuRect(x, y, w, h, r, g, b, a)
    DrawRect(x + (w / 2.0), y + (h / 2.0), w, h, r, g, b, a)
end

local function drawTextRaw(x, y, scale, text, font, r, g, b, a, justify, wrapX)
    SetTextFont(font or 0)
    SetTextScale(scale, scale)
    SetTextColour(r or 255, g or 255, b or 255, a or 255)
    SetTextOutline()
    SetTextDropshadow(0, 0, 0, 0, 255)

    SetTextCentre(false)
    SetTextRightJustify(false)

    if justify == 0 then
        SetTextCentre(true)
    elseif justify == 2 then
        SetTextRightJustify(true)
    end

    if wrapX then
        SetTextWrap(0.0, wrapX)
    end

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
    if #menuStack > 1 then
        table.remove(menuStack, #menuStack)
    else
        closeMenu()
    end
end

local function menuRows()
    local path = getMenuPath()
    local rows = {}

    if path == 'main' then
        if permissions.global then
            rows[#rows + 1] = { type = 'submenu', left = 'Global Traffic', right = '→', target = 'global', desc = 'Manage server-wide traffic presets and custom sliders.' }
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
            if p.id == targetId then
                target = p
                break
            end
        end
        if target then
            rows = {
                { type = 'label', left = target.name, right = target.identifier or 'unknown', desc = 'Persistent identifier for this player.' },
                { type = 'action', left = 'Grant Operator Access', desc = 'Grant menu access.', action = function() TriggerServerEvent('traffic_control:grantByPlayerId', target.id, false) end },
                { type = 'action', left = 'Revoke Operator Access', desc = 'Remove operator access.', action = function() TriggerServerEvent('traffic_control:revokeByPlayerId', target.id, false) end },
                { type = 'action', left = 'Grant Admin Access', desc = 'Grant full traffic control admin access.', action = function() TriggerServerEvent('traffic_control:grantByPlayerId', target.id, true) end },
                { type = 'action', left = 'Revoke Admin Access', desc = 'Remove traffic control admin access.', action = function() TriggerServerEvent('traffic_control:revokeByPlayerId', target.id, true) end },
            }
        else
            rows = {
                { type = 'label', left = 'Player not found', right = '', desc = 'This player is no longer online.' }
            }
        end
    end

    return rows
end

local function adjustSlider(row, delta)
    if not customDraft then
        customDraft = deepCopy(currentGlobalSettings())
    end
    customDraft[row.key] = clamp(round2((customDraft[row.key] or 1.0) + delta), Config.SliderMin, Config.SliderMax)
end

local function activateRow(row)
    if row.type == 'action' and row.action then
        row.action()
    elseif row.type == 'submenu' then
        pushMenu(row.target)
    end
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
            local value = ((customDraft and customDraft[row.key]) or row.value or 0.0)
            right = string.format('%.2f', value)
            local barX = x + w - 0.126
            local barY = ry + 0.022
            drawSliderBar(barX, barY, 0.078, 0.006, value)
            drawTextRaw(barX - 0.014, ry + 0.004, 0.26, '<', 0, rightColor, rightColor, rightColor, 255, 1)
            drawTextRaw(barX + 0.081, ry + 0.004, 0.26, '>', 0, rightColor, rightColor, rightColor, 255, 1)
            drawTextRaw(x + w - 0.010, ry + 0.007, 0.30, right, 0, rightColor, rightColor, rightColor, 255, 2, x + w - 0.010)
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
    state.mode = payload.mode or Config.DefaultMode
    state.custom = payload.custom
    state.actorName = payload.actorName or 'system'
end)

RegisterNetEvent('traffic_control:updatePlayerList', function(payload)
    players = payload or {}
end)

RegisterNetEvent('traffic_control:setPermissions', function(payload)
    permissions = payload or permissions
end)

RegisterNetEvent('traffic_control:openMenu', function()
    if permissions.menu or permissions.hasAccess then
        openMenu()
    end
end)

RegisterCommand('+trafficmenu', function()
    if permissions.menu or permissions.hasAccess then
        if menuOpen then
            closeMenu()
        else
            openMenu()
        end
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

        if menuOpen then
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
                if row and row.type == 'slider' then
                    adjustSlider(row, -Config.SliderStep)
                end
            elseif IsDisabledControlJustPressed(0, 175) or IsDisabledControlJustPressed(0, 190) then
                local row = rows[idx]
                if row and row.type == 'slider' then
                    adjustSlider(row, Config.SliderStep)
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
