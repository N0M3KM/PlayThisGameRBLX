--!strict
local Schemas = require("../../../src/shared/Contracts/RequestSchemas")
local Legacy = require("../../../src/shared/Contracts/Schemas")
local DeepFreeze = require("../../../src/shared/Util/DeepFreeze")
local Result = require("../../../src/shared/Contracts/Result")
type Data = { [string]: unknown }
type Case = { Name: string, Validate: (unknown) -> boolean, Value: Data }
local function accepts<T>(validate: (unknown) -> Result.Result<T>): (unknown) -> boolean
	return function(value: unknown): boolean
		return validate(value).Ok
	end
end
local passed = 0
local currentTest = "Request schemas"
local function expect(condition: boolean)
	assert(condition, currentTest)
end
local function test(name: string, callback: () -> ())
	currentTest = name
	local outcome = table.pack(pcall(callback))
	assert(outcome[1], `{name}: {tostring(outcome[2])}`)
	passed += 1
	print(`PASS {name}`)
end
local function roundCommand(): Data
	return { RequestId = "request-1", RoundId = 1, CharacterGeneration = 1, GearSlot = 1 }
end
local cases: { Case } = {
	{
		Name = "PurchaseItem",
		Validate = accepts(Schemas.purchaseItem),
		Value = { RequestId = "r1", Category = "Utility", ItemId = "medkit", Quantity = 2 },
	},
	{
		Name = "EquipLoadout",
		Validate = accepts(Schemas.equipLoadout),
		Value = { RequestId = "r1", Category = "Gear", ItemId = "pistol", GearSlot = 1 },
	},
	{ Name = "UseGear", Validate = accepts(Schemas.useGear), Value = roundCommand() },
	{ Name = "ReloadGear", Validate = accepts(Schemas.reloadGear), Value = roundCommand() },
	{ Name = "UseAbility", Validate = accepts(Schemas.useAbility), Value = roundCommand() },
	{
		Name = "UseUtility",
		Validate = accepts(Schemas.useUtility),
		Value = { RequestId = "r1", RoundId = 1, CharacterGeneration = 1, UtilityId = "medkit" },
	},
	{ Name = "RequestFreeSpin", Validate = accepts(Schemas.requestFreeSpin), Value = { RequestId = "r1" } },
	{ Name = "SpendPaidSpin", Validate = accepts(Schemas.spendPaidSpin), Value = { RequestId = "r1" } },
	{
		Name = "SubmitPick",
		Validate = accepts(Schemas.submitPick),
		Value = { RequestId = "r1", EntitlementId = "token-1", MapId = "baseplate", ScenarioId = "regular" },
	},
	{
		Name = "OpenDialogue",
		Validate = accepts(Schemas.openDialogue),
		Value = { RequestId = "r1", NpcId = "npc_1", CharacterGeneration = 1 },
	},
	{
		Name = "ChooseDialogue",
		Validate = accepts(Schemas.chooseDialogue),
		Value = { RequestId = "r1", SessionId = "session-1", ChoiceId = "choice_1", CharacterGeneration = 1 },
	},
	{
		Name = "CloseDialogue",
		Validate = accepts(Schemas.closeDialogue),
		Value = { RequestId = "r1", SessionId = "session-1" },
	},
	{
		Name = "DebugCommand",
		Validate = accepts(Schemas.debugCommand),
		Value = { RequestId = "r1", CommandId = "inspect_foundation", RoundId = 1 },
	},
}
for _, case in cases do
	test(`{case.Name} rejects identity spoofing, inherited data and missing correlation`, function()
		expect(case.Validate(case.Value))
		expect(not case.Validate(nil))
		expect(not case.Validate({}))
		local spoofed = table.clone(case.Value)
		spoofed.UserId = 999
		expect(not case.Validate(spoofed))
		spoofed.UserId = nil
		spoofed.RequestId = string.rep("x", 65)
		expect(not case.Validate(spoofed))
		spoofed.RequestId = "request/path"
		expect(not case.Validate(spoofed))
		expect(not case.Validate(setmetatable(table.clone(case.Value), {})))
		expect(not case.Validate(setmetatable({}, { __index = case.Value })))
	end)
