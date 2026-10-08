--!strict
-- Shape validation only. Handlers must check rate, state, ownership, proximity and current generation.
local Requests = require("./Requests")
local Result = require("./Result")
local Boundary = require("./Boundary")
local Validation = require("../Registry/Validation")
local Game = require("../Config/Game")
local RequestSchemas = {}
local function gearSlot(value: unknown): boolean
	return Validation.integer(value, 1, Game.GearSlots)
end
local roundFields: Boundary.Fields = {
	RequestId = Boundary.token,
	RoundId = Boundary.positiveInteger,
	CharacterGeneration = Boundary.positiveInteger,
	GearSlot = gearSlot,
}
local gearFields = table.clone(roundFields)
gearFields.AimOrigin = Boundary.optional(Boundary.point)
gearFields.AimDirection = Boundary.optional(Boundary.direction)

function RequestSchemas.purchaseItem(value: unknown): Result.Result<Requests.PurchaseItem>
	return Boundary.record(value, {
		RequestId = Boundary.token,
		Category = Boundary.oneOf({ "Gear", "Utility", "Armour", "Class" }),
		ItemId = Boundary.id,
		Quantity = function(quantity: unknown): boolean
			return Validation.integer(quantity, 1, Game.UtilityCap)
		end,
	}, function(candidate: unknown): boolean
		local data = candidate :: { Category: string, Quantity: number }
		return data.Category == "Utility" or data.Quantity == 1
	end)
end

function RequestSchemas.equipLoadout(value: unknown): Result.Result<Requests.EquipLoadout>
	return Boundary.record(value, {
		RequestId = Boundary.token,
		Category = Boundary.oneOf({ "Gear", "Armour", "Class" }),
		ItemId = Boundary.id,
		GearSlot = Boundary.optional(gearSlot),
	}, function(candidate: unknown): boolean
		local data = candidate :: { Category: string, GearSlot: number? }
		return if data.Category == "Gear" then data.GearSlot ~= nil else data.GearSlot == nil
	end)
end

function RequestSchemas.useGear(value: unknown): Result.Result<Requests.UseGear>
	return Boundary.record(value, gearFields, function(candidate: unknown): boolean
		local data = candidate :: { AimOrigin: unknown, AimDirection: unknown }
		return (data.AimOrigin == nil) == (data.AimDirection == nil)
	end)
end

function RequestSchemas.reloadGear(value: unknown): Result.Result<Requests.ReloadGear>
	return Boundary.record(value, roundFields)
end

function RequestSchemas.useAbility(value: unknown): Result.Result<Requests.UseAbility>
	return Boundary.record(value, roundFields)
end

function RequestSchemas.useUtility(value: unknown): Result.Result<Requests.UseUtility>
	return Boundary.record(value, {
		RequestId = Boundary.token,
		RoundId = Boundary.positiveInteger,
		CharacterGeneration = Boundary.positiveInteger,
		UtilityId = Boundary.id,
		Placement = Boundary.optional(Boundary.point),
		Facing = Boundary.optional(Boundary.direction),
	}, function(candidate: unknown): boolean
		local data = candidate :: { Placement: unknown, Facing: unknown }
		return data.Facing == nil or data.Placement ~= nil
	end)
end

function RequestSchemas.requestFreeSpin(value: unknown): Result.Result<Requests.RequestFreeSpin>
	return Boundary.record(value, { RequestId = Boundary.token })
end

function RequestSchemas.spendPaidSpin(value: unknown): Result.Result<Requests.SpendPaidSpin>
	return Boundary.record(value, { RequestId = Boundary.token })
end

function RequestSchemas.submitPick(value: unknown): Result.Result<Requests.SubmitPick>
	return Boundary.record(value, {
		RequestId = Boundary.token,
		EntitlementId = Boundary.token,
		MapId = Boundary.id,
		ScenarioId = Boundary.id,
	})
end

function RequestSchemas.openDialogue(value: unknown): Result.Result<Requests.OpenDialogue>
	return Boundary.record(value, {
		RequestId = Boundary.token,
		NpcId = Boundary.id,
		CharacterGeneration = Boundary.positiveInteger,
	})
end

function RequestSchemas.chooseDialogue(value: unknown): Result.Result<Requests.ChooseDialogue>
	return Boundary.record(value, {
		RequestId = Boundary.token,
		SessionId = Boundary.token,
		ChoiceId = Boundary.id,
		CharacterGeneration = Boundary.positiveInteger,
	})
end

function RequestSchemas.closeDialogue(value: unknown): Result.Result<Requests.CloseDialogue>
	return Boundary.record(value, { RequestId = Boundary.token, SessionId = Boundary.token })
end

function RequestSchemas.debugCommand(value: unknown): Result.Result<Requests.DebugCommand>
	return Boundary.record(value, {
		RequestId = Boundary.token,
		CommandId = Boundary.id,
		RoundId = Boundary.optional(Boundary.positiveInteger),
	})
end

function RequestSchemas.commandResult(value: unknown): Result.Result<Requests.CommandResult>
	return Boundary.record(value, {
		RequestId = Boundary.token,
		Result = function(outcome: unknown): boolean
			if not Boundary.plain(outcome) then
				return false
			end
			local data = outcome :: { [string]: unknown }
			if data.Ok == true then
				return Boundary.record(outcome, {
					Ok = function(ok: unknown): boolean
						return ok == true
					end,
					Value = function(accepted: unknown): boolean
						return type(accepted) == "boolean"
					end,
				}).Ok
			elseif data.Ok == false then
				return Boundary.record(outcome, {
					Ok = function(ok: unknown): boolean
						return ok == false
					end,
					Code = Result.isErrorCode,
				}).Ok
			end
			return false
		end,
	})
end

return table.freeze(RequestSchemas)
