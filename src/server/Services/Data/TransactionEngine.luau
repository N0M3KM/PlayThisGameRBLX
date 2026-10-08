--!strict
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Operations = require("./ProfileOperations")
local Transaction = require("./DataService/Transaction")
local TransactionEngine = {}
export type Runtime = {
	clock: () -> number,
	wait: (number) -> (),
	QueueTimeoutSeconds: number,
	PollIntervalSeconds: number,
	MaxPendingPerPlayer: number,
}
type Ticket = { Deadline: number }

--[=[ A bounded FIFO serializes B-owned operations without refreshing stale revisions.
	The boundary remains the only profile owner; uncertainty fencing stays there.
]=]
function TransactionEngine.new(boundary: Operations.Boundary, timing: Runtime): Operations.Engine
	assert(timing.QueueTimeoutSeconds > 0 and timing.QueueTimeoutSeconds < math.huge, "Invalid queue timeout")
	assert(
		timing.PollIntervalSeconds > 0 and timing.PollIntervalSeconds < math.huge,
		"Invalid queue poll interval"
	)
	assert(timing.MaxPendingPerPlayer >= 1 and timing.MaxPendingPerPlayer % 1 == 0, "Invalid queue capacity")
	local queues: { [number]: { Ticket } } = {}
	return table.freeze({
		execute = function(
			command: Operations.Command,
			mutator: Operations.Mutator,
			guard: Operations.Guard?
		): Result.Result<Payloads.TransactionReceipt>
			if not Transaction.validateMutation(command) then
				return Result.failure("InvalidRequest")
			end
			-- Queue waits may yield. Own the complete identity before entering the queue.
			local owned: Operations.Command = table.freeze({
				TransactionId = command.TransactionId,
				UserId = command.UserId,
				ExpectedRevision = command.ExpectedRevision,
				Reason = command.Reason,
				Fingerprint = command.Fingerprint,
			})
			local userId = owned.UserId
			local queue = queues[userId]
			if not queue then
				queue = {}
				queues[userId] = queue
			end
			if #queue >= timing.MaxPendingPerPlayer then
				return Result.failure("RateLimited")
			end
			local ticket = { Deadline = timing.clock() + timing.QueueTimeoutSeconds }
			table.insert(queue, ticket)
			local function remove()
				local index = table.find(queue :: { Ticket }, ticket)
				if index then
					table.remove(queue :: { Ticket }, index)
				end
				if #queue == 0 then
					queues[userId] = nil
				end
			end
			while queue[1] ~= ticket and timing.clock() < ticket.Deadline do
				timing.wait(
					math.min(timing.PollIntervalSeconds, math.max(0, ticket.Deadline - timing.clock()))
				)
			end
			if timing.clock() >= ticket.Deadline then
				remove()
				return Result.failure("Unavailable")
			end
			local ok, receipt = pcall(boundary.ApplyMutation, boundary, owned, mutator, guard)
			remove()
			return if ok then receipt else Result.failure("Unavailable")
		end,
	})
end

return table.freeze(TransactionEngine)
