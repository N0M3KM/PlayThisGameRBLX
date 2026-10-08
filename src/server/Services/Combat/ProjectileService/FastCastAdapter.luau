--!strict
-- Verified against the original FastCast API docs on 2026-10-08. No package is installed here.
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Types = require("./Types")
local Validate = require("./Validation")
local FastCastAdapter = {}
export type Connection = { Disconnect: (Connection) -> () }
export type ActiveCast = { Terminate: (ActiveCast) -> () }
export type Hit = { Instance: unknown }
export type Behavior = { MaxDistance: number, RaycastParams: unknown? }
export type Caster = {
	Fire: (Caster, unknown, unknown, number, Behavior) -> ActiveCast,
	RayHit: { Connect: (unknown, (ActiveCast, Hit) -> ()) -> Connection },
	CastTerminating: { Connect: (unknown, (ActiveCast) -> ()) -> Connection },
}
export type Api = { new: () -> Caster, newBehavior: () -> Behavior }
type Record = { hit: (unknown) -> (), ended: () -> (), hitOnce: boolean }

--[=[ One listener pair per caster; CastTerminating owns cleanup, including misses and cancellation. ]=]
function FastCastAdapter.new(api: Api): Result.Result<Types.Transport>
	local ok, caster = Validate.sync(api.new)
	if not ok or not caster then
		return Result.failure("Unavailable")
	end
	local records: { [ActiveCast]: Record } = {}
	local connections: { Connection } = {}
	local destroyed, fenced = false, false
	local unknownLaunch = false
	local function finish(cast: ActiveCast)
		local record = records[cast]
		if not record then
			return
		end
		records[cast] = nil
		pcall(record.ended)
	end
	local function terminate(cast: ActiveCast): Result.Result<boolean>
		if not records[cast] then
			return Result.success(true)
		end
		local stopped = pcall(cast.Terminate, cast)
		if not stopped then
			-- Do not release capacity for a cast whose underlying simulation might still run.
			fenced = true
			return Result.failure("Unavailable")
		end
		finish(cast)
		return Result.success(true)
	end
	local connected = pcall(function()
		table.insert(
			connections,
			caster.RayHit:Connect(function(cast: ActiveCast, hit: Hit)
				local record = records[cast]
				if not record or record.hitOnce or destroyed or fenced then
					return
				end
				record.hitOnce = true
				pcall(record.hit, hit.Instance)
			end)
		)
		table.insert(connections, caster.CastTerminating:Connect(finish))
	end)
	if not connected then
		for _, connection in connections do
			pcall(connection.Disconnect, connection)
		end
		return Result.failure("Unavailable")
	end
	local function clear(): Result.Result<boolean>
		local pending: { ActiveCast } = {}
		for cast in records do
			table.insert(pending, cast)
		end
		local all = not unknownLaunch
		for _, cast in pending do
			if not terminate(cast).Ok then
				all = false
			end
		end
		return if all then Result.success(true) else Result.failure("Unavailable")
	end
	local transport: Types.Transport = {
		fire = function(launch, hit, ended): Result.Result<Types.Handle>
			if destroyed or fenced then
				return Result.failure("NotReady")
			end
			local fired, cast = Validate.sync(function()
				local behavior = api.newBehavior()
				behavior.MaxDistance = launch.Range
				behavior.RaycastParams = launch.RaycastParams
				return caster:Fire(
					Vector3.new(launch.Origin.X, launch.Origin.Y, launch.Origin.Z),
					Vector3.new(launch.Direction.X, launch.Direction.Y, launch.Direction.Z),
					launch.Speed,
					behavior
				)
			end)
			if not fired or not cast then
				-- Fire may have side effects before throwing. Never retry against an unknown cast.
				fenced = true
				unknownLaunch = true
				return Result.failure("Unavailable")
			end
			records[cast] = { hit = hit, ended = ended, hitOnce = false }
			return Result.success({
				cancel = function()
					return terminate(cast)
				end,
			})
		end,
		clear = clear,
		destroy = function(): Result.Result<boolean>
			local cleaned = clear()
			if not cleaned.Ok then
				return cleaned
			end
			destroyed = true
			for _, connection in connections do
				pcall(connection.Disconnect, connection)
			end
			connections = {}
			return Result.success(true)
		end,
	}
	return Result.success(transport)
end

return table.freeze(FastCastAdapter)
