local QBCore = exports['qb-core']:GetCoreObject()

local currentState = 'idle' -- 'idle' | 'menu' | 'customizing'
local previewVehicle = nil
local savedCoords = nil
local currentPlate = nil
local previewCam = nil
local camAngle = 0.0

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

        local loc = Config.PreviewLocation
        SetEntityCoords(ped, loc.x, loc.y, loc.z, false, false, false, false)
        SetEntityHeading(ped, loc.w)
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
        local fwd = GetEntityForwardVector(ped)
        local pos = GetEntityCoords(ped) + fwd * 5.0
        previewVehicle = CreateVehicle(hash, pos.x, pos.y, pos.z, loc.w + 180.0, true, false)
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
        local vehCoords = GetEntityCoords(previewVehicle)
        camAngle = GetEntityHeading(previewVehicle) + 30.0
        local rad = math.rad(camAngle)
        previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamCoord(previewCam,
            vehCoords.x - 6.0 * math.sin(rad),
            vehCoords.y + 6.0 * math.cos(rad),
            vehCoords.z + 1.5)
        PointCamAtCoord(previewCam, vehCoords.x, vehCoords.y, vehCoords.z + 0.3)
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
    local vehCoords = GetEntityCoords(previewVehicle)
    local rad = math.rad(camAngle)
    SetCamCoord(previewCam,
        vehCoords.x - 6.0 * math.sin(rad),
        vehCoords.y + 6.0 * math.cos(rad),
        vehCoords.z + 1.5)
    PointCamAtCoord(previewCam, vehCoords.x, vehCoords.y, vehCoords.z + 0.3)
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
        TriggerServerEvent('outrun-garage:server:exitPreview')
    end
end)
