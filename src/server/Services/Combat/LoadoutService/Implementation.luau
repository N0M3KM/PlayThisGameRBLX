--!strict
local Service = require("@game/ReplicatedStorage/Shared/Contracts/Service")
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Requests = require("@game/ReplicatedStorage/Shared/Contracts/Requests")
local Schemas = require("@game/ReplicatedStorage/Shared/Contracts/RequestSchemas")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Selection = require("./Selection")
local Types = require("./Types")
local ToolGuard = require("../ToolGrantGuard")
local Implementation = {}
type Locked = { Snapshot: Payloads.LoadoutSnapshot, Generation: number }

--[=[ Equipping persists only in a reserved lobby window. Frozen round snapshots and
	private Tool records remain authoritative until explicit round/player cleanup.
]=]
function Implementation.new(deps: Types.Dependencies): Types.Api
	local locked: { [number]: Locked } = {}
	local busy: { [number]: boolean } = {}
	local epochs: { [number]: number } = {}
	local initialized, started, destroyed = false, false, false
	local tools = ToolGuard.new(deps)
	local function clear(userId: number): Result.Result<boolean>
		local existed = locked[userId] ~= nil
		locked[userId] = nil
		epochs[userId] = (epochs[userId] or 0) + 1
		tools.clear(userId)
		return Result.success(existed)
	end
	local function clearRound(roundId: number?)
		local pending = {}
		for userId, record in locked do
			if roundId == nil or record.Snapshot.RoundId == roundId then
				table.insert(pending, userId)
			end
		end
		for _, userId in pending do
			clear(userId)
		end
	end
	local function withLobby<T>(
		userId: number,
		callback: (() -> boolean, Payloads.PlayerStateSnapshot) -> Result.Result<T>
	): Result.Result<T>
		if not started then
			return Result.failure("NotReady")
		end
		if locked[userId] then
			return Result.failure("WrongState")
		end
		if busy[userId] then
			return Result.failure("RateLimited")
		end
		busy[userId] = true
		local epoch = epochs[userId] or 0
		local reservedOk, reservation = pcall(deps.players.ReserveLobby, deps.players, userId)
		if not reservedOk then
			busy[userId] = nil
			return Result.failure("Unavailable")
		end
		if not reservation.Ok then
			busy[userId] = nil
			return Result.failure(reservation.Code)
		end
		local function guard(): boolean
			return started
				and not locked[userId]
				and (epochs[userId] or 0) == epoch
				and deps.players:ValidateLobbyReservation(reservation.Value)
		end
		local ok, outcome = pcall(function(): Result.Result<T>
			local state = deps.players:Get(userId)
			if not state.Ok then
				return Result.failure(state.Code)
			end
			if state.Value.State ~= "Lobby" or not guard() then
				return Result.failure("WrongState")
			end
			return callback(guard, state.Value)
		end)
		local released = pcall(deps.players.ReleaseLobby, deps.players, reservation.Value)
		busy[userId] = nil
		return if ok and released then outcome else Result.failure("Unavailable")
	end
	local function equip(userId: number, request: Requests.EquipLoadout): Result.Result<boolean>
		local checked = Schemas.equipLoadout(request)
		if not checked.Ok then
			return Result.failure(checked.Code)
		end
		local intent = checked.Value
		return withLobby(userId, function(guard): Result.Result<boolean>
			local selected = deps.selection.read(userId)
			if not selected.Ok then
				return Result.failure(selected.Code)
			end
			local profile = deps.data:Read(userId)
			if not profile.Ok then
				return Result.failure(profile.Code)
			end
			local candidate = Selection.copy(selected.Value)
			if intent.Category == "Gear" then
				local slot = intent.GearSlot :: number
				if slot > #candidate.GearIds + 1 then
					return Result.failure("InvalidRequest")
				end
				candidate.GearIds[slot] = intent.ItemId
			elseif intent.Category == "Armour" then
				candidate.ArmourId = intent.ItemId
			else
				candidate.ClassId = intent.ItemId
			end
			local valid = Selection.validate(deps.catalog, profile.Value.Inventory, candidate)
			if not valid.Ok then
				return Result.failure(valid.Code)
			end
			if not guard() then
				return Result.failure("WrongState")
			end
			return deps.selection.write(userId, valid.Value, intent.RequestId, guard)
		end)
	end
	local self: Types.Api = {
		Name = "LoadoutService",
		IsStub = false,
		Init = function(_self: Service.Interface)
			if not destroyed then
				initialized = true
			end
		end,
		Start = function(_self: Service.Interface)
			if initialized and not destroyed then
				started = true
			end
		end,
		Stop = function(_self: Service.Interface)
			started = false
			clearRound(nil)
		end,
		Destroy = function(_self: Service.Interface)
			started = false
			destroyed = true
			clearRound(nil)
			tools.destroy()
		end,
		IsStarted = function(_self: Service.Interface): boolean
			return started
		end,
		Call = function(
			_self: Service.Interface,
			_command: string,
			_arguments: Service.Arguments?
		): Service.StubResult
			return { Ok = false, Code = "NotReady" }
		end,
		Equip = function(
			_self: Service.Interface,
			userId: number,
			slot: number,
			contentId: string
		): Result.Result<boolean>
			return equip(
				userId,
				{ RequestId = deps.requestId(), Category = "Gear", ItemId = contentId, GearSlot = slot }
			)
		end,
		EquipSelection = function(
			_self: Service.Interface,
			userId: number,
			request: Requests.EquipLoadout
		): Result.Result<boolean>
			return equip(userId, request)
		end,
		SnapshotAndLock = function(
			_self: Service.Interface,
			userId: number,
			roundId: number
		): Result.Result<Payloads.LoadoutSnapshot>
			if not started then
				return Result.failure("NotReady")
			end
			if roundId % 1 ~= 0 or roundId <= 0 or roundId == math.huge then
				return Result.failure("InvalidRequest")
			end
			local existing = locked[userId]
			if existing then
				local state = deps.players:Get(userId)
				if
					existing.Snapshot.RoundId == roundId
					and state.Ok
					and state.Value.CharacterGeneration == existing.Generation
				then
					return Result.success(existing.Snapshot)
				end
				return Result.failure("StaleRound")
			end
			return withLobby(userId, function(guard, state): Result.Result<Payloads.LoadoutSnapshot>
				local selected = deps.selection.read(userId)
				if not selected.Ok then
					return Result.failure(selected.Code)
				end
				local profile = deps.data:Read(userId)
				if not profile.Ok then
					return Result.failure(profile.Code)
				end
				local valid = Selection.validate(deps.catalog, profile.Value.Inventory, selected.Value)
				if not valid.Ok then
					return Result.failure(valid.Code)
				end
				if not guard() then
					return Result.failure("WrongState")
				end
				local snapshot = Selection.snapshot(userId, roundId, valid.Value)
				locked[userId] = { Snapshot = snapshot, Generation = state.CharacterGeneration }
				return Result.success(snapshot)
			end)
		end,
		GetLocked = function(
			_self: Service.Interface,
			userId: number,
			roundId: number
		): Result.Result<Payloads.LoadoutSnapshot>
			local record = locked[userId]
			if not started or not record then
				return Result.failure("NotReady")
			end
			if record.Snapshot.RoundId ~= roundId then
				return Result.failure("StaleRound")
			end
			return Result.success(record.Snapshot)
		end,
		Grant = function(_self: Service.Interface, userId: number, roundId: number): Result.Result<boolean>
			local record = locked[userId]
			if not started or not record then
				return Result.failure("NotReady")
			end
			if record.Snapshot.RoundId ~= roundId then
				return Result.failure("StaleRound")
			end
			return tools.grant(record.Snapshot, record.Generation)
		end,
		ValidateTool = function(
			_self: Service.Interface,
			userId: number,
			roundId: number,
			generation: number,
			slot: number
		): Result.Result<Tool>
			if not started then
				return Result.failure("NotReady")
			end
			return tools.validate(userId, roundId, generation, slot)
		end,
		Unlock = function(_self: Service.Interface, userId: number, roundId: number): Result.Result<boolean>
			local record = locked[userId]
			if record and record.Snapshot.RoundId ~= roundId then
				return Result.failure("StaleRound")
			end
			return clear(userId)
		end,
		Clear = function(_self: Service.Interface, userId: number): Result.Result<boolean>
			return clear(userId)
		end,
		ClearRound = function(_self: Service.Interface, roundId: number)
			clearRound(roundId)
		end,
	}
	return self
end
return table.freeze(Implementation)
