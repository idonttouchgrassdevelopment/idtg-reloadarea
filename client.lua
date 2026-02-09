-- Reload Area Script - focuses on safe local streaming refreshes without side effects
local isReloading = false
local cooldowns = {}

local settings = {
    commands = {
        reloadarea = 'reloadarea',
        surface = 'surface',
        teleport = 'teleport'
    },
    cooldownSeconds = {
        reloadarea = 15,
        surface = 5,
        teleport = 20
    },
    reloadDurationMs = 10000,
    focusOffset = 4500.0,
    focusZ = 0.0,
    collisionAttempts = 24,
    collisionDelayMs = 200,
    freezeSafetyTimeoutMs = 15000,
    aggressiveStreamingFlush = true,
    screenFadeMs = 500,
    surfaceProbeStartOffset = 200.0,
    surfaceProbeStep = 100.0,
    surfaceProbeAttempts = 8,
    safeReturn = {
        enabled = false,
        coords = vector3(0.0, 0.0, 72.0),
        heading = 0.0
    }
}

local function getCommandName(commandKey)
    return settings.commands[commandKey] or commandKey
end

local function getCooldownMs(commandKey)
    local seconds = settings.cooldownSeconds[commandKey] or 0
    return math.max(0, seconds) * 1000
end

local function isOnCooldown(commandKey)
    local now = GetGameTimer()
    local expiresAt = cooldowns[commandKey]

    if not expiresAt or expiresAt <= now then
        cooldowns[commandKey] = nil
        return false, 0
    end

    local secondsLeft = math.ceil((expiresAt - now) / 1000)
    return true, secondsLeft
end

local function startCooldown(commandKey)
    local cooldownMs = getCooldownMs(commandKey)
    if cooldownMs <= 0 then
        return
    end

    cooldowns[commandKey] = GetGameTimer() + cooldownMs
end

local function setBlackScreen(enabled)
    if enabled then
        if not IsScreenFadingOut() and not IsScreenFadedOut() then
            DoScreenFadeOut(settings.screenFadeMs)
        end

        local timeoutAt = GetGameTimer() + settings.screenFadeMs + 1000
        while not IsScreenFadedOut() and GetGameTimer() < timeoutAt do
            Wait(0)
        end
        return
    end

    if IsScreenFadedOut() or IsScreenFadingOut() then
        DoScreenFadeIn(settings.screenFadeMs)
    end
end

RegisterCommand(getCommandName('reloadarea'), function()
    if isReloading then
        lib.notify({
            title = 'Reload Area',
            description = 'A texture refresh is already running.',
            type = 'error'
        })
        return
    end

    local onCooldown, secondsLeft = isOnCooldown('reloadarea')
    if onCooldown then
        lib.notify({
            title = 'Reload Area',
            description = ('Please wait %ss before using this again.'):format(secondsLeft),
            type = 'error'
        })
        return
    end

    startCooldown('reloadarea')
    CreateThread(function()
        reloadAreaTextures()
    end)
end)

RegisterKeyMapping(getCommandName('reloadarea'), 'Reload Nearby Textures (Client-Side Keybind)', 'keyboard', '')

local function restorePlayerState(state)
    if not state then return end

    local ped = PlayerPedId()

    ClearFocus()
    ClearHdArea()

    if state.wasFrozen then
        FreezeEntityPosition(ped, true)
    else
        FreezeEntityPosition(ped, false)
    end

    if state.radarVisible then
        DisplayRadar(true)
    else
        DisplayRadar(false)
    end

    if state.coords and state.heading then
        SetEntityCoordsNoOffset(ped, state.coords.x, state.coords.y, state.coords.z, false, false, false)
        SetEntityHeading(ped, state.heading)
    end

    setBlackScreen(false)
end

local function findGroundZ(coords)
    for i = 1, settings.surfaceProbeAttempts do
        local probeZ = coords.z + settings.surfaceProbeStartOffset + ((i - 1) * settings.surfaceProbeStep)
        local foundGround, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, probeZ, false)

        if foundGround then
            return groundZ
        end
    end

    return nil
end

RegisterCommand(getCommandName('surface'), function()
    local ped = PlayerPedId()
    if ped == 0 then
        return
    end

    local onCooldown, secondsLeft = isOnCooldown('surface')
    if onCooldown then
        lib.notify({
            title = 'Surface Rescue',
            description = ('Please wait %ss before using this again.'):format(secondsLeft),
            type = 'error'
        })
        return
    end

    local coords = GetEntityCoords(ped)
    local groundZ = findGroundZ(coords)

    if not groundZ then
        lib.notify({
            title = 'Surface Rescue',
            description = 'Could not find safe ground. Try again in a different spot.',
            type = 'error'
        })
        return
    end

    RequestCollisionAtCoord(coords.x, coords.y, groundZ)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, groundZ + 1.0, false, false, false)
    startCooldown('surface')

    lib.notify({
        title = 'Surface Rescue',
        description = 'Moved you back to the nearest surface level.',
        type = 'success'
    })
end)

RegisterKeyMapping(getCommandName('surface'), 'Teleport to nearest surface if you fell through the map', 'keyboard', '')

