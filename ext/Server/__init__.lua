class 'BoxGameServer'

local Round = require 'round'
local m_Round = Round(300, 2, 4, 3, true)

-- In this table we keep guids of weapons, attachments and soldier info to spawn soldiers later on.
local m_AssetsGuids = {
	box = {instanceGuid = Guid("071572A1-FC46-308E-A495-6EE575154438"), partitionGuid = Guid("8D3FAB68-B78E-11E0-A405-EA03C5FF7246")},
	wall = {instanceGuid = Guid("4399B484-5158-E694-262F-828DDC325BA3"), partitionGuid = Guid("55EE9583-5C62-11E0-8D20-91499D5EE2D1")},
	soldierAsset = {instanceGuid = Guid("84A4BE20-B110-42E5-9588-365643624525"), partitionGuid = Guid("CE67CB9D-5F04-4428-B8E4-B10C5B7F4E6C")},
	soldierBlueprint = {instanceGuid = Guid("261E43BF-259B-41D2-BF3B-9AE4DDA96AD2"), partitionGuid = Guid("F256E142-C9D8-4BFE-985B-3960B9E9D189")},
	m416 = {instanceGuid = Guid("3A6B6A16-E5A1-33E0-5B53-56E77833DAF4"), partitionGuid = Guid("8CEB0AB8-434C-11E0-895C-C63F7BF240ED")},
	m320 = {instanceGuid = Guid("E3123B4B-37E9-464D-8DFE-C3C8ADB43645"), partitionGuid = Guid("605553B5-ECD7-47B2-929F-9082C4DFE78C")},
	acogAtt = {instanceGuid = Guid("907D25C8-C981-9C87-B343-799314995E04"), partitionGuid = Guid("ABC924BF-433F-11E0-9C5D-9327CF10E42D")},
	silencerAtt = {instanceGuid = Guid("B1775312-0421-666A-B6E5-0C23C9CAF1A0"), partitionGuid = Guid("4B60750C-4340-11E0-9C5D-9327CF10E42D")},
	drPepperCammo = {instanceGuid = Guid("2C86F862-3FEE-4231-804D-BBB769E7A78B"), partitionGuid = Guid("B06E6037-4797-47A5-8917-2772EC79B3C5")}
}

-- Playable area dimensions.
local m_AreaWidth = 10
local m_AreaLength = 20
local m_AreaHeight = 10

local m_StartingPos = { x = 0, y = 100, z = 0}

-- These are the sizes of the box. It's 1m wide and 1.29m tall.
local m_BoxWidth = 1
local m_BoxHeight = 1.29

local m_DisabledBoxes = {}
local m_LevelLoaded = false

local m_PendingRestart = false

function BoxGameServer:__init()
	print("Initializing BoxGameServer")
	self:RegisterEvents()
end

function BoxGameServer:RegisterEvents()
	Events:Subscribe('Level:Loaded', self, self.OnLevelLoaded)
	Events:Subscribe('Player:Chat', self, self.OnChat)
	Events:Subscribe('UpdateManager:Update', self, self.OnUpdateManager)
	Events:Subscribe('Player:Killed', self, self.OnPlayerKilled)

	Hooks:Install('EntityFactory:CreateFromBlueprint', 999, self, self.OnEntityCreateFromBlueprint)

	Events:Subscribe('Round:PreRoundStart', self, self.OnPreRoundStarted)
	Events:Subscribe('Round:RoundStart', self, self.OnRoundStarted)
end

function BoxGameServer:OnUpdateManager(p_Delta, p_Pass)
	if p_Pass == UpdatePass.UpdatePass_PreFrame then
		if m_PendingRestart then
			m_PendingRestart = false
			self:SetLevel()
		end
	end
end

