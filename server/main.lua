local QBCore = exports['qb-core']:GetCoreObject()

local rateLimits = {}

local function CheckRateLimit(src, action, cooldown)
    local key = src .. ':' .. action
    local now = os.time()
    if rateLimits[key] and (now - rateLimits[key]) < cooldown then
        return false
    end
    rateLimits[key] = now
    return true
end

local function IsModelAllowed(model)
    for _, v in ipairs(Config.AllowedVehicles) do
        if v.model == model then return true end
    end
    return false
end

local function GetVehicleLabel(model)
    for _, v in ipairs(Config.AllowedVehicles) do
        if v.model == model then return v.label end
    end
    return model
end

local function GeneratePlate(cb)
    local prefix = Config.PlatePrefix
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local remaining = 8 - #prefix

    local function attempt()
        local plate = prefix
        for _ = 1, remaining do
            local i = math.random(1, #chars)
            plate = plate .. chars:sub(i, i)
        end
        MySQL.scalar('SELECT COUNT(*) FROM player_vehicles WHERE plate = ?', {plate}, function(count)
            if count and count > 0 then
                attempt()
            else
                cb(plate)
            end
        end)
    end

    attempt()
end

-- Obter veículos do jogador
QBCore.Functions.CreateCallback('outrun-garage:server:getVehicles', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end

    local cid = Player.PlayerData.citizenid
    MySQL.query('SELECT vehicle, plate, mods, state FROM player_vehicles WHERE citizenid = ? AND garage = ?',
        {cid, Config.DefaultGarage}, function(result)
        local vehicles = {}
        if result then
            for _, row in ipairs(result) do
                vehicles[#vehicles+1] = {
                    model = row.vehicle,
                    label = GetVehicleLabel(row.vehicle),
                    plate = row.plate,
                    state = row.state,
                    mods = row.mods and json.decode(row.mods) or nil,
                }
            end
        end
        cb(vehicles)
    end)
end)

-- Adquirir veículo gratuito
QBCore.Functions.CreateCallback('outrun-garage:server:acquireVehicle', function(source, cb, model)
    if not CheckRateLimit(source, 'acquire', 5) then
        return cb(false, 'Aguarde antes de pegar outro veículo.')
    end

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false, 'Jogador não encontrado.') end
    if not IsModelAllowed(model) then return cb(false, 'Modelo não permitido.') end

    local cid = Player.PlayerData.citizenid

    MySQL.scalar('SELECT COUNT(*) FROM player_vehicles WHERE citizenid = ? AND garage = ?',
        {cid, Config.DefaultGarage}, function(count)
        if count and count >= Config.MaxVehiclesPerPlayer then
            return cb(false, 'Limite de veículos atingido (' .. Config.MaxVehiclesPerPlayer .. ').')
        end

        GeneratePlate(function(plate)
            local hash = tostring(GetHashKey(model))
            local license = Player.PlayerData.license or ''

            MySQL.insert(
                'INSERT INTO player_vehicles (citizenid, license, vehicle, hash, plate, mods, garage, fuel, engine, body, state) VALUES (?, ?, ?, ?, ?, ?, ?, 100, 1000.0, 1000.0, 1)',
                {cid, license, model, hash, plate, '{}', Config.DefaultGarage},
                function(id)
                    if id then
                        cb(true, nil, {model = model, label = GetVehicleLabel(model), plate = plate})
                    else
                        cb(false, 'Erro ao salvar veículo.')
                    end
                end
            )
        end)
    end)
end)

-- Salvar mods (valida ownership)
QBCore.Functions.CreateCallback('outrun-garage:server:saveMods', function(source, cb, plate, props)
    if not CheckRateLimit(source, 'save', 2) then return cb(false) end

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end

    local cid = Player.PlayerData.citizenid

    MySQL.scalar('SELECT COUNT(*) FROM player_vehicles WHERE citizenid = ? AND plate = ?',
        {cid, plate}, function(count)
        if not count or count == 0 then return cb(false) end

        MySQL.update('UPDATE player_vehicles SET mods = ? WHERE citizenid = ? AND plate = ?',
            {json.encode(props), cid, plate}, function(rows)
            cb(rows and rows > 0)
        end)
    end)
end)

-- Apagar veículo (valida ownership + garagem)
QBCore.Functions.CreateCallback('outrun-garage:server:deleteVehicle', function(source, cb, plate)
    if not CheckRateLimit(source, 'delete', 5) then return cb(false) end

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end

    local cid = Player.PlayerData.citizenid

    MySQL.update('DELETE FROM player_vehicles WHERE citizenid = ? AND plate = ? AND garage = ?',
        {cid, plate, Config.DefaultGarage}, function(rows)
        cb(rows and rows > 0)
    end)
end)

-- Routing bucket: entrar no preview isolado
RegisterNetEvent('outrun-garage:server:enterPreview', function()
    local src = source
    if Config.UseRoutingBucket then
        SetPlayerRoutingBucket(src, src + 1000)
    end
end)

-- Routing bucket: sair do preview
RegisterNetEvent('outrun-garage:server:exitPreview', function()
    local src = source
    if Config.UseRoutingBucket then
        SetPlayerRoutingBucket(src, 0)
    end
end)

-- Limpar rate limits ao desconectar
AddEventHandler('playerDropped', function()
    local src = source
    rateLimits[src .. ':acquire'] = nil
    rateLimits[src .. ':save'] = nil
    rateLimits[src .. ':delete'] = nil
end)

-- ==================== EXPORTS ====================

-- Retorna todos os veículos do jogador na garagem outrun
exports('GetPlayerVehicles', function(citizenid)
    local result = MySQL.query.await(
        'SELECT vehicle, plate, mods FROM player_vehicles WHERE citizenid = ? AND garage = ?',
        {citizenid, Config.DefaultGarage}
    )
    local vehicles = {}
    if result then
        for _, row in ipairs(result) do
            vehicles[#vehicles+1] = {
                model = row.vehicle,
                label = GetVehicleLabel(row.vehicle),
                plate = row.plate,
                mods = row.mods and json.decode(row.mods) or {},
            }
        end
    end
    return vehicles
end)

-- Retorna props (mods) de um veículo específico — compatível com SetVehicleProperties
exports('GetVehicleMods', function(citizenid, plate)
    local result = MySQL.single.await(
        'SELECT mods FROM player_vehicles WHERE citizenid = ? AND plate = ? AND garage = ?',
        {citizenid, plate, Config.DefaultGarage}
    )
    if result and result.mods then
        return json.decode(result.mods)
    end
    return nil
end)
