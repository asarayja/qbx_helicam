local config = require 'config.client'
local sharedConfig = require 'config.shared'

-- Camera Configuration from config
local FOV_MAX = config.camera.fovMax
local FOV_MIN = config.camera.fovMin
local ZOOM_SPEED = config.camera.zoomSpeed
local LR_SPEED = config.camera.leftRightSpeed
local UD_SPEED = config.camera.upDownSpeed
local toggleHeliCam = config.controls.toggleCamera
local toggleVision = config.controls.toggleVision
local toggleLockOn = config.controls.toggleLockOn
local heliCam = false
local fov = (FOV_MAX + FOV_MIN) * 0.5

---@enum
local VISION_STATE = {
    normal = 0,
    nightmode = 1,
    thermal = 2,
}

local visionState = VISION_STATE.normal
local scanValue = 0

---@enum
local VEHICLE_LOCK_STATE = {
    dormant = 0,
    scanning = 1,
    locked = 2,
}

local vehicleLockState = VEHICLE_LOCK_STATE.dormant
local vehicleDetected = nil
local lockedOnVehicle = nil
local lastVehicleData = nil -- Cache for vehicle info to avoid duplicate NUI messages

local function isHeliHighEnough(heli)
    return GetEntityHeightAboveGround(heli) > config.heightRequirement.minimum
end

local function changeVision()
    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
    if visionState == VISION_STATE.normal then
        SetNightvision(true)
    elseif visionState == VISION_STATE.nightmode then
        SetNightvision(false)
        SetSeethrough(true)
    elseif visionState == VISION_STATE.thermal then
        SetSeethrough(false)
    else
        error('Unexpected visionState ' .. json.encode(visionState))
    end
    visionState = (visionState + 1) % 3
end

local function hideHudThisFrame()
    HideHelpTextThisFrame()
    HideHudAndRadarThisFrame()

    for _, component in ipairs(config.hiddenHudComponents) do
        HideHudComponentThisFrame(component)
    end
end

local function checkInputRotation(cam, zoomValue)
    local rightAxisX = GetDisabledControlNormal(0, config.controls.rightAxisX)
    local rightAxisY = GetDisabledControlNormal(0, config.controls.rightAxisY)
    local rotation = GetCamRot(cam, 2)
    if rightAxisX == 0.0 and rightAxisY == 0.0 then return end

    local zoomFactor = zoomValue + 0.1
    local newZ = rotation.z - rightAxisX * UD_SPEED * zoomFactor
    local newY = rightAxisY * -1.0 * LR_SPEED * zoomFactor
    local newX = math.max(math.min(config.camera.rotationLimits.maxX, rotation.x + newY), config.camera.rotationLimits.minX)
    SetCamRot(cam, newX, 0.0, newZ, 2)
end

local function handleZoom(cam)
    if IsControlJustPressed(0, config.controls.scrollUp) then -- Scrollup
        fov = math.max(fov - ZOOM_SPEED, FOV_MIN)
    end
    if IsControlJustPressed(0, config.controls.scrollDown) then
        fov = math.min(fov + ZOOM_SPEED, FOV_MAX) -- ScrollDown
    end
    local currentFov = GetCamFov(cam)
    if math.abs(fov - currentFov) < 0.1 then -- the difference is too small, just set the value directly to avoid unneeded updates to FOV of order 10^-5
        fov = currentFov
    end
    SetCamFov(cam, currentFov + (fov - currentFov) * config.camera.smoothingFactor) -- Smoothing of camera zoom
end

local function rotAnglesToVec(rot) -- input vector3
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local function getVehicleInView(cam)
    local camCoords = GetCamCoord(cam)
    local camRot = GetCamRot(cam, 2)
    local forwardVector = rotAnglesToVec(camRot)
    local targetCoords = camCoords + (forwardVector * config.camera.raycastDistance)
    local rayHandle = CastRayPointToPoint(camCoords.x, camCoords.y, camCoords.z, targetCoords.x, targetCoords.y, targetCoords.z, 10, cache.vehicle, 0)
    local _, _, _, _, entityHit = GetRaycastResult(rayHandle)

    return entityHit > 0 and IsEntityAVehicle(entityHit) and entityHit or nil
end

