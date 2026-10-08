--!strict
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Projection = require("./Projection")
export type Replica = {
	SetValue: (self: Replica, path: { string }, value: unknown) -> (),
	IsActive: (self: Replica) -> boolean,
	Destroy: (self: Replica) -> (),
}
export type Parameters = {
	ClassToken: unknown,
	Data: { Snapshot: unknown },
	Replication: unknown,
	Tags: { [string]: number | string },
}
export type Api = {
	NewClassToken: (name: string) -> unknown,
	NewReplica: (parameters: Parameters) -> Replica,
}
export type Record = {
	Replica: Replica?,
	Owner: unknown,
	Snapshot: unknown,
	Revision: number,
	Poisoned: boolean,
}
local TransportRecord = {}

function TransportRecord.destroy(record: Record): boolean
	record.Poisoned = true
	if not record.Replica then
		return false -- Constructor errors supplied no safe cleanup handle; never retry creation.
	end
	return pcall(function()
		local replica = record.Replica :: Replica
		replica:Destroy()
		assert(not replica:IsActive(), "Destroy left an active replica")
	end)
end

local function update(
	record: Record,
	owner: unknown,
	snapshot: unknown,
	revision: number
): Result.Result<boolean>
	if record.Poisoned or record.Owner ~= owner then
		return Result.failure("Unavailable")
	end
	if revision < record.Revision then
		return Result.failure("InvalidRequest")
	end
	local active, isActive = pcall(function()
		return (record.Replica :: Replica):IsActive()
	end)
	if not active or not isActive then
		TransportRecord.destroy(record)
		return Result.failure("Unavailable")
	end
	if revision == record.Revision then
		return if Projection.equal(record.Snapshot, snapshot)
			then Result.success(true)
			else Result.failure("InvalidRequest")
	end
	local ok = pcall(function()
		local replica = record.Replica :: Replica
		assert(replica:IsActive(), "Inactive replica")
		replica:SetValue({ "Snapshot" }, Projection.copy(snapshot))
		assert(replica:IsActive(), "Update left an inactive replica")
	end)
	if not ok then
		TransportRecord.destroy(record)
		return Result.failure("Unavailable")
	end
	record.Snapshot, record.Revision = snapshot, revision
	return Result.success(true)
end

function TransportRecord.publish(
	api: Api,
	record: Record?,
	owner: unknown,
	snapshot: unknown,
	revision: number,
	classToken: unknown,
	tags: { [string]: number | string }
): (Result.Result<boolean>, Record)
	if record then
		return update(record, owner, snapshot, revision), record
	end
	local created: Record = { Owner = owner, Snapshot = snapshot, Revision = revision, Poisoned = true }
	local ok, replica = pcall(api.NewReplica, {
		ClassToken = classToken,
		Data = { Snapshot = Projection.copy(snapshot) },
		Replication = owner,
		Tags = tags,
	})
	if not ok then
		return Result.failure("Unavailable"), created
	end
	created.Replica = replica
	local active, isActive = pcall(function()
		return replica:IsActive()
	end)
	if not active or not isActive then
		TransportRecord.destroy(created)
		return Result.failure("Unavailable"), created
	end
	created.Poisoned = false
	return Result.success(true), created
end

return table.freeze(TransportRecord)
