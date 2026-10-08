--!strict
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Schemas = require("@game/ReplicatedStorage/Shared/Contracts/SnapshotSchemas")
local Validation = require("@game/ReplicatedStorage/Shared/Registry/Validation")
local Limits = require("@game/ReplicatedStorage/Shared/Config/Validation")
local Config = require("@game/ReplicatedStorage/Shared/Config/Data")
local TransportRecord = require("./TransportRecord")

export type Replica = TransportRecord.Replica
export type Parameters = TransportRecord.Parameters
export type Api = TransportRecord.Api
export type Adapter = {
	publishPrivate: (
		userId: number,
		owner: unknown,
		snapshot: Payloads.PlayerDataSnapshot
	) -> Result.Result<boolean>,
	publishMatch: (snapshot: Payloads.MatchSnapshot) -> Result.Result<boolean>,
	publishBoard: (snapshot: Payloads.BoardSnapshot) -> Result.Result<boolean>,
	remove: (userId: number) -> Result.Result<boolean>,
	clear: () -> Result.Result<boolean>,
}
type Record = TransportRecord.Record
type Tokens = { Private: unknown, Match: unknown, Board: unknown }
local tokensByApi = setmetatable({} :: { [Api]: Tokens }, { __mode = "k" })
local Adapter = {}

--[=[ Inject the mandated ReplicaService API. No library is loaded or replaced here.
	Its All audience includes future ready clients; private audiences are actual Player objects.
	Data.Snapshot is replaced atomically, including optional fields removed by later revisions.
]=]
function Adapter.new(api: Api): Adapter
	local tokens = tokensByApi[api]
	if not tokens then
		tokens = {
			Private = api.NewClassToken("PTGPlayerData"),
			Match = api.NewClassToken("PTGMatch"),
			Board = api.NewClassToken("PTGBoard"),
		}
		tokensByApi[api] = tokens
	end
	local classTokens = tokens :: Tokens
	local private: { [number]: Record } = {}
	local public: Record? = nil
	local boards: { [string]: Record } = {}
	local boardPending: { [string]: boolean } = {}
	local pending: { [number]: { Cancelled: boolean } } = {}
	local matchPending, closed = false, false
	local destroy = TransportRecord.destroy
	local function publish(
		record: Record?,
		owner: unknown,
		snapshot: unknown,
		revision: number,
		token: unknown,
		tags: { [string]: number | string }
	): (Result.Result<boolean>, Record)
		return TransportRecord.publish(api, record, owner, snapshot, revision, token, tags)
	end
	local function remove(userId: number): Result.Result<boolean>
		if not Validation.playerId(userId, Limits.MaxInteger) then
			return Result.failure("InvalidRequest")
		end
		local inFlight = pending[userId]
		if inFlight then
			inFlight.Cancelled = true
		end
		local record = private[userId]
		if not record then
			return Result.success(true)
		end
		if not destroy(record) then
			return Result.failure("Unavailable")
		end
		private[userId] = nil
		return Result.success(true)
	end
	return table.freeze({
		publishPrivate = function(
			userId: number,
			owner: unknown,
			snapshot: Payloads.PlayerDataSnapshot
		): Result.Result<boolean>
			if closed or pending[userId] then
				return Result.failure("NotReady")
			end
			local validated = Schemas.player(snapshot)
			if not validated.Ok or validated.Value.UserId ~= userId or owner == nil or owner == "All" then
				return Result.failure("InvalidRequest")
			end
			local inFlight = { Cancelled = false }
			pending[userId] = inFlight
			local outcome, record = publish(
				private[userId],
				owner,
				validated.Value,
				validated.Value.Revision,
				classTokens.Private,
				{ UserId = userId }
			)
			pending[userId] = nil
			if closed or inFlight.Cancelled then
				if not destroy(record) then
					private[userId] = record
				end
				return Result.failure("NotReady")
			end
			private[userId] = record
			return outcome
		end,
		publishMatch = function(snapshot: Payloads.MatchSnapshot): Result.Result<boolean>
			if closed or matchPending then
				return Result.failure("NotReady")
			end
			local validated = Schemas.match(snapshot)
			if not validated.Ok then
				return Result.failure("InvalidRequest")
			end
			matchPending = true
			local outcome, record =
				publish(public, "All", validated.Value, validated.Value.Revision, classTokens.Match, {})
			matchPending = false
			public = record
			if closed then
				destroy(record)
				return Result.failure("NotReady")
			end
			return outcome
		end,
		publishBoard = function(snapshot: Payloads.BoardSnapshot): Result.Result<boolean>
			if closed then
				return Result.failure("NotReady")
			end
			local validated = Schemas.board(snapshot)
			if not validated.Ok then
				return Result.failure("InvalidRequest")
			end
			local board = validated.Value
			if boardPending[board.Id] then
				return Result.failure("NotReady")
			end
			if not boards[board.Id] then
				local count = 0
				for _ in boards do
					count += 1
				end
				for id in boardPending do
					if not boards[id] then
						count += 1
					end
				end
				if count >= Config.MaxPublicBoards then
					return Result.failure("LimitReached")
				end
			end
			boardPending[board.Id] = true
			local outcome, record = publish(
				boards[board.Id],
				"All",
				board,
				board.UpdatedAt,
				classTokens.Board,
				{ BoardId = board.Id }
			)
			boardPending[board.Id] = nil
			boards[board.Id] = record
			if closed then
				destroy(record)
				return Result.failure("NotReady")
			end
			return outcome
		end,
		remove = remove,
		clear = function(): Result.Result<boolean>
			closed = true -- Terminal adapter lifecycle; callers construct a fresh wrapper to restart.
			local success = next(pending) == nil and not matchPending and next(boardPending) == nil
			for userId in private do
				if not remove(userId).Ok then
					success = false
				end
			end
			if public then
				if destroy(public) then
					public = nil
				else
					success = false
				end
			end
			for id, record in boards do
				if destroy(record) then
					boards[id] = nil
				else
					success = false
				end
			end
			return if success then Result.success(true) else Result.failure("Unavailable")
		end,
	})
end

return table.freeze(Adapter)