local function renderVehicleInfo(vehicle)
    local pos = GetEntityCoords(vehicle)
    local model = GetEntityModel(vehicle)
    local vehName = GetLabelText(GetDisplayNameFromVehicleModel(model))
    local licensePlate = qbx.getVehiclePlate(vehicle)
    local speed = math.ceil(GetEntitySpeed(vehicle) * 3.6)
    local street1, street2 = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
    local streetLabel = GetStreetNameFromHashKey(street1)
    if street2 ~= 0 then
        streetLabel = streetLabel .. ' | ' .. GetStreetNameFromHashKey(street2)
    end
    
    -- Cache the last sent data to avoid sending duplicate NUI messages
    local currentData = {
        model = vehName,
        plate = licensePlate,
        speed = speed,
        street = streetLabel,
    }
    
    -- Only send NUI message if data has changed
    if not lastVehicleData or 
       lastVehicleData.model ~= currentData.model or
       lastVehicleData.plate ~= currentData.plate or
       math.abs(lastVehicleData.speed - currentData.speed) > config.performance.speedUpdateThreshold or
       lastVehicleData.street ~= currentData.street then
        
        SendNUIMessage({
            type = 'heliupdateinfo',
            model = currentData.model,
            plate = currentData.plate,
            speed = currentData.speed,
            street = currentData.street,
        })
        
        lastVehicleData = currentData
    end
end

local function heliCamThread()
    CreateThread(function()
        local sleep
        local lastUpdateTime = GetGameTimer()
        while heliCam do
            sleep = config.performance.minimumThreadSleep -- Minimum wait time to reduce CPU load
            local currentTime = GetGameTimer()
            
            if vehicleLockState == VEHICLE_LOCK_STATE.scanning then
                if scanValue < 100 and currentTime - lastUpdateTime >= config.performance.scanUpdateDelay then
                    scanValue += config.performance.scanIncrementStep -- Configurable increment step
                    if scanValue >= 100 then
                        scanValue = 100
                        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                        lockedOnVehicle = vehicleDetected
                        vehicleLockState = VEHICLE_LOCK_STATE.locked
                    end
                    SendNUIMessage({
                        type = 'heliscan',
                        scanvalue = scanValue,
                    })
                    lastUpdateTime = currentTime
                    sleep = config.performance.scanSleepActive
                end
            elseif vehicleLockState == VEHICLE_LOCK_STATE.locked then
                scanValue = 100
                if currentTime - lastUpdateTime >= config.performance.vehicleInfoUpdateDelay then
                    renderVehicleInfo(lockedOnVehicle)
                    lastUpdateTime = currentTime
                end
                sleep = config.performance.scanSleepLocked
            else
                scanValue = 0
                sleep = config.performance.scanSleepIdle
            end
            Wait(sleep)
        end
    end)
end

local function unlockCam(cam)
    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
    lockedOnVehicle = nil
    local rot = GetCamRot(cam, 2) -- All this because I can't seem to get the camera unlocked from the entity
    fov = GetCamFov(cam)
    local oldCam = cam
    DestroyCam(oldCam, false)
    local newCam = CreateCam('DEFAULT_SCRIPTED_FLY_CAMERA', true)
    AttachCamToEntity(newCam, cache.vehicle, config.camera.attachOffset.x, config.camera.attachOffset.y, config.camera.attachOffset.z, true)
    SetCamRot(newCam, rot.x, rot.y, rot.z, 2)
    SetCamFov(newCam, fov)
    RenderScriptCams(true, false, 0, true, false)
    vehicleLockState = VEHICLE_LOCK_STATE.dormant
    scanValue = 0
    SendNUIMessage({
        type = 'disablescan',
    })
    return newCam
end

local function turnOffCam()
    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
    heliCam = false
    vehicleLockState = VEHICLE_LOCK_STATE.dormant
    scanValue = 0
    lastVehicleData = nil -- Reset cached data
    SendNUIMessage({
        type = 'disablescan',
    })
    SendNUIMessage({
        type = 'heliclose',
    })
end

