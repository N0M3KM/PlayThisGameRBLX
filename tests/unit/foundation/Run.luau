--!strict
local Scope = require("../../../src/shared/Util/Scope")
local WeightedRandom = require("../../../src/shared/Util/WeightedRandom")
local DeepFreeze = require("../../../src/shared/Util/DeepFreeze")
local Registry = require("../../../src/shared/Registry/Registry")
local Framework = require("../../../src/shared/Framework/Framework")
local ServiceStub = require("../../../src/server/Infrastructure/ServiceStub")
local FoundationLoop = require("../../../src/server/Infrastructure/FoundationLoop")
local Game = require("../../../src/shared/Config/Game")
local Catalog = require("../../../src/shared/Contracts/ServiceCatalog")
local Validation = require("../../../src/shared/Registry/Validation")
local KnitAdapter = require("../../../src/shared/Framework/KnitAdapter")
local ErrorBoundary = require("../../../src/server/Infrastructure/ErrorBoundary")
local Logger = require("../../../src/server/Infrastructure/Logger")
local MapValidator = require("../../../src/shared/Registry/MapValidator")
local MapSnapshot = require("../../../src/shared/Contracts/Assets/MapSnapshot")
local Schemas = require("../../../src/shared/Contracts/Schemas")
local passed = 0
local currentTest = "Foundation"
local function expect(condition: boolean, message: string?)
	assert(condition, message or currentTest)
end
local function test(name: string, callback: () -> ())
	currentTest = name
	local outcome = table.pack(pcall(callback))
	local ok, message = outcome[1], outcome[2]
	expect(ok, `{name}: {tostring(message)}`)
	passed += 1
	print(`PASS {name}`)
end
local function rejects(callback: () -> ())
	expect(not pcall(callback), "Expected rejection")
