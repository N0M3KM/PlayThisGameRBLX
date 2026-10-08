--!strict
-- Pure result snapshots; settlement and rewards remain owned by the data service.
local States = require("../../Contracts/States")
local Validation = require("../../Registry/Validation")
local Limits = require("../../Config/Validation")

export type Stat = { UserId: number, Kills: number, Damage: number, Assists: number }
export type Options = {
	RoundId: number,
	Reason: States.Outcome,
	Participants: { number },
	Alive: { number },
	Stats: { Stat },
	PreviewOnly: boolean,
}
export type Result = {
	Outcome: { SettlementId: string, RoundId: number, Reason: States.Outcome, Survivors: { number } },
	Leaders: { Kills: number?, Damage: number?, Assists: number? },
	Stats: { Stat },
	PreviewOnly: boolean,
}

local ResultsCalculator = {}

local function finite(value: number): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function positiveInteger(value: number, label: string)
	assert(finite(value) and value > 0 and value % 1 == 0, label .. " must be a positive finite integer")
end

local function validateArray<T>(values: { T }, label: string)
	assert(type(values) == "table", label .. " must be an array")
	local count = 0
	for key in values do
		assert(
			type(key) == "number" and key >= 1 and key % 1 == 0,
			label .. " must have sequential integer keys"
		)
		count += 1
	end
	for index = 1, count do
		assert(values[index] ~= nil, label .. " must not contain gaps")
	end
end

local function idSet(values: { number }, label: string): { [number]: boolean }
	validateArray(values, label)
	local ids: { [number]: boolean } = {}
	for _, userId in values do
		assert(
			Validation.playerId(userId, Limits.MaxInteger),
			label .. " UserId must be a nonzero finite integer"
		)
		assert(not ids[userId], `Duplicate UserId {userId} in {label}`)
		ids[userId] = true
	end
	return ids
end

local function validateStat(stat: Stat)
	assert(type(stat) == "table", "Stats entries must be tables")
	assert(
		Validation.playerId(stat.UserId, Limits.MaxInteger),
		"Stats UserId must be a nonzero finite integer"
	)
	assert(
		finite(stat.Kills) and stat.Kills >= 0 and stat.Kills % 1 == 0,
		"Kills must be a nonnegative finite integer"
	)
	assert(
		finite(stat.Assists) and stat.Assists >= 0 and stat.Assists % 1 == 0,
		"Assists must be a nonnegative finite integer"
	)
	assert(finite(stat.Damage) and stat.Damage >= 0, "Damage must be nonnegative and finite")
end

local function copyStats(values: { Stat }, participants: { [number]: boolean }): { Stat }
	validateArray(values, "Stats")
	local seen: { [number]: boolean } = {}
	local result: { Stat } = {}
	for _, stat in values do
		validateStat(stat)
		assert(not seen[stat.UserId], `Duplicate UserId {stat.UserId} in Stats`)
		seen[stat.UserId] = true
		if participants[stat.UserId] then
			table.insert(
				result,
				table.freeze({
					UserId = stat.UserId,
					Kills = stat.Kills,
					Damage = stat.Damage,
					Assists = stat.Assists,
				})
			)
		end
	end
	table.sort(result, function(left: Stat, right: Stat): boolean
		return left.UserId < right.UserId
	end)
	return table.freeze(result)
end

local function leader(stats: { Stat }, category: "Kills" | "Damage" | "Assists"): number?
	local best = 0
	local userId: number? = nil
	for _, stat in stats do
		local value = stat[category]
		if value > best then
			best = value
			userId = stat.UserId
		end
	end
	return userId
end

--[=[ Copies and freezes a round result without awarding currency or writing profiles.
	Positive category ties use the lowest UserId as a deterministic presentation rule.
	Alive/stat records outside the participant snapshot cannot appear in the result.
]=]
function ResultsCalculator.calculate(options: Options): Result
	positiveInteger(options.RoundId, "RoundId")
	assert(States.Outcome[options.Reason] ~= nil, "Reason must be a supported round outcome")
	assert(type(options.PreviewOnly) == "boolean", "PreviewOnly must be a boolean")
	local participants = idSet(options.Participants, "Participants")
	local alive = idSet(options.Alive, "Alive")
	local stats = copyStats(options.Stats, participants)
	local survivors: { number } = {}
	if options.Reason == "Survived" or options.Reason == "BossDefeated" then
		for userId in alive do
			if participants[userId] then
				table.insert(survivors, userId)
			end
		end
	end
	table.sort(survivors)
	local outcome = table.freeze({
		SettlementId = "round_" .. tostring(options.RoundId),
		RoundId = options.RoundId,
		Reason = options.Reason,
		Survivors = table.freeze(survivors),
	})
	local leaders = table.freeze({
		Kills = leader(stats, "Kills"),
		Damage = leader(stats, "Damage"),
		Assists = leader(stats, "Assists"),
	})
	return table.freeze({
		Outcome = outcome,
		Leaders = leaders,
		Stats = stats,
		PreviewOnly = options.PreviewOnly,
	})
end

return table.freeze(ResultsCalculator)
