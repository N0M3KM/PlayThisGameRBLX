--!strict
local Payloads = require("../../../src/shared/Contracts/Payloads")
local Schemas = require("../../../src/shared/Contracts/SnapshotSchemas")
local Binding = require("../../../src/shared/Framework/SnapshotBinding")
local Fixture = require("../../fixtures/FoundationReplica")
local Scope = require("../../../src/shared/Util/Scope")
type Data = { [string]: unknown }
local passed = 0
local currentTest = "Snapshot binding"
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
local function match(revision: number, roundId: number): Payloads.MatchSnapshot
	return { ContractVersion = 0, Revision = revision, RoundId = roundId, State = "Active", EndsAt = 240 }
end
local function player(userId: number, revision: number): Payloads.PlayerDataSnapshot
	return {
		SchemaVersion = 1,
		UserId = userId,
		Revision = revision,
		Coins = 0,
		TotalXP = 0,
		Level = 1,
		Inventory = { Gears = { "pistol" }, Utilities = { medkit = 2 }, Armours = {}, Classes = {} },
		FreeSpinRemainingSeconds = 900,
		PaidSpins = 0,
	}
end
local function matchBinding(callback: (Payloads.MatchSnapshot) -> ()): Binding.Binding<Payloads.MatchSnapshot>
	return Binding.new({
		Validate = Schemas.match,
		RevisionOf = function(value: Payloads.MatchSnapshot): number
			return value.Revision
		end,
		RoundOf = function(value: Payloads.MatchSnapshot): number
			return value.RoundId
		end,
		OnChanged = callback,
	})
