--!strict
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Validation = require("@game/ReplicatedStorage/Shared/Registry/Validation")
local GameConfig = require("@game/ReplicatedStorage/Shared/Config/Game")
local Sync = require("./DroidService/Sync")
local SpawnPolicy = {}

function SpawnPolicy.cap(
	mapRate: number,
	scenario: number,
	event: number,
	maximum: number
): Result.Result<number>
	if not Validation.finite(maximum) or maximum < 0 or maximum % 1 ~= 0 then
		return Result.failure("InvalidRequest")
	end
	for _, value in { mapRate, scenario, event } do
		if not Validation.finite(value) or value < 0 then
			return Result.failure("InvalidRequest")
		end
	end
	local cap = math.floor(GameConfig.BaseDroidCap * mapRate * scenario * event)
	return if Validation.integer(cap, 0, maximum) then Result.success(cap) else Result.failure("LimitReached")
end

--[=[ Never repeats the last marker. If safety excludes all alternatives, wait instead of spawning on a player. ]=]
function SpawnPolicy.select(
	spawns: { Payloads.Point },
	last: number?,
	players: { Payloads.Point },
	minimumDistance: number,
	random: () -> number
): Result.Result<number>
	if not Validation.finite(minimumDistance) or minimumDistance < 0 then
		return Result.failure("InvalidRequest")
	end
	local eligible: { number } = {}
	for index, spawn in spawns do
		if index == last or not Validation.point(spawn, 100000) then
			continue
		end
		local safe = true
		for _, player in players do
			if not Validation.point(player, 100000) then
				return Result.failure("InvalidRequest")
			end
			local dx, dy, dz = spawn.X - player.X, spawn.Y - player.Y, spawn.Z - player.Z
			if dx * dx + dy * dy + dz * dz < minimumDistance * minimumDistance then
				safe = false
				break
			end
		end
		if safe then
			table.insert(eligible, index)
		end
	end
	if #eligible == 0 then
		return Result.failure("NotReady")
	end
	local ok, unit = pcall(function()
		return Sync.call(random)
	end)
	if not ok or not Validation.finite(unit) or unit < 0 or unit >= 1 then
		return Result.failure("Unavailable")
	end
	return Result.success(eligible[math.floor(unit * #eligible) + 1])
end

return table.freeze(SpawnPolicy)
