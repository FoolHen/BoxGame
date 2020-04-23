class 'BoxGameClient'


function BoxGameClient:__init()
	print("Initializing BoxGameClient")
	self:RegisterEvents()
end

function BoxGameClient:RegisterEvents()
	Hooks:Install('UI:PushScreen', 999, self, self.OnPushScreen)
	Events:Subscribe('Engine:Message', self, self.OnEngineMessage)
end

function BoxGameClient:OnEngineMessage(p_Message) 
	if p_Message.type == MessageType.CoreEnteredIngameMessage then
		NetEvents:SendLocal('BoxGame:PlayerReady')
	end
end

function BoxGameClient:OnPushScreen(p_Hook, p_Screen, p_GraphPriority, p_ParentGraph)

	local s_Screen = UIGraphAsset(p_Screen)
	if string.find(s_Screen.name:lower(), "spawnscreen") or
		s_Screen.name == 'UI/Flow/Screen/SpawnButtonScreen' then
		p_Hook:Return(nil)
		return
	end

	if  s_Screen.name == 'UI/Flow/Screen/HudScreen' or
			s_Screen.name == 'UI/Flow/Screen/HudMPScreen' then

		-- We create a copy to pass to the hook
		local s_Clone = p_Screen:Clone(p_Screen.instanceGuid)
		local s_ScreenClone = UIGraphAsset(s_Clone)

		local s_NodeCount = #s_Screen.nodes

		for i = s_NodeCount, 1, -1 do
			local s_Node = s_Screen.nodes[i]

			-- Remove the greande red alert.
			if s_Node ~= nil then
				if  s_Node.name == 'DamageIndicator' or
					s_Node.name == 'InteractionManager' or
					s_Node.name == 'AlertManager' or
					s_Node.name == 'ScaleformDisableNestedMasks' then

					s_ScreenClone.nodes:erase(i)
				end
			end
		end

		p_Hook:Pass(s_ScreenClone, p_GraphPriority, p_ParentGraph)
		return
	end
end

g_BoxGameClient = BoxGameClient()

