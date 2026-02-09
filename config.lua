Config = {
    commands = {
        reloadArea = 'reloadarea',
        surfaceRescue = 'surface',
        safeTeleport = 'teleport'
    },
    keyMappings = {
        reloadArea = {
            description = 'Reload Nearby Textures (Client-Side Keybind)',
            defaultMapper = 'keyboard',
            defaultKey = ''
        },
        surfaceRescue = {
            description = 'Teleport to nearest surface if you fell through the map',
            defaultMapper = 'keyboard',
            defaultKey = ''
        },
        safeTeleport = {
            description = 'Teleport to a configured safe area if you are under the map',
            defaultMapper = 'keyboard',
            defaultKey = ''
        }
    },
    safeReturn = {
        enabled = true,
        cooldownSeconds = 30,
        coords = {
            x = 0.0,
            y = 0.0,
            z = 72.0
        },
        heading = 0.0
    }
}
