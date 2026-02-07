-- Reload Area Script - focuses on safe local streaming refreshes without side effects
local cooldownActive = false
local isReloading = false

local settings = {
    cooldownSeconds = 15,
    reloadDurationMs = 10000,
    focusOffset = 4500.0,
    focusZ = 0.0,
    collisionAttempts = 24,
    collisionDelayMs = 200,
    freezeSafetyTimeoutMs = 15000,
    aggressiveStreamingFlush = true
}

RegisterCommand('reloadarea', function()
    if isReloading then
        lib.notify({
            title = 'Reload Area',
            description = 'A texture refresh is already running.',
            type = 'error'
        })
        return
    end

    if cooldownActive then
        lib.notify({
            title = 'Reload Area',
            description = 'Please wait for cooldown to finish.',
            type = 'error'
        })
        return
    end

    cooldownActive = true
    CreateThread(function()
        reloadAreaTextures()

        Wait(settings.cooldownSeconds * 1000)
        cooldownActive = false
        lib.notify({
            title = 'Reload Area',
            description = 'Cooldown expired. You can reload textures again.',
            type = 'inform'
        })
    end)
end)

RegisterKeyMapping('reloadarea', 'Reload Nearby Textures (Client-Side Keybind)', 'keyboard', '')

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
end

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
