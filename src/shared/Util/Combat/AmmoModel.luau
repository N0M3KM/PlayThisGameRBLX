--!strict
local Result = require("../../Contracts/Result")
local Validation = require("../../Registry/Validation")
export type Snapshot = { Loaded: number, Reserve: number, Capacity: number, ReloadEndsAt: number? }
export type Model = {
	snapshot: (number) -> Snapshot,
	fire: (number) -> Result.Result<Snapshot>,
	reload: (number, number) -> Result.Result<Snapshot>,
	cancelReload: () -> (),
	addMagazines: (number) -> Result.Result<Snapshot>,
}
local AmmoModel = {}

--[=[ Owns one weapon's magazine/reserve. Reload transfers once when server time reaches its end. ]=]
function AmmoModel.new(capacity: number, loaded: number, reserve: number, maxReserve: number): Model
	assert(Validation.integer(maxReserve, 1, 9007199254740991), "Invalid reserve capacity")
	assert(Validation.integer(capacity, 1, maxReserve), "Invalid magazine capacity")
	assert(Validation.integer(loaded, 0, capacity), "Invalid loaded ammo")
	assert(Validation.integer(reserve, 0, maxReserve), "Invalid reserve ammo")
	local endsAt: number? = nil
	local lastNow = 0
	local function advance(now: number): boolean
		if not Validation.finite(now) or now < lastNow then
			return false
		end
		lastNow = now
		if endsAt and now >= endsAt then
			local transferred = math.min(capacity - loaded, reserve)
			loaded += transferred
			reserve -= transferred
			endsAt = nil
		end
		return true
	end
	local function snapshot(): Snapshot
		return table.freeze({ Loaded = loaded, Reserve = reserve, Capacity = capacity, ReloadEndsAt = endsAt })
	end
	return table.freeze({
		snapshot = function(now: number): Snapshot
			advance(now)
			return snapshot()
		end,
		fire = function(now: number): Result.Result<Snapshot>
			if not advance(now) then
				return Result.failure("InvalidRequest")
			end
			if endsAt then
				return Result.failure("WrongState")
			end
			if loaded == 0 then
				return Result.failure("LimitReached")
			end
			loaded -= 1
			return Result.success(snapshot())
		end,
		reload = function(now: number, duration: number): Result.Result<Snapshot>
			if
				not advance(now)
				or not Validation.finite(duration)
				or duration <= 0
				or not Validation.finite(now + duration)
			then
				return Result.failure("InvalidRequest")
			end
			if endsAt or loaded == capacity or reserve == 0 then
				return Result.failure("WrongState")
			end
			endsAt = now + duration
			return Result.success(snapshot())
		end,
		cancelReload = function()
			endsAt = nil
		end,
		addMagazines = function(count: number): Result.Result<Snapshot>
			if not Validation.integer(count, 1, maxReserve) then
				return Result.failure("InvalidRequest")
			end
			reserve = math.min(maxReserve, reserve + capacity * count)
			return Result.success(snapshot())
		end,
	})
end

return table.freeze(AmmoModel)
