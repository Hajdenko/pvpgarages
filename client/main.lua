local isSaveLooping = false
local isSavingVehicle = false

local function getVehicleType(model)
    if IsThisModelABike(model) then
        return 'bike'
    end

    -- Not really sure if quadbike is considered an automobile or a bike
    if IsThisModelACar(model) or IsThisModelAQuadbike(model) then
        return 'automobile'
    end

    if IsThisModelABoat(model) or IsThisModelAJetski(model) then
        return 'boat'
    end

    if IsThisModelAPlane(model) then
        return 'plane'
    end

    if IsThisModelAHeli(model) then
        return 'heli'
    end
end

-- Taken from ox_lib, but higher timeout value and modified
RegisterNetEvent(GetCurrentResourceName()..':setVehicleProperties', function(netId, data)
    local timeout = 10000

    while not NetworkDoesEntityExistWithNetworkId(netId) and timeout > 0 do
        Wait(0)
        timeout -= 1
    end

    if timeout > 0 then
        local vehicle = NetToVeh(netId)

        if NetworkGetEntityOwner(vehicle) ~= cache.playerId then return end

        lib.setVehicleProperties(vehicle, data)
    end
end)

---@param vehicle number?
local function saveVehicle(vehicle)
    if not isSavingVehicle then
        isSavingVehicle = true

        if not vehicle and (cache.seat ~= -1 or (IsPedInAnyVehicle(cache.ped, false) == 0)) then
            ShowNotification(locale('not_driver'), 'error')
            HideUI()
            return
        end

        local vehicle = cache.vehicle or vehicle
        local props = lib.getVehicleProperties(vehicle)

        if not props then return end

        props.plate = props.plate:strtrim(' ') -- Trim whitespace
        props.fuelLevel = GetVehicleFuelLevel(vehicle)
        local netId = NetworkGetNetworkIdFromEntity(vehicle)

        ShowNotification(locale('saving0'), 'success')
        Wait(1000)
        ShowNotification(locale('saving1'), 'info')
        Wait(500)
        ShowNotification(locale('saving2'), 'info')
        Wait(500)

        local result = lib.callback.await(GetCurrentResourceName()..':saveVehicle', false, props, netId)
        
        if result then
            ShowNotification(locale('vehicle_saved'), 'success')
        else
            ShowNotification(locale('not_your_vehicle'), 'error')
        end

        isSavingVehicle = false
    else
        if (cache.vehicle) then
            ShowNotification(locale('save_calm_down'), 'error')
        end
    end
end

local function saveLooping(vehicle)
    if not vehicle then return end
    local props = lib.getVehicleProperties(vehicle)

    if not props then return end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local success = lib.callback.await(GetCurrentResourceName()..':doesPlayerOwnVehicle', false, props)
    if vehicle and success then
        local vehicleSpeedCheckActive = false
    
        local function checkSpeed()
            if isSaveLooping then return end
            while IsPedInAnyVehicle(cache.ped, false) do
                isSaveLooping = true
                Citizen.Wait(200)
                
                local speed = GetEntitySpeed(vehicle)
    
                if (speed < 15.0 and not vehicleSpeedCheckActive) then
                    ShowUI(('[%s] - %s'):format(Binds.second.currentKey, locale('save_vehicle')), 'floppy-disk')
                    vehicleSpeedCheckActive = true
                    Binds.second.addListener('garage', function()
                        saveVehicle()
                    end)
                elseif (speed >= 15.0 and vehicleSpeedCheckActive) then
                    HideUI()
                    vehicleSpeedCheckActive = false
                    Binds.first.removeListener('garage')
                    Binds.second.removeListener('garage')
                end
            end

            isSaveLooping = false

            local nearbyVehicles = lib.getNearbyVehicles(GetEntityCoords(vehicle), 10.0, true)

            if nearbyVehicles then
                for _, nearbyVehicle in ipairs(nearbyVehicles) do
                    if nearbyVehicle.vehicle == vehicle then
                        Binds.first.removeListener('garage')
                        Binds.second.removeListener('garage')
                        Binds.second.addListener('garage_vehicle', function() 
                            saveVehicle(vehicle)
                        end)
                        Citizen.Wait(5000)
                        break
                    end
                end
            end
        end
    
        Citizen.CreateThread(checkSpeed)
    end
