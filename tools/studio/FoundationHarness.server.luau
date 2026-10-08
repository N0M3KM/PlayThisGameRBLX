--!strict
-- Isolated Studio assertions. Simulated cycles are not live-round or multiplayer evidence.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local TestService = game:GetService("TestService")
local Server = game:GetService("ServerScriptService").Server
local FoundationLoop = require(Server.Infrastructure.FoundationLoop)
local ServiceStub = require(Server.Infrastructure.ServiceStub)
local Foundation = require(Server.Boot.Foundation)
local Shared = game:GetService("ReplicatedStorage").Shared
local mode = game:GetService("ReplicatedStorage"):FindFirstChild("MatchPreviewMode")
if mode and mode:IsA("BoolValue") and mode.Value then
	script:SetAttribute("FoundationHarnessStatus", "SkippedMatchPreview")
	return
end
local Scope = require(Shared.Util.Scope)
local Game = require(Shared.Config.Game)
local Schemas = require(Shared.Contracts.SnapshotSchemas)
local HttpService = game:GetService("HttpService")
local Catalog = require(Shared.Contracts.ServiceCatalog)
local AssetValidator = require(Server.Services.Match.MapValidator)
local Fixture = require(game:GetService("ServerStorage").Assets.Maps.FoundationFixture)
local readinessScope = Scope.new()
local transportScope = Scope.new()
game:BindToClose(function()
	transportScope:destroy()
end)
local status = "Pending"
Server:SetAttribute("FoundationHarnessStatus", status)
Server:SetAttribute("FoundationHarnessFailure", nil)
local function check(condition: boolean, message: string)
	TestService:Check(condition, message)
	assert(condition, message)
