local cache = pr_lib.cache

if not LoadResourceFile(cache.resource, 'web/build/index.html') then
    error(
    'Unable to load UI. Build ox_doorlock or download the latest release.\n	^3https://github.com/overextended/ox_doorlock/releases/latest/download/ox_doorlock.zip^0')
end

local function EnsureMovableEntity(door, subDoor)
    local target = subDoor or door
    local entity = target.entity
    
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        return entity
    end
    
    -- Scan local game pool for matching entities
    local targetCoords = target.closed?.coords or target.coords
    if not subDoor then
        targetCoords = door.closed?.coords or door.originalCoords or door.coords
    end
    
    local objects = GetGamePool('CObject')
    local dynamicEntity = nil
    local staticEntity = 0
    
    for i = 1, #objects do
        local obj = objects[i]
        if GetEntityModel(obj) == target.model and #(GetEntityCoords(obj) - targetCoords) < 1.5 then
            if Entity(obj).state.isDynamicDoor and Entity(obj).state.doorId == door.id then
                -- Check if it matches subDoor index if applicable
                if not subDoor or Entity(obj).state.subDoorIndex == subDoor.index then
                    dynamicEntity = obj
                end
            else
                staticEntity = obj
            end
        end
    end
    
    if dynamicEntity then
        target.entity = dynamicEntity
        if staticEntity ~= 0 then
            SetEntityAsMissionEntity(staticEntity, true, true)
            DeleteEntity(staticEntity)
        end
        return dynamicEntity
    else
        -- Request server-side creation
        TriggerServerEvent('ox_doorlock:requestDoorReplacement', door.id)
        
        -- Hide the static door locally immediately while waiting for server spawn
        if staticEntity ~= 0 then
            SetEntityAsMissionEntity(staticEntity, true, true)
            DeleteEntity(staticEntity)
        end
        return nil
    end
end

local function GetEntityLocalVectors(entity)
    local heading = GetEntityHeading(entity)
    local rad = math.rad(heading)
    local cosRad = math.cos(rad)
    local sinRad = math.sin(rad)
    
    local right = vector3(cosRad, sinRad, 0.0)
    local forward = vector3(-sinRad, cosRad, 0.0)
    local up = vector3(0.0, 0.0, 1.0)
    
    return right, forward, up
end

local function GetSlideOffset(entity, direction, distance)
    local right, forward, up = GetEntityLocalVectors(entity)
    if direction == 'up' then
        return up * distance
    elseif direction == 'down' then
        return -up * distance
    elseif direction == 'left' then
        return -right * distance
    elseif direction == 'right' then
        return right * distance
    elseif direction == 'forward' then
        return forward * distance
    elseif direction == 'backward' then
        return -forward * distance
    end
    return vector3(0.0, 0.0, 0.0)
end

local function InterpolateHeading(current, target, step)
    local diff = (target - current + 180) % 360 - 180
    if math.abs(diff) < step then
        return target
    end
    return current + (diff > 0 and step or -step)
end

local function InterpolateCoords(current, target, step)
    local diff = target - current
    local dist = #diff
    if dist < step then
        return target
    end
    return current + (diff / dist) * step
end

local activeAnimations = {}

