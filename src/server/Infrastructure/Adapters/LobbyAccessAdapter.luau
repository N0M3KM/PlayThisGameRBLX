--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Domain = require(Shared.Contracts.DomainInterfaces)
local Result = require(Shared.Contracts.Result)
local LobbyAccess = require(script.Parent.Parent.Parent.Services.Data.LobbyAccess)
local LobbyAccessAdapter = {}

--[=[ Reserves lobby eligibility through an atomic, confirmed shop operation.
	Consumes only A's published interface; the shop owns releasing its token.
]=]
function LobbyAccessAdapter.new(players: Domain.PlayerStateService): LobbyAccess.Access
	return {
		acquire = function(userId)
			local reserved = players:ReserveLobby(userId)
			if not reserved.Ok then
				return Result.failure(reserved.Code)
			end
			local token = reserved.Value
			local released = false
			return Result.success({
				valid = function()
					return not released and players:ValidateLobbyReservation(token)
				end,
				release = function()
					if released then
						return
					end
					released = true
					local outcome = players:ReleaseLobby(token)
					if not outcome.Ok then
						warn(`Lobby reservation release: {outcome.Code}`)
					end
				end,
			})
		end,
	}
end

return table.freeze(LobbyAccessAdapter)
