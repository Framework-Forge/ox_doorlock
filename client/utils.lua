local cache = pr_lib.cache
local Entity = Entity

local function getDoorFromEntity(data)
	local entity = type(data) == 'table' and data.entity or data

	if not entity then return end

	local state = Entity(entity)?.state
	local doorId = state?.doorId

	if not doorId then return end

	local door = doors[doorId]

	if not door then
		state.doorId = nil
	end

	return door
end

exports('getClosestDoorId', function() return ClosestDoor?.id end)
exports('getDoorIdFromEntity', function(entityId) return getDoorFromEntity(entityId)?.id end) -- same as Entity(entityId).state.doorId

local function entityIsNotDoor(data)
	local entity = type(data) == 'number' and data or data.entity
	return not getDoorFromEntity(entity)
end

PickingLock = false

local function canPickLock(entity)
	if PickingLock then return false end

	local door = getDoorFromEntity(entity)

	return door and door.lockpick and (Config.CanPickUnlockedDoors or door.state == 1)
end

---@param entity number
local function pickLock(entity)
	local door = getDoorFromEntity(entity)

	if not door or PickingLock or not door.lockpick or (not Config.CanPickUnlockedDoors and door.state == 0) then return end

	PickingLock = true

	TaskTurnPedToFaceCoord(cache.ped, door.coords.x, door.coords.y, door.coords.z, 4000)
	Wait(500)

	local animDict = 'mp_common_heist'
	if not pr_lib.requestAnimDict(animDict) then
		PickingLock = false
		return
	end

	TaskPlayAnim(cache.ped, animDict, 'pick_door', 3.0, 1.0, -1, 49, 0, true, true, true)

	local success = pr_lib.skillCheck(door.lockpickDifficulty or Config.LockDifficulty)
	local rand = math.random(1, success and 100 or 5)

	if success then
		TriggerServerEvent('ox_doorlock:setState', door.id, door.state == 1 and 0 or 1, true)
	end

	if rand == 1 then
		TriggerServerEvent('ox_doorlock:breakLockpick')
		pr_lib.notify.Notify({ type = 'error', description = locale('lockpick_broke') })
	end

	StopEntityAnim(cache.ped, 'pick_door', animDict, 0)
	RemoveAnimDict(animDict)

	PickingLock = false
end

exports('pickClosestDoor', function()
	if not ClosestDoor then return end

	pickLock(ClosestDoor.entity)
end)

local tempData = {}

local function captureTransform(entity)
	local coords = GetEntityCoords(entity)
	local rotation = GetEntityRotation(entity, 2)

	return {
		coords = vector3(coords.x, coords.y, coords.z),
		rotation = vector3(rotation.x, rotation.y, rotation.z),
	}
end

local function setTransform(entity, transform)
	SetEntityCoordsNoOffset(entity, transform.coords.x, transform.coords.y, transform.coords.z, false, false, false)
	SetEntityRotation(entity, transform.rotation.x, transform.rotation.y, transform.rotation.z, 2, true)
end

local function toVectorTransform(transform)
	if not transform then return end

	local coords, rotation = transform.coords, transform.rotation
	transform.coords = vector3(coords.x, coords.y, coords.z)
	transform.rotation = vector3(rotation.x, rotation.y, rotation.z)
end

