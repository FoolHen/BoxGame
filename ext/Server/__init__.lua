class 'BoxGameServer'

local m_BoxInstanceGuid = Guid("071572A1-FC46-308E-A495-6EE575154438")
local m_BoxPartitionGuid = Guid("8D3FAB68-B78E-11E0-A405-EA03C5FF7246")

local m_WallInstanceGuid = Guid("4399B484-5158-E694-262F-828DDC325BA3")
local m_WallPartitionGuid = Guid("55EE9583-5C62-11E0-8D20-91499D5EE2D1")

-- Playable area dimensions.
local m_AreaWidth = 10
local m_AreaLength = 20
local m_AreaHeight = 10

local m_StartingPos = { x = 0, y = 100, z = 0}

-- These are the sizes of the box. It's 1m wide and 1.29m tall.
local m_BoxWidth = 1
local m_BoxHeight = 1.29

-- In these vars we keep references of weapons, attachments and soldier info to spawn soldiers later.
local m_SoldierAsset = nil
local m_SoldierBlueprint = nil
local m_Weapon = nil
local m_M320 = nil
local m_WeaponAtt0 = nil
local m_WeaponAtt1 = nil
local m_DrPepper = nil

local m_DisabledBoxes = {}
local m_LevelLoaded = false

function BoxGameServer:__init()
	print("Initializing BoxGameServer")
	self:RegisterEvents()
end

function BoxGameServer:RegisterEvents()
	Events:Subscribe('Partition:Loaded', self, self.OnPartitionLoaded)
	Events:Subscribe('Server:LevelLoaded', self, self.OnLevelLoaded)
	Events:Subscribe('Player:Chat', self, self.OnChat)
	Hooks:Install('ServerEntityFactory:CreateFromBlueprint', 999, self, self.OnEntityCreateFromBlueprint)
	Hooks:Install('UI:PushScreen', 999, self, self.OnPushScreen)
	Events:Subscribe('Player:Respawn', self, self.OnPlayerRespawn)
end

function BoxGameServer:OnPushScreen(p_Hook, p_Screen, p_GraphPriority, p_ParentGraph)
	if p_Screen == nil then
		return
	end

	local s_Screen = UIGraphAsset(p_Screen)

	if s_Screen.name == 'UI/Flow/Screen/SpawnButtonScreen' then
		print("foundddddd")
		p_Hook:Return(nil)
		return
	end
end

function BoxGameServer:OnPlayerRespawn(p_Player)
	-- Disable parachute, so ppl fall to their death.
	p_Player:EnableInput(EntryInputActionEnum.EIAToggleParachute, false)
end

function BoxGameServer:OnLevelLoaded(p_Map, p_GameMode, p_Round)
	m_LevelLoaded = true

	-- Spawn all boxes.
	for x = 1, m_AreaWidth do
		for y = 1, m_AreaHeight do
			for z = 1, m_AreaLength do
				-- print(x..","..y..","..z)
				self:SpawnBox(x, y, z)
			end
		end
	end
	print("walls now")
	-- Spawn the walls that divide the top of the boxes in 2 spawn areas.
	self:SpawnWalls()
end

function BoxGameServer:OnChat(player, recipientMask, message)
	if message == '!start' then
		self:StartRound()
	end
end

function BoxGameServer:StartRound()
	-- Enable all disabled entities.
	for _, l_InstanceId in pairs(m_DisabledBoxes) do
		Events:Dispatch('BlueprintManager:EnableEntityByEntityId', l_InstanceId, true)
	end

	-- Clear table of disabled entities.
	m_DisabledBoxes = {}

	-- If there's any player alive we kill him.
	for _, l_Player in pairs(PlayerManager:GetPlayers()) do
		if l_Player.soldier ~= nil then
			l_Player.soldier:Kill(false)
		end
	end

	-- Spawn every player.
	for _, l_Player in pairs(PlayerManager:GetPlayers()) do
		self:SpawnPlayer(l_Player)
	end
end

