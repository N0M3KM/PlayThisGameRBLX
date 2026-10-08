--!strict
-- Draft v0 Instance-free AI boundary. Serial actuation revalidates every returned intent.
local Payloads = require("./Payloads")
export type Ability = {
	Id: string,
	Range: number?,
	CooldownSeconds: number?,
	Damage: number?,
	DurationSeconds: number?,
	RecoverySeconds: number?,
}
export type Target = Payloads.TargetSnapshot & { Structure: boolean? }
export type Agent = Payloads.TargetSnapshot & {
	DefinitionId: string,
	Abilities: { Ability },
	Visible: { [string]: boolean }, -- Entity key = round:generation:id.
	LastAttacker: Payloads.EntityRef?,
	StuckSeconds: number,
}
export type Policy = {
	MaxAgents: number,
	MaxTargets: number,
	AcquireRange: number,
	LastAttackerBonus: number,
	StructureBonus: number,
	DistanceWeight: number,
	StuckJumpSeconds: number,
	StuckRepathSeconds: number,
}
export type Frame = {
	Version: number,
	RoundId: number,
	Sequence: number,
	Now: number,
	Agents: { Agent },
	Targets: { Target },
	Config: Policy,
}
export type Metrics = {
	Workers: number,
	Pending: number,
	Dispatched: number,
	ParallelBatches: number,
	Failures: number,
	Timeouts: number,
	Dropped: number,
	AverageMs: number,
	P95Ms: number,
}
return table.freeze({ Version = 1, Frozen = false })