local function configureCustomTransform(entity, doorType, startsOpened)
	local initial = captureTransform(entity)
	local position = initial.coords
	local rotation = initial.rotation
	local confirmed = false

	-- The left-click that selected the map entity is still active on this frame.
	-- Consume it before accepting a confirmation for the adjustment mode.
	while IsControlPressed(0, 24) or IsDisabledControlPressed(0, 24) do
		Wait(0)
	end

	SetEntityDrawOutlineShader(1)
	SetEntityDrawOutlineColor(0, 150, 200, 200)
	SetEntityDrawOutline(entity, true)
	FreezeEntityPosition(entity, true)
	pr_lib.showTextUI(('Configure the %s position | Mouse wheel: rotate | WASD: move | Q/E: up/down | LMB: confirm | RMB: cancel'):format(startsOpened and 'closed' or 'open'))

	while true do
		DisablePlayerFiring(cache.playerId, true)
		for _, control in ipairs({ 14, 15, 24, 25, 32, 33, 34, 35, 38, 44 }) do
			DisableControlAction(0, control, true)
		end

		if IsDisabledControlJustPressed(0, 24) then
			confirmed = true
			break
		end

		if IsDisabledControlJustPressed(0, 25) then break end

		local changed = false
		if doorType == 'rotate' then
			if IsDisabledControlPressed(0, 15) then
				rotation = vector3(rotation.x, rotation.y, rotation.z + 1.0)
				changed = true
			elseif IsDisabledControlPressed(0, 14) then
				rotation = vector3(rotation.x, rotation.y, rotation.z - 1.0)
				changed = true
			end
		end

		local heading = math.rad(rotation.z)
		local right = vector3(math.cos(heading), math.sin(heading), 0.0)
		local forward = vector3(-math.sin(heading), math.cos(heading), 0.0)
		local step = 0.015

		if IsDisabledControlPressed(0, 32) then position = position + forward * step changed = true end
		if IsDisabledControlPressed(0, 33) then position = position - forward * step changed = true end
		if IsDisabledControlPressed(0, 34) then position = position - right * step changed = true end
		if IsDisabledControlPressed(0, 35) then position = position + right * step changed = true end
		if IsDisabledControlPressed(0, 44) then position = position + vector3(0.0, 0.0, step) changed = true end
		if IsDisabledControlPressed(0, 38) then position = position - vector3(0.0, 0.0, step) changed = true end

		if changed then
			setTransform(entity, { coords = position, rotation = rotation })
		end

		Wait(0)
	end

	local final = confirmed and captureTransform(entity) or nil
	setTransform(entity, initial)
	FreezeEntityPosition(entity, false)
	SetEntityDrawOutline(entity, false)
	pr_lib.hideTextUI()

	if not final then return end
	return startsOpened and final or initial, startsOpened and initial or final
end

local availableDoorModels