end

function SpawnVehicle(args)
    ---@type integer, VehicleProperties
    local index, props in args
    
    local garage = Config.Garages[index]
    
    if Config.SpawnpointCheck and lib.getClosestVehicle(garage.SpawnPosition.xyz, 3.0, false) then
        ShowNotification(locale('spawn_occupied'), 'error')
        return
    end

    lib.requestModel(props.model)
    local type = getVehicleType(props.model)
    local netId = lib.callback.await(GetCurrentResourceName()..':takeOutVehicle', false, index, props.plate, type)
    
    while not NetworkDoesEntityExistWithNetworkId(netId) do Wait(0) end

    local vehicle = NetworkGetEntityFromNetworkId(netId)

    CreateThread(function()
        while true do
            if NetworkGetEntityOwner(vehicle) == cache.playerId then
                lib.setVehicleProperties(vehicle, props)
                return
            end

            local plate = GetVehicleNumberPlateText(vehicle)

            if plate == props.plate then
                return
            end

            Wait(0)
        end
    end)

    -- The player doesn't get warped in the vehicle sometimes, repeat it and timeout after 2000 attempts
    for _ = 1, 2000 do
        TaskWarpPedIntoVehicle(cache.ped, vehicle, -1)
    
        if GetVehiclePedIsIn(cache.ped, false) == vehicle then
            break
        end

        Wait(0)
    end

    SetVehicleFuelLevel(vehicle, 100.0)

    saveLooping(vehicle)
end

function GetVehicleLabel(model)
    local label = GetLabelText(GetDisplayNameFromVehicleModel(model))
    
    if label == 'NULL' then 
        label = GetDisplayNameFromVehicleModel(model)
    end

    return label
end

local function getClassIcon(class)
    if class == 8 then
        return 'motorcycle'
    elseif class == 13 then
        return 'bicycle'
    elseif class == 15 then
        return 'helicopter'
    else
        return 'car'
    end
end

local function getFuelBarColor(fuel)
    -- fuelLevel not defined in vehicleProps??
    if not fuel then return 'lime' end

    if fuel > 75.0 then
        return 'lime'
    elseif fuel > 50.0 then
        return 'yellow'
    elseif fuel > 25.0 then
        return 'orange'
    else
        return 'red'
    end
end

local function openGarageVehicles(args)
    local index in args
    local vehicles = lib.callback.await(GetCurrentResourceName()..':getOwnedVehicles', false, index)
    
    if #vehicles == 0 then
        ShowNotification(locale('no_owned_vehicles'), 'error')
        return
    end

    ---@type ContextMenuArrayItem[]
    local options = {}

    for _, vehicle in ipairs(vehicles) do
        ---@type VehicleProperties
        local props = json.decode(vehicle.mods or vehicle.vehicle)

        local vehColor = props.color1 and props.color1 or props.color2
        vehColor.r = vehColor[1]; vehColor.g = vehColor[2]; vehColor.b = vehColor[3]

        local class = GetVehicleClassFromName(GetDisplayNameFromVehicleModel(props.model))
        local fuelLevel = props.fuelLevel or 100.0

        ---@type ContextMenuArrayItem
        local option = {
            title = locale('vehicle_info', GetVehicleLabel(props.model), props.plate),
            icon = getClassIcon(class),
            iconColor = ("rgb(%s,%s,%s)"):format(vehColor.r, vehColor.g, vehColor.b),
            progress = class ~= 13 and fuelLevel,
            colorScheme = class ~= 13 and getFuelBarColor(fuelLevel),
            metadata = {
                ---@diagnostic disable-next-line: assign-type-mismatch
                { label = locale('status'), value = locale(vehicle.state) },
                
                ---@diagnostic disable-next-line: assign-type-mismatch
                { label = locale('fuel'), value = class ~= 13 and locale('fuel_always_full') }
            },
            args = { index = index, props = props },
            onSelect = vehicle.state == 'in_garage' and SpawnVehicle or function()
                if vehicle.state == 'out_garage' then
                    local coords = lib.callback.await(GetCurrentResourceName()..':getVehicleCoords', false, vehicle.plate)
                    SetNewWaypoint(coords.x, coords.y)
                    ShowNotification(locale('out_garage_message'))
                elseif vehicle.state == 'in_impound' then
                    ShowNotification(locale('in_impound_message'), 'error')
                end
            end
        }

        table.insert(options, option)
    end

    lib.registerContext({
        id = 'garage_vehicles',
        title = locale('player_vehicles'),
        options = options
    })

    lib.showContext('garage_vehicles')
