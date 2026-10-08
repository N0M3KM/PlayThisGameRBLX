--!strict
export type Worker = {
	Id: number,
	Actor: Actor,
	Outcome: BindableEvent,
	Connection: RBXScriptConnection,
	Ready: boolean,
	CreatedAt: number,
	Retries: number,
}
export type Api = {
	Workers: { [number]: Worker },
	spawn: (number, number, number) -> Worker,
	remove: (number) -> (),
	destroy: () -> (),
}
local Pool = {}

--[=[ Pool owns Actors, scripts and result connections; no per-droid Instances or Heartbeats. ]=]
function Pool.new(
	template: Script,
	parent: Instance,
	onResult: (Worker, unknown, unknown, unknown, unknown, unknown) -> ()
): Api
	local folder = Instance.new("Folder")
	folder.Name = "PTG_DroidWorkers"
	folder.Parent = parent
	local workers: { [number]: Worker } = {}
	local function remove(id: number)
		local worker = workers[id]
		if worker then
			workers[id] = nil
			worker.Connection:Disconnect()
			worker.Actor:Destroy()
		end
	end
	return {
		Workers = workers,
		remove = remove,
		spawn = function(id, now, retries): Worker
			remove(id)
			local actor = Instance.new("Actor")
			actor.Name = "Worker_" .. tostring(id)
			local outcome = Instance.new("BindableEvent")
			outcome.Name = "Outcome"
			outcome.Parent = actor
			local worker: Worker
			local connection = outcome.Event:Connect(function(jobId, decisions, elapsed, failures, crashed)
				if workers[id] ~= worker then
					return
				end
				if jobId == "Ready" then
					worker.Ready = true
				else
					onResult(worker, jobId, decisions, elapsed, failures, crashed)
				end
			end)
			worker = {
				Id = id,
				Actor = actor,
				Outcome = outcome,
				Connection = connection,
				Ready = false,
				CreatedAt = now,
				Retries = retries,
			}
			workers[id] = worker
			local runner = template:Clone()
			runner.Name = "BrainWorker"
			runner.Enabled = false
			runner.Parent = actor
			actor.Parent = folder
			runner.Enabled = true
			return worker
		end,
		destroy = function()
			for id in workers do
				remove(id)
			end
			folder:Destroy()
		end,
	}
end
return table.freeze(Pool)
