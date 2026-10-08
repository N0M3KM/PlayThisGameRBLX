--!strict
local Pathfinding = game:GetService("PathfindingService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Result = require(Shared.Contracts.Result)
local Config = require("@game/ReplicatedStorage/Shared/Config/DroidRuntime")
local Sync = require("@game/ServerScriptService/Server/Services/Droids/DroidService/Sync")
export type Queue = {
	request: (
		string,
		Vector3,
		Vector3,
		() -> boolean,
		(Result.Result<{ PathWaypoint }>) -> ()
	) -> Result.Result<boolean>,
	step: () -> (),
	remove: (string) -> (),
	metrics: () -> { Pending: number, Active: number },
	destroy: () -> (),
}
type Job = {
	Key: string,
	From: Vector3,
	To: Vector3,
	Current: () -> boolean,
	Callback: (Result.Result<{ PathWaypoint }>) -> (),
	Cancelled: boolean,
	Active: boolean,
	Thread: thread?,
	Path: Path?,
}
local PathQueue = {}

--[=[ ComputeAsync stays serial and concurrency bounded. An expired in-flight computation retains its slot until return. ]=]
function PathQueue.new(clock: () -> number): Queue
	local waiting: { Job } = {}
	local jobs: { [string]: Job } = {}
	local threads: { [thread]: Job } = {}
	local active, destroyed = 0, false
	local function now(): number?
		local ok, value = pcall(function()
			return Sync.call(clock)
		end)
		return if ok
				and type(value) == "number"
				and value == value
				and value >= 0
				and value < math.huge
			then value
			else nil
	end
	local function isCurrent(job: Job): boolean
		if destroyed or job.Cancelled then
			return false
		end
		local ok, value = pcall(function()
			return Sync.call(job.Current)
		end)
		return ok and value == true and not destroyed and not job.Cancelled
	end
	local function destroyPath(job: Job)
		local path = job.Path
		job.Path = nil
		if path then
			pcall(function()
				path:Destroy()
			end)
		end
	end
	local function finish(job: Job)
		destroyPath(job)
		if job.Active then
			job.Active = false
			active -= 1
		end
		if job.Thread then
			threads[job.Thread] = nil
			job.Thread = nil
		end
		if jobs[job.Key] == job then
			jobs[job.Key] = nil
		end
	end
	local function notify(job: Job, result: Result.Result<{ PathWaypoint }>)
		if isCurrent(job) then
			pcall(function()
				Sync.run(function()
					job.Callback(result)
				end)
			end)
		end
	end
	local function run(job: Job)
		local began = now()
		if not began or not isCurrent(job) then
			finish(job)
			return
		end
		-- ComputeAsync may yield; owner cancellation destroys the tracked Path even before it returns.
		local ok, waypoints = pcall(function(): { PathWaypoint }?
			local path = Pathfinding:CreatePath()
			job.Path = path
			path:ComputeAsync(job.From, job.To)
			if not destroyed and not job.Cancelled and path.Status == Enum.PathStatus.Success then
				return path:GetWaypoints()
			end
			return nil
		end)
		finish(job)
		local ended = now()
		if not ended or ended < began or ended - began > Config.PathTimeoutSeconds then
			return
		end
		notify(job, if ok and waypoints then Result.success(waypoints) else Result.failure("Unavailable"))
	end
	return table.freeze({
		request = function(key, from, to, current, callback): Result.Result<boolean>
			if destroyed then
				return Result.failure("NotReady")
			end
			if jobs[key] then
				return Result.failure("Cooldown")
			end
			if #waiting + active >= Config.PathQueueLimit then
				return Result.failure("LimitReached")
			end
			local job: Job = {
				Key = key,
				From = from,
				To = to,
				Current = current,
				Callback = callback,
				Cancelled = false,
				Active = false,
			}
			jobs[key] = job
			table.insert(waiting, job)
			return Result.success(true)
		end,
		step = function()
			local started = 0
			while
				not destroyed
				and active < Config.PathConcurrency
				and #waiting > 0
				and started < Config.PathsPerStep
			do
				local job = table.remove(waiting, 1) :: Job
				if not isCurrent(job) then
					finish(job)
					continue
				end
				active, started = active + 1, started + 1
				job.Active = true
				local thread = coroutine.create(function()
					run(job)
				end)
				job.Thread = thread
				threads[thread] = job
				local spawned = pcall(task.spawn, thread)
				if not spawned then
					finish(job)
					notify(job, Result.failure("Unavailable"))
				end
			end
		end,
		remove = function(key: string)
			local job = jobs[key]
			if job then
				job.Cancelled = true
				jobs[key] = nil
				destroyPath(job)
				local index = table.find(waiting, job)
				if index then
					table.remove(waiting, index)
				end
			end
		end,
		metrics = function()
			return { Pending = #waiting, Active = active }
		end,
		destroy = function()
			destroyed = true
			for _, job in jobs do
				job.Cancelled = true
			end
			for thread, job in threads do
				job.Cancelled = true
				destroyPath(job)
				if coroutine.status(thread) ~= "dead" then
					pcall(task.cancel, thread)
				end
				finish(job)
			end
			table.clear(threads)
			table.clear(waiting)
			table.clear(jobs)
			active = 0
		end,
	})
end
return table.freeze(PathQueue)
