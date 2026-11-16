# Ox Doorlock

Door management resource, with compatibility for [ox_core](https://github.com/overextended/ox_core), [es_extended](https://github.com/esx-framework/esx_core), [nd_core](https://github.com/ND-Framework/ND_Core), and [qbox](https://github.com/Qbox-project/qbx_core).  
Successor to nui_doorlock with less scuff and more stuff.

_The UI needs to be built - use the [latest release](https://github.com/overextended/ox_doorlock/releases/latest/download/ox_doorlock.zip) if you want to drag-n-drop._

Refer to [CONTRIBUTING.md](./CONTRIBUTING.md) for contribution guidelines and to see our Contributor License Agreement.\
Refer to [NOTICE.md](./NOTICE.md) for additional information and legal notices.

## Dependencies

### pr_bridge

All runtime services are resolved through `pr_bridge`, including database access, callbacks, locale, notifications, input, skill checks, cache, raycasts, TextUI, and targeting.

Doors remain stored in the configured database. The concrete database and target implementations are selected by `pr_bridge`; `ox_doorlock` does not import a database driver, `ox_lib`, or a target resource directly.

## Usage

Use the `/doorlock` command to open the UI and enter the settings for your new door.  
Once you confirm the settings, activate your targeting resource (typically LALT) to select the entity (or entities) to use.

Adding any arguments after the command will open the closest door to you, to easily modify it.

## Conversion

Placing nui_doorlock config files into the `convert` folder will convert the data and insert it into the database.  
Success is _not_ guaranteed if using a fork on nui_doorlock, like the qb version.

## Client API

- Use the closest door. Still performs server-side checks, so may fail.

```lua
exports.ox_doorlock:useClosestDoor()
```

- Pick the lock of the closest door. Still performs server-side checks, so may fail.

```lua
exports.ox_doorlock:pickClosestDoor()
```

## Server API

- Get data for door

```lua
local mrpd_locker_rooms = exports.ox_doorlock:getDoor(1)
local mrpd_locker_rooms = exports.ox_doorlock:getDoorFromName('mrpd locker rooms')
```

- Set door state (0: unlocked, 1: locked)

```lua
TriggerEvent('ox_doorlock:setState', mrpd_locker_rooms.id, state)
```

- Listen for event when door is toggled

```lua
AddEventHandler('ox_doorlock:stateChanged', function(source, doorId, state, usedItem)
    if usedItem == 'trainticket' then
        local xPlayer = ESX.GetPlayerFromId(source)
        xPlayer.removeInventoryItem(usedItem, 1)
    end
end)
```

## Door Settings

### General

- Door name
  - Used to easily identify the door.
- Passcode
  - Door can be unlocked by anybody by using the code or phrase.
- Autolock interval
  - Door will be locked after x seconds.
- Interact distance
  - Door can only be used when within x metres.
- Door rate
  - Door movement speed for sliding/garage/automatic doors, or swinging doors when locked.
- Locked
  - Sets the door as locked by default.
- Double
  - Door is a set of two doors, controlled together.
- Automatic
  - Sliding/garage/automatic door.
- Lockpick
  - Door can be lockpicked when interacting with a targeting resource.
- Hide UI
  - No indicators (i.e. icon, text) will display on the door.

### Characters

- Character Id
  - Character identifier used by a framework (i.e. player.charid, xPlayer.identifier, Player.CitizenId).

### Groups

- Group
  - Framework dependent, referring to jobs, gangs, etc.
- Grade
  - The minimum grade to allow access for the group (0 to allow all).

### Items

- Item
  - Name of the item.
- Metadata type
  - Requires metadata support (i.e. ox_inventory) to check slot.metadata.type

### Lockpick

- Difficulty
  - Sets the lockpicking skill-check difficulty.
- Area size
  - Custom difficulty area size.
- Speed multiplier
  - Custom difficulty idicator speed.
