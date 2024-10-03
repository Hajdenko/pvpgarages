-- Used to store vehicles that have been taken out
---@type table<string, number>
local activeVehicles = {}

lib.callback.register(GetCurrentResourceName()..':getOwnedVehicles', function(source, index)
    local player = Framework.getPlayerFromId(source)
    if not player then return end
    
    local garage = Config.Garages[index]
    local vehicles = MySQL.query.await(Queries.getGarage, {
        player:getIdentifier(), garage.Type
    })

    for _, vehicle in ipairs(vehicles) do
        if vehicle.stored == 1 or vehicle.stored == true then
            vehicle.state = 'in_garage'
        elseif activeVehicles[vehicle.plate] then
            local entity = activeVehicles[vehicle.plate]
            if not DoesEntityExist(entity) then
                activeVehicles[vehicle.plate] = nil
                vehicle.state = 'in_impound'
            elseif not DoesEntityExist(entity) or GetVehiclePetrolTankHealth(entity) <= 0 or GetVehicleBodyHealth(entity) <= 0 then
                DeleteEntity(entity)
                activeVehicles[vehicle.plate] = nil
                vehicle.state = 'in_impound'
            else
                vehicle.state = 'out_garage'
            end
        else
            vehicle.state = 'in_impound'
        end
    end

    return vehicles
end)

lib.callback.register(GetCurrentResourceName()..':getImpoundedVehicles', function(source, index)
    local player = Framework.getPlayerFromId(source)
    if not player then return end
    
    local impound = Config.Impounds[index]
    local vehicles = MySQL.query.await(Queries.getImpound, {
        player:getIdentifier(), impound.Type
    })

    local filtered = {}

    for _, vehicle in ipairs(vehicles) do
        local entity = activeVehicles[vehicle.plate]

        if not entity then
            table.insert(filtered, vehicle)
        elseif not DoesEntityExist(entity) then
            activeVehicles[vehicle.plate] = nil
            table.insert(filtered, vehicle)
        elseif GetVehiclePetrolTankHealth(entity) <= 0 or GetVehicleBodyHealth(entity) <= 0 then
            DeleteEntity(entity)
            activeVehicles[vehicle.plate] = nil
            table.insert(filtered, vehicle)
        end
    end

    return filtered
end)

lib.callback.register(GetCurrentResourceName()..':takeOutVehicle', function(source, index, plate, type)
    local player = Framework.getPlayerFromId(source)
    if not player then return end

    local vehicle = MySQL.single.await(Queries.getStoredVehicle, {
        player:getIdentifier(), plate, 1
    })

    if vehicle then
        MySQL.update.await(Queries.setStoredVehicle, { 0, plate })
        local garage = Config.Garages[index]
        local coords = GetEntityCoords(GetPlayerPed(source))
        local props = json.decode(vehicle.mods or vehicle.vehicle)
        local entity = Utils.createVehicle(props.model, vector4(coords.x,coords.y,coords.z,GetEntityHeading(GetPlayerPed(source))), type)

        if entity == 0 then return end

        while NetworkGetEntityOwner(entity) == -1 do Wait(0) end

        local netId, owner = NetworkGetNetworkIdFromEntity(entity), NetworkGetEntityOwner(entity)
        
        TriggerClientEvent(GetCurrentResourceName()..':setVehicleProperties', owner, netId, props)

        activeVehicles[plate] = entity

        return netId
    end
end)

lib.callback.register(GetCurrentResourceName()..':doesPlayerOwnVehicle', function(source, props, netId)
    local player = Framework.getPlayerFromId(source)
    if not player then return end

    local vehicle = MySQL.single.await(Queries.getOwnedVehicle, {
        player:getIdentifier(), props.plate
    })
    
    if vehicle then
        return true
    end
    
    return false
end)

lib.callback.register(GetCurrentResourceName()..':saveVehicle', function(source, props, netId)
    local player = Framework.getPlayerFromId(source)
    if not player then return end

    local vehicle = MySQL.single.await(Queries.getOwnedVehicle, {
        player:getIdentifier(), props.plate
    })
    
    if vehicle then
        local oldProps = json.decode(vehicle.mods or vehicle.vehicle)

        if props.model ~= oldProps.model then
            return false
        end

        MySQL.update.await(Queries.setStoredVehicle, { 1, props.plate })
        MySQL.update.await(Queries.setVehicleProps, { json.encode(props), props.plate })

        local vehicle = NetworkGetEntityFromNetworkId(netId)
            
        if DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
        end

        activeVehicles[props.plate] = nil;

        return true
    end
    
    return false
end)

lib.callback.register(GetCurrentResourceName()..':retrieveVehicle', function(source, index, plate, type)
    if activeVehicles[plate] then return end

    local player = Framework.getPlayerFromId(source)
    if not player then return end

    local vehicle = MySQL.single.await(Queries.getOwnedVehicle, {
        player:getIdentifier(), plate
    })

    if vehicle then
        if player:getAccountMoney('money') < Config.ImpoundPrice then return false end

        player:removeAccountMoney('money', Config.ImpoundPrice)

        local impound = Config.Impounds[index]
        local coords = impound.SpawnPosition
        local props = json.decode(vehicle.mods or vehicle.vehicle)
        local entity = Utils.createVehicle(props.model, coords, type)

        if entity == 0 then return end

        while NetworkGetEntityOwner(entity) == -1 do Wait(0) end

        local netId, owner = NetworkGetNetworkIdFromEntity(entity), NetworkGetEntityOwner(entity)
        
        TriggerClientEvent(GetCurrentResourceName()..':setVehicleProperties', owner, netId, props)

        activeVehicles[props.plate] = entity

        return true, netId
    end

    return false
end)

lib.callback.register(GetCurrentResourceName()..':getVehicleCoords', function(source, plate)
    local entity = activeVehicles[plate]

    if not entity then return end

    return GetEntityCoords(entity)
end)

lib.addCommand({'garage', 'grg', 'grz', 'garaz'}, {
    help = 'Opens the garage menu.',
}, function(source)
    lib.callback.await(GetCurrentResourceName()..':openGarage', source)
end)