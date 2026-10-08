--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Service = require(Shared.Contracts.Service)
local Result = require(Shared.Contracts.Result)
local Scope = require(Shared.Util.Scope)
local Ledger = require(script.Parent.VoteLedger)
local Lifecycle = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceLifecycle)
local Interface = require(script.Parent.Interface)
local Implementation = {}
export type Voting = Interface.Interface & {
	Snapshot: (Service.Interface) -> Ledger.Snapshot,
	Close: (Service.Interface) -> (),
}

function Implementation.new(random: Random, clock: () -> number, changed: (Ledger.Snapshot) -> ()): Voting
	local scope = Scope.new()
	local runScope: Scope.Scope? = nil
	local ledger = Ledger.new(function(minimum, maximum)
		return random:NextInteger(minimum, maximum)
	end)
	local function publish()
		local outcome = table.pack(pcall(changed, ledger:snapshot()))
		if not outcome[1] then
			warn(`Voting listener failed: {tostring(outcome[2])}`)
		end
	end
	local facade = Lifecycle.new("VotingService", scope, {
		Start = function()
			local owned = scope:child()
			runScope = owned
			local removing = Players.PlayerRemoving:Connect(function(player)
				local outcome = ledger:removePlayer(player.UserId)
				if outcome.Ok and outcome.Value then
					publish()
				end
			end)
			owned:add(function()
				removing:Disconnect()
			end)
		end,
		Stop = function()
			if runScope then
				runScope:destroy()
				runScope = nil
			end
			ledger:close()
		end,
	})
	local result = (facade :: unknown) :: Voting
	result.Open = function(
		self: Service.Interface,
		roundId: number,
		choices: { string },
		deadline: number
	): Result.Result<boolean>
		if not self:IsStarted() then
			return Result.failure("NotReady")
		end
		local outcome = ledger:open(roundId, choices, deadline)
		if outcome.Ok then
			publish()
		end
		return outcome
	end
	result.Cast = function(
		self: Service.Interface,
		userId: number,
		roundId: number,
		mapId: string
	): Result.Result<boolean>
		if not self:IsStarted() or not Players:GetPlayerByUserId(userId) then
			return Result.failure("NotReady")
		end
		local outcome = ledger:cast(userId, roundId, mapId, clock())
		if outcome.Ok and outcome.Value then
			publish()
		end
		return outcome
	end
	result.RemovePlayer = function(_self: Service.Interface, userId: number): Result.Result<boolean>
		local outcome = ledger:removePlayer(userId)
		if outcome.Ok and outcome.Value then
			publish()
		end
		return outcome
	end
	result.Resolve = function(_self: Service.Interface, roundId: number): Result.Result<string>
		local outcome = ledger:resolve(roundId, clock())
		if outcome.Ok then
			publish()
		end
		return outcome
	end
	result.Snapshot = function(_self: Service.Interface): Ledger.Snapshot
		return ledger:snapshot()
	end
	result.Close = function(_self: Service.Interface)
		ledger:close()
		publish()
	end
	return result
end
return table.freeze(Implementation)
