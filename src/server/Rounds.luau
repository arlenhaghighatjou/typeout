local players = game:GetService("Players")
local replicatedstorage = game:GetService("ReplicatedStorage")

local shared = replicatedstorage.Shared
local announce = shared.Announce
local roundvalue = shared.Round
local alivevalue = shared.Alive

local minplayers = 2
local intermission = 5
local winnerdelay = 2
local loadtimeout = 10
local bodydelay = 2
local grace = 3
local roundlength = 180
local warnings = { 60, 30, 10 }

local inround = false
local alive: { [Player]: boolean } = {}
local loading: { [Player]: boolean } = {}
local out: { [Player]: boolean } = {}

local maps: { any } = {}
local mapindex = 0
local currentfocus: Instance? = nil
local lobbyfocus: Instance? = nil

local function findmaps()
	local first = workspace:WaitForChild("Spawns")
	table.insert(maps, { name = "islands", spawns = first })
	local extra = {}
	for _, child in workspace:GetChildren() do
		local spawns = child:IsA("Folder") and child:FindFirstChild("Spawns")
		if spawns then
			table.insert(extra, { name = string.lower(child.Name), spawns = spawns })
		end
	end
	table.sort(extra, function(a, b)
		return a.name < b.name
	end)
	for _, entry in extra do
		table.insert(maps, entry)
	end
	lobbyfocus = first:FindFirstChildWhichIsA("SpawnLocation")
end

local function usemap(index: number)
	local current = maps[index]
	for _, entry in maps do
		for _, spawn in entry.spawns:GetChildren() do
			if spawn:IsA("SpawnLocation") then
				spawn.Enabled = entry == current
			end
		end
	end
	mapindex = index
	currentfocus = current.spawns:FindFirstChildWhichIsA("SpawnLocation")
	return current
end

local function ingame(player: Player): boolean
	return player:GetAttribute("InGame") == true
end

local function participants(): { Player }
	local list = {}
	for _, player in players:GetPlayers() do
		if ingame(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function living(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function countalive(): number
	local count = 0
	if inround then
		for _ in alive do
			count += 1
		end
	else
		for _, player in participants() do
			if living(player) then
				count += 1
			end
		end
	end
	return count
end

local function refresh()
	alivevalue.Value = countalive()
	for _, player in players:GetPlayers() do
		if not ingame(player) then
			player:SetAttribute("Alive", false)
		elseif inround then
			player:SetAttribute("Alive", alive[player] == true)
		else
			player:SetAttribute("Alive", living(player))
		end
	end
end

local function clearbody(player: Player)
	local character = player.Character
	player.ReplicationFocus = currentfocus
	if character then
		player.Character = nil
		character:Destroy()
	end
end

local function removebody(player: Player)
	local character = player.Character
	if not character then
		return
	end
	task.delay(bodydelay, function()
		if player.Character == character then
			clearbody(player)
		end
	end)
end

local function load(player: Player)
	if loading[player] or not ingame(player) then
		return
	end
	loading[player] = true
	task.spawn(function()
		player:SetAttribute("TypedOut", nil)
		player.ReplicationFocus = nil
		pcall(function()
			player:LoadCharacter()
		end)
		loading[player] = nil
		if inround and player.Parent and ingame(player) and living(player) then
			alive[player] = true
		end
		refresh()
	end)
end

local function loadall()
	local pending = 0
	for _, player in participants() do
		pending += 1
		task.spawn(function()
			player:SetAttribute("TypedOut", nil)
			player.ReplicationFocus = nil
			pcall(function()
				player:LoadCharacter()
			end)
			pending -= 1
		end)
	end
	local deadline = os.clock() + loadtimeout
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

local function sweep()
	for player in alive do
		if not player.Parent or not ingame(player) then
			alive[player] = nil
		elseif not living(player) then
			alive[player] = nil
			out[player] = true
			if not player:GetAttribute("TypedOut") then
				announce:FireAllClients(player.DisplayName .. " died")
			end
			removebody(player)
		end
	end
	refresh()
end

local function onplayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		if not out[player] and ingame(player) then
			return
		end
		task.defer(function()
			if (out[player] or not ingame(player)) and player.Character == character then
				clearbody(player)
			end
		end)
	end)

	player:GetAttributeChangedSignal("InGame"):Connect(function()
		if ingame(player) then
			load(player)
		else
			alive[player] = nil
			out[player] = nil
			clearbody(player)
			player.ReplicationFocus = lobbyfocus
			refresh()
		end
	end)

	load(player)
end

local function run()
	while true do
		while #participants() < minplayers do
			out = {}
			for _, player in participants() do
				if not living(player) then
					load(player)
				end
			end
			refresh()
			task.wait(2)
		end

		out = {}
		local map = usemap(mapindex % #maps + 1)
		loadall()
		alive = {}
		for _, player in participants() do
			if player.Character then
				alive[player] = true
			end
		end
		roundvalue.Value += 1
		inround = true
		refresh()
		announce:FireAllClients("round " .. roundvalue.Value .. " started on " .. map.name)
		task.wait(grace)

		local started = os.clock()
		local warned = {}
		local timedout = false
		while true do
			sweep()
			if countalive() <= 1 then
				break
			end
			if roundlength > 0 then
				local left = roundlength - (os.clock() - started)
				if left <= 0 then
					timedout = true
					break
				end
				for _, mark in warnings do
					if mark < roundlength and left <= mark and not warned[mark] then
						warned[mark] = true
						announce:FireAllClients(mark .. " seconds left")
					end
				end
			end
			task.wait(0.25)
		end

		local winner = if timedout then nil else next(alive)
		inround = false
		alive = {}
		refresh()

		if timedout then
			announce:FireAllClients("time is up")
		end
		announce:FireAllClients("round is over")
		task.wait(winnerdelay)
		if winner and winner.Parent then
			announce:FireAllClients("winner is " .. winner.DisplayName)
		else
			announce:FireAllClients("nobody won")
		end
		task.wait(intermission)
	end
end

return function()
	players.CharacterAutoLoads = false
	findmaps()
	usemap(1)
	mapindex = 0

	players.PlayerAdded:Connect(onplayer)
	players.PlayerRemoving:Connect(function(player)
		alive[player] = nil
		loading[player] = nil
		out[player] = nil
		refresh()
	end)
	for _, player in players:GetPlayers() do
		onplayer(player)
	end
	task.spawn(run)
end
