--!strict
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")

--[=[ A server-owned lease excludes round entry until the pending shop write finishes.
	A state snapshot alone cannot protect a purchase across a yielding save.
]=]
export type Lease = { valid: () -> boolean, release: () -> () }
export type Access = { acquire: (userId: number) -> Result.Result<Lease> }

return table.freeze({})