local function getAvailableDoorModels()
	if availableDoorModels then return availableDoorModels end

	local file = LoadResourceFile(cache.resource, 'data/door_models.json')
	local models = file and json.decode(file)
	if not models then return end

	availableDoorModels = {}
	for model in pairs(models) do
		local numericModel = tonumber(model)
		if numericModel and numericModel >= -2147483648 and numericModel <= 2147483647 then
			availableDoorModels[#availableDoorModels + 1] = numericModel
		end
	end
	table.sort(availableDoorModels)
	return availableDoorModels
end

local function loadDoorModel(model)
	if not IsModelInCdimage(model) or not IsModelValid(model) then return false end

	RequestModel(model)
	local timeout = GetGameTimer() + 5000
	while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(0) end
	return HasModelLoaded(model)
end

local function createDoorPreview(model, transform)
	if not loadDoorModel(model) then return end

	-- Use the same entity flags as doors_creator. Some streamed door models cannot
	-- be spawned as a purely local object on OneSync, which returns entity 0.
	local entity = CreateObjectNoOffset(model, transform.coords.x, transform.coords.y, transform.coords.z, true, true, false)
	if entity == 0 then
		entity = CreateObject(model, transform.coords.x, transform.coords.y, transform.coords.z, true, true, false)
	end
	if entity == 0 then return end

	SetEntityAsMissionEntity(entity, true, true)
	setTransform(entity, transform)
	SetEntityAlpha(entity, 180, false)
	SetEntityCollision(entity, false, false)
	FreezeEntityPosition(entity, true)
	return entity
end

local function getPreviewModel(models, index, direction, transform)
	for _ = 1, #models do
		local preview = createDoorPreview(models[index], transform)
		if preview then return preview, index end

		index = index + direction
		if index > #models then index = 1 end
		if index < 1 then index = #models end
	end
end

local function chooseNewDoorModel()
	local models = getAvailableDoorModels()
	if not models or #models == 0 then
		pr_lib.notify.Notify({ type = 'error', description = 'Door model list could not be loaded.' })
		return
	end

	local coords = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 2.0, 0.0)
	local transform = {
		coords = vector3(coords.x, coords.y, coords.z),
		rotation = vector3(0.0, 0.0, GetEntityHeading(cache.ped)),
	}
	local index = 1
	local preview
	preview, index = getPreviewModel(models, index, 1, transform)
	if not preview then
		pr_lib.notify.Notify({ type = 'error', description = 'No valid door model could be loaded.' })
		return
	end

	while IsControlPressed(0, 24) or IsDisabledControlPressed(0, 24) do Wait(0) end
	SetEntityDrawOutlineShader(1)
	SetEntityDrawOutlineColor(0, 150, 200, 200)
	SetEntityDrawOutline(preview, true)
	pr_lib.showTextUI(('Page Up/Down: model %d/%d | Mouse wheel: rotate | WASD: move | Q/E: up/down | LMB: select | RMB: cancel'):format(index, #models))

	local selected = false
	while true do
		DisablePlayerFiring(cache.playerId, true)
		for _, control in ipairs({ 10, 11, 14, 15, 24, 25, 32, 33, 34, 35, 38, 44 }) do
			DisableControlAction(0, control, true)
		end

		if IsDisabledControlJustPressed(0, 24) then
			selected = true
			break
		end
		if IsDisabledControlJustPressed(0, 25) then break end

		local nextIndex, direction
		if IsDisabledControlJustPressed(0, 10) then
			nextIndex = index == #models and 1 or index + 1
			direction = 1
		elseif IsDisabledControlJustPressed(0, 11) then
			nextIndex = index == 1 and #models or index - 1
			direction = -1
		end

		if nextIndex then
			local newPreview
			newPreview, nextIndex = getPreviewModel(models, nextIndex, direction, transform)
			if newPreview then
				SetEntityDrawOutline(preview, false)
				DeleteEntity(preview)
				preview, index = newPreview, nextIndex
				SetEntityDrawOutline(preview, true)
			end
		end

		local changed = false
		if IsDisabledControlPressed(0, 15) then transform.rotation = vector3(transform.rotation.x, transform.rotation.y, transform.rotation.z + 1.0) changed = true end
		if IsDisabledControlPressed(0, 14) then transform.rotation = vector3(transform.rotation.x, transform.rotation.y, transform.rotation.z - 1.0) changed = true end

		local heading = math.rad(transform.rotation.z)
		local right = vector3(math.cos(heading), math.sin(heading), 0.0)
		local forward = vector3(-math.sin(heading), math.cos(heading), 0.0)
		local step = 0.015
		if IsDisabledControlPressed(0, 32) then transform.coords = transform.coords + forward * step changed = true end
		if IsDisabledControlPressed(0, 33) then transform.coords = transform.coords - forward * step changed = true end
		if IsDisabledControlPressed(0, 34) then transform.coords = transform.coords - right * step changed = true end
		if IsDisabledControlPressed(0, 35) then transform.coords = transform.coords + right * step changed = true end
		if IsDisabledControlPressed(0, 44) then transform.coords = transform.coords + vector3(0.0, 0.0, step) changed = true end
		if IsDisabledControlPressed(0, 38) then transform.coords = transform.coords - vector3(0.0, 0.0, step) changed = true end
		if changed then setTransform(preview, transform) end

		Wait(0)
	end

	SetEntityDrawOutline(preview, false)
	pr_lib.hideTextUI()
	if not selected then
		DeleteEntity(preview)
		return
	end

	return preview, models[index]
end

local function createNewDoor(data)
	if data.doorType ~= 'rotate' and data.doorType ~= 'slide' then
		pr_lib.notify.Notify({ type = 'error', description = 'Place New Door is available for Rotate and Slide doors only.' })
		return
	end

	local count = data.doors and 2 or 1
	local entries = {}
	for i = 1, count do
		local preview, model = chooseNewDoorModel()
		if not preview then return end

		local closed, opened = configureCustomTransform(preview, data.doorType, data.doorOpened)
		DeleteEntity(preview)
		if not closed then return end

		entries[i] = {
			model = model,
			coords = closed.coords,
			rotation = closed.rotation,
			heading = math.floor(closed.rotation.z + 0.5),
			closed = closed,
			open = opened,
		}
	end

	if count == 2 then
		data.doors = entries
		data.coords = entries[1].coords - ((entries[1].coords - entries[2].coords) / 2)
	else
		local entry = entries[1]
		data.model = entry.model
		data.coords = entry.coords
		data.rotation = entry.rotation
		data.heading = entry.heading
		data.closed = entry.closed
		data.open = entry.open
	end

	data.placeNew = nil
	return true
end

local function addDoorlock(data)
	local entity = type(data) == 'number' and data or data.entity
	local model = GetEntityModel(entity)
	local coords = GetEntityCoords(entity)

	AddDoorToSystem(`temp`, model, coords.x, coords.y, coords.z, false, false, false)
	DoorSystemSetDoorState(`temp`, 4, false, false)

	coords = GetEntityCoords(entity)
	local rot = GetEntityRotation(entity, 2)
	tempData[#tempData + 1] = {
		entity = entity,
		model = model,
		coords = coords,
		heading = math.floor(GetEntityHeading(entity) + 0.5),
		rotation = vector3(rot.x, rot.y, rot.z)
	}

	RemoveDoorFromSystem(`temp`)
end

local isAddingDoorlock = false

local activePreviewId = nil

RegisterNUICallback('notify', function(data, cb)
	cb(1)
	pr_lib.notify.Notify({ title = data })
end)

RegisterNUICallback('previewSound', function(data, cb)
	cb(1)
	if not data.soundName or data.soundName == '' then return end

	SendNUIMessage({
		action = 'playSound',
		data = {
			sound = data.soundName,
			volume = 1.0
		}
	})
end)

RegisterNUICallback('createDoor', function(data, cb)
	cb(1)
	SetNuiFocus(false, false)

	data.state = (data.state == true or data.state == 1) and 1 or 0

	if data.items and not next(data.items) then
		data.items = nil
	end

	if data.characters and not next(data.characters) then
		data.characters = nil
	end

	if data.lockpickDifficulty and not next(data.lockpickDifficulty) then
		data.lockpickDifficulty = nil
	end

	if data.groups and not next(data.groups) then
		data.groups = nil
	end

	if data.doorGroup == '' then
		data.doorGroup = nil
	end

	if not data.id and data.placeNew then
		isAddingDoorlock = true
		local created = createNewDoor(data)
		isAddingDoorlock = false
		if not created then return end

		TriggerServerEvent('ox_doorlock:editDoorlock', false, data)
		ClearDoorTable(tempData)
		return
	end

	if not data.id then
		isAddingDoorlock = true
		local doorCount = data.doors and 2 or 1
		local lastEntity = 0

		pr_lib.showTextUI(locale('add_door_textui'))

		repeat
			DisablePlayerFiring(cache.playerId, true)
			DisableControlAction(0, 25, true)

			local hit, entity, coords = pr_lib.raycast.cam(1|16)
			local changedEntity = lastEntity ~= entity
			local doorA = tempData[1]?.entity

			if changedEntity and lastEntity ~= doorA then
				SetEntityDrawOutline(lastEntity, false)
			end

			lastEntity = entity

			if hit then
				---@diagnostic disable-next-line: param-type-mismatch
				DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.2, 0.2, 0.2, 255, 42, 24,
					100, false, false, 0, true, false, false, false)
			end

			if hit and entity > 0 and GetEntityType(entity) == 3 and (doorCount == 1 or doorA ~= entity) and entityIsNotDoor(entity) then
				if changedEntity then
					SetEntityDrawOutline(entity, true)
				end

				if IsDisabledControlJustPressed(0, 24) then
					addDoorlock(entity)
				end
			end

			if IsDisabledControlJustPressed(0, 25) then
				SetEntityDrawOutline(entity, false)

				if not doorA then
					isAddingDoorlock = false
					return pr_lib.hideTextUI()
				end

				SetEntityDrawOutline(doorA, false)
				ClearDoorTable(tempData)
			end
		until tempData[doorCount]

		pr_lib.hideTextUI()
		SetEntityDrawOutline(tempData[1].entity, false)

		if data.doorType == 'rotate' or data.doorType == 'slide' then
			for i = 1, doorCount do
				local closed, opened = configureCustomTransform(tempData[i].entity, data.doorType, data.doorOpened)

				if not closed then
					isAddingDoorlock = false
					ClearDoorTable(tempData)
					return
				end

				tempData[i].closed = closed
				tempData[i].open = opened
				tempData[i].coords = closed.coords
				tempData[i].rotation = closed.rotation
				tempData[i].heading = math.floor(closed.rotation.z + 0.5)
			end
		end

		if data.doors then
			SetEntityDrawOutline(tempData[2].entity, false)
			tempData[1].entity = nil
			tempData[2].entity = nil
			data.doors = tempData
		else
			data.model = tempData[1].model
			data.coords = tempData[1].coords
			data.heading = tempData[1].heading
			data.rotation = tempData[1].rotation
			data.closed = tempData[1].closed
			data.open = tempData[1].open
		end
	else
		if data.doors then
			for i = 1, 2 do
				local coords = data.doors[i].coords
				data.doors[i].coords = vector3(coords.x, coords.y, coords.z)
				if data.doors[i].rotation then
					local rot = data.doors[i].rotation
					data.doors[i].rotation = vector3(rot.x, rot.y, rot.z)
				end
				toVectorTransform(data.doors[i].closed)
				toVectorTransform(data.doors[i].open)
				data.doors[i].entity = nil
			end
		else
			data.entity = nil
		end

		data.coords = vector3(data.coords.x, data.coords.y, data.coords.z)
		if data.rotation then
			local rot = data.rotation
			data.rotation = vector3(rot.x, rot.y, rot.z)
		end
		toVectorTransform(data.closed)
		toVectorTransform(data.open)
		data.distance = nil
		data.zone = nil
	end

	isAddingDoorlock = false

	TriggerServerEvent('ox_doorlock:editDoorlock', data.id or false, data)
	ClearDoorTable(tempData)
end)

RegisterNUICallback('deleteDoor', function(id, cb)
	cb(1)
	TriggerServerEvent('ox_doorlock:editDoorlock', id)
end)

RegisterNUICallback('teleportToDoor', function(id, cb)
	cb(1)
	SetNuiFocus(false, false)
	TriggerServerEvent('ox_doorlock:teleportToDoor', id)
end)

RegisterNUICallback('exit', function(_, cb)
	cb(1)
	SetNuiFocus(false, false)
end)

local function openUi(id)
	if source == '' or isAddingDoorlock then return end

	if not NuiHasLoaded then
		NuiHasLoaded = true

		SendNuiMessage(json.encode({
			action = 'updateDoorData',
			data = doors
		}, { with_hole = false }))
		Wait(100)

		SendNUIMessage({
			action = 'setSoundFiles',
			data = pr_lib.callback.await('ox_doorlock:getSounds', false)
		})
	end

	SetNuiFocus(true, true)
	SendNuiMessage(json.encode({
		action = 'setVisible',
		data = id
	}))
end

RegisterNetEvent('ox_doorlock:triggeredCommand', function(closest)
	openUi(closest and ClosestDoor?.id or nil)
end)

CreateThread(function()
	local target = pr_lib.target
	if not target or type(target.addGlobalObject) ~= 'function' then return end

	target.addGlobalObject({
		{
			name = 'pickDoorlock',
			label = locale('pick_lock'),
			icon = 'fas fa-user-lock',
			onSelect = pickLock,
			canInteract = canPickLock,
			items = Config.LockpickItems,
			anyItem = true,
			distance = 1
		}
	})

	AddEventHandler('onResourceStop', function(resource)
		if resource == cache.resource and type(target.removeGlobalObject) == 'function' then
			target.removeGlobalObject({ 'pickDoorlock' })
		end
	end)
end)
