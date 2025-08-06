return {
    -- Vehicle Authorization
    authorizedHelicopters = {
        [`polmav`] = true,
        [`maverick`] = true,
        [`buzzard`] = true,
        [`buzzard2`] = true,
    },

    -- Camera Settings
    camera = {
        fovMax = 80.0,                          -- Maximum field of view
        fovMin = 10.0,                          -- Minimum field of view (max zoom level)
        zoomSpeed = 2.0,                        -- Camera zoom speed
        leftRightSpeed = 3.0,                   -- Speed by which the camera pans left-right
        upDownSpeed = 3.0,                      -- Speed by which the camera pans up-down
        smoothingFactor = 0.05,                 -- FOV smoothing factor (lower = smoother)
        raycastDistance = 400.0,                -- Distance for vehicle detection raycast
        attachOffset = {x = 0.0, y = 0.0, z = -1.5}, -- Camera attachment offset from vehicle
        rotationLimits = {
            maxX = 20.0,                        -- Maximum camera rotation X
            minX = -89.5,                       -- Minimum camera rotation X
        },
    },

    -- Control IDs (GTA V Controls)
    controls = {
        toggleCamera = 51,                      -- Toggle helicopter camera (Default: E)
        toggleVision = 25,                      -- Toggle vision mode (Default: Right mouse)
        toggleLockOn = 22,                      -- Lock onto vehicle (Default: Space)
        scrollUp = 241,                         -- Zoom in (Mouse wheel up)
        scrollDown = 242,                       -- Zoom out (Mouse wheel down)
        rightAxisX = 220,                       -- Right stick X axis
        rightAxisY = 221,                       -- Right stick Y axis
    },

    -- Keybind Settings
    keybinds = {
        camera = {
            name = 'camera',
            defaultKey = 'E',
            disabled = true,
        },
        spotlight = {
            name = 'spotlight',
            defaultKey = 'H',
            disabled = true,
        },
        rappel = {
            name = 'rappel',
            defaultKey = 'X',
            disabled = true,
        },
    },

    -- Performance Settings
    performance = {
        vehicleCheckDelay = 250,                -- Delay between vehicle detection checks (ms)
        scanUpdateDelay = 50,                   -- Delay between scan progress updates (ms)
        vehicleInfoUpdateDelay = 250,           -- Delay between vehicle info updates (ms)
        scanIncrementStep = 2,                  -- Scan progress increment per update
        speedUpdateThreshold = 2,               -- Speed difference threshold for updates (km/h)
        minimumThreadSleep = 100,               -- Minimum sleep time for threads (ms)
        scanSleepActive = 50,                   -- Sleep time during active scanning (ms)
        scanSleepLocked = 250,                  -- Sleep time when locked on vehicle (ms)
        scanSleepIdle = 500,                    -- Sleep time when idle (ms)
        vehicleThreadSleep = 100,               -- Sleep time for vehicle thread (ms)
    },

    -- Height Requirements
    heightRequirement = {
        minimum = 1.5,                          -- Minimum height above ground to use camera
    },

    -- HUD Components to Hide
    hiddenHudComponents = {1, 2, 3, 4, 13, 11, 12, 15, 18, 19},

    -- Vision Settings
    vision = {
        nightvisionModifier = 'heliGunCam',     -- Timecycle modifier for night vision
        nightvisionStrength = 0.3,              -- Strength of the night vision effect
    },

    -- Scaleform Settings
    scaleform = {
        movieName = 'HELI_CAM',                 -- Scaleform movie name
        logoType = 0,                           -- 0 for nothing, 1 for LSPD logo
    },

    -- NUI Throttling (Client-side)
    nui = {
        updateThrottle = 50,                    -- Minimum time between NUI updates (ms)
    },
}