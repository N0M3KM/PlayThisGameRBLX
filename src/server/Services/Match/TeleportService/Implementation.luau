--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.Match)
local Limits = require(Shared.Config.Validation)
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
local Result = require(Shared.Contracts.Result)
local Service = require(Shared.Contracts.Service)
local Validation = require(Shared.Registry.Validation)
local Scope = require(Shared.Util.Scope)
local Lifecycle = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceLifecycle)
local Interface = require(script.Parent.Interface)

type Candidate = { UserId: number, Player: Player, Character: Model, Generation: number, Slot: number }
type Batch = { RoundId: number, Scope: Scope.Scope }
local Implementation = {}

local function move(character: Model, position: Vector3): boolean
	local root = character:FindFirstChild("HumanoidRootPart")
	if not character.Parent or not root or not root:IsA("BasePart") then
		return false
	end
	local ok, message = pcall(function()
		character:PivotTo(CFrame.new(position + Vector3.new(0, Config.SpawnLift, 0)))
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end)
	if not ok then
		warn(`Teleport failed: {tostring(message)}`)
	end
	return ok
end

local function loadedMap(roundId: number, mapId: string): boolean
	local map = Workspace:FindFirstChild(`Round_{roundId}_{mapId}`)
	return map ~= nil
		and map:IsA("Model")
		and map:GetAttribute("RoundId") == roundId
		and map:GetAttribute("MapId") == mapId
end

