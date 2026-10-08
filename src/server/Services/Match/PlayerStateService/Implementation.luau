--!strict
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.Match)
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local Service = require(Shared.Contracts.Service)
local States = require(Shared.Contracts.States)
local Scope = require(Shared.Util.Scope)
local Lifecycle = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceLifecycle)
local Interface = require(script.Parent.Interface)

type Record = {
	Player: Player,
	Scope: Scope.Scope,
	CharacterScope: Scope.Scope?,
	Character: Model?,
	Snapshot: Payloads.PlayerStateSnapshot,
	Afk: boolean,
}
local Implementation = {}
local LEGAL: { [string]: { [string]: boolean } } = table.freeze({
	Lobby = table.freeze({}),
	InRound = table.freeze({ Dead = true, Spectating = true, Lobby = true }),
	Dead = table.freeze({ Spectating = true, Lobby = true }),
	Spectating = table.freeze({ Lobby = true }),
})

local function finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

local function living(record: Record): boolean
	local character = record.Character
	if
		record.Player.Parent ~= Players
		or not character
		or record.Player.Character ~= character
		or not character.Parent
	then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	return humanoid ~= nil
		and finite(humanoid.Health)
		and humanoid.Health > 0
		and root ~= nil
		and root:IsA("BasePart")
		and finite(root.Position.X)
		and finite(root.Position.Y)
		and finite(root.Position.Z)
end

local function inAfkZone(record: Record): boolean
	local lobby = Workspace:FindFirstChild("MatchLobby")
	local zone = if lobby then lobby:FindFirstChild("AFKZone") else nil
	local character = record.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not zone or not zone:IsA("BasePart") or not root or not root:IsA("BasePart") then
		return false
	end
	local point = zone.CFrame:PointToObjectSpace(root.Position)
	return finite(point.X)
		and finite(point.Y)
		and finite(point.Z)
		and math.abs(point.X) <= zone.Size.X / 2
		and math.abs(point.Y) <= zone.Size.Y / 2 + Config.ZoneHeightTolerance
		and math.abs(point.Z) <= zone.Size.Z / 2
end

