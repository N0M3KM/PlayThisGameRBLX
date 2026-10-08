--!strict
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local DamageLedger = {}
export type Limits = { MaxFacts: number, MaxContributors: number }
export type Ledger = {
	canRecord: (number?) -> Result.Result<boolean>,
	record: (Payloads.DamageFact) -> Result.Result<boolean>,
	facts: () -> { Payloads.DamageFact },
	contributions: () -> { [number]: number },
}

--[=[ Retains every accepted loss until round cleanup. Capacity failure never evicts reward facts. ]=]
function DamageLedger.new(limits: Limits): Ledger
	assert(limits.MaxFacts > 0 and limits.MaxFacts % 1 == 0, "Invalid fact cap")
	assert(limits.MaxContributors > 0 and limits.MaxContributors % 1 == 0, "Invalid contributor cap")
	local facts: { Payloads.DamageFact } = {}
	local totals: { [number]: number } = {}
	local seen: { [string]: boolean } = {}
	local contributors, dead = 0, false
	local function canRecord(userId: number?): Result.Result<boolean>
		if dead then
			return Result.failure("WrongState")
		end
		if
			#facts >= limits.MaxFacts
			or (userId and not totals[userId] and contributors >= limits.MaxContributors)
		then
			return Result.failure("LimitReached")
		end
		return Result.success(true)
	end
	return {
		canRecord = canRecord,
		record = function(fact)
			if seen[fact.FactId] then
				return Result.failure("WrongState")
			end
			local allowed = canRecord(fact.CreditedUserId)
			if not allowed.Ok then
				return allowed
			end
			if
				fact.ActualHpLoss <= 0
				or fact.ActualHpLoss ~= fact.ActualHpLoss
				or fact.ActualHpLoss == math.huge
			then
				return Result.failure("InvalidRequest")
			end
			local ref = table.freeze(table.clone(fact.Target))
			local owned = table.clone(fact)
			owned.Target = ref
			table.insert(facts, table.freeze(owned))
			seen[fact.FactId] = true
			local userId = fact.CreditedUserId
			if userId then
				if not totals[userId] then
					contributors += 1
				end
				totals[userId] = (totals[userId] or 0) + fact.ActualHpLoss
			end
			dead = fact.Lethal
			return Result.success(true)
		end,
		facts = function()
			return table.freeze(table.clone(facts))
		end,
		contributions = function()
			return table.freeze(table.clone(totals))
		end,
	}
end

return table.freeze(DamageLedger)
