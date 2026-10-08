--!strict
-- Prepared pure transport regressions; execution is deliberately excluded from this task.
local Adapter = require("../../../src/server/Services/Data/ReplicaPublisher/Adapter")
local Payloads = require("../../../src/shared/Contracts/Payloads")
type ReplicaRecord = {
	Replica: Adapter.Replica,
	Parameters: Adapter.Parameters,
	Writes: number,
	Active: boolean,
}
type Fixture = {
	Api: Adapter.Api,
	Records: { ReplicaRecord },
	Failures: { Write: boolean, Destroy: boolean, Create: boolean },
	Tokens: { string },
	Hooks: { OnCreate: (() -> ())? },
}

local function fixture(): Fixture
	local records: { ReplicaRecord } = {}
	local failures = { Write = false, Destroy = false, Create = false }
	local tokens: { string } = {}
	local hooks: { OnCreate: (() -> ())? } = {}
	local api: Adapter.Api = {
		NewClassToken = function(name)
			table.insert(tokens, name)
			return { Class = name }
		end,
		NewReplica = function(parameters)
			assert(not failures.Create, "Injected constructor failure")
			local record: ReplicaRecord
			local replica: Adapter.Replica = {
				IsActive = function(_self)
					return record.Active
				end,
				SetValue = function(_self, path, value)
					assert(
						record.Active and path[1] == "Snapshot" and #path == 1,
						"Only an active snapshot can be replaced"
					)
					parameters.Data.Snapshot = value
					record.Writes += 1
					assert(not failures.Write, "Injected failure after mutation")
				end,
				Destroy = function(_self)
					assert(not failures.Destroy, "Injected destroy failure")
					record.Active = false
				end,
			}
			record = { Replica = replica, Parameters = parameters, Writes = 0, Active = true }
			table.insert(records, record)
			if hooks.OnCreate then
				hooks.OnCreate()
			end
			return replica
		end,
	}
	return { Api = api, Records = records, Failures = failures, Tokens = tokens, Hooks = hooks }
end

local function player(revision: number): Payloads.PlayerDataSnapshot
	return {
		SchemaVersion = 1,
		UserId = 7,
		Revision = revision,
		Coins = 5.9,
		TotalXP = 11.8,
		Level = 1,
		Inventory = { Gears = { "rifle" }, Utilities = {}, Armours = {}, Classes = {} },
		FreeSpinRemainingSeconds = 900,
		PaidSpins = 0,
	}
end

local function idle(revision: number): Payloads.MatchSnapshot
	return { ContractVersion = Payloads.Version, Revision = revision, RoundId = 0, State = "Idle" }
end