end
test("scope LIFO, idempotence and failure isolation", function()
	local scope = Scope.new()
	local order = {}
	scope:add(function()
		table.insert(order, 1)
	end)
	scope:add(function()
		error("cleanup failure")
	end)
	scope:add(function()
		table.insert(order, 3)
	end)
	expect(#scope:destroy() == 1)
	expect(order[1] == 3 and order[2] == 1 and scope:count() == 0)
	expect(#scope:destroy() == 0)
	rejects(function()
		scope:add(function() end)
	end)
end)
test("20 round children detach from persistent parent", function()
	local parent = Scope.new()
	for _ = 1, 20 do
		local child = parent:child()
		expect(parent:count() == 1)
		child:destroy()
		expect(parent:count() == 0)
	end
	local count = 0
	local release = parent:add(function()
		count += 1
	end)
	release()
	release()
	expect(count == 1 and parent:count() == 0)
	parent:destroy()
end)
test("nested scope propagates cleanup errors", function()
	local parent = Scope.new()
	parent:child():add(function()
		error("nested failure")
	end)
	expect(#parent:destroy() == 1)
end)
test("weighted RNG boundaries and invalid weights", function()
	local entries = { { Id = "a", Weight = 1 }, { Id = "b", Weight = 3 } }
	expect(WeightedRandom.pick(entries, function()
		return 0
	end) == "a")
	expect(WeightedRandom.pick(entries, function()
		return 0.25
	end) == "b")
	rejects(function()
		WeightedRandom.pick(entries, function()
			return 1
		end)
	end)
	rejects(function()
		WeightedRandom.pick({ { Id = "a", Weight = 0 / 0 } }, function()
			return 0
		end)
	end)
	local selected = WeightedRandom.withoutReplacement(entries, 2, function()
		return 0
	end)
	expect(selected[1] == "a" and selected[2] == "b" and #entries == 2)
end)
test("configs freeze deeply and reject cycles/functions", function()
	local data = { Child = { Count = 1 } }
	DeepFreeze.freeze((data :: unknown) :: DeepFreeze.DataTable)
	expect(table.isfrozen(data) and table.isfrozen(data.Child))
	rejects(function()
		data.Child.Count = 2
	end)
	local cycle: { [string]: unknown } = {}
	cycle.Self = cycle
	rejects(function()
		DeepFreeze.freeze(cycle)
	end)
	rejects(function()
		DeepFreeze.freeze({ Callback = function() end })
	end)
end)
test("registry validation, stable order and sealing", function()
	type Definition = { Id: string }
	local registry = Registry.new(function(value: Definition)
		return value.Id
	end, function(_value: Definition): { string }
		return {}
	end, function(value: Definition)
		table.freeze(value)
	end)
	registry:add({ Id = "b" })
	registry:add({ Id = "a" })
	expect(registry:all()[1].Id == "a")
	rejects(function()
		registry:add({ Id = "a" })
	end)
	registry:seal()
	rejects(function()
		registry:add({ Id = "c" })
	end)
end)
test("framework startup can resolve registered dependencies", function()
	local services: { [string]: Framework.Service } = {}
	local framework: Framework.Adapter
	framework = Framework.new({
		createService = function(service)
			services[service.Name] = service
			return service
		end,
		getService = function(name)
			return services[name]
		end,
		start = function()
			expect(framework.getService("A").Name == "A")
		end,
	})
	framework.createService({ Name = "A" })
	rejects(function()
		framework.getService("A")
	end)
	framework.start()
	rejects(function()
		framework.start()
	end)
	rejects(function()
		framework.createService({ Name = "B" })
	end)
end)
test("failed framework startup stays unavailable", function()
	local framework = Framework.new({
		createService = function(value)
			return value
		end,
		getService = function(name)
			return { Name = name }
		end,
		start = function()
			error("start failure")
		end,
	})
	framework.createService({ Name = "A" })
	rejects(function()
		framework.start()
	end)
	rejects(function()
		framework.getService("A")
	end)
	rejects(function()
		framework.start()
	end)
end)
test("all 29 stubs reject mutation and validate lifecycle", function()
	local names: { [string]: boolean } = {}
	expect(#Catalog == 29)
	for _, entry in Catalog do
		expect(not names[entry.Name])
		names[entry.Name] = true
		local stub = ServiceStub.new(entry.Name, entry.Commands)
		rejects(function()
			stub:Start()
		end)
		stub:Init()
		stub:Start()
		rejects(function()
			stub:Start()
		end)
		for _, command in entry.Commands do
			local result = stub:Call(command)
			expect(not result.Ok and result.Code == "NotReady" and table.isfrozen(result))
		end
		rejects(function()
			stub:Call("UnknownCommand")
		end)
		stub:Stop()
		stub:Stop()
		stub:Destroy()
		stub:Destroy()
		expect(not stub:IsStarted())
		rejects(function()
			stub:Start()
		end)
	end
end)
local function durations(): FoundationLoop.Durations
	return {
		Intermission = 1,
		Voting = 1,
		Loading = 1,
		Teleport = 0,
		PreRound = 1,
		Active = 240,
		Resolution = 0,
		Results = 1,
	}
end
test("stub loop 20 cycles, empty server cleanup and duration snapshot", function()
	local time, cleanups = 0, 0
	local config = durations()
	local loop = FoundationLoop.new(config, function()
		return time
	end, function() end, function()
		cleanups += 1
	end)
	loop:setPlayerCount(1)
	config.Active = 0
	for _ = 1, 20 do
		for _ = 1, 8 do
			local deadline = loop:getEndsAt()
			assert(deadline, currentTest)
			if loop:getState() == "Active" then
				expect(deadline - time == 240)
			end
			time = deadline
			loop:step()
		end
	end
	expect(loop:getRoundId() == 21 and cleanups == 21)
	loop:setPlayerCount(0)
	expect(loop:getState() == "Idle" and loop:getEndsAt() == nil)
	loop:destroy()
	loop:destroy()
end)
test("throwing/reentrant loop hooks cannot prevent safe teardown", function()
	local loop: FoundationLoop.Loop
	loop = FoundationLoop.new(durations(), function()
		return 0
	end, function()
		loop:step()
	end, function()
		error("cleanup failed")
	end)
	loop:setPlayerCount(1)
	expect(loop:getState() == "Intermission" and #loop:getErrors() == 2)
	loop:destroy()
	expect(loop:getState() == "Idle" and #loop:getErrors() == 4)
end)
test("confirmed decisions remain distinct from unapproved tuning", function()
	expect(Game.RoundDurationSeconds == 240 and Game.BossDeadlineSeconds == 240)
	expect(Game.BossHpMultiplier == 50 and Game.FreeSpinCooldownSeconds == 900)
	expect(not Game.Features.Gems and not Game.Features.LobbyInteractables)
	expect(not Game.Proposals.Approved)
end)
test("validation rejects NaN, infinity and malformed spatial data", function()
	expect(not Validation.finite(0 / 0) and not Validation.finite(math.huge))
	expect(Validation.integer(2, 1, 3) and not Validation.integer(1.5, 1, 3))
	expect(Validation.id("regular_droid") and not Validation.id("../server"))
	expect(Validation.point({ X = 0, Y = 1, Z = 2 }, 100))
	expect(not Validation.point({ X = 0, Y = 0 / 0, Z = 2 }, 100))
	expect(not Validation.point({ X = 0, Y = 1, Z = 2, UserId = 1 }, 100))
end)
test("Knit adapter preserves facade identity and rejects failed startup", function()
	local stub = ServiceStub.new("A", { "Query" })
	local services: { [string]: KnitAdapter.Service } = {}
	local adapter = KnitAdapter.new({
		CreateService = function(service)
			services[service.Name] = service
			return service
		end,
		GetService = function(name)
			return services[name]
		end,
		Start = function()
			return {
				await = function()
					return true, nil
				end,
			}
		end,
	})
	adapter.createService((stub :: unknown) :: KnitAdapter.Service)
	adapter.start()
	expect(adapter.getService("A") == (stub :: unknown) :: KnitAdapter.Service)
	local failed = KnitAdapter.new({
		CreateService = function(service)
			return service
		end,
		GetService = function(name)
			return { Name = name }
		end,
		Start = function()
			return {
				await = function()
					return false, "failed"
				end,
			}
		end,
	})
	rejects(function()
		failed.start()
	end)
end)
test("bounded logs and tagged error reporting", function()
	local logger = Logger.new(2, function()
		return 10
	end, function() end)
	logger:log("Info", "A", "one")
	logger:log("Info", "B", "two")
	logger:log("Info", "C", "three")
	expect(#logger:entries() == 2 and logger:entries()[1].Tag == "B")
	local reported = ""
	expect(not ErrorBoundary.run("operation", function()
		error("failure")
	end, function(tag, _message)
		reported = tag
	end))
	expect(reported == "operation")
end)
test("three primitive map snapshots and negative asset fixtures", function()
	local function snapshot(id: string): MapSnapshot.Map
		return {
			Path = id,
			Id = id,
			IsModel = true,
			HasGeometry = true,
			PlayerSpawns = {
				{ Id = "player_1", Position = { X = 0, Y = 5, Z = 0 }, Anchored = true, HasTag = true },
			},
			DroidSpawns = {
				{ Id = "droid_1", Position = { X = 20, Y = 5, Z = 0 }, Anchored = true, HasTag = true },
				{ Id = "droid_2", Position = { X = -20, Y = 5, Z = 0 }, Anchored = true, HasTag = true },
			},
			RecoveryPoint = { X = 0, Y = 10, Z = 0 },
			RecoveryAnchored = true,
			UnsafeDescendants = {},
		}
	end
	local policy = { MaxCoordinate = 100000, RecoveryHeight = -50 }
	for _, id in { "foundation_a", "foundation_b", "foundation_c" } do
		expect(#MapValidator.validate(snapshot(id), policy) == 0)
	end
	local unanchored = snapshot("unanchored_map")
	unanchored.RecoveryAnchored = false
	expect(#MapValidator.validate(unanchored, policy) == 1)
	local bad = snapshot("bad_map")
	bad.DroidSpawns[2].Id = bad.DroidSpawns[1].Id
	bad.PlayerSpawns[1].Position.Y = 0 / 0
	bad.RecoveryPoint = nil
	bad.UnsafeDescendants = { "bad_map.Script" }
	expect(#MapValidator.validate(bad, policy) == 4)
	table.remove(bad.DroidSpawns)
	expect(#MapValidator.validate(bad, policy) >= 4)
end)
test("intent schema rejects spoofed authority and malformed fields", function()
	local intent = {
		RequestId = "request-1",
		RoundId = 1,
		CharacterGeneration = 1,
		Action = "Fire",
		Slot = 1,
		Aim = { X = 0, Y = 0, Z = 10 },
	}
	local accepted = Schemas.inputIntent(intent)
	assert(accepted.Ok, "Valid input shape must be accepted")
	local acceptedAim = accepted.Value.Aim
	assert(acceptedAim, "Validated aim must be present")
	expect(table.isfrozen(accepted.Value) and table.isfrozen(acceptedAim))
	intent.Aim.Z = 99
	expect(acceptedAim.Z == 10)
	local spoofed = (table.clone(intent) :: unknown) :: { [string]: unknown }
	spoofed.UserId = 999
	expect(not Schemas.inputIntent(spoofed).Ok)
	spoofed.UserId = nil
	spoofed.Slot = 4
	expect(not Schemas.inputIntent(spoofed).Ok)
	spoofed.Slot = 1
	spoofed.Aim = { X = math.huge, Y = 0, Z = 0 }
	expect(not Schemas.inputIntent(spoofed).Ok)
	expect(not Schemas.inputIntent({}).Ok)
	expect(not Schemas.inputIntent(setmetatable({}, {})).Ok)
	expect(not Schemas.entityRef({ Id = "entity-1", Generation = 0, RoundId = 1 }).Ok)
	expect(Schemas.entityRef({ Id = "entity-1", Generation = 1, RoundId = 1 }).Ok)
end)
test("saved wheel snapshot has finite remaining connected time only", function()
	expect(Schemas.wheelClock({ RemainingSeconds = 600, ProfileReady = true, PaidSpins = 2 }).Ok)
	expect(not Schemas.wheelClock({ RemainingSeconds = -1, ProfileReady = true, PaidSpins = 2 }).Ok)
	expect(not Schemas.wheelClock({ RemainingSeconds = 0 / 0, ProfileReady = true, PaidSpins = 2 }).Ok)
	expect(not Schemas.wheelClock({
		RemainingSeconds = 600,
		ProfileReady = true,
		PaidSpins = 2,
		NextFreeSpinAt = 123,
	}).Ok)
end)
print(`Foundation total: {passed} tests passed (pure logic only).`)
return passed
