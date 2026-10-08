--!strict
-- A separate preview project selects these implementations; Foundation keeps its original safe harness.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage.Shared
local Framework = require(Shared.Framework.Framework)
local KnitAdapter = require(Shared.Framework.KnitAdapter)
local Service = require(Shared.Contracts.Service)
local Payloads = require(Shared.Contracts.Payloads)
local Domain = require(Shared.Contracts.DomainInterfaces)
local Catalog = require(Shared.Contracts.ServiceCatalog)
local Scope = require(Shared.Util.Scope)
local Config = require(Shared.Config.Match)
local Maps = require(Shared.Config.Maps)
local Results = require(Shared.Util.Match.ResultsCalculator)
local VoteLedger = require(Shared.Util.Match.VoteLedger)
local Services = script.Parent.Parent.Services.Match
local MapService = require(Services.MapService.Implementation)
local PlayerState = require(Services.PlayerStateService.Implementation)
local Teleports = require(Services.TeleportService.Implementation)
local Voting = require(Services.VotingService.Implementation)
local Scenarios = require(Services.ScenarioDirector.Implementation)
local Loop = require(Services.GameLoopService.Implementation)
local StubFactories = require(script.Parent.StubFactories)
local DroidPreview = require(script.Parent.DroidPreview)
local Match = {}
local started = false
local activeFramework: Framework.Adapter? = nil

--[=[ Studio diagnostics resolve the same registered facades as domain callers. ]=]
function Match.resolve(name: string): Service.Interface
	local framework = activeFramework
	assert(framework, "Match is not ready")
	return (framework.getService(name) :: unknown) :: Service.Interface
end

