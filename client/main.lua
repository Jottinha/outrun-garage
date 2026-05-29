local QBCore = exports['qb-core']:GetCoreObject()

local currentState = 'idle' -- 'idle' | 'menu' | 'customizing'
local previewVehicle = nil
local savedCoords = nil
local currentPlate = nil
local previewCam = nil
local camAngle = 0.0

-- Posiciona a câmera orbital usando os parâmetros do Config (raio/altura/mira)
local function PositionPreviewCam()
    if not previewCam or not previewVehicle or not DoesEntityExist(previewVehicle) then return end
    local cam = Config.PreviewCam
    local v = GetEntityCoords(previewVehicle)
    local rad = math.rad(camAngle)
    SetCamCoord(previewCam,
        v.x - cam.distance * math.sin(rad),
        v.y + cam.distance * math.cos(rad),
        v.z + cam.height)
    PointCamAtCoord(previewCam, v.x, v.y, v.z + cam.lookZ)
end

-- Carrega o interior do Auto Shop (IPL + entity sets) via bob74_ipl
local function LoadAutoShop()
    if not Config.UseAutoShop then return end
    local ok, obj = pcall(function() return exports['bob74_ipl']:GetTunerGarageObject() end)
    if ok and obj and obj.LoadDefault then obj.LoadDefault() end
end

local function UnloadAutoShop()
    if not Config.UseAutoShop then return end
    local ok, obj = pcall(function() return exports['bob74_ipl']:GetTunerGarageObject() end)
    if ok and obj and obj.Ipl and obj.Ipl.Remove then obj.Ipl.Remove() end
end

-- Abre o menu principal
RegisterCommand(Config.Command, function()
    if currentState ~= 'idle' then return end

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        QBCore.Functions.Notify('Saia do veículo primeiro.', 'error')
        return
    end

    OpenGarage()
end, false)

function OpenGarage()
    currentState = 'menu'

    QBCore.Functions.TriggerCallback('outrun-garage:server:getVehicles', function(vehicles)
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openMenu',
            vehicles = vehicles,
            maxVehicles = Config.MaxVehiclesPerPlayer,
            allowedVehicles = Config.AllowedVehicles,
        })
    end)
end

function RefreshMenu()
    QBCore.Functions.TriggerCallback('outrun-garage:server:getVehicles', function(vehicles)
        SendNUIMessage({
            action = 'openMenu',
            vehicles = vehicles,
            maxVehicles = Config.MaxVehiclesPerPlayer,
            allowedVehicles = Config.AllowedVehicles,
        })
    end)
end

function CloseMenu()
    currentState = 'idle'
    SetNuiFocus(false, false)
    SendNUIMessage({action = 'closeAll'})
end

function ExitPreview()
    SetNuiFocus(false, false)
    SendNUIMessage({action = 'closeAll'})

    if previewCam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(previewCam, false)
        previewCam = nil
    end

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)

    if previewVehicle and DoesEntityExist(previewVehicle) then
        DeleteEntity(previewVehicle)
    end
    previewVehicle = nil
    currentPlate = nil

    TriggerServerEvent('outrun-garage:server:exitPreview')

    if savedCoords then
        SetEntityCoords(ped, savedCoords.x, savedCoords.y, savedCoords.z, false, false, false, false)
        savedCoords = nil
    end

    UnloadAutoShop()
    currentState = 'idle'
end

-- ==================== NUI CALLBACKS ====================

RegisterNUICallback('closeMenu', function(_, cb)
    cb('ok')
    CloseMenu()
end)

RegisterNUICallback('acquireVehicle', function(data, cb)
    cb('ok')
    QBCore.Functions.TriggerCallback('outrun-garage:server:acquireVehicle', function(success, msg, vehicle)
        if success then
            QBCore.Functions.Notify('Veículo adquirido: ' .. (vehicle.label or vehicle.model), 'success')
        else
            QBCore.Functions.Notify(msg or 'Erro ao adquirir veículo.', 'error')
        end
        RefreshMenu()
    end, data.model)
end)

RegisterNUICallback('deleteVehicle', function(data, cb)
    cb('ok')
    QBCore.Functions.TriggerCallback('outrun-garage:server:deleteVehicle', function(success)
        if success then
            QBCore.Functions.Notify('Veículo removido.', 'success')
        else
            QBCore.Functions.Notify('Erro ao remover veículo.', 'error')
        end
        RefreshMenu()
    end, data.plate)
end)

