class 'BoxGameShared'

require '__shared/enums'
require '__shared/config'

local m_AssetsGuids = {
	m320Projectile = {instanceGuid = Guid("CEC6D381-72DE-B7D4-E998-0D566E0575C6"), partitionGuid = Guid("D37476C2-3A86-11E0-BC25-D51252D5A427")},
	m320Projectile2 = {instanceGuid = Guid("393E4094-C2A2-4DF2-B977-F82E6974A8CB"), partitionGuid = Guid("FD79A08F-F108-4751-B2C0-6C47397133B5")},
	aimingController = {instanceGuid = Guid("58DFC3A8-A7D6-4AE9-8226-BA627A84809A"), partitionGuid = Guid("8C7B467F-8790-448B-9365-C70825D61486")},
}

function BoxGameShared:__init()
	print("Initializing BoxGameShared")
	self:RegisterEvents()
end

function BoxGameShared:RegisterEvents()
	Events:Subscribe('Partition:Loaded', self, self.OnPartitionLoaded)
end

function BoxGameShared:OnPartitionLoaded(p_Partition)
	if p_Partition == nil then
		m_Logger:Error('Partition is nil')
		return
	end

	local s_Instances = p_Partition.instances

	for _, s_Instance in pairs(s_Instances) do
		if s_Instance ~= nil then
			if s_Instance.instanceGuid == m_AssetsGuids.m320Projectile.instanceGuid or
			  	s_Instance.instanceGuid == m_AssetsGuids.m320Projectile2.instanceGuid then
				print('Modifying m320 projectile')
				local s_Proj = _G[s_Instance.typeInfo.name](s_Instance)
				s_Proj:MakeWritable()
				s_Proj.trailEffect = nil
				s_Proj.gravity = 0
				s_Proj.explosion = nil
			elseif s_Instance.instanceGuid == m_AssetsGuids.aimingController.instanceGuid then
				print('Modifying aimingController')
				local s_AC = _G[s_Instance.typeInfo.name](s_Instance)
				s_AC:MakeWritable()
				local stand = AimingPoseData(s_AC.standPose)
				local crouch = AimingPoseData(s_AC.crouchPose)

				-- Increase pitch angle, so you can shoot straight down with the m320
				stand.minimumPitch = -89
				stand.maximumPitch = 89

				crouch.minimumPitch = -89
				crouch.maximumPitch = 89
			end
		end
	end
end

g_BoxGameShared = BoxGameShared()

