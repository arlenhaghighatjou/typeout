local players = game:GetService("Players")
local replicatedstorage = game:GetService("ReplicatedStorage")
local runservice = game:GetService("RunService")

local player = players.LocalPlayer
local guis = require(script.Parent.Guis)
local shared = replicatedstorage:WaitForChild("Shared")
local lobbyaction = shared:WaitForChild("LobbyAction")
local lobbystate = shared:WaitForChild("LobbyState")

local orbitcenter = Vector3.new(0, 0, -15)
local orbitradius = 300
local orbitheight = 170
local orbitspeed = 0.05
local attributewait = 5
local modetext = { public = "public", friends = "friends only", private = "private" }

return function()
	local gui = guis.get("Lobby")
	local menu = gui:WaitForChild("Menu")
	local template = gui:WaitForChild("Row")
	local notice = menu:WaitForChild("Notice")

	local party = menu:WaitForChild("Party")
	local partyheader = party:WaitForChild("Header")
	local partylist = party:WaitForChild("List")
	local primary = party:WaitForChild("Primary")
	local publicbutton = party:WaitForChild("Public")
	local startbutton = party:WaitForChild("Start")

	local games = menu:WaitForChild("Games")
	local gameslist = games:WaitForChild("List")
	local empty = games:WaitForChild("Empty")

	local state = nil
	local inlobby = false
	local angle = 0

	local function send(action: string, value: any?)
		lobbyaction:FireServer(action, value)
	end

	local function clear(list: Instance)
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
	end

	local function addrow(list: Instance, order: number, text: string, action: string?, value: any?)
		local row = template:Clone()
		local label = row:WaitForChild("Text")
		local join = row:WaitForChild("Join")
		row.LayoutOrder = order
		label.Text = text
		if action then
			join.Activated:Connect(function()
				send(action, value)
			end)
		else
			join.Visible = false
		end
		row.Visible = true
		row.Parent = list
	end

	local function render()
		if not state then
			return
		end
		clear(partylist)
		clear(gameslist)

		local mine = nil
		for _, entry in state.parties do
			if entry.id == state.mine then
				mine = entry
			end
		end

		if mine then
			partyheader.Text = "your party"
			for index, name in mine.members do
				addrow(partylist, index, if index == 1 then name .. " (leader)" else name)
			end
			primary.Text = "leave party"
			publicbutton.Visible = state.leading
			startbutton.Visible = state.leading
			publicbutton.Text = modetext[mine.mode] or "public"
		else
			partyheader.Text = "parties"
			for index, entry in state.parties do
				addrow(partylist, index, entry.leader .. "'s party - " .. #entry.members, "join", entry.id)
			end
			primary.Text = "create party"
			publicbutton.Visible = false
			startbutton.Visible = false
		end

		for index, entry in state.games do
			local text = entry.host .. "'s game - round " .. entry.round .. " - " .. entry.players .. " players"
			if entry.mode == "friends" then
				text = text .. " (friends)"
			end
			addrow(gameslist, index, text, "joingame", entry.id)
		end
		empty.Visible = #state.games == 0
		notice.Text = state.notice or ""
	end

	primary.Activated:Connect(function()
		if state and state.mine then
			send("leave")
		else
			send("create")
		end
	end)
	publicbutton.Activated:Connect(function()
		send("mode")
	end)
	startbutton.Activated:Connect(function()
		send("start")
	end)

	lobbystate.OnClientEvent:Connect(function(newstate)
		if typeof(newstate) == "table" then
			state = newstate
			render()
		end
	end)

	runservice:BindToRenderStep("LobbyCamera", Enum.RenderPriority.Camera.Value + 1, function(delta)
		if not inlobby then
			return
		end
		angle += delta * orbitspeed
		local camera = workspace.CurrentCamera
		local position = orbitcenter
			+ Vector3.new(math.cos(angle) * orbitradius, orbitheight, math.sin(angle) * orbitradius)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(position, orbitcenter)
	end)

	local function update()
		local ingame = player:GetAttribute("InGame") == true
		if ingame and inlobby then
			inlobby = false
			gui.Enabled = false
			workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		elseif not ingame and not inlobby then
			inlobby = true
			gui.Enabled = true
			player.CameraMode = Enum.CameraMode.Classic
			send("sync")
		end
	end

	local deadline = os.clock() + attributewait
	while player:GetAttribute("InGame") == nil and os.clock() < deadline do
		task.wait(0.1)
	end
	player:GetAttributeChangedSignal("InGame"):Connect(update)
	update()
end
