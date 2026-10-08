--!strict
-- Server facade for the engine-independent round state machine.
local Machine = require(game:GetService("ReplicatedStorage").Shared.Util.Match.RoundMachine)
export type Machine = Machine.Machine
export type Snapshot = Machine.Snapshot
return Machine