do
	local memory = fixture()
	local adapter = Adapter.new(memory.Api)
	local owner = {}
	local snapshot = player(1)
	assert(adapter.publishPrivate(7, owner, snapshot).Ok, "Initial private projection must publish")
	local created = memory.Records[1]
	assert(created.Parameters.Replication == owner, "Private audience must be only its owner")
	local replicaData = created.Parameters.Data.Snapshot :: Payloads.PlayerDataSnapshot
	snapshot.Inventory.Gears[1] = "changed_source"
	assert(replicaData.Inventory.Gears[1] == "rifle", "Transport receives detached data")
	replicaData.Inventory.Gears[1] = "changed_transport"
	assert(
		adapter.publishPrivate(7, owner, player(1)).Ok,
		"Transport mutation cannot alter revision baseline"
	)
	assert(created.Writes == 0, "An identical revision is a no-op")
	local changed = player(1)
	changed.Coins = 100
	assert(not adapter.publishPrivate(7, owner, changed).Ok, "Same revision cannot change values")
	assert(not adapter.publishPrivate(7, owner, player(0)).Ok, "Revisions cannot go backwards")
	assert(not adapter.publishPrivate(8, owner, player(2)).Ok, "UserId mismatch must fail")
	assert(not adapter.publishPrivate(7, "All", player(2)).Ok, "Private snapshots cannot target All")
	assert(not adapter.publishPrivate(7, {}, player(2)).Ok, "Changed owner cannot inherit a replica")
	assert(
		adapter.publishPrivate(7, owner, player(2)).Ok and created.Writes == 1,
		"Higher revisions update once"
	)
	assert(adapter.remove(7).Ok and not created.Active, "Remove destroys the private replica")
	assert(adapter.remove(7).Ok, "Remove is idempotent")
	assert(adapter.publishPrivate(7, {}, player(0)).Ok, "New sessions can begin after explicit removal")
	assert(#memory.Tokens == 3, "Each projection class receives one token")
	Adapter.new(memory.Api)
	assert(#memory.Tokens == 3, "ReplicaService tokens are created once per API instance")
end

do
	local memory = fixture()
	local adapter = Adapter.new(memory.Api)
	local active: Payloads.MatchSnapshot = {
		ContractVersion = Payloads.Version,
		Revision = 1,
		RoundId = 1,
		State = "Active",
		EndsAt = 240,
		MapId = "map_one",
		ScenarioId = "normal",
	}
	assert(adapter.publishMatch(active).Ok, "Active public projection must publish")
	local record = memory.Records[1]
	assert(record.Parameters.Replication == "All", "Public audience covers current and late-ready clients")
	assert(adapter.publishMatch(idle(2)).Ok, "Idle transition must publish")
	local latest = record.Parameters.Data.Snapshot :: Payloads.MatchSnapshot
	assert(
		latest.MapId == nil and latest.ScenarioId == nil and latest.EndsAt == nil,
		"Whole projection replacement removes optional keys"
	)
	assert(adapter.clear().Ok and not record.Active, "Stop destroys the public replica")
	assert(adapter.clear().Ok, "Stop cleanup is idempotent")
	assert(not adapter.publishMatch(idle(3)).Ok, "A stopped adapter is terminal")
end

do
	local memory = fixture()
	local adapter = Adapter.new(memory.Api)
	local owner = {}
	assert(
		adapter.publishPrivate(7, owner, player(1)).Ok,
		"Failure fixture starts with an active private replica"
	)
	memory.Failures.Write = true
	assert(
		not adapter.publishPrivate(7, owner, player(2)).Ok,
		"Partial transport failure cannot be acknowledged"
	)
	assert(not memory.Records[1].Active, "Partial update failure destroys the affected replica")
	memory.Failures.Write = false
	assert(
		not adapter.publishPrivate(7, owner, player(2)).Ok,
		"Failed update remains fenced until explicit removal"
	)
	assert(adapter.remove(7).Ok, "Explicit removal clears an inactive handle")
	assert(adapter.publishPrivate(7, owner, player(2)).Ok, "A clean handle can publish after removal")
	memory.Records[2].Active = false
	assert(
		not adapter.publishPrivate(7, owner, player(2)).Ok,
		"Same revision cannot acknowledge a dead replica"
	)
end

do
	local memory = fixture()
	local adapter = Adapter.new(memory.Api)
	local owner = {}
	assert(
		adapter.publishPrivate(7, owner, player(1)).Ok,
		"Cleanup fixture starts with an active private replica"
	)
	memory.Failures.Destroy = true
	assert(not adapter.remove(7).Ok, "Destroy failure cannot be acknowledged")
	assert(not adapter.publishPrivate(7, owner, player(2)).Ok, "A destroy failure fences its audience")
	memory.Failures.Destroy = false
	assert(adapter.remove(7).Ok, "Cleanup can retry the same handle")
	memory.Failures.Create = true
	assert(not adapter.publishPrivate(7, owner, player(2)).Ok, "Constructor failure cannot be acknowledged")
	memory.Failures.Create = false
	assert(
		not adapter.publishPrivate(7, owner, player(2)).Ok,
		"Unknown constructor side effects forbid retry creation"
	)
	assert(#memory.Records == 1, "A fenced constructor never allocates another handle")
	assert(not adapter.clear().Ok, "Unresolved constructor cleanup must remain visible")
end

do
	local memory = fixture()
	local adapter = Adapter.new(memory.Api)
	local invalid = player(1) :: unknown
	(invalid :: { [string]: unknown }).ProcessedReceiptIds = { secret = true }
	assert(
		not adapter.publishPrivate(7, {}, invalid :: Payloads.PlayerDataSnapshot).Ok,
		"Receipt metadata is forbidden"
	)
	local match = idle(1) :: unknown
	(match :: { [string]: unknown }).Coins = 9000
	assert(
		not adapter.publishMatch(match :: Payloads.MatchSnapshot).Ok,
		"Private fields are forbidden in match projection"
	)
	assert(#memory.Records == 0, "Private metadata and public projection extras never reach transport")
end

do
	local memory = fixture()
	local adapter = Adapter.new(memory.Api)
	local board: Payloads.BoardSnapshot =
		{ Id = "coins", Entries = { { UserId = 7, Value = 5.9 } }, UpdatedAt = 1.5 }
	assert(adapter.publishBoard(board).Ok, "Public board facts publish")
	local created = memory.Records[1]
	assert(
		created.Parameters.Replication == "All" and created.Parameters.Tags.BoardId == "coins",
		"Boards have their own public audience and identity"
	)
	board.Entries[1].Value = 999
	assert(
		(created.Parameters.Data.Snapshot :: Payloads.BoardSnapshot).Entries[1].Value == 5.9,
		"Board entries are detached"
	)
	assert(not adapter.publishBoard(board).Ok, "Same timestamp cannot change board values")
	board.UpdatedAt = 1
	assert(not adapter.publishBoard(board).Ok, "A stale board timestamp cannot publish")
	board.UpdatedAt = 2
	assert(adapter.publishBoard(board).Ok, "Later board timestamp can update its existing audience")
	assert(adapter.publishBoard(board).Ok and created.Writes == 1, "Identical timestamp retry is a no-op")
	for _, id in { "kills", "survives", "donations" } do
		assert(
			adapter.publishBoard({ Id = id, Entries = {}, UpdatedAt = 1 }).Ok,
			"Four board audiences are supported"
		)
	end
	assert(
		not adapter.publishBoard({ Id = "extra", Entries = {}, UpdatedAt = 1 }).Ok,
		"A fifth board cannot allocate an audience"
	)
	assert(#memory.Records == 4, "Board audience count stays bounded")
	assert(adapter.clear().Ok, "Board audiences stop cleanly")
	for _, record in memory.Records do
		assert(not record.Active, "Stop destroys every board audience")
	end
end

do
	local memory = fixture()
	local adapter = Adapter.new(memory.Api)
	memory.Hooks.OnCreate = function()
		assert(adapter.remove(7).Ok, "Removal during creation cancels its pending audience")
	end
	assert(
		not adapter.publishPrivate(7, {}, player(1)).Ok,
		"A removed owner cannot receive a late create acknowledgement"
	)
	assert(not memory.Records[1].Active, "Late-created owner replica is destroyed")
	memory.Hooks.OnCreate = function()
		assert(not adapter.clear().Ok, "Stop exposes pending cleanup until a constructor returns")
	end
	assert(not adapter.publishMatch(idle(1)).Ok, "A stopped publisher cannot acknowledge a late creation")
	assert(not memory.Records[2].Active, "Late public creation is destroyed on return")
	assert(adapter.clear().Ok, "Cleanup completes after pending calls drain")
end

return 7
