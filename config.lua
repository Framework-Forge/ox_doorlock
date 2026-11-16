---@type DoorlockConfig
---@diagnostic disable-next-line: missing-fields
Config = {}

-- Keep the original locale(...) contract while resolving translations through pr_bridge.
local doorLocale = pr_lib.locale()

function locale(key, ...)
    return doorLocale(key, ...)
end

-- Replacements for the table helpers previously injected by ox_lib.
function DoorTableType(value)
    if type(value) ~= 'table' then return type(value) end

    local count, highest = 0, 0

    for key in pairs(value) do
        if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then return 'hash' end
        count = count + 1
        if key > highest then highest = key end
    end

    return highest == count and 'array' or 'hash'
end

function ClearDoorTable(value)
    for key in pairs(value) do value[key] = nil end
    return value
end

---Trigger a notification on the client when the door state is successfully updated.
Config.Notify = false

---Create a persistent notification while in-range of a door, prompting to lock/unlock.
Config.DrawTextUI = false

---Set the properties used by [DrawSprite](https://docs.fivem.net/natives/?_0xE7FFAE5EBF23D890).
Config.DrawSprite = {
    -- Unlocked
    [0] = { 'mpsafecracking', 'lock_open', 0, 0, 0.018, 0.018, 0, 255, 255, 255, 100 },

    -- Locked
    [1] = { 'mpsafecracking', 'lock_closed', 0, 0, 0.018, 0.018, 0, 255, 255, 255, 100 },
}

---Allow the specified ace principal to use 'command.doorlock'.
Config.CommandPrincipal = 'group.admin'

---Allow players with the 'command.doorlock' principal to use any door.
Config.PlayerAceAuthorised = false

---The default skill check difficulty when lockpicking a door.
Config.LockDifficulty = { 'easy', 'easy', 'medium' }

---Allow lockpicks to be used to lock an unlocked door.
Config.CanPickUnlockedDoors = false

---An array of items that function as lockpicks.
Config.LockpickItems = {
    'lockpick'
}

---Play sounds using game audio (sound natives) instead of through NUI.
Config.NativeAudio = true
