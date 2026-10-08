--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local Operations = require("@game/ServerScriptService/Server/Services/Data/ProfileOperations")
local LoadoutDataAdapter = {}
export type Store = {
	read: (number) -> Result.Result<Payloads.LoadoutSelection>,
	write: (number, Payloads.LoadoutSelection, string, () -> boolean) -> Result.Result<boolean>,
}

--[=[ Bridges C selection to B's confirmed-save boundary; clients cannot provide profile mutators. ]=]
function LoadoutDataAdapter.new(data: Operations.Boundary, engine: Operations.Engine): Store
	return table.freeze({
		read = function(userId: number): Result.Result<Payloads.LoadoutSelection>
			return data:ReadLoadout(userId)
		end,
		write = function(
			userId: number,
			selection: Payloads.LoadoutSelection,
			requestId: string,
			guard: () -> boolean
		): Result.Result<boolean>
			local read = data:Read(userId)
			if not read.Ok then
				return Result.failure(read.Code)
			end
			local gears = table.clone(selection.GearIds)
			local armour, class = selection.ArmourId, selection.ClassId
			local command: Operations.Command = {
				TransactionId = `equip:{requestId}`,
				UserId = userId,
				ExpectedRevision = read.Value.Revision,
				Reason = "Inventory",
				Fingerprint = `equip|{table.concat(gears, ",")}|{armour or ""}|{class or ""}`,
			}
			local outcome = engine.execute(command, function(profile)
				for _, id in gears do
					if not table.find(profile.Inventory.Gears, id) then
						return Result.failure("NotOwned")
					end
				end
				if armour and not table.find(profile.Inventory.Armours, armour) then
					return Result.failure("NotOwned")
				end
				if class and class ~= "none" and not table.find(profile.Inventory.Classes, class) then
					return Result.failure("NotOwned")
				end
				profile.Loadout = { Gears = table.clone(gears), Armour = armour, Class = class }
				return Result.success(true)
			end, guard)
			return if outcome.Ok then Result.success(true) else Result.failure(outcome.Code)
		end,
	})
end

return table.freeze(LoadoutDataAdapter)