end

local function openGarage()
    openGarageVehicles({ index = 1 })
end

local function retrieveVehicle(args)
    ---@type integer, VehicleProperties
    local index, props in args
    
    lib.requestModel(props.model)
    local type = getVehicleType(props.model)
    local success, netId = lib.callback.await(GetCurrentResourceName()..':retrieveVehicle', false, index, props.plate, type)

    if not success then
        ShowNotification(locale('not_enough_money'), 'error')
        return
    end

    while not NetworkDoesEntityExistWithNetworkId(netId) do Wait(0) end

    local vehicle = NetworkGetEntityFromNetworkId(netId)

    CreateThread(function()
        while true do
            if NetworkGetEntityOwner(vehicle) == cache.playerId then
                lib.setVehicleProperties(vehicle, props)
                return
            end

            local plate = GetVehicleNumberPlateText(vehicle)

            if plate == props.plate then
                return
            end

            Wait(0)
        end
    end)

    -- The player doesn't get warped in the vehicle sometimes, repeat it and timeout after 2000 attempts
    for _ = 1, 2000 do
        TaskWarpPedIntoVehicle(cache.ped, vehicle, -1)
        
        if GetVehiclePedIsIn(cache.ped, false) == vehicle then
            break
        end

        Wait(0)
    end

    SetVehicleFuelLevel(vehicle, 100.0)
end

local function openImpoundVehicles(args)
    local index = args.index
    local vehicles = lib.callback.await(GetCurrentResourceName()..':getImpoundedVehicles', false, index)
    
    if #vehicles == 0 then
        local owned_vehicles = lib.callback.await(GetCurrentResourceName()..':getOwnedVehicles', false, index)
    
        if #owned_vehicles == 0 then
            ShowNotification(locale('no_impounded_vehicles_and_no_vehicles'), 'error')
            return
        end

        ShowNotification(locale('no_impounded_vehicles'), 'error')
        openGarage()
        return
    end

    ---@type ContextMenuArrayItem[]
    local options = {}

    for _, vehicle in ipairs(vehicles) do
        ---@type VehicleProperties
        local props = json.decode(vehicle.mods or vehicle.vehicle)

        local class = GetVehicleClassFromName(GetDisplayNameFromVehicleModel(props.model))
        local fuelLevel = props.fuelLevel or 100.0

        local vehColor = props.color1 and props.color1 or props.color2
        vehColor.r = vehColor[1]; vehColor.g = vehColor[2]; vehColor.b = vehColor[3]

        ---@type ContextMenuArrayItem
        local option = {
            title = locale('vehicle_info', GetVehicleLabel(props.model), props.plate),
            icon = getClassIcon(class),
            iconColor = ("rgb(%s,%s,%s)"):format(vehColor.r, vehColor.g, vehColor.b),
            progress = class ~= 13 and fuelLevel,
            colorScheme = class ~= 13 and getFuelBarColor(fuelLevel),
            metadata = {
                ---@diagnostic disable-next-line: assign-type-mismatch
                { label = locale('fuel'), value = class ~= 13 and fuelLevel .. '%' or locale('no_fueltank') }
            },
            args = { index = index, props = props },
            onSelect = retrieveVehicle
        }

        table.insert(options, option)
    end

    lib.registerContext({
        id = 'impound_vehicles',
        title = locale('player_vehicles'),
        options = options
    })

    lib.showContext('impound_vehicles')
