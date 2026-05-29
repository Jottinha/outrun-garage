local customsVehicle = nil
local customsModel = nil

local perfMods = {
    {id = 'engine',       label = 'Motor',       modType = 11},
    {id = 'brakes',       label = 'Freios',      modType = 12},
    {id = 'transmission', label = 'Transmissão', modType = 13},
    {id = 'suspension',   label = 'Suspensão',   modType = 15},
    {id = 'armor',        label = 'Blindagem',   modType = 16},
}

local modLabels = {
    [-1] = 'Stock',
    [0]  = 'Nível 1',
    [1]  = 'Nível 2',
    [2]  = 'Nível 3',
    [3]  = 'Nível 4',
}

-- Normaliza um valor para 0-100% contra um máximo de referência
local function pct(value, max)
    if not max or max <= 0 then return 0 end
    local p = (value / max) * 100.0
    if p < 0 then p = 0 elseif p > 100 then p = 100 end
    return math.floor(p + 0.5)
end

-- Lê as natives de performance do veículo e devolve as 4 stats em porcentagem
function GetVehicleStats(vehicle)
    local ref = Config.PerfStats

    -- Top speed real medido por modelo (Config.TopSpeeds). Fallback para a
    -- estimativa do jogo se o modelo não estiver na tabela.
    local speedKmh = (customsModel and Config.TopSpeeds[customsModel])
        or (GetVehicleEstimatedMaxSpeed(vehicle) * 3.6)

    return {
        speed    = pct(speedKmh,                        ref.maxSpeed),
        speedKmh = math.floor(speedKmh + 0.5),
        accel    = pct(GetVehicleAcceleration(vehicle), ref.maxAccel),
        braking  = pct(GetVehicleMaxBraking(vehicle),   ref.maxBraking),
        traction = pct(GetVehicleMaxTraction(vehicle),  ref.maxTraction),
    }
end

-- Reenvia as stats atualizadas para o NUI (chamado após cada modificação)
local function SendStats()
    if customsVehicle and DoesEntityExist(customsVehicle) then
        SendNUIMessage({action = 'updateStats', stats = GetVehicleStats(customsVehicle)})
    end
end

function OpenCustomsMenu(vehicle, model)
    customsVehicle = vehicle
    customsModel = model
    SetVehicleModKit(vehicle, 0)

    local categories = {}

    -- Mods de performance
    for _, cat in ipairs(perfMods) do
        local num = GetNumVehicleMods(vehicle, cat.modType)
        if num > 0 then
            local cur = GetVehicleMod(vehicle, cat.modType)
            local opts = {{index = -1, label = 'Stock', selected = (cur == -1)}}
            for i = 0, num - 1 do
                opts[#opts+1] = {index = i, label = modLabels[i] or ('Nível ' .. (i + 1)), selected = (cur == i)}
            end
            categories[#categories+1] = {id = cat.id, label = cat.label, type = 'mod', modType = cat.modType, options = opts}
        end
    end

    -- Turbo
    categories[#categories+1] = {
        id = 'turbo', label = 'Turbo', type = 'toggle',
        modType = 18, enabled = IsToggleModOn(vehicle, 18),
    }

    -- Xenon
    categories[#categories+1] = {
        id = 'xenon', label = 'Faróis Xenon', type = 'toggle',
        modType = 22, enabled = IsToggleModOn(vehicle, 22),
    }

    -- Cores
    local primary, secondary = GetVehicleColours(vehicle)

    categories[#categories+1] = {
        id = 'primaryColor', label = 'Cor Primária', type = 'color',
        target = 'primary', currentColor = primary, options = Config.Colors,
    }
    categories[#categories+1] = {
        id = 'secondaryColor', label = 'Cor Secundária', type = 'color',
        target = 'secondary', currentColor = secondary, options = Config.Colors,
    }

    -- Tipo de roda
    categories[#categories+1] = {
        id = 'wheelType', label = 'Tipo de Roda', type = 'wheelType',
        currentType = GetVehicleWheelType(vehicle), options = Config.WheelTypes,
    }

    -- Modelo de roda
    local numWheels = GetNumVehicleMods(vehicle, 23)
    local curWheel = GetVehicleMod(vehicle, 23)
    local wOpts = {{index = -1, label = 'Stock', selected = (curWheel == -1)}}
    for i = 0, numWheels - 1 do
        wOpts[#wOpts+1] = {index = i, label = 'Roda ' .. (i + 1), selected = (curWheel == i)}
    end
    categories[#categories+1] = {
        id = 'wheelIndex', label = 'Modelo de Roda', type = 'mod',
        modType = 23, options = wOpts,
    }

    -- Película
    categories[#categories+1] = {
        id = 'windowTint', label = 'Película', type = 'tint',
        currentTint = GetVehicleWindowTint(vehicle), options = Config.WindowTints,
    }

    SetNuiFocus(true, true)
    SendNUIMessage({action = 'openCustomize', categories = categories, stats = GetVehicleStats(vehicle)})
end

-- Aplicar mod de performance / rodas
RegisterNUICallback('applyMod', function(data, cb)
    cb('ok')
    if customsVehicle and DoesEntityExist(customsVehicle) then
        SetVehicleMod(customsVehicle, data.modType, data.index, false)
        SendStats()
    end
end)

-- Toggle (turbo, xenon)
RegisterNUICallback('applyToggle', function(data, cb)
    cb('ok')
    if customsVehicle and DoesEntityExist(customsVehicle) then
        ToggleVehicleMod(customsVehicle, data.modType, data.enabled)
        SendStats()
    end
end)

-- Aplicar cor
RegisterNUICallback('applyColor', function(data, cb)
    cb('ok')
    if not customsVehicle or not DoesEntityExist(customsVehicle) then return end
    local p, s = GetVehicleColours(customsVehicle)
    if data.target == 'primary' then
        SetVehicleColours(customsVehicle, data.colorId, s)
    else
        SetVehicleColours(customsVehicle, p, data.colorId)
    end
end)

-- Mudar tipo de roda e atualizar opções disponíveis
RegisterNUICallback('applyWheelType', function(data, cb)
    cb('ok')
    if not customsVehicle or not DoesEntityExist(customsVehicle) then return end

    SetVehicleWheelType(customsVehicle, data.wheelType)

    local num = GetNumVehicleMods(customsVehicle, 23)
    local cur = GetVehicleMod(customsVehicle, 23)
    local opts = {{index = -1, label = 'Stock', selected = (cur == -1)}}
    for i = 0, num - 1 do
        opts[#opts+1] = {index = i, label = 'Roda ' .. (i + 1), selected = (cur == i)}
    end
    SendNUIMessage({action = 'updateWheelOptions', options = opts})
    SendStats()
end)

-- Película
RegisterNUICallback('applyTint', function(data, cb)
    cb('ok')
    if customsVehicle and DoesEntityExist(customsVehicle) then
        SetVehicleWindowTint(customsVehicle, data.tintId)
    end
end)
