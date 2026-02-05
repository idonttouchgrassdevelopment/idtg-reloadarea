-- Reload Area Script - Fixed to avoid teleporting and keep player visible
local cooldownActive = false
local cooldownSeconds = 15
local reloadDuration = 10000

RegisterCommand('reloadarea', function()
    if cooldownActive then
        lib.notify({
            title = 'Reload Area',
            description = 'Please wait for cooldown to finish.',
            type = 'error'
        })
        return
    end

    cooldownActive = true
    reloadAreaTextures()

    CreateThread(function()
        Wait(cooldownSeconds * 1000)
        cooldownActive = false
        lib.notify({
            title = 'Reload Area',
            description = 'Cooldown expired. You can reload textures again.',
            type = 'inform'
        })
    end)
end)

RegisterKeyMapping('reloadarea', 'Reload Nearby Textures (Client-Side Keybind)', 'keyboard', '')

function reloadAreaTextures()
    local ped = PlayerPedId()
    local originalCoords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    optimizeClientTextures()

    -- Move camera focus away instead of teleporting player
    -- This forces the game to unload textures in the area
    local tempFocus = vector3(originalCoords.x + 5000.0, originalCoords.y + 5000.0, 0.0)
    SetFocusArea(tempFocus.x, tempFocus.y, tempFocus.z, 0.0, 0.0, 0.0)
    
    -- Freeze player but keep them visible for other players
    FreezeEntityPosition(ped, true)
    -- Remove SetEntityVisible to keep player visible for other players
    DisplayRadar(false)
    SetDrawOrigin(originalCoords.x, originalCoords.y, originalCoords.z, 0)

    lib.notify({
        title = 'Reload Area',
        description = 'Refreshing textures... Please wait.',
        type = 'inform'
    })

    Wait(reloadDuration)

    -- Restore camera focus to original location
    ClearFocus()
    RequestCollisionAtCoord(originalCoords)
    
    -- Force collision and texture reload
    local interior = GetInteriorAtCoords(originalCoords)
    if interior ~= 0 then RefreshInterior(interior) end

    -- Multiple collision requests to ensure proper loading
    for i = 1, 15 do
        RequestCollisionAtCoord(originalCoords)
        Wait(200)
    end

    -- Wait for collision to load completely
    local attempts = 0
    while not HasCollisionLoadedAroundEntity(ped) and attempts < 30 do
        RequestCollisionAtCoord(originalCoords)
        Wait(250)
        attempts += 1
    end

    -- Clear draw origin and restore player state
    ClearDrawOrigin()
    
    -- Small delay before restoring full functionality
    Wait(500)
    
    -- Restore player state (player was never hidden)
    FreezeEntityPosition(ped, false)
    DisplayRadar(true)
    
    -- Ensure player is at original coordinates (should be, but just in case)
    SetEntityCoordsNoOffset(ped, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false)
    SetEntityHeading(ped, heading)
    Wait(1000)

    lib.notify({
        title = 'Reload Area',
        description = 'Textures refreshed and optimized.',
        type = 'success'
    })

    -- sendWebhookLog(originalCoords)
end

function optimizeClientTextures()
    SetReducePedModelBudget(true)
    SetReduceVehicleModelBudget(true)

    ClearFocus()
    ClearHdArea()
    ClearAllBrokenGlass()
    ClearTimecycleModifier()
    SetTimecycleModifier("neutral")
    SetTimecycleModifierStrength(0.0)

    TriggerEvent("graphics:flush")

    Wait(300)

    SetReducePedModelBudget(false)
    SetReduceVehicleModelBudget(false)
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