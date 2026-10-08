--!strict
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Boundary = require("@game/ReplicatedStorage/Shared/Contracts/Boundary")
local Game = require("@game/ReplicatedStorage/Shared/Config/Game")
local Selection = {}
export type Value = { GearIds: { string }, ArmourId: string?, ClassId: string? }
export type Definition = { AssetId: string?, Free: boolean? }
export type Category = "Gear" | "Armour" | "Class"
export type Catalog = (Category, string) -> Result.Result<Definition>

function Selection.copy(selection: Value): Value
	return {
		GearIds = table.clone(selection.GearIds),
		ArmourId = selection.ArmourId,
		ClassId = selection.ClassId,
	}
end

--[=[ Ownership is server data. Free defaults must be explicitly declared by the catalog. ]=]
function Selection.owned(
	catalog: Catalog,
	inventory: Payloads.Inventory,
	category: Category,
	id: string
): Result.Result<boolean>
	local definition = catalog(category, id)
	if not definition.Ok then
		return Result.failure(definition.Code)
	end
	local owned = if category == "Gear"
		then inventory.Gears
		elseif category == "Armour" then inventory.Armours
		else inventory.Classes
	if not definition.Value.Free and not table.find(owned, id) then
		return Result.failure("NotOwned")
	end
	return Result.success(true)
end

function Selection.validate(
	catalog: Catalog,
	inventory: Payloads.Inventory,
	selection: Value
): Result.Result<Value>
	if not Boundary.plain(selection.GearIds) or #selection.GearIds > Game.GearSlots then
		return Result.failure("InvalidRequest")
	end
	local count = 0
	local seen: { [string]: boolean } = {}
	for slot, id in selection.GearIds do
		count += 1
		if
			type(slot) ~= "number"
			or slot % 1 ~= 0
			or slot < 1
			or slot > #selection.GearIds
			or type(id) ~= "string"
			or seen[id]
		then
			return Result.failure("InvalidRequest")
		end
		seen[id] = true
		local owned = Selection.owned(catalog, inventory, "Gear", id)
		if not owned.Ok then
			return Result.failure(owned.Code)
		end
	end
	if count ~= #selection.GearIds then
		return Result.failure("InvalidRequest")
	end
	local optional: { [Category]: string? } = { Armour = selection.ArmourId, Class = selection.ClassId }
	for category, id in optional do
		if id then
			local owned = Selection.owned(catalog, inventory, category :: Category, id)
			if not owned.Ok then
				return Result.failure(owned.Code)
			end
		end
	end
	return Result.success(Selection.copy(selection))
end

function Selection.snapshot(userId: number, roundId: number, selection: Value): Payloads.LoadoutSnapshot
	return table.freeze({
		UserId = userId,
		RoundId = roundId,
		GearIds = table.freeze(table.clone(selection.GearIds)),
		ArmourId = selection.ArmourId,
		ClassId = selection.ClassId,
	})
end
return table.freeze(Selection)
