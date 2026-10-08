--!strict
local Config = require("@game/ReplicatedStorage/Shared/Config/Data")
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Validation = require("@game/ReplicatedStorage/Shared/Registry/Validation")
local Operations = require("../ProfileOperations")
local ProfileTypes = require("../ProfileTypes")
local Settlement = {}
export type Payout = {
	UserId: number,
	Coins: number,
	XP: number,
	Kills: number,
	Damage: number,
	Assists: number,
	Survives: number,
	Rounds: number,
}
export type Plan = {
	Kind: "Kill" | "Boss" | "Survival",
	SourceId: string,
	SnapshotId: string,
	Payouts: { Payout },
}

function Settlement.empty(userId: number): Payout
	return { UserId = userId, Coins = 0, XP = 0, Kills = 0, Damage = 0, Assists = 0, Survives = 0, Rounds = 0 }
end

local function nonnegative(value: number): boolean
	return Validation.finite(value) and value >= 0 and value <= Config.MaxInteger
end

local function validPayout(payout: Payout): boolean
	if not Validation.playerId(payout.UserId, Config.MaxInteger) then
		return false
	end
	for _, value in { payout.Coins, payout.XP, payout.Damage } do
		if not nonnegative(value) then
			return false
		end
	end
	for _, value in { payout.Kills, payout.Assists, payout.Survives, payout.Rounds } do
		if not nonnegative(value) or value % 1 ~= 0 then
			return false
		end
	end
	return true
end

function Settlement.credit(profile: ProfileTypes.Profile, payout: Payout): Result.Result<boolean>
	local coins, xp = profile.Coins + payout.Coins, profile.TotalXP + payout.XP
	if not nonnegative(coins) or not nonnegative(xp) then
		return Result.failure("LimitReached")
	end
	for _, key in { "Kills", "Damage", "Assists", "Survives", "Rounds" } do
		if not nonnegative(profile.Stats[key] + payout[key]) then
			return Result.failure("LimitReached")
		end
	end
	profile.Coins, profile.TotalXP = coins, xp
	for _, key in { "Kills", "Damage", "Assists", "Survives", "Rounds" } do
		profile.Stats[key] += payout[key]
	end
	return Result.success(true)
end

--[=[ Partial multi-player failure is not acknowledged. Durable per-target entries make
	a retry skip confirmed credits and continue remaining recipients, including reconnects.
]=]
function Settlement.apply(
	data: Operations.Boundary,
	engine: Operations.Engine,
	plan: Plan,
	guard: Operations.Guard
): Result.Result<{ Payloads.TransactionReceipt }>
	local sourceId, snapshotId = plan.SourceId, plan.SnapshotId
	local kind: "Kill" | "Boss" | "Survival" = plan.Kind
	if #sourceId == 0 or #snapshotId == 0 or #snapshotId > Config.MaxTransactionIdLength then
		return Result.failure("InvalidRequest")
	end
	local seen: { [number]: boolean } = {}
	local sorted: { Payout } = {}
	for _, payout in plan.Payouts do
		if #sorted >= Config.MaxCollectionEntries or seen[payout.UserId] or not validPayout(payout) then
			return Result.failure("InvalidRequest")
		end
		seen[payout.UserId] = true
		local id = string.format("%s:%d:%s:%.0f", kind, #sourceId, sourceId, payout.UserId)
		if #id > Config.MaxTransactionIdLength then
			return Result.failure("InvalidRequest")
		end
		table.insert(sorted, table.freeze(table.clone(payout)))
	end
	table.sort(sorted, function(a, b)
		return a.UserId < b.UserId
	end)
	local receipts: { Payloads.TransactionReceipt } = {}
	for _, payout in sorted do
		local read = data:Read(payout.UserId)
		if not read.Ok then
			return Result.failure(read.Code)
		end
		local command: Operations.Command = {
			TransactionId = string.format("%s:%d:%s:%.0f", kind, #sourceId, sourceId, payout.UserId),
			UserId = payout.UserId,
			ExpectedRevision = read.Value.Revision,
			Reason = kind,
			Fingerprint = string.format(
				"%s|%.17g|%.17g|%.0f|%.17g|%.0f|%.0f|%.0f",
				snapshotId,
				payout.Coins,
				payout.XP,
				payout.Kills,
				payout.Damage,
				payout.Assists,
				payout.Survives,
				payout.Rounds
			),
		}
		local receipt = engine.execute(command, function(profile)
			return Settlement.credit(profile, payout)
		end, guard)
		if not receipt.Ok then
			return Result.failure(receipt.Code)
		end
		table.insert(receipts, receipt.Value)
	end
	return Result.success(table.freeze(receipts))
end

return table.freeze(Settlement)