function BoxGameServer:OnPlayerKilled(p_Victim, p_Inflictor, p_Position, p_Weapon, p_RoadKill, p_HeadShot, p_VictimInReviveState)
	if p_Victim == nil then
		return
	end

	if m_Round:getRoundState() ~= RoundState.Running then
		return
	end

	local s_AlivePlayers = 0
	local s_Player = nil
	for _, l_Player in pairs(PlayerManager:GetPlayers()) do
		if l_Player.alive then
			s_Player = l_Player
			s_AlivePlayers = s_AlivePlayers + 1
		end
	end

	if s_AlivePlayers == 1 then
		ChatManager:SendMessage('Player ' .. s_Player.name .. ' wins!')
	elseif s_AlivePlayers == 0 then
		print('All players dead, this shouldn\'t happen.')
	end

	m_Round:endRound()

end

function BoxGameServer:OnPreRoundStarted()
	m_PendingRestart = true
	for _, l_Player in pairs(PlayerManager:GetPlayers()) do
		self:SetInputRestrictions(l_Player, false)
	end
end

function BoxGameServer:OnRoundStarted()

	for _, l_Player in pairs(PlayerManager:GetPlayers()) do
		self:SetInputRestrictions(l_Player, true)
	end
end

function BoxGameServer:SetInputRestrictions(p_Player, p_Enabled)
	p_Player:EnableInput(EntryInputActionEnum.EIAFire, p_Enabled)
	p_Player:EnableInput(EntryInputActionEnum.EIAThrottle, p_Enabled)
	p_Player:EnableInput(EntryInputActionEnum.EIAStrafe, p_Enabled)
	p_Player:EnableInput(EntryInputActionEnum.EIABrake, p_Enabled)
	p_Player:EnableInput(EntryInputActionEnum.EIAToggleParachute, false)
end

function BoxGameServer:OnLevelLoaded(p_Map, p_GameMode, p_Round)
	m_LevelLoaded = true

	-- Spawn all boxes.
	for x = 1, m_AreaWidth do
		for y = 1, m_AreaHeight do
			for z = 1, m_AreaLength do
				self:SpawnBox(x, y, z)
			end
		end
	end
	
	-- Spawn the walls that divide the top of the boxes in 2 spawn areas.
	self:SpawnWalls()
end

function BoxGameServer:OnChat(player, recipientMask, message)
	if message == 'pos' then
		print(player.soldier.transform.trans)
	end

	if message == 'start' then
		self:SetLevel()
	end
end

function BoxGameServer:SetLevel()
	-- Enable all disabled entities.
	for _, l_InstanceId in pairs(m_DisabledBoxes) do
		Events:Dispatch('BlueprintManager:EnableEntityByEntityId', l_InstanceId, true)
	end

	-- Clear table of disabled entities.
	m_DisabledBoxes = {}

	-- If there's any player alive or down we kill him.
	for _, l_Player in pairs(PlayerManager:GetPlayers()) do
		if l_Player.soldier ~= nil then
			l_Player.soldier:Kill(false)
		elseif l_Player.corpse ~= nil then
			l_Player.corpse:ForceDead()
		end
	end

	-- Spawn players that are ready.
	for _, l_PlayerGuid in pairs(m_Round:getPlayersReady()) do
		local s_Player = PlayerManager:GetPlayerByGuid(l_PlayerGuid)

		if s_Player ~= nil then
			self:SpawnPlayer(s_Player)
		end
	end
end

