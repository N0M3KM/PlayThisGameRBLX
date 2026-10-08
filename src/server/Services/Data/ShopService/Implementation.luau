--!strict
local Config = require("@game/ReplicatedStorage/Shared/Config/Data")
local Domain = require("@game/ReplicatedStorage/Shared/Contracts/DomainInterfaces")
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Service = require("@game/ReplicatedStorage/Shared/Contracts/Service")
local Scope = require("@game/ReplicatedStorage/Shared/Util/Scope")
local Lifecycle = require("@game/ServerScriptService/Server/Infrastructure/ServiceLifecycle")
local ProfileTypes = require("../ProfileTypes")
local ProfileOperations = require("../ProfileOperations")
local InventoryService = require("../InventoryService")
local ShopCatalog = require("../ShopCatalog")
local LobbyAccess = require("../LobbyAccess")
local Implementation = {}

--[=[ One confirmed mutation both charges and grants. The injected lobby lease stays
	held across queue/save yields so round entry cannot race the purchase.
]=]
function Implementation.new(
	boundary: ProfileOperations.Boundary,
	catalog: ShopCatalog.Catalog,
	access: LobbyAccess.Access,
	engine: ProfileOperations.Engine
): Domain.ShopService
	local pending: { [number]: boolean } = {}
	local pendingCount = 0
	local service = (Lifecycle.new("ShopService", Scope.new()) :: unknown) :: Domain.ShopService
	service.Purchase = function(
		_self: Service.Interface,
		userId: number,
		contentId: string,
		requestId: string
	): Result.Result<Payloads.TransactionReceipt>
		if not service:IsStarted() then
			return Result.failure("NotReady")
		end
		if
			type(userId) ~= "number"
			or userId ~= userId
			or userId == 0
			or math.abs(userId) > Config.MaxInteger
			or userId % 1 ~= 0
			or type(contentId) ~= "string"
			or type(requestId) ~= "string"
			or #requestId == 0
			or #requestId > Config.MaxTransactionIdLength - 5
		then
			return Result.failure("InvalidRequest")
		end
		local product = catalog.get(contentId)
		if not product then
			return Result.failure("UnknownId")
		end
		if product.Acquisition ~= "Shop" or product.Price == nil then
			return Result.failure("NotOwned")
		end
		if pending[userId] or pendingCount >= Config.MaxPendingShopPurchases then
			return Result.failure("RateLimited")
		end
		pending[userId] = true
		pendingCount += 1
		local acquiredOk, acquired = pcall(access.acquire, userId)
		if not acquiredOk then
			pending[userId] = nil
			pendingCount -= 1
			return Result.failure("Unavailable")
		end
		if not acquired.Ok then
			pending[userId] = nil
			pendingCount -= 1
			return Result.failure(acquired.Code)
		end
		local lease = acquired.Value
		local function guarded(): boolean
			return service:IsStarted() and lease.valid()
		end
		local ok, receipt = pcall(function(): Result.Result<Payloads.TransactionReceipt>
			local snapshot = boundary:Read(userId)
			if not snapshot.Ok then
				return Result.failure(snapshot.Code)
			end
			local price = product.Price :: number
			return engine.execute({
				UserId = userId,
				TransactionId = "shop:" .. requestId,
				ExpectedRevision = snapshot.Value.Revision,
				Reason = "Shop",
				Fingerprint = string.format("purchase:%s:%s:%.17g", contentId, product.Category, price),
			}, function(profile: ProfileTypes.Profile): Result.Result<boolean>
				if not guarded() then
					return Result.failure("WrongState")
				end
				if profile.Coins < price then
					return Result.failure("InsufficientFunds")
				end
				local grant = InventoryService.grantCandidate(profile, product, 1, false)
				if not grant.Ok then
					return grant
				end
				profile.Coins -= price
				return Result.success(true)
			end, guarded)
		end)
		local released = pcall(lease.release)
		pending[userId] = nil
		pendingCount -= 1
		if not ok or not released then
			return Result.failure("Unavailable")
		end
		return receipt
	end
	return service
end

return table.freeze(Implementation)
