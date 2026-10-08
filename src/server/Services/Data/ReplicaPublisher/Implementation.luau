--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Domain = require(Shared.Contracts.DomainInterfaces)
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local Schemas = require(Shared.Contracts.SnapshotSchemas)
local Service = require(Shared.Contracts.Service)
local Scope = require(Shared.Util.Scope)
local Lifecycle = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceLifecycle)
local Adapter = require(script.Parent.Adapter)
local Implementation = {}

--[=[ Publishes committed allowlisted projections through an explicitly injected transport.
	The data service publishes after load/confirmed commit; All replicas cover current and late-ready clients.
]=]
function Implementation.new(adapter: Adapter.Adapter): Domain.ReplicaPublisher
	local scope = Scope.new()
	local removal: RBXScriptConnection? = nil
	local service: Domain.ReplicaPublisher
	local function remove(userId: number): Result.Result<boolean>
		return adapter.remove(userId)
	end
	service = Lifecycle.new("ReplicaPublisher", scope, {
		Start = function()
			removal = Players.PlayerRemoving:Connect(function(player)
				if not remove(player.UserId).Ok then
					warn("ReplicaPublisher owner cleanup failed")
				end
			end)
		end,
		Stop = function()
			if removal then
				removal:Disconnect()
				removal = nil
			end
			if not adapter.clear().Ok then
				warn("ReplicaPublisher cleanup failed; affected publishers remain fenced")
			end
		end,
	}) :: Domain.ReplicaPublisher
	service.PublishPrivate = function(
		_self: Service.Interface,
		userId: number,
		snapshot: Payloads.PlayerDataSnapshot
	)
		if not service:IsStarted() then
			return Result.failure("NotReady")
		end
		local validated = Schemas.player(snapshot)
		if not validated.Ok or validated.Value.UserId ~= userId then
			return Result.failure("InvalidRequest")
		end
		local owner = Players:GetPlayerByUserId(userId)
		if not owner or owner.Parent ~= Players then
			return Result.failure("NotReady")
		end
		local outcome = adapter.publishPrivate(userId, owner, validated.Value)
		if
			not service:IsStarted()
			or owner.Parent ~= Players
			or Players:GetPlayerByUserId(userId) ~= owner
		then
			remove(userId)
			return Result.failure("NotReady")
		end
		return outcome
	end
	service.PublishMatch = function(_self: Service.Interface, snapshot: Payloads.MatchSnapshot)
		return if service:IsStarted() then adapter.publishMatch(snapshot) else Result.failure("NotReady")
	end
	service.PublishBoard = function(_self: Service.Interface, snapshot: Payloads.BoardSnapshot)
		return if service:IsStarted() then adapter.publishBoard(snapshot) else Result.failure("NotReady")
	end
	service.Remove = function(_self: Service.Interface, userId: number)
		return remove(userId)
	end
	return service
end

return table.freeze(Implementation)
