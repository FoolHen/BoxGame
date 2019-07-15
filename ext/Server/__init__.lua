class 'BoxGameServer'

local m_BoxInstanceGuid = Guid("071572A1-FC46-308E-A495-6EE575154438")
local m_BoxPartitionGuid = Guid("8D3FAB68-B78E-11E0-A405-EA03C5FF7246")

local m_WallInstanceGuid = Guid("4399B484-5158-E694-262F-828DDC325BA3")
local m_WallPartitionGuid = Guid("55EE9583-5C62-11E0-8D20-91499D5EE2D1")


local m_AreaWidth = 10
local m_AreaLength = 20
local m_AreaHeight = 10

local m_StartingPos = {x=0, y=100, z=0}

local m_BoxWidth = 1
local m_BoxHeight = 1.29

local soldierAsset = nil
local soldierBlueprint = nil
local weapon = nil
local M320 = nil
local weaponAtt0 = nil
local weaponAtt1 = nil
local drPepper = nil

local m_DisabledBoxes = {}

function string:split(sep)
	local sep, fields = sep or ":", {}
	local pattern = string.format("([^%s]+)", sep)
	self:gsub(pattern, function(c) fields[#fields+1] = c end)
	return fields
end

function BoxGameServer:__init()
	print("Initializing BoxGameServer")
	self:RegisterVars()
	self:RegisterEvents()
end


function BoxGameServer:RegisterVars()
	self.m_LevelLoaded = false
end

function BoxGameServer:RegisterEvents()
	Events:Subscribe('Partition:Loaded', self, self.OnPartitionLoaded)
	Events:Subscribe('Server:LevelLoaded', self, self.OnLevelLoaded)
	Events:Subscribe('Level:LoadResources', OnLoadResources)
	Events:Subscribe('Player:Chat', self, self.OnChat)
	Hooks:Install('ServerEntityFactory:CreateFromBlueprint', 999, self, self.OnEntityCreateFromBlueprint)
end

function BoxGameServer:OnLoadResources()
	soldierAsset = nil
	soldierBlueprint = nil
	weapon = nil
	weaponAtt0 = nil
	weaponAtt1 = nil
	drPepper = nil
end

function BoxGameServer:OnLevelLoaded(p_Map, p_GameMode, p_Round)
	self.m_LevelLoaded = true
	for x=1, m_AreaWidth do
		for y=1, m_AreaHeight do
			for z=1, m_AreaLength do
				self:SpawnBox(x, y, z)
			end
		end
	end

	self:SpawnWalls()
end

function BoxGameServer:OnChat(player, recipientMask, message)
	if message == '' then
		return
	end

	print('Chat: ' .. message)

	local parts = message:split(' ')

	if parts[1] == 'spawn' then
		self:SpawnPlayer(player)
	end

	if parts[1] == '!start' then
		for _, l_InstanceId in pairs(m_DisabledBoxes) do
			Events:Dispatch('BlueprintManager:EnableEntityByEntityId', l_InstanceId, true)
		end

		m_DisabledBoxes = {}

		for _, l_Player in pairs(PlayerManager:GetPlayers()) do
			if l_Player.soldier ~= nil then
				l_Player.soldier:Kill(false)
			end
		end

		for _, l_Player in pairs(PlayerManager:GetPlayers()) do
			self:SpawnPlayer(l_Player)
		end
	end
end

function BoxGameServer:OnEntityCreateFromBlueprint(p_Hook, p_Blueprint, p_Transform, p_Variation, p_Parent )
	if not self.m_LevelLoaded then
		p_Hook:Call()
		return
	end

	local entities = p_Hook:Call()

	if entities == nil then
		return
	end

	if p_Blueprint.instanceGuid == m_BoxInstanceGuid then
		for k,entity in pairs(entities) do
			if entity:Is('ServerPhysicsEntity') then
				entity = PhysicsEntity(entity)

				entity:RegisterCollisionCallback(function(entity, info)
					if info.entity:Is("ServerGrenadeEntity") then
						info.entity:Destroy()

						local instanceId = entity.instanceId
						Events:Dispatch('BlueprintManager:EnableEntityByEntityId', instanceId, false)

						table.insert(m_DisabledBoxes, instanceId)
					end
					
				end)
			end
		end
	end
end

function BoxGameServer:OnPartitionLoaded(p_Partition)
	local instances = p_Partition.instances

	for _, instance in pairs(instances) do
		if instance.typeInfo.name == 'VeniceSoldierCustomizationAsset' then
			local asset = VeniceSoldierCustomizationAsset(instance)

			if asset.name == 'Gameplay/Kits/RURecon' then
				print('Found soldier customization asset ' .. asset.name)
				soldierAsset = asset
			end
		end

		if instance.typeInfo.name == 'SoldierBlueprint' then
			soldierBlueprint = SoldierBlueprint(instance)
			print('Found soldier blueprint ' .. soldierBlueprint.name)
		end

		if instance.typeInfo.name == 'SoldierWeaponUnlockAsset' then
			local asset = SoldierWeaponUnlockAsset(instance)

			if asset.name == 'Weapons/M416/U_M416' then
				print('Found soldier weapon unlock asset ' .. asset.name)
				weapon = asset
			elseif asset.name == 'Weapons/Gadgets/M320/U_M320_LVG' then
				print('Found soldier weapon unlock asset ' .. asset.name)
				M320 = asset
			end
		end
		if instance.typeInfo.name == 'UnlockAsset' then
			local asset = UnlockAsset(instance)

			if asset.name == 'Weapons/M416/U_M416_ACOG' then
				print('Found weapon unlock asset ' .. asset.name)
				weaponAtt0 = asset
			end

			if asset.name == 'Weapons/M416/U_M416_Silencer' then
				print('Found weapon unlock asset ' .. asset.name)
				weaponAtt1 = asset
			end

			if asset.name == 'Persistence/Unlocks/Soldiers/Visual/MP/RU/MP_RU_Recon_Appearance_DrPepper' then
				print('Found appearance asset ' .. asset.name)
				drPepper = asset
			end
		end
	end
end

function BoxGameServer:SpawnPlayer(player)
	if player == nil or player.soldier ~= nil then
		print('Player must be dead to spawn')
		return
	end

	local transform = LinearTransform(
		Vec3(1, 0, 0),
		Vec3(0, 1, 0),
		Vec3(0, 0, 1),
		Vec3(0, 0, 0)
	)

	transform.trans.x = m_StartingPos.x + m_AreaWidth * m_BoxWidth / 2
	transform.trans.y = 1 +  m_StartingPos.y + m_AreaHeight * m_BoxHeight

	if player.teamId == TeamId.Team1 then
		transform.trans.z = m_StartingPos.z + m_AreaLength * m_BoxWidth / 4
	elseif player.teamId == TeamId.Team2 then
		transform.trans.z =m_StartingPos.z + m_AreaLength * 3 *m_BoxWidth / 4
	else
		return
	end

	print('Setting soldier primary weapon')
	player:SelectWeapon(WeaponSlot.WeaponSlot_0, weapon, { weaponAtt0, weaponAtt1 })
	player:SelectWeapon(WeaponSlot.WeaponSlot_1, M320, {})

	print('Setting soldier class and appearance')
	player:SelectUnlockAssets(soldierAsset, { drPepper })

	print('Creating soldier')
	local soldier = player:CreateSoldier(soldierBlueprint, transform)

	if soldier == nil then
		print('Failed to create player soldier')
		return
	end

	print('Spawning soldier')
	player:SpawnSoldierAt(soldier, transform, CharacterPoseType.CharacterPoseType_Stand)


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
			Vec3(m_StartingPos.x + (m_AreaWidth * m_BoxWidth) / 2.0 + 0.5, m_StartingPos.y + (m_AreaHeight * m_BoxHeight) + 3.2, m_StartingPos.z + (m_AreaLength * m_BoxWidth) / 2.0 + 0.5)
		)
	Events:Dispatch('BlueprintManager:SpawnBlueprint', "wall1", m_WallPartitionGuid, m_WallInstanceGuid, tostring(s_Transform), nil)

	--Flip the second wall 180º
	s_Transform.left.x = -1
	s_Transform.forward.z = -1

	Events:Dispatch('BlueprintManager:SpawnBlueprint', "wall2", m_WallPartitionGuid, m_WallInstanceGuid, tostring(s_Transform), nil)
end

g_BoxGameServer = BoxGameServer()

