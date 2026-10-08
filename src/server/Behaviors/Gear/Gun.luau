--!strict
local Domain = require("@game/ReplicatedStorage/Shared/Contracts/DomainInterfaces")
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Gun = {}
export type Strategy = { fire: (Payloads.ProjectileRequest) -> Result.Result<string> }

--[=[ GearService admits ammo/cadence before invoking the shared server gun strategy. ]=]
function Gun.new(projectiles: Domain.ProjectileService): Strategy
	return table.freeze({
		fire = function(request: Payloads.ProjectileRequest): Result.Result<string>
			return projectiles:Cast(request)
		end,
	})
end
return table.freeze(Gun)
