return {
    -- Debug Settings
    debug = false,                              -- Enable debug prints
    
    -- General Settings
    resourceName = 'qbx_helicam',              -- Resource name for consistency
    
    -- Version Information
    version = '1.1.0',                         -- Current version
    
    -- Server Settings
    server = {
        enableVersionCheck = true,              -- Enable automatic version checking
        logSpotlightToggle = false,             -- Log spotlight toggle events
    },
    
    -- Entity State Settings
    entityState = {
        spotlightStateName = 'spotlight',       -- State bag name for spotlight
        syncToAll = true,                       -- Sync state to all clients
    },
}
