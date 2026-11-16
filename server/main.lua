local cache = pr_lib.cache
local Database = pr_lib.database

if not LoadResourceFile(cache.resource, 'web/build/index.html') then
    error(
        'Unable to load UI. Build ox_doorlock or download the latest release.\n	^3https://github.com/overextended/ox_doorlock/releases/latest/download/ox_doorlock.zip^0')
end

pr_lib.load('server.convert')

local utils = pr_lib.load('server.utils')
local TriggerEventHooks = pr_lib.load('server.hooks')
local doors = {}

local function encodeData(door)
    local double = door.doors

    return json.encode({
        auto = door.auto,
        autolock = door.autolock,
        coords = door.coords,
        doors = double and {
            {
                coords = double[1].coords,
                heading = double[1].heading,
                model = double[1].model,
                rotation = double[1].rotation,
                closed = double[1].closed,
                open = double[1].open,
            },
            {
                coords = double[2].coords,
                heading = double[2].heading,
                model = double[2].model,
                rotation = double[2].rotation,
                closed = double[2].closed,
                open = double[2].open,
            },
        },
        characters = door.characters,
        groups = door.groups,
        heading = door.heading,
        items = door.items,
        lockpick = door.lockpick,
        hideUi = door.hideUi,
        holdOpen = door.holdOpen,
        lockSound = door.lockSound,
        maxDistance = door.maxDistance,
        doorRate = door.doorRate,
        model = door.model,
        rotation = door.rotation,
        state = door.state,
        unlockSound = door.unlockSound,
        passcode = door.passcode,
        lockpickDifficulty = door.lockpickDifficulty,
        doorGroup = door.doorGroup,
        doorType = door.doorType,
        doorOpened = door.doorOpened,
        closed = door.closed,
        open = door.open,
        -- Keep old custom settings while existing doors are gradually migrated
        -- through the new visual creator.
        openSpeed = door.openSpeed,
        closeSpeed = door.closeSpeed,
        openAngle = door.openAngle,
        slideDirection = door.slideDirection,
        slideDistance = door.slideDistance,
        closedHeading = door.closedHeading,
        openHeading = door.openHeading,
    })
end

local function getDoor(door)
    door = type(door) == 'table' and door or doors[door]
    if not door then return false end
    return {
        id = door.id,
        name = door.name,
        state = door.state,
        coords = door.coords,
        characters = door.characters,
        groups = door.groups,
        items = door.items,
        maxDistance = door.maxDistance,
    }
end

exports('getDoor', getDoor)