--[=[ Moves only captured current characters; cancellation never mutates a replacement character. ]=]
function Implementation.new(resolve: (string) -> Service.Interface): Interface.Interface
	local scope = Scope.new()
	local maps: DomainInterfaces.MapService? = nil
	local players: DomainInterfaces.PlayerStateService? = nil
	local active: Batch? = nil
	local function cancelActive()
		local batch = active
		if batch then
			batch.Scope:destroy()
			if active == batch then
				active = nil
			end
		end
	end
	local facade = Lifecycle.new("TeleportService", scope, {
		Start = function()
			maps = (resolve("MapService") :: unknown) :: DomainInterfaces.MapService
			players = (resolve("PlayerStateService") :: unknown) :: DomainInterfaces.PlayerStateService
		end,
		Stop = cancelActive,
	})
	local result = (facade :: unknown) :: Interface.Interface

	result.ToMap = function(
		self: Service.Interface,
		roundId: number,
		mapId: string,
		participantIds: { number }
	): Result.Result<{ number }>
		local mapService, playerService = maps, players
		if not self:IsStarted() or not mapService or not playerService then
			return Result.failure("NotReady")
		end
		if not Validation.integer(roundId, 1, Limits.MaxInteger) or not Validation.id(mapId) then
			return Result.failure("InvalidRequest")
		end
		if active then
			return Result.failure("WrongState")
		end
		local seen: { [number]: boolean } = {}
		for _, userId in participantIds do
			if not Validation.playerId(userId, Limits.MaxInteger) or seen[userId] then
				return Result.failure("InvalidRequest")
			end
			seen[userId] = true
		end
		local spawnResult = mapService:GetSpawns(roundId)
		if not spawnResult.Ok then
			return Result.failure(spawnResult.Code)
		end
		if not loadedMap(roundId, mapId) then
			return Result.failure("StaleRound")
		end
		local spawns = spawnResult.Value
		if #spawns == 0 then
			return Result.failure("Unavailable")
		end
		for _, point in spawns do
			if not Validation.point(point, Config.MapCoordinateLimit) then
				return Result.failure("Unavailable")
			end
		end
		local candidates: { Candidate } = {}
		for slot, userId in participantIds do
			local snapshot = playerService:Get(userId)
			local player = Players:GetPlayerByUserId(userId)
			local character = if player then player.Character else nil
			if
				snapshot.Ok
				and snapshot.Value.State == "InRound"
				and snapshot.Value.RoundId == roundId
				and player
				and character
			then
				table.insert(candidates, {
					UserId = userId,
					Player = player,
					Character = character,
					Generation = snapshot.Value.CharacterGeneration,
					Slot = slot,
				})
			end
		end
		local batch: Batch = { RoundId = roundId, Scope = scope:child() }
		active = batch
		local moved: { number } = {}
		local function finish(code: Result.ErrorCode?): Result.Result<{ number }>
			batch.Scope:destroy()
			if active == batch then
				active = nil
			end
			return if code then Result.failure(code) else Result.success(moved)
		end
		for index, candidate in candidates do
			if index > 1 then
				task.wait(Config.TeleportStaggerSeconds)
			end
			if batch.Scope:isDestroyed() or not self:IsStarted() or not loadedMap(roundId, mapId) then
				return finish("StaleRound")
			end
			local currentSpawns = mapService:GetSpawns(roundId)
			if not currentSpawns.Ok then
				return finish(currentSpawns.Code)
			end
			local current = playerService:Get(candidate.UserId)
			local humanoid = candidate.Character:FindFirstChildOfClass("Humanoid")
			if
				current.Ok
				and current.Value.State == "InRound"
				and current.Value.RoundId == roundId
				and current.Value.CharacterGeneration == candidate.Generation
				and Players:GetPlayerByUserId(candidate.UserId) == candidate.Player
				and candidate.Player.Character == candidate.Character
				and humanoid
				and Validation.finite(humanoid.Health)
				and humanoid.Health > 0
			then
				-- A player may enter the AFK zone while earlier participants are moving.
				if playerService:IsAfk(candidate.UserId) then
					playerService:Transition(
						candidate.UserId,
						"InRound",
						"Lobby",
						roundId,
						candidate.Generation
					)
				else
					local point = spawns[(candidate.Slot - 1) % #spawns + 1]
					if move(candidate.Character, Vector3.new(point.X, point.Y, point.Z)) then
						table.insert(moved, candidate.UserId)
					else
						playerService:Transition(
							candidate.UserId,
							"InRound",
							"Lobby",
							roundId,
							candidate.Generation
						)
					end
				end
			end
		end
		return finish(nil)
	end

	result.ToLobby = function(
		self: Service.Interface,
		userId: number,
		generation: number
	): Result.Result<boolean>
		local playerService = players
		if not self:IsStarted() or not playerService then
			return Result.failure("NotReady")
		end
		if
			not Validation.playerId(userId, Limits.MaxInteger)
			or not Validation.integer(generation, 1, Limits.MaxInteger)
		then
			return Result.failure("InvalidRequest")
		end
		local snapshot = playerService:Get(userId)
		if not snapshot.Ok then
			return Result.failure(snapshot.Code)
		end
		if snapshot.Value.CharacterGeneration ~= generation then
			return Result.failure("StaleRound")
		end
		local player = Players:GetPlayerByUserId(userId)
		local character = if player then player.Character else nil
		if not character then
			return Result.failure("Unavailable")
		end
		local lobby = Workspace:FindFirstChild("MatchLobby")
		local marker = if lobby then lobby:FindFirstChild("LobbySpawn") else nil
		local fallback = Config.LobbyPosition
		local position = if marker and marker:IsA("BasePart")
			then marker.Position
			else Vector3.new(fallback.X, fallback.Y, fallback.Z)
		if not move(character, position) then
			return Result.failure("Unavailable")
		end
		if snapshot.Value.State ~= "Lobby" then
			return playerService:Transition(
				userId,
				snapshot.Value.State,
				"Lobby",
				snapshot.Value.RoundId or 0,
				generation
			)
		end
		return Result.success(true)
	end
	result.Cancel = function(_self: Service.Interface, roundId: number): Result.Result<boolean>
		if not Validation.integer(roundId, 1, Limits.MaxInteger) then
			return Result.failure("InvalidRequest")
		end
		if active and active.RoundId == roundId then
			cancelActive()
		end
		return Result.success(true)
	end
	return result
end

return table.freeze(Implementation)
