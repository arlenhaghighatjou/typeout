local players = game:GetService("Players")
local replicatedstorage = game:GetService("ReplicatedStorage")

local submitword = replicatedstorage.Shared.SubmitWord
local announce = replicatedstorage.Shared.Announce

local penalty = 5
local maxlength = 40

local lockeduntil: { [Player]: number } = {}

local function alivehumanoid(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

local function findtarget(guesser: Player, guess: string): (Player?, Humanoid?)
	for _, other in players:GetPlayers() do
		if other ~= guesser then
			local word = other:GetAttribute("Word")
			local humanoid = alivehumanoid(other)
			if humanoid and typeof(word) == "string" and string.lower(word) == guess then
				return other, humanoid
			end
		end
	end
	return nil, nil
end

return function()
	submitword.OnServerInvoke = function(player: Player, text: any)
		local now = os.clock()
		local locked = lockeduntil[player]
		if locked and locked > now then
			return { correct = false, wait = locked - now }
		end
		if typeof(text) ~= "string" or #text > maxlength or not alivehumanoid(player) then
			return { correct = false, wait = 0 }
		end

		local guess = string.lower(string.match(text, "^%s*(.-)%s*$") or "")
		if guess == "" then
			return { correct = false, wait = 0 }
		end

		local target, humanoid = findtarget(player, guess)
		if target and humanoid then
			target:SetAttribute("TypedOut", true)
			humanoid.Health = 0
			announce:FireAllClients(target.DisplayName .. " was typed out!")
			return { correct = true, name = target.DisplayName }
		end

		lockeduntil[player] = now + penalty
		return { correct = false, wait = penalty }
	end

	players.PlayerRemoving:Connect(function(player)
		lockeduntil[player] = nil
	end)
end