exports('getAllDoors', function()
    local allDoors = {}

    for _, door in pairs(doors) do
        allDoors[#allDoors + 1] = getDoor(door)
    end

    return allDoors
end)

exports('getDoorFromName', function(name)
    for _, door in pairs(doors) do
        if door.name == name then
            return getDoor(door)
        end
    end
end)

exports('editDoor', function(id, data)
    local door = doors[id]

    if door then
        for k, v in pairs(data) do
            if k ~= 'id' then
                local current = door[k]
                local t1 = type(current)
                local t2 = type(v)

                if t1 ~= 'nil' and v ~= '' and t1 ~= t2 then
                    error(("Expected '%s' for door.%s, received %s (%s)"):format(t1, k, t2, v))
                end

                door[k] = v ~= '' and v or nil
            end
        end

        Database.update('UPDATE ox_doorlock SET name = ?, data = ? WHERE id = ?', { door.name, encodeData(door), id })
        TriggerClientEvent('ox_doorlock:editDoorlock', -1, id, door)
    end
end)

local soundDirectory = Config.NativeAudio and 'audio/dlc_oxdoorlock/oxdoorlock' or 'web/build/sounds'
local fileFormat = '%.wav'
local sounds = utils.getFilesInDirectory(soundDirectory, fileFormat)

pr_lib.callback.register('ox_doorlock:getSounds', function()
    return sounds
end)

local spawnedDynamicDoors = {}

RegisterNetEvent('ox_doorlock:requestDoorReplacement', function(doorId)
    local src = source
    local door = doors[doorId]
    if not door then return end
    
    -- If we already spawned a dynamic door for this doorId, check if it still exists
    if spawnedDynamicDoors[doorId] then
        local entityOrTable = spawnedDynamicDoors[doorId]
        if type(entityOrTable) == 'table' then
            local allExist = true
            for i = 1, 2 do
                if not DoesEntityExist(entityOrTable[i]) then
                    allExist = false
                end
            end
            if allExist then
                return
            end
        else
            if DoesEntityExist(entityOrTable) then
                return
            end
        end
    end
    
    -- Spawn the object on the server
    local double = door.doors
    if double then
        local newEntities = {}
        for i = 1, 2 do
            local subDoor = double[i]
            local closed = subDoor.closed
            local coords = closed?.coords or subDoor.coords
            local heading = closed?.rotation?.z or subDoor.heading
            local obj = CreateObjectNoOffset(subDoor.model, coords.x, coords.y, coords.z, true, true, false)
            local attempts = 0
            while not DoesEntityExist(obj) and attempts < 100 do
                Wait(10)
                attempts = attempts + 1
            end
            if DoesEntityExist(obj) then
                if closed?.rotation then
                    SetEntityRotation(obj, closed.rotation.x, closed.rotation.y, closed.rotation.z, 2, true)
                elseif subDoor.rotation then
                    SetEntityRotation(obj, subDoor.rotation.x, subDoor.rotation.y, subDoor.rotation.z, 2, true)
                else
                    SetEntityHeading(obj, heading)
                end
                FreezeEntityPosition(obj, true)
                Entity(obj).state.doorId = doorId
                Entity(obj).state.subDoorIndex = i
                Entity(obj).state.isDynamicDoor = true
                newEntities[i] = obj
            end
        end
        spawnedDynamicDoors[doorId] = newEntities
    else
        local closed = door.closed
        local coords = closed?.coords or door.originalCoords or door.coords
        local heading = closed?.rotation?.z or door.heading
        local obj = CreateObjectNoOffset(door.model, coords.x, coords.y, coords.z, true, true, false)
        local attempts = 0
        while not DoesEntityExist(obj) and attempts < 100 do
            Wait(10)
            attempts = attempts + 1
        end
        if DoesEntityExist(obj) then
            if closed?.rotation then
                SetEntityRotation(obj, closed.rotation.x, closed.rotation.y, closed.rotation.z, 2, true)
            elseif door.rotation then
                SetEntityRotation(obj, door.rotation.x, door.rotation.y, door.rotation.z, 2, true)
            else
                SetEntityHeading(obj, heading)
            end
            FreezeEntityPosition(obj, true)
            Entity(obj).state.doorId = doorId
            Entity(obj).state.isDynamicDoor = true
            spawnedDynamicDoors[doorId] = obj
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for _, entityOrTable in pairs(spawnedDynamicDoors) do
        if type(entityOrTable) == 'table' then
            for _, ent in pairs(entityOrTable) do
                if DoesEntityExist(ent) then
                    DeleteEntity(ent)
                end
            end
        else
            if DoesEntityExist(entityOrTable) then
                DeleteEntity(entityOrTable)
            end
        end
    end
end)



local function normalizeDoorGroup(value)
    if type(value) ~= 'string' then return nil end

    value = value:match('^%s*(.-)%s*$'):gsub('%s+', ' ')
    if value == '' then return nil end

    local normalized = value:lower()

    for _, existingDoor in pairs(doors) do
        local existingGroup = existingDoor.doorGroup

        if type(existingGroup) == 'string' then
            existingGroup = existingGroup:match('^%s*(.-)%s*$'):gsub('%s+', ' ')
            if existingGroup:lower() == normalized then return existingGroup end
        end
    end

    return value
end

local function createDoor(id, door, name)
    local double = door.doors
    door.id = id
    door.name = name
    door.doorGroup = normalizeDoorGroup(door.doorGroup)

    if double then
        for i = 1, 2 do
            double[i].hash = joaat(('ox_door_%s_%s'):format(id, i))

            local coords = double[i].coords
            double[i].coords = vector3(coords.x, coords.y, coords.z)
            if double[i].rotation then
                local rot = double[i].rotation
                double[i].rotation = vector3(rot.x, rot.y, rot.z)
            end

            for _, state in ipairs({ 'closed', 'open' }) do
                local transform = double[i][state]
                if transform then
                    local coords = transform.coords
                    local rotation = transform.rotation
                    transform.coords = vector3(coords.x, coords.y, coords.z)
                    transform.rotation = vector3(rotation.x, rotation.y, rotation.z)
                end
            end
        end

        if not door.coords then
            door.coords = double[1].coords - ((double[1].coords - double[2].coords) / 2)
        end
    else
        door.hash = joaat(('ox_door_%s'):format(id))
    end

    door.coords = vector3(door.coords.x, door.coords.y, door.coords.z)
    if door.rotation then
        local rot = door.rotation
        door.rotation = vector3(rot.x, rot.y, rot.z)
    end

    for _, state in ipairs({ 'closed', 'open' }) do
        local transform = door[state]
        if transform then
            local coords = transform.coords
            local rotation = transform.rotation
            transform.coords = vector3(coords.x, coords.y, coords.z)
            transform.rotation = vector3(rotation.x, rotation.y, rotation.z)
        end
    end

    if not door.state then
        door.state = 1
    end

    if type(door.items?[1]) == 'string' then
        local items = {}

        for i = 1, #door.items do
            items[i] = {
                name = door.items[i],
                remove = false,
            }
        end

        door.items = items
        Database.update('UPDATE ox_doorlock SET data = ? WHERE id = ?', { encodeData(door), id })
    end

    doors[id] = door
    return door
end

exports('createDoor', function(data)
    if type(data) ~= 'table' then
        error('Expected table for door data')
    end

    if not data.coords then
        local double = data.doors

        if double then
            data.coords = double[1].coords - ((double[1].coords - double[2].coords) / 2)
        else
            error('Door data requires coords or doors')
        end
    end

    if not data.name then
        data.name = tostring(data.coords)
    end

    data.doorGroup = normalizeDoorGroup(data.doorGroup)

    local insertId = Database.insert('INSERT INTO ox_doorlock (name, data) VALUES (?, ?)',
        { data.name, encodeData(data) })
    local door = createDoor(insertId, data, data.name)

    TriggerClientEvent('ox_doorlock:setState', -1, door.id, door.state, false, door)

    return door.id
end)

exports('removeDoor', function(id)
    local door = doors[id]

    if not door then
        error(('No door found with id %s'):format(id))
    end

    Database.update('DELETE FROM ox_doorlock WHERE id = ?', { id })
    doors[id] = nil
    TriggerClientEvent('ox_doorlock:editDoorlock', -1, id, nil)

    return true
end)

local isLoaded = false
local ox_inventory = exports.ox_inventory

SetTimeout(0, function()
    if GetPlayer then return end

    function GetPlayer(_) end
end)

function RemoveItem(playerId, item, slot)
    local player = GetPlayer(playerId)

    if player then ox_inventory:RemoveItem(playerId, item, 1, nil, slot) end
end

---@param player table
---@param items string[] | { name: string, remove?: boolean, metadata?: string }[]
---@param removeItem? boolean
---@return string?
function DoesPlayerHaveItem(player, items, removeItem)
    local playerId = player.source or player.PlayerData.source

    for i = 1, #items do
        local item = items[i]
        local itemName = item.name or item
        local data = ox_inventory:Search(playerId, 'slots', itemName, item.metadata)[1]

        if data and data.count > 0 then
            if removeItem or item.remove then
                ox_inventory:RemoveItem(playerId, itemName, 1, nil, data.slot)
            end

            return itemName
        end
    end
end

local function isAuthorised(playerId, door, lockpick)
    if Config.PlayerAceAuthorised and IsPlayerAceAllowed(playerId, 'command.doorlock') then
        return true
    end

    -- e.g. add_ace group.police "doorlock.mrpd locker rooms" allow
    -- add_principal fivem:123456 group.police
    -- or add_ace identifier.fivem:123456 "doorlock.mrpd locker rooms" allow
    if IsPlayerAceAllowed(playerId, ('doorlock.%s'):format(door.name)) then
        return true
    end

    local player = GetPlayer(playerId)
    local authorised = door.passcode or false --[[@as boolean | string | nil]]

    if player then
        if lockpick then
            return DoesPlayerHaveItem(player, Config.LockpickItems)
        end

        local hasRestrictions = (door.groups and next(door.groups)) or (door.characters and next(door.characters)) or (door.items and next(door.items))

        if not hasRestrictions then
            authorised = true
        else
            if door.characters and pr_lib.table.contains(door.characters, GetCharacterId(player)) then
                authorised = true
                goto continue
            end

            if door.groups and next(door.groups) then
                authorised = IsPlayerInGroup(player, door.groups) and true or nil
            end

            if not authorised and door.items then
                authorised = DoesPlayerHaveItem(player, door.items) or nil
            end
        end
    end

    if authorised ~= nil and door.passcode then
        authorised = door.passcode == pr_lib.callback.await('ox_doorlock:inputPassCode', playerId)
    end

    ::continue::

    local hookResult = TriggerEventHooks('doorAuthorization', {
        source = playerId,
        door = door,
        lockpick = lockpick,
        authorised = authorised,
    })

    if hookResult == nil then return authorised end

    return authorised or hookResult == nil or hookResult
end

local sql = LoadResourceFile(cache.resource, 'sql/ox_doorlock.sql')

if sql then Database.query(sql) end

Database.ready(function()
    while Config.DoorList do Wait(100) end

    local response = Database.query('SELECT `id`, `name`, `data` FROM `ox_doorlock`')

    for i = 1, #response do
        local door = response[i]
        createDoor(door.id, json.decode(door.data), door.name)
    end

    isLoaded = true

    TriggerEvent('ox_doorlock:loaded')
end)

---@param id number
---@param state 0 | 1 | boolean
---@param lockpick? boolean
---@return boolean
local function setDoorState(id, state, lockpick)
    local door = doors[id]

    state = (state == 1 or state == 0) and state or (state and 1 or 0)

    if door then
        local authorised = not source or source == '' or isAuthorised(source, door, lockpick)

        if authorised then
            door.state = state
            TriggerClientEvent('ox_doorlock:setState', -1, id, state, source)

            if door.autolock and state == 0 then
                SetTimeout(door.autolock * 1000, function()
                    if door.state ~= 1 then
                        door.state = 1

                        TriggerClientEvent('ox_doorlock:setState', -1, id, door.state)
                        TriggerEvent('ox_doorlock:stateChanged', nil, door.id, door.state == 1)
                    end
                end)
            end

            TriggerEvent('ox_doorlock:stateChanged', source, door.id, state == 1,
                type(authorised) == 'string' and authorised)

            return true
        end

        if source then
            pr_lib.notify.Notify(source,
                { type = 'error', icon = 'lock', description = locale(state == 0 and 'cannot_unlock' or 'cannot_lock') })
        end
    end

    return false
end

RegisterNetEvent('ox_doorlock:setState', setDoorState)
exports('setDoorState', setDoorState)

pr_lib.callback.register('ox_doorlock:getDoors', function()
    while not isLoaded do Wait(100) end

    return doors, sounds
end)

RegisterNetEvent('ox_doorlock:editDoorlock', function(id, data)
    if IsPlayerAceAllowed(source, 'command.doorlock') then
        if data then
            if not data.coords then
                local double = data.doors
                data.coords = double[1].coords - ((double[1].coords - double[2].coords) / 2)
            end

            if not data.name then
                data.name = tostring(data.coords)
            end

            data.doorGroup = normalizeDoorGroup(data.doorGroup)
        end

        if id then
            if data then
                Database.update('UPDATE ox_doorlock SET name = ?, data = ? WHERE id = ?',
                    { data.name, encodeData(data), id })
            else
                Database.update('DELETE FROM ox_doorlock WHERE id = ?', { id })
            end

            doors[id] = data
            TriggerClientEvent('ox_doorlock:editDoorlock', -1, id, data)
        else
            local insertId = Database.insert('INSERT INTO ox_doorlock (name, data) VALUES (?, ?)',
                { data.name, encodeData(data) })
            local door = createDoor(insertId, data, data.name)

            TriggerClientEvent('ox_doorlock:setState', -1, door.id, door.state, false, door)
        end
    end
end)

RegisterNetEvent('ox_doorlock:breakLockpick', function()
    local player = GetPlayer(source)
    return player and DoesPlayerHaveItem(player, Config.LockpickItems, true)
end)

RegisterNetEvent('ox_doorlock:teleportToDoor', function(id)
    if not IsPlayerAceAllowed(source, 'command.doorlock') then
        return
    end

    local door = doors[id]
    if not door or not door.coords then
        return
    end

    local ped = GetPlayerPed(source)
    SetEntityCoords(ped, door.coords.x, door.coords.y, door.coords.z, false, false, false, false)
end)

pr_lib.addCommand('doorlock', {
    help = locale('create_modify_lock'),
    params = {
        {
            name = 'closest',
            help = locale('command_closest'),
            optional = true,
        },
    },
    restricted = Config.CommandPrincipal
}, function(source, args)
    TriggerClientEvent('ox_doorlock:triggeredCommand', source, args.closest)
end)

function GetNameFromDoor(name)
    local results = Database.query('SELECT * FROM ox_doorlock WHERE name LIKE ?', {'%' .. name .. '%'})
    if results and #results > 0 then
        return results
    end
    return nil
end

RegisterNetEvent('ox_doorlock:RemoveDoorlock', function(name)
    local doorData = GetNameFromDoor(name)

    if doorData and #doorData > 0 then
        for _, door in ipairs(doorData) do
            Database.update('DELETE FROM ox_doorlock WHERE id = ?', { door.id })
            TriggerClientEvent('ox_doorlock:editDoorlock', -1, door.id, nil)
        end
    else
        print('No doors found with the name:', name)
    end
end)