RegisterCommand(getCommandName('teleport'), function()
    local ped = PlayerPedId()
    if ped == 0 then
        return
    end

    local onCooldown, secondsLeft = isOnCooldown('teleport')
    if onCooldown then
        lib.notify({
            title = 'Safe Zone Teleport',
            description = ('Please wait %ss before using this again.'):format(secondsLeft),
            type = 'error'
        })
        return
    end

    local destination = settings.safeReturn.coords
    local destinationHeading = settings.safeReturn.heading

    if settings.safeReturn.enabled then
        RequestCollisionAtCoord(destination.x, destination.y, destination.z)
        SetEntityCoordsNoOffset(ped, destination.x, destination.y, destination.z, false, false, false)
        SetEntityHeading(ped, destinationHeading)
        startCooldown('teleport')

        lib.notify({
            title = 'Safe Zone Teleport',
            description = 'Teleported you back to the configured safe area.',
            type = 'success'
        })
        return
    end

    local coords = GetEntityCoords(ped)
    local groundZ = findGroundZ(coords)

    if not groundZ then
        lib.notify({
            title = 'Safe Zone Teleport',
            description = 'No safe area configured and no surface found nearby.',
            type = 'error'
        })
        return
    end

    RequestCollisionAtCoord(coords.x, coords.y, groundZ)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, groundZ + 1.0, false, false, false)
    startCooldown('teleport')

    lib.notify({
        title = 'Safe Zone Teleport',
        description = 'No safe area configured, moved you to the nearest surface instead.',
        type = 'inform'
    })
end)

RegisterKeyMapping(getCommandName('teleport'), 'Teleport to a configured safe area if you are under the map', 'keyboard', '')

local function optimizeClientStreaming(originalCoords)
    local pedBudgetReduced = false
    local vehicleBudgetReduced = false

    SetReducePedModelBudget(true)
    pedBudgetReduced = true

    SetReduceVehicleModelBudget(true)
    vehicleBudgetReduced = true

    -- Flush local world state that commonly causes texture persistence.
    ClearAllBrokenGlass()
    ClearHdArea()

    if settings.aggressiveStreamingFlush then
        ClearTimecycleModifier()
        SetTimecycleModifier("neutral")
        SetTimecycleModifierStrength(0.0)
        TriggerEvent("graphics:flush")
    end

    -- Refresh interior textures around the player only.
    local interior = GetInteriorAtCoords(originalCoords.x, originalCoords.y, originalCoords.z)
    if interior ~= 0 then
        PinInteriorInMemory(interior)
        RefreshInterior(interior)
    end

    Wait(250)

    if interior ~= 0 then
        UnpinInterior(interior)
    end

    if pedBudgetReduced then
        SetReducePedModelBudget(false)
    end

    if vehicleBudgetReduced then
        SetReduceVehicleModelBudget(false)
    end
end

function reloadAreaTextures()
    if isReloading then
        return
    end

    isReloading = true

    local ped = PlayerPedId()
    if ped == 0 then
        isReloading = false
        return
    end

    local originalCoords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    local state = {
        wasFrozen = IsEntityPositionFrozen(ped),
        radarVisible = IsRadarEnabled(),
        coords = originalCoords,
        heading = heading
    }

    FreezeEntityPosition(ped, true)
    DisplayRadar(false)
    SetDrawOrigin(originalCoords.x, originalCoords.y, originalCoords.z, 0)
    setBlackScreen(true)

    CreateThread(function()
        Wait(settings.freezeSafetyTimeoutMs)
        if isReloading then
            restorePlayerState(state)
            isReloading = false

            lib.notify({
                title = 'Reload Area',
                description = 'Safety restore triggered. You can try again.',
                type = 'error'
            })
        end
    end)

    lib.notify({
        title = 'Reload Area',
        description = 'Refreshing textures... Please wait.',
        type = 'inform'
    })

    optimizeClientStreaming(originalCoords)

    -- Move focus far enough to force local stream eviction without moving the player entity.
    local tempFocus = vector3(
        originalCoords.x + settings.focusOffset,
        originalCoords.y + settings.focusOffset,
        settings.focusZ
    )

    SetFocusArea(tempFocus.x, tempFocus.y, tempFocus.z, 0.0, 0.0, 0.0)
    Wait(settings.reloadDurationMs)

    ClearFocus()
    ClearHdArea()
    ClearDrawOrigin()

    RequestCollisionAtCoord(originalCoords.x, originalCoords.y, originalCoords.z)

    for i = 1, settings.collisionAttempts do
        RequestCollisionAtCoord(originalCoords.x, originalCoords.y, originalCoords.z)

        if HasCollisionLoadedAroundEntity(ped) then
            break
        end

        Wait(settings.collisionDelayMs)
    end

    restorePlayerState(state)

    isReloading = false

    lib.notify({
        title = 'Reload Area',
        description = 'Textures refreshed and local streaming cleaned up.',
        type = 'success'
    })
end

function sendWebhookLog(coords)
    local webhookUrl = "https://yourwebhookurl.com" -- Replace with actual webhook URL
    local name = GetPlayerName(PlayerId())
    local serverId = GetPlayerServerId(PlayerId())

    local data = {
        username = "ReloadArea Logger",
        embeds = {{
            title = "Texture Reload Triggered",
            color = 65280,
            fields = {
                { name = "Player", value = name .. " [" .. serverId .. "]", inline = true },
                { name = "Position", value = ("X: %.2f, Y: %.2f, Z: %.2f"):format(coords.x, coords.y, coords.z), inline = false },
                { name = "Time", value = os.date("%Y-%m-%d %H:%M:%S"), inline = true }
            },
            footer = { text = "Texture Reload Log" }
        }}
    }

    PerformHttpRequest(webhookUrl, function() end, "POST", json.encode(data), {
        ["Content-Type"] = "application/json"
    })
end
