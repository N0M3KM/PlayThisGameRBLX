--!strict
-- Server facade for the engine-independent sticky vote ledger.
local Ledger = require(game:GetService("ReplicatedStorage").Shared.Util.Match.VoteLedger)
export type Snapshot = Ledger.Snapshot
return Ledger
