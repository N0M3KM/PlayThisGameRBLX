--!strict
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local Domain = require(Shared.Contracts.DomainInterfaces)
local Result = require(Shared.Contracts.Result)
local Validation = require(Shared.Registry.Validation)
local Config = require(Shared.Config.Combat)
local World = require(script.Parent.Parent.Parent.Services.Combat.CombatWorld)
export type Tuning = { Damage: number, Range: number, Width: number, Height: number, KnockbackSpeed: number? }
export type Options = {
	world: World.World,
	damage: Domain.DamageService,
	knockback: ((Payloads.EntityRef, Vector3) -> ())?,
}
local Melee = {}

--[=[ Bounds and line of sight originate from the current server root, never a client-selected victim. ]=]
function Melee.new(options: Options): (Payloads.EntityRef, Tuning) -> Result.Result<boolean>
	return function(source: Payloads.EntityRef, tuning: Tuning): Result.Result<boolean>
		for _, value in { tuning.Damage, tuning.Range, tuning.Width, tuning.Height } do
			if not Validation.finite(value) or value <= 0 then
				return Result.failure("InvalidRequest")
			end
		end
		if
			tuning.KnockbackSpeed
			and (not Validation.finite(tuning.KnockbackSpeed) or tuning.KnockbackSpeed < 0)
		then
			return Result.failure("InvalidRequest")
		end
		local resolved = options.world.resolve(source)
		local root, model = options.world.root(source), options.world.model(source)
		if not resolved.Ok or resolved.Value.Hp <= 0 or not root or not model then
			return Result.failure("StaleRound")
		end
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		overlap.FilterDescendantsInstances = { model }
		overlap.MaxParts = Config.MaxMeleeTargets * 8
		local center = root.CFrame * CFrame.new(0, 0, -tuning.Range / 2)
		local parts = Workspace:GetPartBoundsInBox(
			center,
			Vector3.new(tuning.Width, tuning.Height, tuning.Range),
			overlap
		)
		local seen: { [string]: boolean } = {}
		local hits = 0
		local ray = RaycastParams.new()
		ray.FilterType = Enum.RaycastFilterType.Exclude
		ray.FilterDescendantsInstances = { model }
		for _, part in parts do
			local target = options.world.fromPart(part)
			if not target or target.RoundId ~= source.RoundId then
				continue
			end
			local identity = `{target.Generation}:{target.Id}`
			if seen[identity] then
				continue
			end
			seen[identity] = true
			local targetRoot = options.world.root(target)
			if not targetRoot or (targetRoot.Position - root.Position).Magnitude > tuning.Range then
				continue
			end
			local obstruction = Workspace:Raycast(root.Position, targetRoot.Position - root.Position, ray)
			if obstruction and options.world.fromPart(obstruction.Instance) ~= target then
				continue
			end
			local result = options.damage:Apply({
				Target = target,
				Source = source,
				Amount = tuning.Damage,
				Faction = resolved.Value.Faction,
				Kind = "Melee",
			})
			if result.Ok and result.Value.ActualHpLoss > 0 then
				hits += 1
				if tuning.KnockbackSpeed and options.knockback then
					local delta = targetRoot.Position - root.Position
					if delta.Magnitude > 0 then
						pcall(options.knockback, target, delta.Unit * tuning.KnockbackSpeed)
					end
				end
			end
			if hits >= Config.MaxMeleeTargets then
				break
			end
		end
		return Result.success(true)
	end
end

return table.freeze(Melee)
