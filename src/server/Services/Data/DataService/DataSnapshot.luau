--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local Game = require(Shared.Config.Game)
local DeepFreeze = require(Shared.Util.DeepFreeze)
local XpCurve = require(Shared.Util.Economy.XpCurve)
local ProfileTypes = require(script.Parent.Parent.ProfileTypes)
local ProfileTemplate = require(script.Parent.Parent.ProfileTemplate)
local DataSnapshot = {}

--[=[ Publishes only the minimal public profile surface. Linear XP pacing is provisional (D-21). ]=]
function DataSnapshot.create(userId: number, profile: ProfileTypes.Profile): Payloads.PlayerDataSnapshot
	local copy = ProfileTemplate.clone(profile)
	local result: Payloads.PlayerDataSnapshot = {
		SchemaVersion = copy.SchemaVersion,
		UserId = userId,
		Revision = copy.Revision,
		Coins = copy.Coins,
		TotalXP = copy.TotalXP,
		Level = XpCurve.calculate(copy.TotalXP, Game.Proposals.XpPerLevel).Level,
		Inventory = copy.Inventory,
		FreeSpinRemainingSeconds = copy.Wheel.FreeSpinRemainingSeconds,
		PaidSpins = copy.Wheel.PendingPaidSpins,
	}
	DeepFreeze.freeze((result :: unknown) :: DeepFreeze.DataTable)
	return result
end

--[=[ Checkpoints only monotonic seconds spent loaded and connected; never wall-clock downtime. ]=]
function DataSnapshot.checkpoint(profile: ProfileTypes.Profile, elapsed: number): ProfileTypes.Profile
	local candidate = ProfileTemplate.clone(profile)
	candidate.Wheel.FreeSpinRemainingSeconds =
		math.max(0, candidate.Wheel.FreeSpinRemainingSeconds - math.max(0, elapsed))
	return candidate
end

return table.freeze(DataSnapshot)