--[=[ Tracks durable player identity and generation-scoped characters without per-player polling. ]=]
function Implementation.new(onChanged: ((Payloads.PlayerStateSnapshot) -> ())?): Interface.Interface
	local serviceScope = Scope.new()
	local records: { [number]: Record } = {}
	local reservations: { [number]: { TokenId: string, Record: Record, Generation: number } } = {}
	local runScope: Scope.Scope? = nil
	local activeRound: number? = nil
	local participants: { number } = {}
	local facade: Interface.Interface
	local function removeParticipant(userId: number)
		local index = table.find(participants, userId)
		if index then
			table.remove(participants, index)
		end
	end

	local function publish(record: Record)
		if onChanged then
			local outcome = table.pack(pcall(onChanged, table.freeze(table.clone(record.Snapshot))))
			if not outcome[1] then
				warn(`PlayerStateService listener failed: {tostring(outcome[2])}`)
			end
		end
	end

	local function setState(record: Record, state: States.PlayerState, roundId: number?)
		if state == "Lobby" then
			removeParticipant(record.Player.UserId)
		end
		record.Snapshot.State = state
		record.Snapshot.RoundId = roundId
		publish(record)
	end

	local function clearCharacter(record: Record, character: Model)
		if record.Character ~= character then
			return
		end
		record.Character = nil
		local scope = record.CharacterScope
		record.CharacterScope = nil
		if scope then
			scope:destroy()
		end
		if record.Snapshot.State == "InRound" then
			setState(record, "Dead", record.Snapshot.RoundId)
		end
	end

	local function bindCharacter(record: Record, character: Model)
		if
			record.Scope:isDestroyed()
			or record.Player.Character ~= character
			or record.Character == character
		then
			return
		end
		if record.Character then
			clearCharacter(record, record.Character)
		end
		record.Character = character
		record.Snapshot.CharacterGeneration += 1
		local generation = record.Snapshot.CharacterGeneration
		local scope = record.Scope:child()
		record.CharacterScope = scope
		if record.Snapshot.RoundId then
			setState(record, "Spectating", record.Snapshot.RoundId)
		else
			publish(record)
		end
		local setup = task.defer(function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid then
				local candidate = character:WaitForChild("Humanoid", Config.CharacterWaitSeconds)
				if candidate and candidate:IsA("Humanoid") then
					humanoid = candidate
				end
			end
			if
				scope:isDestroyed()
				or record.Player.Character ~= character
				or record.Snapshot.CharacterGeneration ~= generation
				or not humanoid
			then
				return
			end
			local function died()
				if
					record.Character == character
					and record.Snapshot.CharacterGeneration == generation
					and record.Snapshot.State == "InRound"
				then
					setState(record, "Dead", record.Snapshot.RoundId)
				end
			end
			local connection = humanoid.Died:Connect(died)
			scope:add(function()
				connection:Disconnect()
			end)
			if humanoid.Health <= 0 then
				died()
			end
		end)
		scope:add(function()
			if coroutine.status(setup) ~= "dead" then
				task.cancel(setup)
			end
		end)
	end

	local function addPlayer(player: Player)
		local owner = runScope
		if not owner or records[player.UserId] or player.Parent ~= Players then
			return
		end
		local scope = owner:child()
		local record: Record = {
			Player = player,
			Scope = scope,
			CharacterScope = nil,
			Character = nil,
			Afk = false,
			Snapshot = { UserId = player.UserId, State = "Lobby", CharacterGeneration = 0, RoundId = nil },
		}
		records[player.UserId] = record
		local added = player.CharacterAdded:Connect(function(character)
			bindCharacter(record, character)
		end)
		local removing = player.CharacterRemoving:Connect(function(character)
			clearCharacter(record, character)
		end)
		scope:add(function()
			added:Disconnect()
			removing:Disconnect()
			removeParticipant(player.UserId)
			records[player.UserId] = nil
			reservations[player.UserId] = nil
		end)
		publish(record)
		if player.Character then
			bindCharacter(record, player.Character)
		end
	end

	facade = Lifecycle.new("PlayerStateService", serviceScope, {
		Start = function()
			local scope = serviceScope:child()
			runScope = scope
			local added = Players.PlayerAdded:Connect(addPlayer)
			local removed = Players.PlayerRemoving:Connect(function(player)
				local record = records[player.UserId]
				if record then
					record.Scope:destroy()
				end
			end)
			scope:add(function()
				added:Disconnect()
				removed:Disconnect()
			end)
			for _, player in Players:GetPlayers() do
				addPlayer(player)
			end
		end,
		Stop = function()
			local scope = runScope
			runScope = nil
			if scope then
				scope:destroy()
			end
			table.clear(records)
			table.clear(reservations)
			activeRound = nil
			table.clear(participants)
		end,
	}) :: Interface.Interface

	-- The purchasing service owns release. Respawn invalidates the guard while
	-- round entry stays excluded until the in-flight durable operation finishes.
	facade.ReserveLobby = function(
		_self: Service.Interface,
		userId: number
	): Result.Result<Payloads.LobbyReservation>
		local record = records[userId]
		if not facade:IsStarted() or not record then
			return Result.failure("NotReady")
		end
		if record.Snapshot.State ~= "Lobby" or reservations[userId] or not living(record) then
			return Result.failure("WrongState")
		end
		local token = HttpService:GenerateGUID(false)
		reservations[userId] =
			{ TokenId = token, Record = record, Generation = record.Snapshot.CharacterGeneration }
		return Result.success(table.freeze({ UserId = userId, TokenId = token }))
	end
	facade.ValidateLobbyReservation = function(
		_self: Service.Interface,
		reservation: Payloads.LobbyReservation
	): boolean
		local held = reservations[reservation.UserId]
		local record = records[reservation.UserId]
		return facade:IsStarted()
			and held ~= nil
			and record ~= nil
			and held.Record == record
			and held.TokenId == reservation.TokenId
			and held.Generation == record.Snapshot.CharacterGeneration
			and record.Snapshot.State == "Lobby"
			and living(record)
	end
	facade.ReleaseLobby = function(
		_self: Service.Interface,
		reservation: Payloads.LobbyReservation
	): Result.Result<boolean>
		local held = reservations[reservation.UserId]
		if not held then
			return Result.success(true)
		end
		if held.TokenId ~= reservation.TokenId then
			return Result.failure("WrongState")
		end
		reservations[reservation.UserId] = nil
		return Result.success(true)
	end

	facade.Get = function(
		_self: Service.Interface,
		userId: number
	): Result.Result<Payloads.PlayerStateSnapshot>
		local record = records[userId]
		return if record
			then Result.success(table.freeze(table.clone(record.Snapshot)))
			else Result.failure("NotReady")
	end
	facade.IsAfk = function(_self: Service.Interface, userId: number): boolean
		local record = records[userId]
		return not record or record.Afk or inAfkZone(record)
	end
	facade.SetAfk = function(_self: Service.Interface, userId: number, afk: boolean): Result.Result<boolean>
		local record = records[userId]
		if not record then
			return Result.failure("NotReady")
		end
		if type(afk) ~= "boolean" then
			return Result.failure("InvalidRequest")
		end
		record.Afk = afk
		return Result.success(true)
	end
	facade.EligiblePlayers = function(_self: Service.Interface): { number }
		local eligible: { number } = {}
		for userId, record in records do
			if
				record.Snapshot.State == "Lobby"
				and not reservations[userId]
				and not facade:IsAfk(userId)
				and living(record)
			then
				table.insert(eligible, userId)
			end
		end
		table.sort(eligible)
		return eligible
	end
	facade.BeginRound = function(_self: Service.Interface, roundId: number, userIds: { number }): { number }
		if not finite(roundId) or roundId <= 0 or roundId % 1 ~= 0 then
			return {}
		end
		if activeRound then
			return if activeRound == roundId then table.clone(participants) else {}
		end
		activeRound = roundId
		for _, userId in userIds do
			local record = records[userId]
			if
				record
				and record.Snapshot.State == "Lobby"
				and not reservations[userId]
				and not facade:IsAfk(userId)
				and living(record)
			then
				table.insert(participants, userId)
				setState(record, "InRound", roundId)
			end
		end
		table.sort(participants)
		return table.clone(participants)
	end
	facade.ResetRound = function(_self: Service.Interface, roundId: number)
		for _, record in records do
			if record.Snapshot.RoundId == roundId then
				setState(record, "Lobby", nil)
			end
		end
		if activeRound == roundId then
			activeRound = nil
			table.clear(participants)
		end
	end
	facade.Transition = function(
		_self: Service.Interface,
		userId: number,
		expectedState: States.PlayerState,
		nextState: States.PlayerState,
		expectedRoundId: number,
		generation: number
	): Result.Result<boolean>
		local record = records[userId]
		if not record then
			return Result.failure("NotReady")
		end
		local snapshot = record.Snapshot
		if (snapshot.RoundId or 0) ~= expectedRoundId or snapshot.CharacterGeneration ~= generation then
			return Result.failure("StaleRound")
		end
		local nextRoundId = if nextState == "Lobby" then nil else snapshot.RoundId
		local allowed = LEGAL[expectedState]
		local legal = allowed ~= nil and allowed[nextState] == true
		if snapshot.State ~= expectedState or not legal then
			return Result.failure("WrongState")
		end
		setState(record, nextState, nextRoundId)
		return Result.success(true)
	end
	facade.GetAlive = function(_self: Service.Interface, roundId: number): Result.Result<{ number }>
		local alive: { number } = {}
		for userId, record in records do
			if
				record.Snapshot.RoundId == roundId
				and record.Snapshot.State == "InRound"
				and living(record)
			then
				table.insert(alive, userId)
			end
		end
		table.sort(alive)
		return Result.success(alive)
	end
	return facade
end

return table.freeze(Implementation)