RegisterNUICallback('customizeVehicle', function(data, cb)
    cb('ok')
    if currentState ~= 'menu' then return end
    currentState = 'customizing'
    currentPlate = data.plate

    SetNuiFocus(false, false)
    SendNUIMessage({action = 'closeAll'})
    QBCore.Functions.Notify('Preparando veículo...', 'primary')

    CreateThread(function()
        local ped = PlayerPedId()
        savedCoords = GetEntityCoords(ped)

        TriggerServerEvent('outrun-garage:server:enterPreview')

        LoadAutoShop()

        local loc = Config.PreviewLocation
        SetEntityCoords(ped, loc.x, loc.y, loc.z, false, false, false, false)
        SetEntityHeading(ped, loc.w)
        RequestCollisionAtCoord(loc.x, loc.y, loc.z)

        -- Garante que o interior carregou antes de spawnar o carro
        local interior = GetInteriorAtCoords(loc.x, loc.y, loc.z)
        if interior ~= 0 then
            LoadInterior(interior)
            local it = 0
            while not IsInteriorReady(interior) and it < 5000 do Wait(50); it = it + 50 end
        end
        Wait(500)

        local hash = GetHashKey(data.model)
        RequestModel(hash)
        local timeout = 0
        while not HasModelLoaded(hash) do
            Wait(10)
            timeout = timeout + 10
            if timeout > 10000 then
                QBCore.Functions.Notify('Erro ao carregar modelo.', 'error')
                ExitPreview()
                return
            end
        end

        ped = PlayerPedId()
        -- O carro nasce exatamente no ponto capturado (sobre o elevador),
        -- com o heading capturado. O player (invisível) fica ao lado só para
        -- manter o interior carregado.
        previewVehicle = CreateVehicle(hash, loc.x, loc.y, loc.z, loc.w, true, false)
        SetModelAsNoLongerNeeded(hash)

        if not previewVehicle or previewVehicle == 0 then
            QBCore.Functions.Notify('Erro ao criar veículo.', 'error')
            ExitPreview()
            return
        end

        SetVehicleNumberPlateText(previewVehicle, currentPlate)
        SetVehicleOnGroundProperly(previewVehicle)
        Wait(100)
        FreezeEntityPosition(previewVehicle, true)
        SetEntityInvincible(previewVehicle, true)
        SetVehicleDirtLevel(previewVehicle, 0.0)
        SetVehicleModKit(previewVehicle, 0)

        if data.mods and type(data.mods) == 'table' and next(data.mods) then
            QBCore.Functions.SetVehicleProperties(previewVehicle, data.mods)
        end

        FreezeEntityPosition(ped, true)
        SetEntityVisible(ped, false, false)

        -- Câmera 3/4 com rotação por drag do mouse
        camAngle = GetEntityHeading(previewVehicle) + 30.0
        previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        PositionPreviewCam()
        SetCamFov(previewCam, 45.0)
        SetCamActive(previewCam, true)
        RenderScriptCams(true, true, 500, true, true)

        Wait(200)
        OpenCustomsMenu(previewVehicle, data.model)
    end)
end)

RegisterNUICallback('saveCustomize', function(_, cb)
    cb('ok')
    if not previewVehicle or currentState ~= 'customizing' then return end

    local props = QBCore.Functions.GetVehicleProperties(previewVehicle)

    QBCore.Functions.TriggerCallback('outrun-garage:server:saveMods', function(success)
        if success then
            QBCore.Functions.Notify('Modificações salvas!', 'success')
        else
            QBCore.Functions.Notify('Erro ao salvar.', 'error')
        end
        ExitPreview()
    end, currentPlate, props)
end)

RegisterNUICallback('cancelCustomize', function(_, cb)
    cb('ok')
    ExitPreview()
end)

RegisterNUICallback('rotateCam', function(data, cb)
    cb('ok')
    if not previewCam or not previewVehicle or not DoesEntityExist(previewVehicle) then return end
    camAngle = camAngle - data.deltaX * 0.3
    PositionPreviewCam()
end)

-- Limpar se o resource parar (dev/restart)
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if currentState ~= 'idle' then
        SetNuiFocus(false, false)
        if previewCam then
            RenderScriptCams(false, false, 0, true, true)
            DestroyCam(previewCam, false)
            previewCam = nil
        end
        local ped = PlayerPedId()
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true, false)
        if previewVehicle and DoesEntityExist(previewVehicle) then
            DeleteEntity(previewVehicle)
        end
        if savedCoords then
            SetEntityCoords(ped, savedCoords.x, savedCoords.y, savedCoords.z, false, false, false, false)
        end
        UnloadAutoShop()
        TriggerServerEvent('outrun-garage:server:exitPreview')
    end
end)
