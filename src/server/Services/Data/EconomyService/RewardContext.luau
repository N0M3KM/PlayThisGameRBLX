--!strict
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Calculator = require("@game/ReplicatedStorage/Shared/Util/Economy/RewardCalculator")

export type CombatStats = { Damage: number, Assists: number }
export type Kill = {
	SnapshotId: string,
	Options: Calculator.KillOptions,
	Stats: { [number]: CombatStats }?,
}
export type Survival = {
	SnapshotId: string,
	Options: Calculator.SurvivalOptions,
	Participants: { number },
}
export type Provider = {
	nonBoss: (Payloads.DamageFact) -> Result.Result<Kill>,
	boss: (Payloads.BossSettlement) -> Result.Result<Kill>,
	survival: (Payloads.RoundOutcome) -> Result.Result<Survival>,
}

local RewardContext = {}

function RewardContext.copyDamageFact(source: Payloads.DamageFact): Payloads.DamageFact
	local owned = table.clone(source)
	owned.Target = table.freeze(table.clone(source.Target))
	return table.freeze(owned)
end

function RewardContext.copyBossSettlement(source: Payloads.BossSettlement): Payloads.BossSettlement
	local owned = table.clone(source)
	owned.Entity = table.freeze(table.clone(source.Entity))
	owned.Contributions = table.freeze(table.clone(source.Contributions))
	return table.freeze(owned)
end

function RewardContext.copyRoundOutcome(source: Payloads.RoundOutcome): Payloads.RoundOutcome
	local owned = table.clone(source)
	owned.Survivors = table.freeze(table.clone(source.Survivors))
	return table.freeze(owned)
end

--[=[ Provider owns immutable authoritative snapshots, including tuning, contribution
	ledger and boost factors. The same source must reproduce the same snapshot on retry.
	No service queries a mutable current boost or invents omitted combat stats.
]=]
return table.freeze(RewardContext)
