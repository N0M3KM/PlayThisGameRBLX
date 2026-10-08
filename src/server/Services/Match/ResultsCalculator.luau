--!strict
-- Server presentation/settlement adapter. Currency calculation remains in EconomyService.
local Shared = game:GetService("ReplicatedStorage").Shared
local HttpService = game:GetService("HttpService")
local States = require(Shared.Contracts.States)
local Results = require(Shared.Util.Match.ResultsCalculator)
local Integration = require(script.Parent.GameLoopService.RoundIntegration)
local ResultsCalculator = {}

--[=[ Uses a server-unique settlement identity and publishes a frozen result once per caller.
	The match session owns the once-only guard; EconomyService owns durable idempotency.
]=]
function ResultsCalculator.new(
	integration: Integration.Integration,
	preview: boolean,
	ended: (Results.Result) -> ()
): (number, States.Outcome, { number }, { number }) -> ()
	local prefix = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false)
	return function(roundId: number, reason: States.Outcome, participants: { number }, alive: { number })
		local queried = table.pack(pcall(integration.stats, roundId))
		local statsReady = queried[1] == true
		local stats: { Results.Stat } = {}
		if statsReady then
			stats = (queried[2] :: unknown) :: { Results.Stat }
		else
			warn(`Round {roundId} statistics unavailable; settlement withheld: {tostring(queried[2])}`)
		end
		local options: Results.Options = {
			RoundId = roundId,
			Reason = reason,
			Participants = participants,
			Alive = alive,
			Stats = stats,
			PreviewOnly = preview or not statsReady,
		}
		local checked = table.pack(pcall(Results.calculate, options))
		local calculated: Results.Result
		if checked[1] then
			calculated = (checked[2] :: unknown) :: Results.Result
		else
			-- A malformed domain stat snapshot must not hide the terminal match outcome.
			warn(`Round {roundId} statistics rejected; settlement withheld: {tostring(checked[2])}`)
			statsReady, options.Stats, options.PreviewOnly = false, {}, true
			calculated = Results.calculate(options)
		end
		local outcome = table.clone(calculated.Outcome)
		outcome.SettlementId = `{prefix}:{calculated.Outcome.SettlementId}`
		table.freeze(outcome)
		local result = table.clone(calculated)
		result.Outcome = outcome
		table.freeze(result)
		local published = table.pack(pcall(ended, result))
		if not published[1] then
			warn(`Results publishing failed: {tostring(published[2])}`)
		end
		if statsReady then
			local settled = table.pack(pcall(integration.settle, outcome))
			if not settled[1] then
				warn(`Round settlement {outcome.SettlementId} failed: {tostring(settled[2])}`)
			end
		end
	end
end

return table.freeze(ResultsCalculator)