local function handleInVehicle()
    if not LocalPlayer.state.isLoggedIn then return end

    if heliCam then
        SetTimecycleModifier(config.vision.nightvisionModifier)
        SetTimecycleModifierStrength(config.vision.nightvisionStrength)
        local scaleform = lib.requestScaleformMovie(config.scaleform.movieName)
        local cam = CreateCam('DEFAULT_SCRIPTED_FLY_CAMERA', true)
        AttachCamToEntity(cam, cache.vehicle, config.camera.attachOffset.x, config.camera.attachOffset.y, config.camera.attachOffset.z, true)
        SetCamRot(cam, 0.0, 0.0, GetEntityHeading(cache.vehicle), 2)
        SetCamFov(cam, fov)
        RenderScriptCams(true, false, 0, true, false)
        PushScaleformMovieFunction(scaleform, 'SET_CAM_LOGO')
        PushScaleformMovieFunctionParameterInt(config.scaleform.logoType) -- Configurable logo type
        PopScaleformMovieFunctionVoid()
        lockedOnVehicle = nil
        
        local lastVehicleCheck = 0
        local vehicleCheckDelay = config.performance.vehicleCheckDelay -- Configurable delay
        
        while heliCam and not IsEntityDead(cache.ped) and cache.vehicle and isHeliHighEnough(cache.vehicle) do
            local currentTime = GetGameTimer()
            
            if IsControlJustPressed(0, toggleHeliCam) then -- Toggle Helicam
                turnOffCam()
            end
            if IsControlJustPressed(0, toggleVision) then
                changeVision()
            end
            local zoomValue = 0
            if lockedOnVehicle then
                if DoesEntityExist(lockedOnVehicle) then
                    PointCamAtEntity(cam, lockedOnVehicle, 0.0, 0.0, 0.0, true)
                    if IsControlJustPressed(0, toggleLockOn) then
                        cam = unlockCam(cam)
                    end
                else
                    vehicleLockState = VEHICLE_LOCK_STATE.dormant
                    SendNUIMessage({
                        type = 'disablescan',
                    })
                    lockedOnVehicle = nil -- Cam will auto unlock when entity doesn't exist anyway
                end
            else
                zoomValue = (1.0 / (FOV_MAX - FOV_MIN)) * (fov - FOV_MIN)
                checkInputRotation(cam, zoomValue)
                
                -- Only check for vehicles periodically instead of every frame
                if currentTime - lastVehicleCheck >= vehicleCheckDelay then
                    vehicleDetected = getVehicleInView(cam)
                    vehicleLockState = DoesEntityExist(vehicleDetected) and VEHICLE_LOCK_STATE.scanning or VEHICLE_LOCK_STATE.dormant
                    lastVehicleCheck = currentTime
                end
            end
            handleZoom(cam)
            hideHudThisFrame()
            PushScaleformMovieFunction(scaleform, 'SET_ALT_FOV_HEADING')
            PushScaleformMovieFunctionParameterFloat(GetEntityCoords(cache.vehicle).z)
            PushScaleformMovieFunctionParameterFloat(zoomValue)
            PushScaleformMovieFunctionParameterFloat(GetCamRot(cam, 2).z)
            PopScaleformMovieFunctionVoid()
            DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)
            Wait(0)
        end
        heliCam = false
        ClearTimecycleModifier()
        fov = (FOV_MAX + FOV_MIN) * 0.5 -- reset to starting zoom level
        RenderScriptCams(false, false, 0, true, false) -- Return to gameplay camera
        SetScaleformMovieAsNoLongerNeeded(scaleform) -- Cleanly release the scaleform
        DestroyCam(cam, false)
        SetNightvision(false)
        SetSeethrough(false)
    end
end

local camera = lib.addKeybind({
    name = config.keybinds.camera.name,
    description = locale('camera_keybind'),
    defaultKey = config.keybinds.camera.defaultKey,
    disabled = config.keybinds.camera.disabled,
    onPressed = function()
        if not isHeliHighEnough(cache.vehicle) then return end

        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
        heliCam = true
        heliCamThread()
        SendNUIMessage({
            type = 'heliopen',
        })
        -- Send config to NUI for throttling
        SendNUIMessage({
            type = 'updateconfig',
            throttle = config.nui.updateThrottle,
        })
    end
})

local spotlight = lib.addKeybind({
    name = config.keybinds.spotlight.name,
    description = locale('spotlight_keybind'),
    defaultKey = config.keybinds.spotlight.defaultKey,
    disabled = config.keybinds.spotlight.disabled,
    onPressed = function()
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)

        local netId = NetworkGetNetworkIdFromEntity(cache.vehicle)

        TriggerServerEvent('qbx_helicam:server:toggleSpotlightState', netId)
    end,
})

local rappel = lib.addKeybind({
    name = config.keybinds.rappel.name,
    description = locale('rappel_keybind'),
    defaultKey = config.keybinds.rappel.defaultKey,
    disabled = config.keybinds.rappel.disabled,
    onPressed = function()
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
        TaskRappelFromHeli(cache.ped, 1)
    end
})

---@diagnostic disable-next-line: param-type-mismatch
AddStateBagChangeHandler(sharedConfig.entityState.spotlightStateName, nil, function(bagName, _, value)
    local entity = GetEntityFromStateBagName(bagName)

    SetVehicleSearchlight(entity, value, false)
end)

lib.onCache('seat', function(seat)
    if not seat then
        camera:disable(true)
        spotlight:disable(true)
        rappel:disable(true)
        return
    end

    local model = GetEntityModel(cache.vehicle)

    if not config.authorizedHelicopters[model] then return end

    if seat == -1 or seat == 0 then
        rappel:disable(true)

        if DoesVehicleHaveSearchlight(cache.vehicle) then
            spotlight:disable(false)
        end

        camera:disable(false)
    elseif seat >= 1 then
        camera:disable(true)
        spotlight:disable(true)

        if DoesVehicleAllowRappel(cache.vehicle) then
            rappel:disable(false)
        end
    end

    -- Remove the nested CreateThread and use a simpler approach
    CreateThread(function()
        while cache.vehicle do
            handleInVehicle()
            Wait(config.performance.vehicleThreadSleep) -- Configurable delay to prevent excessive CPU usage
        end
    end)
end)