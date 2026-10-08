--!strict
local Result = require("../../Contracts/Result")
local Validation = require("../../Registry/Validation")
local CooldownTracker = {}
export type Tracker = {
	ready: (string, number) -> boolean,
	take: (string, number, number) -> Result.Result<boolean>,
	remove: (string) -> (),
	clear: () -> (),
}

--[=[ Each key is an owned entity/gear/action identity; callers provide a monotonic server clock. ]=]
function CooldownTracker.new(maxKeys: number): Tracker
	assert(Validation.integer(maxKeys, 1, 100000), "Invalid cooldown capacity")
	local deadlines: { [string]: number } = {}
	local count = 0
	local lastNow = 0
	local function valid(now: number): boolean
		if not Validation.finite(now) or now < lastNow then
			return false
		end
		lastNow = now
		return true
	end
	return table.freeze({
		ready = function(key: string, now: number): boolean
			return valid(now) and (deadlines[key] == nil or now >= deadlines[key])
		end,
		take = function(key: string, now: number, duration: number): Result.Result<boolean>
			if
				#key == 0
				or #key > 128
				or not valid(now)
				or not Validation.finite(duration)
				or duration < 0
				or not Validation.finite(now + duration)
			then
				return Result.failure("InvalidRequest")
			end
			if deadlines[key] and now < deadlines[key] then
				return Result.failure("Cooldown")
			end
			if not deadlines[key] then
				for expiredKey, expiresAt in deadlines do
					if now >= expiresAt then
						deadlines[expiredKey] = nil
						count -= 1
					end
				end
				if count >= maxKeys then
					return Result.failure("LimitReached")
				end
				count += 1
			end
			deadlines[key] = now + duration
			return Result.success(true)
		end,
		remove = function(key: string)
			if deadlines[key] then
				count -= 1
				deadlines[key] = nil
			end
		end,
		clear = function()
			table.clear(deadlines)
			count = 0
		end,
	})
end

return table.freeze(CooldownTracker)
