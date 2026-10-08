--!strict
local Config = require("@game/ReplicatedStorage/Shared/Config/Data")
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local ProfileTypes = require("./ProfileTypes")
local ProfileOperations = require("./ProfileOperations")
local ShopCatalog = require("./ShopCatalog")
local InventoryService = {}
export type Interface = {
	Grant: (
		userId: number,
		contentId: string,
		count: number,
		requestId: string,
		reason: Payloads.EconomyReason
	) -> Result.Result<Payloads.TransactionReceipt>,
	Consume: (
		userId: number,
		contentId: string,
		count: number,
		requestId: string,
		guard: ProfileOperations.Guard
	) -> Result.Result<Payloads.TransactionReceipt>,
}

local function validCount(count: number): boolean
	return type(count) == "number"
		and count == count
		and count >= 1
		and count <= Config.MaxInteger
		and count % 1 == 0
end

--[=[ Mutates only a detached transaction candidate. Purchase rejects cap overflow;
	trusted grants clamp utilities and unique grants reject duplicate ownership.
]=]
function InventoryService.grantCandidate(
	profile: ProfileTypes.Profile,
	product: ShopCatalog.Product,
	count: number,
	clamp: boolean
): Result.Result<boolean>
	if not validCount(count) or (product.Category ~= "Utilities" and count ~= 1) then
		return Result.failure("InvalidRequest")
	end
	if product.Category == "Utilities" then
		local owned = profile.Inventory.Utilities[product.Id] or 0
		if not clamp and count > Config.UtilityCap - owned then
			return Result.failure("LimitReached")
		end
		profile.Inventory.Utilities[product.Id] =
			math.min(Config.UtilityCap, owned + math.min(count, Config.UtilityCap))
		return Result.success(true)
	end
	local collection = if product.Category == "Gears"
		then profile.Inventory.Gears
		elseif product.Category == "Armours" then profile.Inventory.Armours
		else profile.Inventory.Classes
	if table.find(collection, product.Id) then
		return Result.failure("LimitReached")
	end
	if #collection >= Config.MaxCollectionEntries then
		return Result.failure("LimitReached")
	end
	table.insert(collection, product.Id)
	return Result.success(true)
end

function InventoryService.consumeCandidate(
	profile: ProfileTypes.Profile,
	product: ShopCatalog.Product,
	count: number
): Result.Result<boolean>
	if product.Category ~= "Utilities" or not validCount(count) then
		return Result.failure("InvalidRequest")
	end
	local owned = profile.Inventory.Utilities[product.Id] or 0
	if owned < count then
		return Result.failure("NotOwned")
	end
	profile.Inventory.Utilities[product.Id] = owned - count
	return Result.success(true)
end

--[=[ Trusted server-domain grants and persisted consumption. Never expose this facade
	as a client remote; callers choose a stable intent id and consume state/cooldown guard.
]=]
function InventoryService.new(
	boundary: ProfileOperations.Boundary,
	catalog: ShopCatalog.Catalog,
	engine: ProfileOperations.Engine
): Interface
	local function apply(
		userId: number,
		contentId: string,
		count: number,
		requestId: string,
		reason: Payloads.EconomyReason,
		consume: boolean,
		guard: ProfileOperations.Guard?
	): Result.Result<Payloads.TransactionReceipt>
		if
			type(userId) ~= "number"
			or userId ~= userId
			or userId == 0
			or math.abs(userId) > Config.MaxInteger
			or userId % 1 ~= 0
			or type(contentId) ~= "string"
			or type(requestId) ~= "string"
			or #requestId == 0
			or #requestId > Config.MaxTransactionIdLength - 10
			or not validCount(count)
		then
			return Result.failure("InvalidRequest")
		end
		local product = catalog.get(contentId)
		if not product then
			return Result.failure("UnknownId")
		end
		local snapshot = boundary:Read(userId)
		if not snapshot.Ok then
			return Result.failure(snapshot.Code)
		end
		return engine.execute({
			UserId = userId,
			TransactionId = "inventory:" .. requestId,
			ExpectedRevision = snapshot.Value.Revision,
			Reason = reason,
			Fingerprint = string.format(
				"%s:%s:%.0f",
				if consume then "consume" else "grant",
				contentId,
				count
			),
		}, function(profile: ProfileTypes.Profile): Result.Result<boolean>
			return if consume
				then InventoryService.consumeCandidate(profile, product, count)
				else InventoryService.grantCandidate(profile, product, count, true)
		end, guard)
	end
	local facade: Interface = {
		Grant = function(
			userId: number,
			contentId: string,
			count: number,
			requestId: string,
			reason: Payloads.EconomyReason
		): Result.Result<Payloads.TransactionReceipt>
			if reason ~= "Receipt" and reason ~= "Wheel" and reason ~= "Quest" and reason ~= "Inventory" then
				return Result.failure("InvalidRequest")
			end
			return apply(userId, contentId, count, requestId, reason, false, nil)
		end,
		Consume = function(
			userId: number,
			contentId: string,
			count: number,
			requestId: string,
			guard: ProfileOperations.Guard
		): Result.Result<Payloads.TransactionReceipt>
			if type(guard) ~= "function" then
				return Result.failure("InvalidRequest")
			end
			return apply(userId, contentId, count, requestId, "Utility", true, guard)
		end,
	}
	return table.freeze(facade)
end

return table.freeze(InventoryService)
