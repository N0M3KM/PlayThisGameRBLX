--!strict
-- Prepared public-data boundary cases; this does not prove replica delivery.
local Schemas = require("../../../src/shared/Contracts/SnapshotSchemas")
local Payloads = require("../../../src/shared/Contracts/Payloads")

local valid: Payloads.BoardSnapshot =
	{ Id = "coins", UpdatedAt = 1, Entries = { { UserId = -1, Value = 12.5 } } }
local checked = Schemas.board(valid)
assert(checked.Ok and table.isfrozen(checked.Value.Entries[1]), "Valid board entries must be frozen")
valid.Entries[1].Value = 999
assert(checked.Value.Entries[1].Value == 12.5, "Public snapshot must own its entries")
assert(
	not Schemas.board({ Id = "coins", UpdatedAt = 1, Entries = {}, ProcessedReceiptIds = {} }).Ok,
	"Private journals rejected"
)
assert(
	not Schemas.board({ Id = "coins", UpdatedAt = 1, Entries = { { UserId = 1, Value = math.huge } } }).Ok,
	"Nonfinite values rejected"
)
assert(
	not Schemas.board({ Id = "coins", UpdatedAt = 1, Entries = { { UserId = 1, Value = -1 } } }).Ok,
	"Negative values rejected"
)
assert(
	not Schemas.board({ Id = "coins", UpdatedAt = 1, Entries = { [2] = { UserId = 1, Value = 0 } } }).Ok,
	"Sparse boards rejected"
)
assert(not Schemas.board({
	Id = "coins",
	UpdatedAt = 1,
	Entries = { { UserId = 1, Value = 1 }, { UserId = 1, Value = 2 } },
}).Ok, "Repeated rank identities rejected")
local entries: { Payloads.BoardEntry } = {}
for id = 1, 50 do
	entries[id] = { UserId = id, Value = 0 }
end
assert(Schemas.board({ Id = "coins", UpdatedAt = 1, Entries = entries }).Ok, "Fifty ranks allowed")
entries[51] = { UserId = 51, Value = 0 }
assert(not Schemas.board({ Id = "coins", UpdatedAt = 1, Entries = entries }).Ok, "Board cap enforced")

return 9
