local replicatedstorage = game:GetService("ReplicatedStorage")
local textchatservice = game:GetService("TextChatService")

local announce = replicatedstorage:WaitForChild("Shared"):WaitForChild("Announce")

return function()
	local channel = textchatservice:WaitForChild("TextChannels"):WaitForChild("RBXGeneral")

	announce.OnClientEvent:Connect(function(text)
		if typeof(text) ~= "string" then
			return
		end
		channel:DisplaySystemMessage(text)
	end)
end