local function AnimateEntity(animKey, entity, closedCoords, closedHeading, state, doorType, openHeading, openAngle, slideDirection, slideDistance, openSpeed, closeSpeed, closedRotation)
    if activeAnimations[animKey] then
        activeAnimations[animKey] = false
        Wait(50)
    end
    activeAnimations[animKey] = true

    CreateThread(function()
        local attempts = 0
        while not NetworkHasControlOfEntity(entity) and attempts < 10 do
            NetworkRequestControlOfEntity(entity)
            Wait(0)
            attempts = attempts + 1
        end

        FreezeEntityPosition(entity, true)

        local targetHeading = closedHeading
        local targetCoords = closedCoords
        local speed = closeSpeed or 1.0

        if state == 0 then -- Open
            speed = openSpeed or 1.0
            if doorType == 'rotate' then
                targetHeading = openHeading or (closedHeading + (openAngle or 90.0))
            elseif doorType == 'slide' then
                local originalHeading = GetEntityHeading(entity)
                if closedRotation then
                    SetEntityRotation(entity, closedRotation.x, closedRotation.y, closedHeading, 2, true)
                else
                    SetEntityHeading(entity, closedHeading)
                end
                local slideOffset = GetSlideOffset(entity, slideDirection, slideDistance or 2.0)
                SetEntityHeading(entity, originalHeading)
                targetCoords = closedCoords + slideOffset
            end
        end

        local headingStep = speed * 1.5
        local coordsStep = speed * 0.05

        while activeAnimations[animKey] and DoesEntityExist(entity) do
            local currentHeading = GetEntityHeading(entity)
            local currentCoords = GetEntityCoords(entity)

            local nextHeading = currentHeading
            local nextCoords = currentCoords
            local headingDone = true
            local coordsDone = true

            if doorType == 'rotate' then
                nextHeading = InterpolateHeading(currentHeading, targetHeading, headingStep)
                headingDone = (nextHeading == targetHeading)
            elseif doorType == 'slide' then
                headingDone = true
            end

            if doorType == 'slide' then
                nextCoords = InterpolateCoords(currentCoords, targetCoords, coordsStep)
                coordsDone = (#(nextCoords - targetCoords) < 0.01)
            elseif doorType == 'rotate' then
                coordsDone = true
            end

            if not headingDone then
                if closedRotation then
                    SetEntityRotation(entity, closedRotation.x, closedRotation.y, nextHeading, 2, true)
                else
                    SetEntityHeading(entity, nextHeading)
                end
            end
            if not coordsDone then
                SetEntityCoords(entity, nextCoords.x, nextCoords.y, nextCoords.z, false, false, false, false)
            end

            if headingDone and coordsDone then
                break
            end

            Wait(10)
        end

        if activeAnimations[animKey] and DoesEntityExist(entity) then
            if doorType == 'rotate' then
                if closedRotation then
                    SetEntityRotation(entity, closedRotation.x, closedRotation.y, targetHeading, 2, true)
                else
                    SetEntityHeading(entity, targetHeading)
                end
            elseif doorType == 'slide' then
                SetEntityCoords(entity, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false, false)
            end
            FreezeEntityPosition(entity, true)
        end

        activeAnimations[animKey] = nil
    end)
end

local function AnimateDoorToState(door)
    local closedCoords = door.originalCoords or door.coords
    local closedHeading = door.closedHeading or door.heading
    local closedRotation = door.rotation
    local double = door.doors
    if double then
        for i = 1, 2 do
            local subDoor = double[i]
            if subDoor.entity and subDoor.entity ~= 0 then
                local subClosedHeading = subDoor.closedHeading or subDoor.heading
                local subOpenHeading = subDoor.openHeading
                local openAngle = door.openAngle or 90.0
                if i == 2 then
                    openAngle = -openAngle
                end
                local slideDirection = door.slideDirection
                if i == 2 and (slideDirection == 'left' or slideDirection == 'right' or slideDirection == 'forward' or slideDirection == 'backward') then
                    if slideDirection == 'left' then slideDirection = 'right'
                    elseif slideDirection == 'right' then slideDirection = 'left'
                    elseif slideDirection == 'forward' then slideDirection = 'backward'
                    elseif slideDirection == 'backward' then slideDirection = 'forward'
                    end
                end
                local animKey = ('door_%d_%d'):format(door.id, i)
                AnimateEntity(animKey, subDoor.entity, subDoor.coords, subClosedHeading, door.state, door.doorType, subOpenHeading, openAngle, slideDirection, door.slideDistance, door.openSpeed, door.closeSpeed, subDoor.rotation)
            end
        end
    else
        if door.entity and door.entity ~= 0 then
            local animKey = ('door_%d'):format(door.id)
            AnimateEntity(animKey, door.entity, closedCoords, closedHeading, door.state, door.doorType, door.openHeading, door.openAngle, door.slideDirection, door.slideDistance, door.openSpeed, door.closeSpeed, closedRotation)
        end
    end
end

local function SnapEntity(entity, closedCoords, closedHeading, state, doorType, openHeading, openAngle, slideDirection, slideDistance, closedRotation)
    if not entity or entity == 0 then return end
    FreezeEntityPosition(entity, true)
    
    if state == 1 then -- Closed
        if closedRotation then
            SetEntityRotation(entity, closedRotation.x, closedRotation.y, closedRotation.z, 2, true)
        else
            SetEntityHeading(entity, closedHeading)
        end
        SetEntityCoords(entity, closedCoords.x, closedCoords.y, closedCoords.z, false, false, false, false)
    else -- Open
        if doorType == 'rotate' then
            local targetHeading = openHeading or (closedHeading + (openAngle or 90.0))
            if closedRotation then
                SetEntityRotation(entity, closedRotation.x, closedRotation.y, targetHeading, 2, true)
            else
                SetEntityHeading(entity, targetHeading)
            end
            SetEntityCoords(entity, closedCoords.x, closedCoords.y, closedCoords.z, false, false, false, false)
        elseif doorType == 'slide' then
            if closedRotation then
                SetEntityRotation(entity, closedRotation.x, closedRotation.y, closedRotation.z, 2, true)
            else
                SetEntityHeading(entity, closedHeading)
            end
            local slideOffset = GetSlideOffset(entity, slideDirection, slideDistance or 2.0)
            local targetCoords = closedCoords + slideOffset
            SetEntityCoords(entity, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false, false)
        end
    end
end

local function SnapDoorToState(door)
    if door.doorType ~= 'rotate' and door.doorType ~= 'slide' then return end
    local closedCoords = door.originalCoords or door.coords
    local closedHeading = door.closedHeading or door.heading
    local closedRotation = door.rotation
    local double = door.doors
    if double then
        for i = 1, 2 do
            local subDoor = double[i]
            if subDoor.entity and subDoor.entity ~= 0 then
                local subClosedHeading = subDoor.closedHeading or subDoor.heading
                local subOpenHeading = subDoor.openHeading
                local openAngle = door.openAngle or 90.0
                if i == 2 then
                    openAngle = -openAngle
                end
                local slideDirection = door.slideDirection
                if i == 2 and (slideDirection == 'left' or slideDirection == 'right' or slideDirection == 'forward' or slideDirection == 'backward') then
                    if slideDirection == 'left' then slideDirection = 'right'
                    elseif slideDirection == 'right' then slideDirection = 'left'
                    elseif slideDirection == 'forward' then slideDirection = 'backward'
                    elseif slideDirection == 'backward' then slideDirection = 'forward'
                    end
                end
                SnapEntity(subDoor.entity, subDoor.coords, subClosedHeading, door.state, door.doorType, subOpenHeading, openAngle, slideDirection, door.slideDistance, subDoor.rotation)
            end
        end
    else
        if door.entity and door.entity ~= 0 then
            SnapEntity(door.entity, closedCoords, closedHeading, door.state, door.doorType, door.openHeading, door.openAngle, door.slideDirection, door.slideDistance, closedRotation)
        end
    end
end

-- Custom doors store their actual closed and open transformations.  This keeps
-- the creator independent from hard-coded headings, offsets, and directions.
local function getCapturedTransform(target, state)
    local transform = state == 0 and target.open or target.closed
    if transform then return transform end

    return {
        coords = target.coords,
        rotation = target.rotation or vector3(0.0, 0.0, target.heading or 0.0),
    }
end

local function hasCapturedTransforms(door)
    if door.doors then
        return door.doors[1].closed and door.doors[1].open and door.doors[2].closed and door.doors[2].open
    end

    return door.closed and door.open
end

local function interpolateAngle(from, to, progress)
    return from + (((to - from + 180.0) % 360.0) - 180.0) * progress
end

local function interpolateRotation(from, to, progress)
    return vector3(
        interpolateAngle(from.x, to.x, progress),
        interpolateAngle(from.y, to.y, progress),
        interpolateAngle(from.z, to.z, progress)
    )
end

local function interpolateRotateCoords(closed, opened, progress)
    local angle = math.rad(((opened.rotation.z - closed.rotation.z + 180.0) % 360.0) - 180.0)
    local cosine, sine = math.cos(angle), math.sin(angle)
    local a, determinant = 1.0 - cosine, (1.0 - cosine) ^ 2 + sine ^ 2

    if determinant < 0.0001 then
        return closed.coords + (opened.coords - closed.coords) * progress
    end

    -- Solve the hinge from the two captured transformations. This produces an
    -- arc instead of a diagonal slide when a rotate door is configured.
    local rotatedX = cosine * closed.coords.x - sine * closed.coords.y
    local rotatedY = sine * closed.coords.x + cosine * closed.coords.y
    local deltaX, deltaY = opened.coords.x - rotatedX, opened.coords.y - rotatedY
    local hingeX = (a * deltaX - sine * deltaY) / determinant
    local hingeY = (sine * deltaX + a * deltaY) / determinant
    local current = angle * progress
    cosine, sine = math.cos(current), math.sin(current)
    local relativeX, relativeY = closed.coords.x - hingeX, closed.coords.y - hingeY

    return vector3(
        hingeX + cosine * relativeX - sine * relativeY,
        hingeY + sine * relativeX + cosine * relativeY,
        closed.coords.z + (opened.coords.z - closed.coords.z) * progress
    )
end

local function setCapturedTransform(entity, transform)
    SetEntityCoordsNoOffset(entity, transform.coords.x, transform.coords.y, transform.coords.z, false, false, false)
    SetEntityRotation(entity, transform.rotation.x, transform.rotation.y, transform.rotation.z, 2, true)
end

local function animateCapturedEntity(animKey, entity, closed, opened, state, doorType)
    if activeAnimations[animKey] then activeAnimations[animKey] = false end
    activeAnimations[animKey] = true

    CreateThread(function()
        local attempts = 0
        while not NetworkHasControlOfEntity(entity) and attempts < 10 do
            NetworkRequestControlOfEntity(entity)
            attempts = attempts + 1
            Wait(0)
        end

        if not DoesEntityExist(entity) then
            activeAnimations[animKey] = nil
            return
        end

        local from = state == 0 and closed or opened
        local target = state == 0 and opened or closed
        local startedAt, duration = GetGameTimer(), 850
        FreezeEntityPosition(entity, true)

        while activeAnimations[animKey] and DoesEntityExist(entity) do
            local progress = math.min((GetGameTimer() - startedAt) / duration, 1.0)
            local coords = doorType == 'rotate' and interpolateRotateCoords(from, target, progress)
                or from.coords + (target.coords - from.coords) * progress
            setCapturedTransform(entity, { coords = coords, rotation = interpolateRotation(from.rotation, target.rotation, progress) })

            if progress >= 1.0 then break end
            Wait(0)
        end

        if activeAnimations[animKey] and DoesEntityExist(entity) then
            setCapturedTransform(entity, target)
            FreezeEntityPosition(entity, true)
        end

        activeAnimations[animKey] = nil
    end)
end

local function animateCapturedDoor(door)
    if door.doors then
        for i = 1, 2 do
            local target = door.doors[i]
            if target.entity and target.entity ~= 0 then
                animateCapturedEntity(('door_%d_%d'):format(door.id, i), target.entity, getCapturedTransform(target, 1), getCapturedTransform(target, 0), door.state, door.doorType)
            end
        end
    elseif door.entity and door.entity ~= 0 then
        animateCapturedEntity(('door_%d'):format(door.id), door.entity, getCapturedTransform(door, 1), getCapturedTransform(door, 0), door.state, door.doorType)
    end
end

local function snapCapturedDoor(door)
    if door.doorType ~= 'rotate' and door.doorType ~= 'slide' then return end

    if door.doors then
        for i = 1, 2 do
            local target = door.doors[i]
            if target.entity and target.entity ~= 0 then
                setCapturedTransform(target.entity, getCapturedTransform(target, door.state))
                FreezeEntityPosition(target.entity, true)
            end
        end
    elseif door.entity and door.entity ~= 0 then
        setCapturedTransform(door.entity, getCapturedTransform(door, door.state))
        FreezeEntityPosition(door.entity, true)
    end
end

local function createDoor(door)
    local double = door.doors
    door.zone = GetLabelText(GetNameOfZone(door.coords.x, door.coords.y, door.coords.z))

    if not door.originalCoords then
        door.originalCoords = door.coords
    end

    if door.doorType == 'rotate' or door.doorType == 'slide' then
        return
    end

    if double then
        for i = 1, 2 do
            AddDoorToSystem(double[i].hash, double[i].model, double[i].coords.x, double[i].coords.y, double[i].coords.z,
                false, false, false)
            DoorSystemSetDoorState(double[i].hash, 4, false, false)
            DoorSystemSetDoorState(double[i].hash, door.state, false, false)

            if door.doorRate or not door.auto then
                DoorSystemSetAutomaticRate(double[i].hash, door.doorRate or 10.0, false, false)
            end
        end
    else
        AddDoorToSystem(door.hash, door.model, door.coords.x, door.coords.y, door.coords.z, false, false, false)
        DoorSystemSetDoorState(door.hash, 4, false, false)
        DoorSystemSetDoorState(door.hash, door.state, false, false)

        if door.doorRate or not door.auto then
            DoorSystemSetAutomaticRate(door.hash, door.doorRate or 10.0, false, false)
        end
    end
end

local nearbyDoors = {}
local Entity = Entity

pr_lib.callback('ox_doorlock:getDoors', false, function(data)
    doors = data

    for _, door in pairs(data) do
        createDoor(door)
    end

    while true do
        ClearDoorTable(nearbyDoors)
        local coords = GetEntityCoords(cache.ped)

        for _, door in pairs(doors) do
            local double = door.doors
            door.distance = #(coords - door.coords)

            if double then
                if door.distance < 80 then
                    for i = 1, 2 do
                        if door.doorType == 'rotate' or door.doorType == 'slide' then
                            double[i].index = i
                            local ent = EnsureMovableEntity(door, double[i])
                            if ent and not double[i].snapped then
                                if hasCapturedTransforms(door) then snapCapturedDoor(door) else SnapDoorToState(door) end
                                double[i].snapped = true
                            end
                        else
                            if not double[i].entity and IsModelValid(double[i].model) then
                                local entity = GetClosestObjectOfType(double[i].coords.x, double[i].coords.y,
                                    double[i].coords.z, 1.0, double[i].model, false, false, false)

                                if entity ~= 0 then
                                    double[i].entity = entity
                                    Entity(entity).state.doorId = door.id
                                end
                            end
                        end
                    end

                    if door.distance < 20 then
                        nearbyDoors[#nearbyDoors + 1] = door
                    end
                else
                    for i = 1, 2 do
                        double[i].entity = nil
                        double[i].snapped = nil
                    end
                end
            elseif door.distance < 80 then
                if door.doorType == 'rotate' or door.doorType == 'slide' then
                    local ent = EnsureMovableEntity(door)
                    if ent and not door.snapped then
                        if hasCapturedTransforms(door) then snapCapturedDoor(door) else SnapDoorToState(door) end
                        door.snapped = true
                    end
                else
                    if not door.entity and IsModelValid(door.model) then
                        local entity = GetClosestObjectOfType(door.coords.x, door.coords.y, door.coords.z, 1.0, door.model,
                            false, false, false)

                        if entity ~= 0 then
                            local min, max = GetModelDimensions(door.model)
                            local points = {
                                GetOffsetFromEntityInWorldCoords(entity, min.x, min.y, min.z).xy,
                                GetOffsetFromEntityInWorldCoords(entity, min.x, min.y, max.z).xy,
                                GetOffsetFromEntityInWorldCoords(entity, min.x, max.y, max.z).xy,
                                GetOffsetFromEntityInWorldCoords(entity, min.x, max.y, min.z).xy,
                                GetOffsetFromEntityInWorldCoords(entity, max.x, min.y, min.z).xy,
                                GetOffsetFromEntityInWorldCoords(entity, max.x, min.y, max.z).xy,
                                GetOffsetFromEntityInWorldCoords(entity, max.x, max.y, max.z).xy,
                                GetOffsetFromEntityInWorldCoords(entity, max.x, max.y, min.z).xy
                            }

                            local centroid = vec2(0, 0)

                            for i = 1, 8 do
                                centroid = centroid + points[i]
                            end

                            centroid = centroid / 8
                            if not door.originalCoords then
                                door.originalCoords = door.coords
                            end
                            door.coords = vec3(centroid.x, centroid.y, door.coords.z)
                            door.entity = entity
                            Entity(entity).state.doorId = door.id
                        end
                    end
                end
                if door.distance < 20 then
                    nearbyDoors[#nearbyDoors + 1] = door
                end
            elseif door.entity then
                door.entity = nil
                door.snapped = nil
            end
        end

        Wait(500)
    end
end)

RegisterNetEvent('ox_doorlock:setState', function(id, state, source, data)
    if not doors then return end

    if data then
        doors[id] = data
        createDoor(data)

        if NuiHasLoaded then
            SendNuiMessage(json.encode({
                action = 'updateDoorData',
                data = data
            }))
        end
    end

    if Config.Notify and source == cache.serverId then
        if state == 0 then
            pr_lib.notify.Notify({
                type = 'success',
                icon = 'unlock',
                description = locale('unlocked_door')
            })
        else
            pr_lib.notify.Notify({
                type = 'success',
                icon = 'lock',
                description = locale('locked_door')
            })
        end
    end

    local door = data or doors[id]
    local double = door.doors
    door.state = state

    if door.doorType == 'rotate' or door.doorType == 'slide' then
        if hasCapturedTransforms(door) then animateCapturedDoor(door) else AnimateDoorToState(door) end
    else
        if double then
            DoorSystemSetDoorState(double[1].hash, door.state, false, false)
            DoorSystemSetDoorState(double[2].hash, door.state, false, false)

            if door.holdOpen then
                DoorSystemSetHoldOpen(double[1].hash, door.state == 0)
                DoorSystemSetHoldOpen(double[2].hash, door.state == 0)
            end

            while door.state == 1 and (not IsDoorClosed(double[1].hash) or not IsDoorClosed(double[2].hash)) do Wait(0) end
        else
            DoorSystemSetDoorState(door.hash, door.state, false, false)

            if door.holdOpen then DoorSystemSetHoldOpen(door.hash, door.state == 0) end
            while door.state == 1 and not IsDoorClosed(door.hash) do Wait(0) end
        end
    end

    if door.state == state and door.distance and door.distance < 20 then
        if Config.NativeAudio then
            RequestScriptAudioBank('dlc_oxdoorlock/oxdoorlock', false)
            local sound = state == 0 and door.unlockSound or door.lockSound or 'door_bolt'
            local soundId = GetSoundId()

            PlaySoundFromCoord(soundId, sound, door.coords.x, door.coords.y, door.coords.z, 'DLC_OXDOORLOCK_SET', false,
                0, false)
            ReleaseSoundId(soundId)
            ReleaseNamedScriptAudioBank('dlc_oxdoorlock/oxdoorlock')
        else
            local volume = (0.01 * GetProfileSetting(300)) / (door.distance / 2)
            if volume > 1 then volume = 1 end
            local sound = state == 0 and door.unlockSound or door.lockSound or 'door_bolt'

            SendNUIMessage({
                action = 'playSound',
                data = {
                    sound = sound,
                    volume = volume
                }
            })
        end
    end
end)

RegisterNetEvent('ox_doorlock:editDoorlock', function(id, data)
    if source == '' then return end

    local door = doors[id]

    if door then
        local double = door.doors
        if double then
            for i = 1, 2 do
                RemoveDoorFromSystem(double[i].hash)
                if double[i].entity then
                    Entity(double[i].entity).state.doorId = nil
                end
            end
        else
            RemoveDoorFromSystem(door.hash)
            if door.entity then
                Entity(door.entity).state.doorId = nil
            end
        end
    end

    if data then
        data.zone = (door and door.zone) or GetLabelText(GetNameOfZone(data.coords.x, data.coords.y, data.coords.z))

        if door then
            if door.distance < 20 then data.distance = 80 end
            data.entity = door.entity
            data.originalCoords = door.originalCoords
            if door.doors and data.doors then
                for i = 1, 2 do
                    data.doors[i].entity = door.doors[i].entity
                end
            end
        end

        doors[id] = data
        createDoor(data)
        if hasCapturedTransforms(data) then snapCapturedDoor(data) else SnapDoorToState(data) end
    else
        doors[id] = nil
        if ClosestDoor?.id == id then
            ClosestDoor = nil
        end
    end

    if NuiHasLoaded then
        SendNuiMessage(json.encode({
            action = 'updateDoorData',
            data = data or id
        }))
    end
end)

ClosestDoor = nil

pr_lib.callback.register('ox_doorlock:inputPassCode', function()
    return ClosestDoor?.passcode and pr_lib.inputDialog(locale('door_lock'), {
        {
            type = 'input',
            label = locale('passcode'),
            password = true,
            icon = 'lock'
        },
    })?[1]
end)

local lastTriggered = 0

local function useClosestDoor()
    if not ClosestDoor then return false end

    local gameTimer = GetGameTimer()

    if gameTimer - lastTriggered > 500 then
        lastTriggered = gameTimer
        TriggerServerEvent('ox_doorlock:setState', ClosestDoor.id, ClosestDoor.state == 1 and 0 or 1)
    end
end

CreateThread(function()
    local lockDoor = locale('lock_door')
    local unlockDoor = locale('unlock_door')
    local showUI
    local drawSprite = Config.DrawSprite

    if drawSprite then
        local sprite1 = drawSprite[0]?[1]
        local sprite2 = drawSprite[1]?[1]

        if sprite1 then
            RequestStreamedTextureDict(sprite1, true)
        end

        if sprite2 then
            RequestStreamedTextureDict(sprite2, true)
        end
    end

    local SetDrawOrigin = SetDrawOrigin
    local ClearDrawOrigin = ClearDrawOrigin
    local DrawSprite = drawSprite and DrawSprite

    while true do
        local num = #nearbyDoors

        if num > 0 then
            local ratio = drawSprite and GetAspectRatio(true)
            for i = 1, num do
                local door = nearbyDoors[i]

                if door.distance < door.maxDistance then
                    if door.distance < (ClosestDoor?.distance or 10) then
                        ClosestDoor = door
                    end

                    if drawSprite and not door.hideUi then
                        local sprite = drawSprite[door.state]

                        if sprite then
                            SetDrawOrigin(door.coords.x, door.coords.y, door.coords.z)
                            DrawSprite(sprite[1], sprite[2], sprite[3], sprite[4], sprite[5], sprite[6] * ratio,
                                sprite[7], sprite[8], sprite[9], sprite[10], sprite[11])
                            ClearDrawOrigin()
                        end
                    end
                end
            end
        else
            ClosestDoor = nil
        end

        if ClosestDoor and ClosestDoor.distance < ClosestDoor.maxDistance then
            if Config.DrawTextUI and not ClosestDoor.hideUi and ClosestDoor.state ~= showUI then
                pr_lib.showTextUI(ClosestDoor.state == 0 and lockDoor or unlockDoor)
                showUI = ClosestDoor.state
            end

            if not PickingLock and IsDisabledControlJustReleased(0, 38) then
                useClosestDoor()
            end
        elseif showUI then
            pr_lib.hideTextUI()
            showUI = nil
        end

        Wait(num > 0 and 0 or 500)
    end
end)

exports('useClosestDoor', useClosestDoor)
exports('getClosestDoor', function() return ClosestDoor end)
