local memorystoreservice = game:GetService("MemoryStoreService")
local players = game:GetService("Players")
local replicatedstorage = game:GetService("ReplicatedStorage")
local runservice = game:GetService("RunService")
local serverstorage = game:GetService("ServerStorage")
local teleportservice = game:GetService("TeleportService")

local roundvalue = replicatedstorage.Shared.Round
local gameplaceid = serverstorage:WaitForChild("GamePlaceId").Value

local infottl = 86400
local listttl = 45
local heartbeat = 15
local cachetime = 6
local maxlisted = 50
local inforetries = 5

local function getmap(name: string): MemoryStoreSortedMap?
	local ok, map = pcall(function()
		return memorystoreservice:GetSortedMap(name)
	end)
	return if ok then map else nil
end

local infomap = getmap("gameinfo") :: any
local publicmap = getmap("publicgames") :: any

local codes: { [string]: string } = {}
local cached = {}
local cachedat = 0
local localgame: any = nil
local info: any = nil

local games = {}

games.studio = runservice:IsStudio()
games.targetplace = if gameplaceid ~= 0 then gameplaceid else game.PlaceId
games.ismatch = (game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0)
	or (gameplaceid ~= 0 and game.PlaceId == gameplaceid)

local function fetchinfo()
	if info or game.PrivateServerId == "" then
		return info
	end
	local ok, value = pcall(function()
		return infomap:GetAsync(game.PrivateServerId)
	end)
	if ok and typeof(value) == "table" then
		info = value
	end
	return info
end

function games.reserve(host: Player, mode: string, count: number): string?
	local ok, code, id = pcall(function()
		return teleportservice:ReserveServer(games.targetplace)
	end)
	if not ok or typeof(code) ~= "string" or typeof(id) ~= "string" then
		return nil
	end
	local entry = {
		code = code,
		host = host.DisplayName,
		hostid = host.UserId,
		mode = mode,
		lobby = game.PlaceId,
		players = count,
		round = 0,
	}
	pcall(function()
		infomap:SetAsync(id, entry, infottl)
	end)
	if mode ~= "private" then
		pcall(function()
			publicmap:SetAsync(id, entry, listttl)
		end)
	end
	return code
end

function games.setlocal(host: Player, mode: string)
	localgame = { host = host.DisplayName, hostid = host.UserId, mode = mode }
end

function games.list()
	if games.studio then
		local list = {}
		if localgame and localgame.mode ~= "private" then
			local count = 0
			for _, player in players:GetPlayers() do
				if player:GetAttribute("InGame") then
					count += 1
				end
			end
			if count > 0 then
				table.insert(list, {
					id = "local",
					host = localgame.host,
					hostid = localgame.hostid,
					mode = localgame.mode,
					players = count,
					round = roundvalue.Value,
				})
			end
		end
		return list
	end

	if os.clock() - cachedat < cachetime then
		return cached
	end
	cachedat = os.clock()

	local ok, entries = pcall(function()
		return publicmap:GetRangeAsync(Enum.SortDirection.Ascending, maxlisted)
	end)
	if ok and typeof(entries) == "table" then
		local list = {}
		local found = {}
		for _, entry in entries do
			local value = entry.value
			if typeof(value) == "table" and typeof(value.code) == "string" and entry.key ~= game.PrivateServerId then
				found[entry.key] = value.code
				table.insert(list, {
					id = entry.key,
					host = tostring(value.host),
					hostid = tonumber(value.hostid) or 0,
					mode = if value.mode == "friends" then "friends" else "public",
					players = tonumber(value.players) or 0,
					round = tonumber(value.round) or 0,
				})
			end
		end
		codes = found
		cached = list
	end
	return cached
end

function games.find(id: string)
	for _, entry in games.list() do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

function games.code(id: string): string?
	return codes[id]
end

function games.lobbyplace(): number?
	if not games.ismatch then
		return nil
	end
	local current = fetchinfo()
	if current and typeof(current.lobby) == "number" then
		return current.lobby
	end
	if gameplaceid == 0 then
		return game.PlaceId
	end
	return nil
end

function games.start()
	if game.PrivateServerId == "" or game.PrivateServerOwnerId ~= 0 then
		return
	end
	task.spawn(function()
		local id = game.PrivateServerId
		for _ = 1, inforetries do
			if fetchinfo() then
				break
			end
			task.wait(2)
		end
		if not info or info.mode == "private" then
			return
		end

		game:BindToClose(function()
			pcall(function()
				publicmap:RemoveAsync(id)
			end)
		end)

		while true do
			info.players = #players:GetPlayers()
			info.round = roundvalue.Value
			pcall(function()
				publicmap:SetAsync(id, info, listttl)
			end)
			task.wait(heartbeat)
		end
	end)
end

return games
