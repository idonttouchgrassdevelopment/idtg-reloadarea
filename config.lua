Config = {
    commands = {
        reloadarea = 'reloadarea',
        surface = 'surface'
    },
    cooldownSeconds = {
        reloadarea = 15,
        surface = 30
    },
    reloadDurationMs = 10000,
    focusOffset = 4500.0,
    focusZ = 0.0,
    collisionAttempts = 24,
    collisionDelayMs = 200,
    freezeSafetyTimeoutMs = 15000,
    aggressiveStreamingFlush = true,
    aggressiveSurfaceFlush = true,
    screenFadeMs = 500,
    surfaceProbeStartOffset = 200.0,
    surfaceProbeStep = 100.0,
    surfaceProbeAttempts = 8,
    surfaceLiftHeight = 1.0,
    surfaceCollisionWaitMs = 3000,
    surfaceTeleportFadeMs = 350,
    optimizeStreamingOnSurface = false,

    -- Keybind entries can clutter the pause-menu legend in servers with many scripts.
    -- Keep this off by default; set to true if you want these commands listed there.
    enableKeyMappings = false,

    -- Shared label used for keybind entries shown in menu/legend.
    -- Keep as a normal string; invalid values safely fall back to 'N/A'.
    keyMappingCategoryLabel = 'N/A',

    -- When true, all keybind entries use only the shared category label text.
    -- This keeps related departments grouped together under one visible category name.
    mergeKeyMappingDescriptions = true
}