end
test("match snapshots reject version, state, deadlines and private authority fields", function()
	for _, field in { "ContractVersion", "Revision", "RoundId", "EndsAt" } do
		for _, invalid in { -1, math.huge, 0 / 0 } do
			local value = (match(1, 1) :: unknown) :: Data
			value[field] = invalid
			expect(not Schemas.match(value).Ok)
		end
	end
	local value = (match(1, 1) :: unknown) :: Data
	value.State = "FakeState"
	expect(not Schemas.match(value).Ok)
	value.State = "Active"
	value.ProcessedReceiptIds = {}
	expect(not Schemas.match(value).Ok)
	expect(Schemas.match({ ContractVersion = 0, Revision = 0, RoundId = 0, State = "Idle" }).Ok)
	value.ProcessedReceiptIds, value.EndsAt = nil, nil
	expect(not Schemas.match(value).Ok)
end)
test("private projections reject journals, metatables, sparse duplicate IDs and utility overflow", function()
	local value = (player(1, 1) :: unknown) :: Data
	value.ProcessedReceiptIds = {}
	expect(not Schemas.player(value).Ok)
	value.ProcessedReceiptIds = nil
	value.Inventory = { Gears = { [2] = "pistol" }, Utilities = {}, Armours = {}, Classes = {} }
	expect(not Schemas.player(value).Ok)
	value.Inventory = { Gears = { "pistol", "pistol" }, Utilities = {}, Armours = {}, Classes = {} }
	expect(not Schemas.player(value).Ok)
	value.Inventory = { Gears = {}, Utilities = { medkit = 101 }, Armours = {}, Classes = {} }
	expect(not Schemas.player(value).Ok)
	value.Inventory = setmetatable({ Gears = {}, Utilities = {}, Armours = {}, Classes = {} }, {})
	expect(not Schemas.player(value).Ok)
	local oversized: { string } = {}
	for index = 1, 257 do
		oversized[index] = `gear_{index}`
	end
	value.Inventory = { Gears = oversized, Utilities = {}, Armours = {}, Classes = {} }
	expect(not Schemas.player(value).Ok)
end)
test("private projection recursively copies and freezes its inventory", function()
	local original = player(1, 1)
	local result = Schemas.player(original)
	assert(result.Ok, currentTest)
	original.Inventory.Gears[1] = "changed"
	original.Inventory.Utilities.medkit = 99
	expect(result.Value.Inventory.Gears[1] == "pistol" and result.Value.Inventory.Utilities.medkit == 2)
	expect(table.isfrozen(result.Value) and table.isfrozen(result.Value.Inventory))
	expect(table.isfrozen(result.Value.Inventory.Gears) and table.isfrozen(result.Value.Inventory.Utilities))
end)
test("binding rejects duplicate revisions and stale rounds before callbacks", function()
	local changes = 0
	local binding = matchBinding(function()
		changes += 1
	end)
	expect(not binding.read().Ok)
	expect(binding.accept(match(2, 2)).Ok)
	expect(not binding.accept(match(2, 2)).Ok)
	expect(not binding.accept(match(1, 2)).Ok)
	expect(not binding.accept(match(3, 1)).Ok)
	expect(binding.accept(match(3, 2)).Ok and changes == 2)
	binding.destroy()
	expect(not binding.accept(match(4, 2)).Ok and not binding.read().Ok)
end)
test("two clients receive public facts and only their private projection", function()
	local fixture = Fixture.new()
	local scope = Scope.new()
	local publicCounts: { number } = { 0, 0 }
	local privateCounts: { number } = { 0, 0 }
	local privateIds: { { number } } = { {}, {} }
	for userId = 1, 2 do
		local public = matchBinding(function()
			publicCounts[userId] += 1
		end)
		public.bind(fixture.matchSubscription, scope)
		local private = Binding.new({
			Validate = Schemas.player,
			RevisionOf = function(value: Payloads.PlayerDataSnapshot): number
				return value.Revision
			end,
			OnChanged = function(value: Payloads.PlayerDataSnapshot)
				table.insert(privateIds[userId], value.UserId)
				privateCounts[userId] += 1
			end,
		})
		private.bind(fixture.privateSubscription(userId), scope)
	end
	expect(fixture.publishMatch(match(1, 1)).Ok)
	expect(fixture.publishPrivate(1, player(1, 1)).Ok)
	expect(not fixture.publishPrivate(2, player(1, 2)).Ok)
	expect(fixture.publishPrivate(2, player(2, 1)).Ok)
	expect(publicCounts[1] == 1 and publicCounts[2] == 1)
	expect(privateCounts[1] == 1 and privateCounts[2] == 1)
	expect(#privateIds[1] == 1 and privateIds[1][1] == 1)
	expect(#privateIds[2] == 1 and privateIds[2][1] == 2)
	expect(fixture.count() == 4 and scope:count() == 4)
	scope:destroy()
	expect(fixture.count() == 0 and scope:count() == 0)
	fixture.destroy()
end)
test("late subscribers replay safely and 20 teardown cycles return to baseline", function()
	local fixture = Fixture.new()
	expect(fixture.publishMatch(match(1, 1)).Ok)
	local scope = Scope.new()
	for _ = 1, 20 do
		local changes = 0
		local binding = matchBinding(function()
			changes += 1
		end)
		binding.bind(fixture.matchSubscription, scope)
		expect(changes == 1 and fixture.count() == 1 and scope:count() == 1)
		binding.destroy()
		binding.destroy()
		expect(fixture.count() == 0 and scope:count() == 0)
	end
	scope:destroy()
	fixture.destroy()
end)
test("reentrant updates never apply an older outer snapshot after a newer one", function()
	local fixture = Fixture.new()
	local scope = Scope.new()
	local first = matchBinding(function(value)
		if value.Revision == 1 then
			expect(fixture.publishMatch(match(2, 1)).Ok)
		end
	end)
	local observed: { number } = {}
	local second = matchBinding(function(value)
		table.insert(observed, value.Revision)
	end)
	first.bind(fixture.matchSubscription, scope)
	second.bind(fixture.matchSubscription, scope)
	expect(fixture.publishMatch(match(1, 1)).Ok)
	local result = second.read()
	assert(result.Ok, currentTest)
	expect(result.Value.Revision == 2)
	for index = 2, #observed do
		expect(observed[index] > observed[index - 1])
	end
	scope:destroy()
	fixture.destroy()
end)
test("destroy during initial replay releases the returned subscription", function()
	local fixture = Fixture.new()
	expect(fixture.publishMatch(match(1, 1)).Ok)
	local scope = Scope.new()
	local binding: Binding.Binding<Payloads.MatchSnapshot>? = nil
	local created = matchBinding(function()
		assert(binding, currentTest)
		binding.destroy()
	end)
	binding = created
	created.bind(fixture.matchSubscription, scope)
	expect(fixture.count() == 0 and scope:count() == 0)
	scope:destroy()
	fixture.destroy()
end)
test("subscription startup and listener errors do not retain partial resources", function()
	local fixture = Fixture.new()
	local scope = Scope.new()
	expect(fixture.publishMatch(match(1, 1)).Ok)
	expect(not pcall(fixture.matchSubscription, function()
		error("replay callback failed")
	end))
	expect(fixture.count() == 0)
	local binding = matchBinding(function() end)
	expect(not pcall(binding.bind, function(): () -> ()
		error("subscribe failed")
	end, scope))
	expect(scope:count() == 0 and not binding.read().Ok)
	local errors = 0
	local failing = Binding.new({
		Validate = Schemas.match,
		RevisionOf = function(value: Payloads.MatchSnapshot): number
			return value.Revision
		end,
		OnChanged = function()
			error("listener failed")
		end,
		OnError = function()
			errors += 1
		end,
	})
	expect(failing.accept(match(1, 1)).Ok and errors == 1 and failing.read().Ok)
	failing.destroy()
	scope:destroy()
	fixture.destroy()
end)
test("injected callbacks cannot resurrect a binding destroyed during validation or accessors", function()
	for _, stage in { "Validate", "Revision", "Round" } do
		local binding: Binding.Binding<Payloads.MatchSnapshot>? = nil
		local function teardown()
			assert(binding, currentTest)
			binding.destroy()
		end
		local created = Binding.new({
			Validate = function(value: unknown)
				if stage == "Validate" then
					teardown()
				end
				return Schemas.match(value)
			end,
			RevisionOf = function(value: Payloads.MatchSnapshot): number
				if stage == "Revision" then
					teardown()
				end
				return value.Revision
			end,
			RoundOf = function(value: Payloads.MatchSnapshot): number
				if stage == "Round" then
					teardown()
				end
				return value.RoundId
			end,
			OnChanged = function()
				error("Destroyed binding must never notify")
			end,
		})
		binding = created
		local accepted, read = created.accept(match(1, 1)), created.read()
		expect(not accepted.Ok and accepted.Code == "Unavailable")
		expect(not read.Ok and read.Code == "Unavailable")
	end
end)
test("manual binding teardown reports throwing disconnect and detaches scope", function()
	local scope = Scope.new()
	local errors = 0
	local binding = Binding.new({
		Validate = Schemas.match,
		RevisionOf = function(value: Payloads.MatchSnapshot): number
			return value.Revision
		end,
		OnChanged = function() end,
		OnError = function()
			errors += 1
		end,
	})
	binding.bind(function(): () -> ()
		return function()
			error("disconnect failed")
		end
	end, scope)
	binding.destroy()
	expect(errors == 1 and scope:count() == 0)
	scope:destroy()
end)
print(`Snapshot binding total: {passed} tests passed (injected transport only).`)
return passed