function BoxGameServer:OnEntityCreateFromBlueprint(p_Hook, p_Blueprint, p_Transform, p_Variation, p_Parent )
	-- Ignore if the level is loading.
	if not m_LevelLoaded then
		p_Hook:Next()
		return
	end

	-- We only care about the box instance, otherwise we dont mess with the hook.
	if p_Blueprint.instanceGuid ~= m_BoxInstanceGuid then
		p_Hook:Next()
		return
	end

	-- Call the hook and save the entities it created with the blueprint.
	local entities = p_Hook:Call()

	if entities == nil then
		return
	end

	-- Loop through all the entities. Blueprints can spawn more than one entity. In this case we care about the physic entity, so we can
	-- assign a callback to it.
	for _, entity in pairs(entities) do
		if entity:Is('ServerPhysicsEntity') then
			-- Cast it.
			entity = PhysicsEntity(entity)

			-- Now we register a collision callback.
			entity:RegisterCollisionCallback(function(entity, info)
				-- When a collision happens we check if the colliding entity is a grenade.
				if info.entity:Is("ServerGrenadeEntity") then
					-- Destroy the grenade as we don't want it to keep colliding with other blocks or explode.
					info.entity:Destroy()

					-- We tell BlueprintManager to disable all entities that the box blueprint created with the entityId of this particular entity.
					-- BlueprintManager stores all entities' ids of each blueprint.
					local instanceId = entity.instanceId
					Events:Dispatch('BlueprintManager:EnableEntityByEntityId', instanceId, false)

					-- We save the entity id so we can enable it back later.
					table.insert(m_DisabledBoxes, instanceId)
				end
			end)
		end
	end
end

function BoxGameServer:OnPartitionLoaded(p_Partition)
	local instances = p_Partition.instances

	for _, instance in pairs(instances) do

		-- Check if the instance is of the type we are looking for.
		if instance.typeInfo.name == 'VeniceSoldierCustomizationAsset' then
			-- Cast it in order to access its members.
			local asset = VeniceSoldierCustomizationAsset(instance)

			-- Check if its name is the one we want save for later.
			if asset.name == 'Gameplay/Kits/RURecon' then
				print('Found soldier customization asset ' .. asset.name)
				m_SoldierAsset = asset
			end
		end

		if instance.typeInfo.name == 'SoldierBlueprint' then
			m_SoldierBlueprint = SoldierBlueprint(instance)
			print('Found soldier blueprint ' .. m_SoldierBlueprint.name)
		end

		if instance.typeInfo.name == 'SoldierWeaponUnlockAsset' then
			local asset = SoldierWeaponUnlockAsset(instance)

			if asset.name == 'Weapons/M416/U_M416' then
				print('Found soldier weapon unlock asset ' .. asset.name)
				m_Weapon = asset
			elseif asset.name == 'Weapons/Gadgets/M320/U_M320_LVG' then
				print('Found soldier weapon unlock asset ' .. asset.name)
				m_M320 = asset
			end
		end
		if instance.typeInfo.name == 'UnlockAsset' then
			local asset = UnlockAsset(instance)

			if asset.name == 'Weapons/M416/U_M416_ACOG' then
				print('Found weapon unlock asset ' .. asset.name)
				m_WeaponAtt0 = asset
			end

			if asset.name == 'Weapons/M416/U_M416_Silencer' then
				print('Found weapon unlock asset ' .. asset.name)
				m_WeaponAtt1 = asset
			end

			if asset.name == 'Persistence/Unlocks/Soldiers/Visual/MP/RU/MP_RU_Recon_Appearance_DrPepper' then
				print('Found appearance asset ' .. asset.name)
				m_DrPepper = asset
			end
		end
	end
end

