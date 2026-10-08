--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.Data)
local Result = require(Shared.Contracts.Result)
local ProfileAdapter = require(script.Parent.Parent.ProfileAdapter)
local ProfileTypes = require(script.Parent.Parent.ProfileTypes)
local DataSnapshot = require(script.Parent.DataSnapshot)
local Transaction = require(script.Parent.Transaction)
local ProfileOperations = require(script.Parent.Parent.ProfileOperations)
local SessionRecord = {}
export type Record = {
	Session: ProfileAdapter.Session,
	Committed: ProfileTypes.Profile,
	Clock: number,
	Busy: boolean,
	Fenced: boolean,
	Released: boolean,
	Releasing: boolean,
	DisconnectedAt: number?,
	Disconnect: () -> (),
}

function SessionRecord.new(session: ProfileAdapter.Session): Record
	return {
		Session = session,
		Committed = session.read(),
		Clock = os.clock(),
		Busy = false,
		Fenced = false,
		Released = false,
		Releasing = false,
		Disconnect = function() end,
	}
end

function SessionRecord.candidate(record: Record): (ProfileTypes.Profile, number)
	local now = record.DisconnectedAt or os.clock()
	return DataSnapshot.checkpoint(record.Committed, now - record.Clock), now
end

--[=[ A failed confirmation may have persisted. Fence rather than roll back an uncertain write. ]=]
function SessionRecord.commit(
	record: Record,
	candidate: ProfileTypes.Profile,
	checkpointTime: number,
	deadline: number,
	guard: ProfileOperations.Guard?
): Result.Result<boolean>
	if record.Fenced or not record.Session.isActive() or not Transaction.guard(guard) then
		return Result.failure("WrongState")
	end
	if
		candidate.Revision == record.Committed.Revision
		and candidate.Wheel.FreeSpinRemainingSeconds ~= record.Committed.Wheel.FreeSpinRemainingSeconds
	then
		if candidate.Revision >= Config.MaxInteger then
			return Result.failure("LimitReached")
		end
		candidate.Revision += 1
	end
	local replaced = record.Session.replace(candidate)
	if not replaced.Ok then
		return replaced
	end
	record.Clock = checkpointTime
	local confirmed = record.Session.saveConfirmed(deadline)
	if not confirmed.Ok or record.Fenced or not record.Session.isActive() then
		record.Fenced = true
		return Result.failure("Unavailable")
	end
	-- A mutator may retain its candidate. Publish an owned copy of the exact
	-- snapshot sent for confirmation rather than that caller-held reference.
	record.Committed = record.Session.read()
	return Result.success(true)
end

--[=[ Release waits for the owned in-flight operation within the shared shutdown deadline. ]=]
function SessionRecord.release(record: Record, deadline: number): Result.Result<boolean>
	record.Fenced = true
	record.DisconnectedAt = record.DisconnectedAt or os.clock()
	record.Disconnect()
	if record.Released then
		return Result.success(true)
	end
	if record.Releasing then
		while record.Releasing and os.clock() < deadline do
			task.wait(math.min(Config.ProfilePollIntervalSeconds, math.max(0, deadline - os.clock())))
		end
		return if record.Released then Result.success(true) else Result.failure("Unavailable")
	end
	record.Releasing = true
	while record.Busy and os.clock() < deadline do
		task.wait(math.min(Config.ProfilePollIntervalSeconds, math.max(0, deadline - os.clock())))
	end
	if not record.Busy and record.Session.isActive() and os.clock() < deadline then
		-- Use the working profile: an in-flight transaction could have persisted despite its caller timing out.
		pcall(function()
			local working = record.Session.read()
			local candidate =
				DataSnapshot.checkpoint(working, (record.DisconnectedAt :: number) - record.Clock)
			if candidate.Wheel.FreeSpinRemainingSeconds ~= working.Wheel.FreeSpinRemainingSeconds then
				if candidate.Revision >= Config.MaxInteger then
					return
				end
				candidate.Revision += 1
			end
			if record.Session.replace(candidate).Ok then
				record.Session.saveConfirmed(deadline)
			end
		end)
	end
	local ok, result = pcall(record.Session.release, deadline)
	record.Releasing = false
	record.Released = ok and result.Ok
	return if ok then result else Result.failure("Unavailable")
end

return table.freeze(SessionRecord)