end

local function openImpound(index)
    openImpoundVehicles({index = index})
end 

local function garagePrompt(index, data)
    if not data then
        data = Config.Garages[index]
        if not data then
            return;
        end
    end

    
    if not isSaveLooping then
        if cache.vehicle then
            ShowUI(('[%s] - %s'):format(Binds.second.currentKey, locale('save_vehicle')), 'floppy-disk')
            Binds.second.addListener('garage', function()
                saveVehicle()
            end)
        else
            local prompt
    
            prompt = (('[%s] - %s'):format(Binds.first.currentKey, locale('open_garage')))
    
            ShowUI(prompt, 'warehouse')
            Binds.first.addListener('garage', function()
                openGarage()
            end)
        end
    end
end

lib.onCache('vehicle', function(vehicle)
    cache.vehicle = vehicle

    saveLooping(vehicle)
end)

for index, data in ipairs(Config.Garages) do
    if (not Config.Target or not data.PedPosition) and data.Position then
        lib.zones.sphere({
            coords = data.Position,
            radius = Config.MaxDistance or 5.0,
            onEnter = function()
                if data.Jobs and not Utils.hasJobs(data.Jobs) then return end

                garagePrompt(1, data)
            end,
            onExit = function()
                if not isSaveLooping then
                    HideUI()
                    Binds.first.removeListener('garage')
                    Binds.second.removeListener('garage')
                end
            end
        })
    elseif (Config.Target or not data.Position) and data.PedPosition then
        if not data.Model then
            warn(('Skipping garage - missing Model, index: %s'):format(index))
            goto continue
        end

        Utils.createPed(data.PedPosition, data.Model, {
            {
                label = locale('open_garage'),
                icon = 'warehouse',
                job = data.Jobs,
                onSelect = openGarage
            },
            {
                label = locale('save_vehicle'),
                icon = 'floppy-disk',
                job = data.Jobs,
                onSelect = function()
                    local vehicle = GetVehiclePedIsIn(cache.ped, true)

                    if Utils.distanceCheck(cache.ped, vehicle, 20.0) then
                        saveVehicle(vehicle)
                    end
                end
            }
        })
    else
        warn(('Skipping garage - missing Position or PedPosition, index: %s'):format(index))
    end

    ::continue::
end

for index, data in ipairs(Config.Impounds) do
    if (not Config.Target or not data.PedPosition) and data.Position then
        lib.zones.sphere({
            coords = data.Position,
            radius = Config.MaxDistance,
            onEnter = function()
                if data.Jobs and not Utils.hasJobs(data.Jobs) then return end

                if not isSaveLooping then
                    ShowUI(('[%s] - %s'):format(Binds.first.currentKey, locale('open_impound')), 'warehouse')
                    Binds.first.addListener('impound', function()
                        openImpound(index)
                    end)
                end
            end,
            onExit = function()
                if not isSaveLooping then
                    HideUI()
                    Binds.first.removeListener('impound')
                end
            end
        })
    elseif (Config.Target or not data.Position) and data.PedPosition then
        if not data.Model then
            warn(('Skipping impound - missing Model, index: %s'):format(index))
            goto continue
        end

        Utils.createPed(data.PedPosition, data.Model, {
            {
                label = locale('open_impound'),
                icon = 'warehouse',
                job = data.Jobs,
                args = index,
                onSelect = openImpound
            }
        })
    else
        warn(('Skipping impound - missing Position or PedPosition, index: %s'):format(index))
    end

    ::continue::
end


lib.callback.register(GetCurrentResourceName()..':openGarage', function(source)
    openGarage()
end)