end
test("shop quantities and equip categories reject invalid combinations", function()
	expect(
		not Schemas.purchaseItem({ RequestId = "r", Category = "Gear", ItemId = "pistol", Quantity = 2 }).Ok
	)
	for _, amount in { -1, 0, 1.5, 101, math.huge, 0 / 0 } do
		expect(not Schemas.purchaseItem({
			RequestId = "r",
			Category = "Utility",
			ItemId = "medkit",
			Quantity = amount,
		}).Ok)
	end
	expect(not Schemas.purchaseItem({ RequestId = "r", Category = "Gems", ItemId = "gem", Quantity = 1 }).Ok)
	expect(not Schemas.equipLoadout({ RequestId = "r", Category = "Gear", ItemId = "pistol" }).Ok)
	expect(
		not Schemas.equipLoadout({ RequestId = "r", Category = "Armour", ItemId = "light", GearSlot = 1 }).Ok
	)
	expect(Schemas.equipLoadout({ RequestId = "r", Category = "Armour", ItemId = "light" }).Ok)
	expect(not Schemas.equipLoadout({ RequestId = "r", Category = "Utility", ItemId = "medkit" }).Ok)
end)
test("round commands reject zero, fractional and nonfinite identity fields", function()
	for _, validate in { accepts(Schemas.useGear), accepts(Schemas.reloadGear), accepts(Schemas.useAbility) } do
		for _, field in { "RoundId", "CharacterGeneration", "GearSlot" } do
			for _, invalid in { 0, -1, 0.5, math.huge, 0 / 0 } do
				local command = roundCommand()
				command[field] = invalid
				expect(not validate(command))
			end
		end
		local command = roundCommand()
		command.GearSlot = 4
		expect(not validate(command))
	end
end)
test("aim requires paired bounded origin and unit direction with owned copies", function()
	local command = roundCommand()
	local origin = { X = 1, Y = 2, Z = 3 }
	local direction = { X = 0, Y = 0, Z = 1 }
	command.AimOrigin, command.AimDirection = origin, direction
	local accepted = Schemas.useGear(command)
	assert(accepted.Ok, currentTest)
	local savedOrigin, savedDirection = accepted.Value.AimOrigin, accepted.Value.AimDirection
	assert(savedOrigin and savedDirection, currentTest)
	origin.X = 99
	direction.Z = 99
	expect(savedOrigin.X == 1 and savedDirection.Z == 1)
	expect(table.isfrozen(accepted.Value) and table.isfrozen(savedOrigin) and table.isfrozen(savedDirection))
	command.AimDirection = nil
	expect(not Schemas.useGear(command).Ok)
	for _, invalid in
		{
			{ X = 0, Y = 0, Z = 0 },
			{ X = math.huge, Y = 0, Z = 0 },
			{ X = 0 / 0, Y = 0, Z = 1 },
			{ X = 0, Y = 0, Z = 2 },
			{ X = 0, Y = 0, Z = 1, Damage = 100 },
		}
	do
		command.AimDirection = invalid
		expect(not Schemas.useGear(command).Ok)
	end
	command.AimDirection = { X = 0, Y = 0, Z = 1 }
	command.AimOrigin = { X = 100001, Y = 0, Z = 0 }
	expect(not Schemas.useGear(command).Ok)
	command.AimOrigin = setmetatable({ X = 0, Y = 0, Z = 0 }, {})
	expect(not Schemas.useGear(command).Ok)
end)
test("utility placement rejects nested authority, metatables and facing without placement", function()
	local intent: Data = { RequestId = "r", RoundId = 1, CharacterGeneration = 1, UtilityId = "turret" }
	intent.Facing = { X = 0, Y = 0, Z = 1 }
	expect(not Schemas.useUtility(intent).Ok)
	intent.Placement = { X = 0, Y = 0, Z = 0, OwnerId = 9 }
	expect(not Schemas.useUtility(intent).Ok)
	intent.Placement = setmetatable({ X = 0, Y = 0, Z = 0 }, {})
	expect(not Schemas.useUtility(intent).Ok)
	local placement = { X = 0, Y = 0, Z = 0 }
	intent.Placement = placement
	local accepted = Schemas.useUtility(intent)
	assert(accepted.Ok and accepted.Value.Placement, currentTest)
	placement.X = 99
	expect(accepted.Value.Placement.X == 0 and table.isfrozen(accepted.Value.Placement))
end)
test("spins cannot supply eligibility, credits, rolls or grants", function()
	for _, validate in { Schemas.requestFreeSpin, Schemas.spendPaidSpin } do
		for _, field in { "PrizeId", "Coins", "PaidSpins", "RemainingSeconds", "NextFreeSpinAt" } do
			local input: Data = { RequestId = "r" }
			input[field] = 0
			expect(not validate(input).Ok)
		end
	end
end)
test("command acknowledgement rejects internal data and ambiguous result branches", function()
	expect(Schemas.commandResult({ RequestId = "r", Result = { Ok = true, Value = true } }).Ok)
	expect(Schemas.commandResult({ RequestId = "r", Result = { Ok = false, Code = "NotReady" } }).Ok)
	local invalidOutcomes: { unknown } = {
		{ Ok = false, Code = "InternalStackTrace" },
		{ Ok = true, Value = true, Code = "NotReady" },
		{ Ok = false, Code = "NotReady", Value = false },
		{ Ok = true, Value = { Coins = 999 } },
	}
	for _, outcome in invalidOutcomes do
		expect(not Schemas.commandResult({ RequestId = "r", Result = outcome }).Ok)
	end
	local outcome = { Ok = false, Code = "NotReady" }
	local result = Schemas.commandResult({ RequestId = "r", Result = outcome })
	assert(result.Ok, currentTest)
	outcome.Code = "Unavailable"
	expect(not result.Value.Result.Ok and result.Value.Result.Code == "NotReady")
	expect(table.isfrozen(result.Value.Result))
end)
test("client vote actions are rejected by the legacy draft schema", function()
	expect(not Legacy.inputIntent({
		RequestId = "r",
		RoundId = 1,
		CharacterGeneration = 1,
		Action = "Vote",
		ContentId = "map_1",
	}).Ok)
end)
test("data freezing rejects metatables and preserves mutable input after validation failure", function()
	local plainChild = { Id = "child" }
	local inherited = setmetatable({ Id = "fixture" }, { __index = { Callback = function() end } })
	local data: DeepFreeze.DataTable = { Good = plainChild, Bad = inherited }
	expect(not pcall(DeepFreeze.freeze, data))
	expect(not table.isfrozen(data) and not table.isfrozen(plainChild))
	local invalid: DeepFreeze.DataTable = { Child = { Callback = function() end } }
	expect(not pcall(DeepFreeze.freeze, invalid))
	local shared = { Id = "shared" }
	local valid: DeepFreeze.DataTable = { First = shared, Second = shared }
	DeepFreeze.freeze(valid)
	expect(table.isfrozen(valid) and table.isfrozen(shared))
end)
print(`Request boundary total: {passed} tests passed (shape checks only).`)
return passed