function BoxGameServer:SpawnPlayer(player)
	if player == nil or player.soldier ~= nil then
		print('Player must be dead to spawn')
		return
	end

	-- Create a LinearTransform to spawn the soldier with.
	local transform = LinearTransform(
		Vec3(1, 0, 0),
		Vec3(0, 1, 0),
		Vec3(0, 0, 1),
		Vec3(0, 0, 0)
	)

	-- We calculate the height and the x position of the spawn point.
	transform.trans.x = m_StartingPos.x + m_AreaWidth * m_BoxWidth / 2
	transform.trans.y = 1 +  m_StartingPos.y + m_AreaHeight * m_BoxHeight

	-- We now calculate the z position, which is the side of the playable area each team plays on.
	if player.teamId == TeamId.Team1 then
		-- 1/4th of the total lenght of the playable area.
		transform.trans.z = m_StartingPos.z + m_AreaLength * m_BoxWidth / 4
	elseif player.teamId == TeamId.Team2 then
		-- 3/4ths for team 2.
		transform.trans.z = m_StartingPos.z + m_AreaLength * 3 * m_BoxWidth / 4
	else
		return
	end

	-- Setting soldier primary weapon with its attachments and the M320 in the second slot.
	player:SelectWeapon(WeaponSlot.WeaponSlot_0, m_Weapon, { m_WeaponAtt0, m_WeaponAtt1 })
	player:SelectWeapon(WeaponSlot.WeaponSlot_1, m_M320, {})

	-- Setting soldier class and appearance
	player:SelectUnlockAssets(m_SoldierAsset, { m_DrPepper })

	-- Creating soldier at the position we calculated.
	local soldier = player:CreateSoldier(m_SoldierBlueprint, transform)

	if soldier == nil then
		print('Failed to create player soldier')
		return
	end

	-- Spawning soldier
	player:SpawnSoldierAt(soldier, transform, CharacterPoseType.CharacterPoseType_Stand)

	-- Set the ammo of the M320 to 999 and remove additional ammo so you cant reload.
	player.soldier:SetWeaponPrimaryAmmoByIndex(WeaponSlot.WeaponSlot_1, 999)
	player.soldier:SetWeaponSecondaryAmmoByIndex(WeaponSlot.WeaponSlot_1, 0)


	print('Soldier spawned')
end



function BoxGameServer:SpawnBox(p_XOffset, p_YOffset, p_ZOffset)
	local s_Transform = LinearTransform(
			Vec3(1,0,0),
			Vec3(0,1,0),
			Vec3(0,0,1),
			Vec3(m_StartingPos.x + p_XOffset * m_BoxWidth, m_StartingPos.y + p_YOffset * m_BoxHeight, m_StartingPos.z + p_ZOffset * m_BoxWidth)
		)

-- rotated 90º (y axis):
-- left: Vec3 {x: 0, y: 0, z: -1}
-- up: Vec3 {x: 0, y: 1, z: 0}
-- forward: Vec3 {x: 1, y: 0, z: 0}

	Events:Dispatch('BlueprintManager:SpawnBlueprint', p_XOffset..":"..p_YOffset..":"..p_ZOffset, m_BoxPartitionGuid, m_BoxInstanceGuid, tostring(s_Transform), nil)
end

function BoxGameServer:SpawnWalls()
	local s_Transform = LinearTransform(
			Vec3(1,0,0),
			Vec3(0,1,0),
			Vec3(0,0,1),
			Vec3(
				m_StartingPos.x + (m_AreaWidth * m_BoxWidth) / 2.0 + 0.5,
				m_StartingPos.y + (m_AreaHeight * m_BoxHeight) + 3.5,
				m_StartingPos.z + (m_AreaLength * m_BoxWidth) / 2.0 + 0.5
			)
		)
	Events:Dispatch('BlueprintManager:SpawnBlueprint', "wall1", m_WallPartitionGuid, m_WallInstanceGuid, tostring(s_Transform), nil)

	-- We need to spawn a second wall and flip it 180º, as the other side of the wall doesnt have texture so you can see through the other side.
	s_Transform.left.x = -1
	s_Transform.forward.z = -1

	Events:Dispatch('BlueprintManager:SpawnBlueprint', "wall2", m_WallPartitionGuid, m_WallInstanceGuid, tostring(s_Transform), nil)
end

g_BoxGameServer = BoxGameServer()