end
local function verifyLoop(scope: Scope.Scope)
	local time, cleanups = 0, 0
	local channel = Instance.new("Folder")
	channel.Name = "FoundationSnapshotFixture"
	channel:SetAttribute("StudioOnly", true)
	transportScope:add(function()
		channel:Destroy()
	end)
	channel.Parent = game:GetService("ReplicatedStorage")
	local revision = 0
	local loop = FoundationLoop.new({
		Intermission = 1,
		Voting = 1,
		Loading = 1,
		Teleport = 0,
		PreRound = 1,
		Active = 240,
		Resolution = 0,
		Results = 1,
	}, function()
		return time
	end, function(state, roundId, endsAt)
		revision += 1
		local validated = Schemas.match({
			ContractVersion = 0,
			Revision = revision,
			State = state,
			RoundId = roundId,
			EndsAt = endsAt,
		})
		assert(validated.Ok, "Simulated match snapshot must validate")
		-- One complete value prevents clients combining fields from different revisions.
		channel:SetAttribute("Snapshot", HttpService:JSONEncode(validated.Value))
		TestService:Message(`Simulated stub round {roundId}: {state}`)
	end, function()
		cleanups += 1
	end)
	scope:add(function()
		loop:destroy()
	end)
	loop:setPlayerCount(1)
	for _ = 1, 20 do
		for _ = 1, 8 do
			local deadline = loop:getEndsAt()
			assert(deadline, "Stub loop must have a deadline")
			time = deadline
			loop:step()
		end
	end
	local completed = loop:getRoundId() == 21 and cleanups == 21
	loop:setPlayerCount(0)
	local idle = loop:getState() == "Idle"
	loop:destroy()
	check(#loop:getErrors() == 0, "Simulated loop callbacks complete without errors")
	check(completed, "Twenty simulated stub cycles completed")
	check(idle, "Empty server returns to Idle")
end
local function verifyFacades()
	for _, entry in Catalog do
		local stub = Foundation.resolve(entry.Name)
		check(stub:IsStarted() and stub.IsStub, `{entry.Name} resolves the started facade`)
		local methods = (stub :: unknown) :: { [string]: unknown }
		for _, command in entry.Commands do
			local method = methods[command]
			assert(type(method) == "function", `Missing typed method: {entry.Name}.{command}`)
			local call = method :: (ServiceStub.Stub) -> unknown
			local result = call(stub)
			local fields = if type(result) == "table" then result :: { [unknown]: unknown } else nil
			-- Player-state queries retain their interface's native return shape.
			if
				entry.Name == "PlayerStateService"
				and (command == "EligiblePlayers" or command == "BeginRound")
			then
				check(fields ~= nil and next(fields) == nil, `{entry.Name}.{command} is empty`)
			elseif entry.Name == "PlayerStateService" and command == "IsAfk" then
				check(result == true, "Unready players stay excluded")
			elseif entry.Name == "PlayerStateService" and command == "ValidateLobbyReservation" then
				check(result == false, "Unready lobby reservations stay invalid")
			elseif entry.Name == "BossCoordinator" and command == "ObserveDeaths" then
				check(type(result) == "function", "Stub observer returns an owned disconnect")
				if type(result) == "function" then
					(result :: () -> ())()
				end
			elseif
				(entry.Name == "PlayerStateService" and command == "ResetRound")
				or (entry.Name == "VotingService" and command == "Close")
				or (
					command == "ClearRound"
					and (
						entry.Name == "StatService"
						or entry.Name == "StatusEffectService"
						or entry.Name == "LoadoutService"
					)
				)
			then
				check(result == nil, `{entry.Name}.{command} retains its void return`)
			else
				check(
					fields ~= nil and fields.Ok == false and fields.Code == "NotReady",
					`{entry.Name}.{command} is safe`
				)
			end
		end
	end
end
local function verifyAssets(scope: Scope.Scope)
	local policy = { MaxCoordinate = 100000, RecoveryHeight = -50 }
	for _, id in { "foundation_a", "foundation_b", "foundation_c" } do
		local model = Fixture.create(id)
		scope:add(function()
			model:Destroy()
		end)
		local errors = AssetValidator.validate(model, policy)
		check(#errors == 0, `Primitive map {id}: {table.concat(errors, "; ")}`)
	end
	local malformed = Fixture.create("foundation_negative")
	scope:add(function()
		malformed:Destroy()
	end)
	local recovery = malformed:FindFirstChild("RecoveryPoint", true)
	assert(recovery and recovery:IsA("BasePart"), "Fixture must have a recovery marker")
	recovery.Anchored = false
	check(#AssetValidator.validate(malformed, policy) == 1, "Unanchored recovery marker is rejected")
	recovery.Anchored = true
	local invalidSpawn = Instance.new("Folder")
	invalidSpawn.Name = "InvalidSpawn"
	local spawnFolder = malformed:FindFirstChild("PlayerSpawns")
	assert(spawnFolder, "Fixture must have player spawns")
	invalidSpawn.Parent = spawnFolder
	local errors = AssetValidator.validate(malformed, policy)
	check(
		#errors == 1 and string.find(errors[1], "InvalidSpawn", 1, true) ~= nil,
		"Malformed spawn child has an actionable path"
	)
end
local function fail(message: string)
	status = "Failed"
	Server:SetAttribute("FoundationHarnessStatus", status)
	Server:SetAttribute("FoundationHarnessFailure", string.sub(message, 1, 1000))
	TestService:Fail(message)
end
local function checkBoot()
	if status ~= "Pending" or not Server:GetAttribute("FoundationReady") then
		return
	end
	status = "Running"
	Server:SetAttribute("FoundationHarnessStatus", status)
	readinessScope:destroy()
	local fixtures = Scope.new()
	local outcome = table.pack(pcall(function()
		verifyFacades()
		verifyLoop(fixtures)
		verifyAssets(fixtures)
	end))
	local cleanupErrors = fixtures:destroy()
	if not outcome[1] or #cleanupErrors > 0 then
		transportScope:destroy()
		fail(if not outcome[1] then tostring(outcome[2]) else table.concat(cleanupErrors, "; "))
		return
	end
	status = "Passed"
	Server:SetAttribute("FoundationHarnessStatus", status)
	TestService:Message(
		"Foundation harness Passed: facades, simulated loop and map fixtures. Record server/client Output separately."
	)
end
local connection = Server:GetAttributeChangedSignal("FoundationReady"):Connect(checkBoot)
readinessScope:add(function()
	connection:Disconnect()
end)
local timeout = task.delay(Game.Foundation.ReadinessTimeoutSeconds, function()
	readinessScope:destroy()
	if status == "Pending" then
		fail("Foundation readiness timed out")
	end
end)
readinessScope:add(function()
	if coroutine.status(timeout) == "suspended" then
		task.cancel(timeout)
	end
end)
checkBoot()
