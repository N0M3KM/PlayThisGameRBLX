--!strict
local AI = require("@game/ReplicatedStorage/Shared/Config/AI")
local DroidAI = require("@game/ReplicatedStorage/Shared/Contracts/DroidAI")
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
export type Api = {
	choose: (DroidAI.Frame, number, number, number, () -> number, (string) -> boolean) -> { string },
	clear: () -> (),
}
local Scheduler = {}

local function key(entity: Payloads.EntityRef): string
	return tostring(entity.RoundId) .. ":" .. tostring(entity.Generation) .. ":" .. entity.Id
end

--[=[ Fair bounded scanning; near/mid/far intervals are injected technical policy. ]=]
function Scheduler.new(config: AI.Config): Api
	local last: { [string]: number } = {}
	local cursor = 1
	local api: Api = {
		clear = function()
			table.clear(last)
			cursor = 1
		end,
		choose = function(
			frame: DroidAI.Frame,
			now: number,
			limit: number,
			budgetMs: number,
			clock: () -> number,
			accept: (string) -> boolean
		): { string }
			local selected: { string } = {}
			local present: { [string]: boolean } = {}
			for _, agent in frame.Agents do
				present[key(agent.Entity)] = true
			end
			for id in last do
				if not present[id] then
					last[id] = nil
				end
			end
			local began = clock()
			local count, scanned, pairsChecked = #frame.Agents, 0, 0
			while scanned < count and #selected < limit do
				if (clock() - began) * 1000 >= budgetMs then
					break
				end
				if cursor > count then
					cursor = 1
				end
				local agent = frame.Agents[cursor]
				cursor += 1
				scanned += 1
				local nearest = math.huge
				for _, target in frame.Targets do
					if pairsChecked >= config.MaxPairs then
						break
					end
					pairsChecked += 1
					if target.Hp > 0 then
						local a, b = agent.Position, target.Position
						local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
						nearest = math.min(nearest, dx * dx + dy * dy + dz * dz)
					end
				end
				local interval = if nearest <= config.NearDistance ^ 2
					then config.NearIntervalSeconds
					elseif nearest <= config.MidDistance ^ 2 then config.MidIntervalSeconds
					else config.FarIntervalSeconds
				local id = key(agent.Entity)
				if
					agent.Hp > 0
					and now >= (last[id] or -math.huge) + interval
					and accept(agent.Entity.Id)
				then
					last[id] = now
					table.insert(selected, agent.Entity.Id)
				end
			end
			return selected
		end,
	}
	return table.freeze(api)
end
return table.freeze(Scheduler)
