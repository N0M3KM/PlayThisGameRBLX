--!strict
local AI = require("@game/ReplicatedStorage/Shared/Config/AI")
local DroidAI = require("@game/ReplicatedStorage/Shared/Contracts/DroidAI")
local Pool = require("../Actors/Pool")
local Scheduler = require("./")
export type Job =
	{ Id: number, RoundId: number, Sequence: number, Began: number, Agents: { [string]: number } }
local Planner = {}

local function workerFor(id: string, count: number): number
	local hash = 0
	for index = 1, #id do
		hash = (hash * 31 + string.byte(id, index)) % 2147483647
	end
	return hash % count + 1
end

--[=[ Partition ownership is stable throughout a round; busy workers do not consume LOD slots. ]=]
function Planner.choose(
	frame: DroidAI.Frame,
	config: AI.Config,
	pool: Pool.Api,
	pending: { [number]: Job },
	scheduler: Scheduler.Api,
	now: number,
	budgetMs: number
): { [number]: { string } }
	local count = 0
	for _ in pending do
		count += 1
	end
	local allowance = math.max(0, config.MaxPendingBatches - count)
	local batches: { [number]: { string } } = {}
	local batchCount = 0
	scheduler.choose(
		frame,
		now,
		config.MaxDecisionsPerFrame,
		math.min(budgetMs, config.FrameBudgetMs),
		os.clock,
		function(id: string): boolean
			local workerId = workerFor(id, config.WorkerCount)
			local worker = pool.Workers[workerId]
			if not worker or not worker.Ready or pending[workerId] then
				return false
			end
			local batch = batches[workerId]
			if not batch then
				if batchCount >= allowance then
					return false
				end
				batch = {}
				batches[workerId] = batch
				batchCount += 1
			end
			if #batch >= config.MaxBatchSize then
				return false
			end
			table.insert(batch, id)
			return true
		end
	)
	return batches
end
return table.freeze(Planner)
