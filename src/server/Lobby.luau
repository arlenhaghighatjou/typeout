local players = game:GetService("Players")
local replicatedstorage = game:GetService("ReplicatedStorage")
local teleportservice = game:GetService("TeleportService")

local games = require(script.Parent.Games)

local shared = replicatedstorage.Shared
local lobbyaction = shared.LobbyAction
local lobbystate = shared.LobbyState

local maxparty = 8
local pushinterval = 5
local actioncooldown = 0.2
local nextmode = { public = "friends", friends = "private", private = "public" }

local parties: { [number]: any } = {}
local partyof: { [Player]: any } = {}
local lastaction: { [Player]: number } = {}
local friendcache: { [Player]: { [number]: boolean } } = {}
local nextid = 0

local function inlobby(player: Player): boolean
	return player:GetAttribute("InGame") ~= true
end

local function isfriend(player: Player, userid: number): boolean
	if player.UserId == userid then
		return true
	end
	local known = friendcache[player]
	if not known then
		known = {}
		friendcache[player] = known
	end
	if known[userid] == nil then
		local ok, result = pcall(function()
			return player:IsFriendsWith(userid)
		end)
		known[userid] = ok and result == true
	end
	return known[userid]
end

local function allowed(player: Player, mode: string, ownerid: number): boolean
	if mode == "public" then
		return true
	elseif mode == "friends" then
		return isfriend(player, ownerid)
	end
	return player.UserId == ownerid
end

local function buildstate(player: Player)
	local mine = partyof[player]

	local partylist = {}
	for _, entry in parties do
		if entry == mine or allowed(player, entry.mode, entry.leader.UserId) then
			local names = {}
			for _, member in entry.members do
				table.insert(names, member.DisplayName)
			end
			table.insert(partylist, {
				id = entry.id,
				leader = entry.leader.DisplayName,
				members = names,
				mode = entry.mode,
			})
		end
	end
	table.sort(partylist, function(a, b)
		return a.id < b.id
	end)

	local gamelist = {}
	for _, entry in games.list() do
		if allowed(player, entry.mode, entry.hostid) then
			table.insert(gamelist, {
				id = entry.id,
				host = entry.host,
				mode = entry.mode,
				players = entry.players,
				round = entry.round,
			})
		end
	end

	return {
		parties = partylist,
		mine = if mine then mine.id else nil,
		leading = mine ~= nil and mine.leader == player,
		games = gamelist,
	}
end

local function push(player: Player, notice: string?)
	if not player.Parent then
		return
	end
	local state = buildstate(player)
	state.notice = notice
	lobbystate:FireClient(player, state)
end

local function pushall()
	for _, player in players:GetPlayers() do
		if inlobby(player) then
			task.spawn(push, player)
		end
	end
end

local function leave(player: Player)
	local entry = partyof[player]
	if not entry then
		return
	end
	partyof[player] = nil
	local index = table.find(entry.members, player)
	if index then
		table.remove(entry.members, index)
	end
	if #entry.members == 0 then
		parties[entry.id] = nil
	elseif entry.leader == player then
		entry.leader = entry.members[1]
	end
end

local function disband(entry)
	parties[entry.id] = nil
	for _, member in entry.members do
		partyof[member] = nil
	end
end

local function tell(members: { Player }, notice: string)
	for _, member in members do
		task.spawn(push, member, notice)
	end
end

local function startgame(player: Player)
	local entry = partyof[player]
	if not entry or entry.leader ~= player then
		return
	end
	local members = table.clone(entry.members)

	if games.studio then
		games.setlocal(player, entry.mode)
		disband(entry)
		for _, member in members do
			member:SetAttribute("InGame", true)
		end
		return
	end

	tell(members, "starting game...")
	local code = games.reserve(player, entry.mode, #members)
	if not code then
		tell(members, "could not start a game, try again")
		return
	end

	local going = {}
	for _, member in members do
		if member.Parent then
			table.insert(going, member)
		end
	end
	disband(entry)
	local ok = pcall(function()
		teleportservice:TeleportToPrivateServer(games.targetplace, code, going)
	end)
	if not ok then
		tell(going, "could not start a game, try again")
	end
end

local function joingame(player: Player, id: string)
	local entry = games.find(id)
	if not entry or not allowed(player, entry.mode, entry.hostid) then
		push(player, "that game is gone")
		return
	end

	if games.studio then
		leave(player)
		player:SetAttribute("InGame", true)
		return
	end

	local code = games.code(id)
	if not code then
		push(player, "that game is gone")
		return
	end
	leave(player)
	push(player, "joining game...")
	local ok = pcall(function()
		teleportservice:TeleportToPrivateServer(games.targetplace, code, { player })
	end)
	if not ok then
		push(player, "could not join, try again")
	end
end

local function leavegame(player: Player)
	if games.ismatch then
		local place = games.lobbyplace()
		if place then
			pcall(function()
				teleportservice:Teleport(place, player)
			end)
		end
	elseif player:GetAttribute("InGame") then
		player:SetAttribute("InGame", false)
	end
end

local function onaction(player: Player, action: any, value: any)
	if typeof(action) ~= "string" then
		return
	end
	local now = os.clock()
	if now - (lastaction[player] or 0) < actioncooldown then
		return
	end
	lastaction[player] = now

	if action == "leavegame" then
		leavegame(player)
		pushall()
		return
	end
	if not inlobby(player) then
		return
	end

	if action == "create" then
		if not partyof[player] then
			nextid += 1
			local entry = { id = nextid, leader = player, members = { player }, mode = "public" }
			parties[nextid] = entry
			partyof[player] = entry
		end
	elseif action == "join" then
		local entry = if typeof(value) == "number" then parties[value] else nil
		if
			entry
			and not partyof[player]
			and #entry.members < maxparty
			and allowed(player, entry.mode, entry.leader.UserId)
		then
			table.insert(entry.members, player)
			partyof[player] = entry
		end
	elseif action == "leave" then
		leave(player)
	elseif action == "mode" then
		local entry = partyof[player]
		if entry and entry.leader == player then
			entry.mode = nextmode[entry.mode] or "public"
		end
	elseif action == "start" then
		startgame(player)
	elseif action == "joingame" then
		if typeof(value) == "string" then
			joingame(player, value)
		end
	end
	pushall()
end

return function()
	local focus = workspace:WaitForChild("Spawns"):FindFirstChildWhichIsA("SpawnLocation")

	local function onplayer(player: Player)
		player.ReplicationFocus = focus
		player:SetAttribute("InGame", games.ismatch)
	end

	players.PlayerAdded:Connect(onplayer)
	players.PlayerRemoving:Connect(function(player)
		leave(player)
		lastaction[player] = nil
		friendcache[player] = nil
		pushall()
	end)
	for _, player in players:GetPlayers() do
		onplayer(player)
	end

	lobbyaction.OnServerEvent:Connect(onaction)
	games.start()

	task.spawn(function()
		while true do
			task.wait(pushinterval)
			pushall()
		end
	end)
end
