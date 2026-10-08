--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local Domain = require(Shared.Contracts.DomainInterfaces)
local Result = require(Shared.Contracts.Result)
local Validation = require(Shared.Registry.Validation)
export type Tuning = { WalkSpeedMultiplier: number?, JumpPowerMultiplier: number? }
local Booster = {}

--[=[ Passives use stable per-gear source IDs. Reapplication replaces that source; unequip removes it. ]=]
function Booster.apply(
	stats: Domain.StatService,
	entity: Payloads.EntityRef,
	gearId: string,
	tuning: Tuning
): Result.Result<boolean>
	if not Validation.id(gearId) then
		return Result.failure("InvalidRequest")
	end
	local source = `gear_{gearId}`
	local modifiers: { Payloads.StatModifier } = {}
	if tuning.WalkSpeedMultiplier then
		table.insert(
			modifiers,
			{ SourceId = source, Stat = "WalkSpeed", Mode = "Multiply", Value = tuning.WalkSpeedMultiplier }
		)
	end
	if tuning.JumpPowerMultiplier then
		table.insert(
			modifiers,
			{ SourceId = source, Stat = "JumpPower", Mode = "Multiply", Value = tuning.JumpPowerMultiplier }
		)
		table.insert(
			modifiers,
			{ SourceId = source, Stat = "JumpHeight", Mode = "Multiply", Value = tuning.JumpPowerMultiplier }
		)
	end
	if #modifiers == 0 then
		return Result.failure("NotReady")
	end
	for _, modifier in modifiers do
		if not Validation.finite(modifier.Value) or modifier.Value <= 0 then
			return Result.failure("InvalidRequest")
		end
	end
	for _, modifier in modifiers do
		local applied = stats:Add(entity, modifier)
		if not applied.Ok then
			stats:RemoveSource(entity, source)
			return Result.failure(applied.Code)
		end
	end
	return Result.success(true)
end

function Booster.remove(
	stats: Domain.StatService,
	entity: Payloads.EntityRef,
	gearId: string
): Result.Result<boolean>
	return stats:RemoveSource(entity, `gear_{gearId}`)
end

return table.freeze(Booster)