function Match.start()
	assert(not started, "Match already started")
	assert(game:GetService("RunService"):IsStudio(), "Match preview is restricted to Studio")
	started = true
	local scope = Scope.new()
	local assets = ServerStorage:FindFirstChild("Assets")
	local lobbyAssets = if assets then assets:FindFirstChild("Lobby") else nil
	local matchAssets = if lobbyAssets then lobbyAssets:FindFirstChild("Match") else nil
	local lobbyTemplate = if matchAssets then matchAssets:FindFirstChild("MatchLobby") else nil
	assert(lobbyTemplate and lobbyTemplate:IsA("Model"), "Match project is missing its lobby template")
	assert(
		not Workspace:FindFirstChild("MatchLobby") and not Workspace:FindFirstChild("MatchPresentation"),
		"Duplicate match owners"
	)
	local lobby = lobbyTemplate:Clone()
	scope:add(function()
		lobby:Destroy()
	end)
	lobby.Parent = Workspace
	local presentation = Instance.new("Folder")
	presentation.Name = "MatchPresentation"
	presentation:SetAttribute("PreviewOnly", Config.PreviewOnly)
	presentation:SetAttribute("State", "Idle")
	presentation:SetAttribute("RoundId", 0)
	presentation.Parent = Workspace
	scope:add(function()
		presentation:Destroy()
	end)
	local knit = require(ReplicatedStorage.Packages.Knit)
	local framework = Framework.new(KnitAdapter.new((knit :: unknown) :: KnitAdapter.KnitApi))
	local random = Random.new()
	local function resolve(name: string): Service.Interface
		return (framework.getService(name) :: unknown) :: Service.Interface
	end
	local function publish(snapshot: Payloads.MatchSnapshot, aliveCount: number)
		presentation:SetAttribute("State", snapshot.State)
		presentation:SetAttribute("RoundId", snapshot.RoundId)
		presentation:SetAttribute("EndsAt", snapshot.EndsAt)
		presentation:SetAttribute("MapId", snapshot.MapId)
		presentation:SetAttribute("ScenarioId", snapshot.ScenarioId)
		presentation:SetAttribute("AliveCount", aliveCount)
		presentation:SetAttribute("Revision", snapshot.Revision)
		local states = (resolve("PlayerStateService") :: unknown) :: Domain.PlayerStateService
		local alive = states:GetAlive(snapshot.RoundId)
		presentation:SetAttribute("AliveList", HttpService:JSONEncode(if alive.Ok then alive.Value else {}))
		if snapshot.State == "Intermission" then
			presentation:SetAttribute("Outcome", nil)
			presentation:SetAttribute("Results", nil)
		end
	end
	local function voteChanged(snapshot: VoteLedger.Snapshot)
		local pads = lobby:FindFirstChild("VotePads")
		if not pads then
			return
		end
		for index, mapId in snapshot.Choices do
			local pad = pads:FindFirstChild(`Pad{index}`)
			if pad then
				pad:SetAttribute("MapId", mapId)
				pad:SetAttribute("Votes", snapshot.Counts[mapId])
				local label = pad:FindFirstChild("VoteLabel")
				if label and label:IsA("BillboardGui") then
					local text = label:FindFirstChild("Text")
					if text and text:IsA("TextLabel") then
						text.Text = if snapshot.Deadline
							then `{Maps.ById[mapId].DisplayName}: {snapshot.Counts[mapId]}`
							else "Voting closed"
					end
				end
			end
		end
	end
	local pads = lobby:FindFirstChild("VotePads")
	if pads then
		for _, pad in pads:GetChildren() do
			if pad:IsA("BasePart") then
				local gui = Instance.new("BillboardGui")
				gui.Name = "VoteLabel"
				gui.Size = UDim2.fromOffset(180, 40)
				gui.StudsOffset = Vector3.new(0, 4, 0)
				gui.AlwaysOnTop = true
				local text = Instance.new("TextLabel")
				text.Name = "Text"
				text.Size = UDim2.fromScale(1, 1)
				text.BackgroundTransparency = 1
				text.Text = "Voting closed"
				text.TextSize = 18
				text.Parent = gui
				gui.Parent = pad
			end
		end
	end
	local playerChanged: ((Payloads.PlayerStateSnapshot) -> ())? = nil
	local real: { [string]: Service.Interface } = {
		MapService = MapService.new(),
		PlayerStateService = PlayerState.new(function(snapshot: Payloads.PlayerStateSnapshot)
			if playerChanged then
				playerChanged(snapshot)
			end
			local player = Players:GetPlayerByUserId(snapshot.UserId)
			if player then
				player:SetAttribute("MatchPlayerState", snapshot.State)
				player:SetAttribute("MatchCharacterGeneration", snapshot.CharacterGeneration)
			end
		end),
		TeleportService = Teleports.new(resolve),
		ScenarioDirector = Scenarios.new(random),
		VotingService = Voting.new(random, function()
			return Workspace:GetServerTimeNow()
		end, voteChanged),
		GameLoopService = Loop.new(resolve, random, publish, function(results: Results.Result)
			presentation:SetAttribute("Outcome", results.Outcome.Reason)
			presentation:SetAttribute("SurvivorCount", #results.Outcome.Survivors)
			presentation:SetAttribute("Results", HttpService:JSONEncode(results))
		end),
	}
	for _, entry in Catalog do
		if not real[entry.Name] then
			real[entry.Name] = StubFactories[entry.Name]()
		end
	end
	local droidPreview = nil
	if Config.DroidPreview then
		assert(assets, "Droid preview requires Assets")
		local ok, preview = pcall(DroidPreview.new, resolve, real, assets, scope)
		if not ok then
			scope:destroy()
			error(tostring(preview), 0)
		end
		droidPreview = preview
		playerChanged = droidPreview.playerChanged
	end
	local registered: { Service.Interface } = {}
	local outcome = table.pack(pcall(function()
		for _, entry in Catalog do
			local facade = ((real[entry.Name] or StubFactories[entry.Name]()) :: unknown) :: Service.Interface
			framework.createService((facade :: unknown) :: Framework.Service)
			table.insert(registered, facade)
			scope:add(function()
				facade:Destroy()
			end)
		end
		framework.start()
		for _, facade in registered do
			facade:Init()
		end
		-- Dependency services start before the loop subscribes/schedules.
		for _, facade in registered do
			if facade.Name ~= "GameLoopService" and not facade:IsStarted() then
				facade:Start()
			end
		end
		real.GameLoopService:Start()
		if droidPreview then
			droidPreview.start()
		end
		local removing = Players.PlayerRemoving:Connect(function(player)
			local voter = real.VotingService :: Voting.Voting
			voter:RemovePlayer(player.UserId)
		end)
		scope:add(function()
			removing:Disconnect()
		end)
	end))
	if not outcome[1] then
		scope:destroy()
		error(tostring(outcome[2]), 0)
	end
	activeFramework = framework
	game:BindToClose(function()
		real.GameLoopService:Stop()
		scope:destroy()
	end)
	presentation:SetAttribute("Ready", true)
	print("Match preview ready: physical voting, map clones, player state, round timers and lobby returns.")
end
return table.freeze(Match)
