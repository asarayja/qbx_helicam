local sharedConfig = require 'config.shared'

if sharedConfig.server.enableVersionCheck then
    lib.versionCheck('Qbox-project/qbx_helicam')
end

RegisterNetEvent('qbx_helicam:server:toggleSpotlightState', function(netId)
    local src = source
    if not src then return end
    
    local vehicle = NetworkGetEntityFromNetworkId(netId)

    if not DoesEntityExist(vehicle) or GetVehicleType(vehicle) ~= 'heli' then return end
    
    -- Additional validation to ensure the player is in the vehicle
    local ped = GetPlayerPed(src)
    if not ped or GetVehiclePedIsIn(ped, false) ~= vehicle then return end

    local spotlightStatus = Entity(vehicle).state[sharedConfig.entityState.spotlightStateName]

    Entity(vehicle).state:set(sharedConfig.entityState.spotlightStateName, not spotlightStatus, sharedConfig.entityState.syncToAll)
    
    if sharedConfig.server.logSpotlightToggle and sharedConfig.debug then
        print(('[%s] Player %s toggled spotlight on vehicle %s to %s'):format(
            sharedConfig.resourceName, 
            src, 
            vehicle, 
            not spotlightStatus and 'ON' or 'OFF'
        ))
    end
end)