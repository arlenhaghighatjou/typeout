local players = game:GetService("Players")
local replicatedstorage = game:GetService("ReplicatedStorage")
local startergui = game:GetService("StarterGui")

local player = players.LocalPlayer
local guis = require(script.Parent.Guis)

return function()
	local shared = replicatedstorage:WaitForChild("Shared")
	local round = shared:WaitForChild("Round")
	local alive = shared:WaitForChild("Alive")
	local lobbyaction = shared:WaitForChild("LobbyAction")

	local gui = guis.get("RoundHud")
	local corner = gui:WaitForChild("Corner")
	local roundlabel = corner:WaitForChild("Round")
	local alivelabel = corner:WaitForChild("Alive")
	local leave = corner:WaitForChild("Leave")

	local function refresh()
		roundlabel.Text = "round " .. round.Value
		alivelabel.Text = alive.Value .. " players alive"
		gui.Enabled = player:GetAttribute("InGame") == true
	end

	round.Changed:Connect(refresh)
	alive.Changed:Connect(refresh)
	player:GetAttributeChangedSignal("InGame"):Connect(refresh)
	refresh()

	leave.Activated:Connect(function()
		lobbyaction:FireServer("leavegame")
	end)

	pcall(function()
		startergui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
end