function BoxGameServer:OnEntityCreateFromBlueprint(p_Hook, p_Blueprint, p_Transform, p_Variation, p_Parent )
	-- Ignore if the level is loading.
	if not m_LevelLoaded then
		return
	end

	-- We only care about the box instance, otherwise we dont mess with the hook.
	if p_Blueprint.instanceGuid ~= m_AssetsGuids.box.instanceGuid then
		return
	end

	-- Call the hook and save the entities it created with the blueprint.
	local entityBus = p_Hook:Call()
	if entityBus == nil or entityBus.entities == nil then
		return
	end

	-- Loop through all the entities. Blueprints can spawn more than one entity. In this case we care about the physic entity, so we can
	-- assign a callback to it.
	for _, entity in pairs(entityBus.entities) do
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

	local weapon = ResourceManager:FindInstanceByGuid(m_AssetsGuids.m416.partitionGuid, m_AssetsGuids.m416.instanceGuid)
	local att0 = ResourceManager:FindInstanceByGuid(m_AssetsGuids.acogAtt.partitionGuid, m_AssetsGuids.acogAtt.instanceGuid)
	local att1 = ResourceManager:FindInstanceByGuid(m_AssetsGuids.silencerAtt.partitionGuid, m_AssetsGuids.silencerAtt.instanceGuid)
	local grenadeLauncher = ResourceManager:FindInstanceByGuid(m_AssetsGuids.m320.partitionGuid, m_AssetsGuids.m320.instanceGuid)
	local soldierAsset = ResourceManager:FindInstanceByGuid(m_AssetsGuids.soldierAsset.partitionGuid, m_AssetsGuids.soldierAsset.instanceGuid)
	local soldierBlueprint = ResourceManager:FindInstanceByGuid(m_AssetsGuids.soldierBlueprint.partitionGuid, m_AssetsGuids.soldierBlueprint.instanceGuid)
	local drPepper = ResourceManager:FindInstanceByGuid(m_AssetsGuids.drPepperCammo.partitionGuid, m_AssetsGuids.drPepperCammo.instanceGuid)

	local rifleSlot = WeaponSlot.WeaponSlot_0
	local grenadeLauncherSlot = WeaponSlot.WeaponSlot_1


	-- Setting soldier primary weapon with its attachments and the M320 in the second slot.
	player:SelectWeapon(rifleSlot, SoldierWeaponUnlockAsset(weapon), { UnlockAsset(att0), UnlockAsset(att1) })
	player:SelectWeapon(grenadeLauncherSlot, SoldierWeaponUnlockAsset(grenadeLauncher), {})

	-- Setting soldier class and appearance
	player:SelectUnlockAssets(VeniceSoldierCustomizationAsset(soldierAsset), { UnlockAsset(drPepper) })

	-- Creating soldier at the position we calculated.
	local soldier = player:CreateSoldier(SoldierBlueprint(soldierBlueprint), transform)

	if soldier == nil then
		print('Failed to create player soldier')
		return
	end

	-- Spawning soldier
	player:SpawnSoldierAt(soldier, transform, CharacterPoseType.CharacterPoseType_Stand)

	-- Set the ammo of the M320 to 999 and remove additional ammo so you cant reload.
	if player.soldier.weaponsComponent and player.soldier.weaponsComponent.weapons then
		soldierWeapon = SoldierWeapon(player.soldier.weaponsComponent.weapons[grenadeLauncherSlot + 1]) -- lua is 1 indexed
		soldierWeapon.primaryAmmo = 999
		soldierWeapon.secondaryAmmo = 0
	end
end

function BoxGameServer:SpawnBox(p_XOffset, p_YOffset, p_ZOffset)
	local s_Transform = LinearTransform(
			Vec3(1,0,0),
			Vec3(0,1,0),
			Vec3(0,0,1),
			Vec3(m_StartingPos.x + p_XOffset * m_BoxWidth, m_StartingPos.y + p_YOffset * m_BoxHeight, m_StartingPos.z + p_ZOffset * m_BoxWidth)
		)
	Events:Dispatch('BlueprintManager:SpawnBlueprint', p_XOffset..":"..p_YOffset..":"..p_ZOffset, m_AssetsGuids.box.partitionGuid, m_AssetsGuids.box.instanceGuid, tostring(s_Transform), nil)
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
	Events:Dispatch('BlueprintManager:SpawnBlueprint', "wall1", m_AssetsGuids.wall.partitionGuid, m_AssetsGuids.wall.instanceGuid, tostring(s_Transform), nil)

	-- We need to spawn a second wall and flip it 180º, as the other side of the wall doesnt have texture so you can see through the other side.
	s_Transform.left.x = -1
	s_Transform.forward.z = -1

	Events:Dispatch('BlueprintManager:SpawnBlueprint', "wall2", m_AssetsGuids.wall.partitionGuid, m_AssetsGuids.wall.instanceGuid, tostring(s_Transform), nil)
end

g_BoxGameServer = BoxGameServer()

