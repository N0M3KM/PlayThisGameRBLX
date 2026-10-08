--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local function waitFor(parent: Instance, name: string, timeout: number): Instance
	local child = parent:WaitForChild(name, timeout)
	assert(child, "Match preview missing " .. parent:GetFullName() .. "." .. name)
	return child
end

local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
assert(Shared, "Match shared modules are missing")
local Scope = require(Shared.Util.Scope)
local MatchConfig = require(Shared.Config.Match)

local MatchPreview = {}

--[=[ Displays public server attributes; owns no gameplay state or client intents. ]=]
function MatchPreview.start(): Scope.Scope
	local scope = Scope.new()
	local ok, result = xpcall(function(): Scope.Scope
		local player = Players.LocalPlayer
		assert(player, "Match preview must start on the client")
		local playerGui = waitFor(player, "PlayerGui", MatchConfig.CharacterWaitSeconds)
		local existing = playerGui:FindFirstChild("MatchPreview")
		local gui: ScreenGui
		if existing then
			assert(existing:IsA("ScreenGui"), "MatchPreview must be a ScreenGui")
			gui = existing
		else
			-- The connected foundation project keeps owner-authored StarterGui content intact.
			local template =
				waitFor(ReplicatedStorage, "MatchPreviewTemplate", MatchConfig.CharacterWaitSeconds)
			assert(template:IsA("ScreenGui"), "Match preview template must be a ScreenGui")
			local clone = template:Clone()
			clone.Name = "MatchPreview"
			clone.Parent = playerGui
			gui = clone
		end
		-- Register cleanup as soon as the GUI is acquired so later waits/assertions
		-- cannot leave it enabled. Only a clone created here is owned by this scope.
		local wasEnabled = gui.Enabled
		scope:add(function()
			gui.Enabled = wasEnabled
			if not existing then
				gui:Destroy()
			end
		end)
		local panel = waitFor(gui, "Panel", MatchConfig.CharacterWaitSeconds)
		local labels: { [string]: TextLabel } = {}
		for _, name in { "Status", "Countdown", "Selection", "Players", "Outcome", "Notice" } do
			local label = waitFor(panel, name, MatchConfig.CharacterWaitSeconds)
			assert(label:IsA("TextLabel"), name .. " must be a TextLabel")
			labels[name] = label
		end
		local presentation = waitFor(Workspace, "MatchPresentation", MatchConfig.CharacterWaitSeconds)
		assert(presentation:IsA("Folder"), "MatchPresentation must be a Folder")

		local function stringAttribute(name: string, fallback: string): string
			local value = presentation:GetAttribute(name)
			return if typeof(value) == "string" and value ~= "" then value else fallback
		end

		local function numberAttribute(name: string): number
			local value = presentation:GetAttribute(name)
			return if typeof(value) == "number"
					and value == value
					and math.abs(value) < math.huge
				then value
				else 0
		end

		local function updateCountdown()
			local endsAt = numberAttribute("EndsAt")
			labels.Countdown.Text = if endsAt > 0
				then string.format(
					"Time remaining: %ds",
					math.ceil(math.max(0, endsAt - Workspace:GetServerTimeNow()))
				)
				else "Waiting for players"
		end

		local function refresh()
			local state = stringAttribute("State", "Lobby")
			labels.Status.Text = string.format("%s | Round %d", state, numberAttribute("RoundId"))
			labels.Selection.Text = string.format(
				"Map: %s | Scenario: %s",
				stringAttribute("MapId", "Pending"),
				stringAttribute("ScenarioId", "Pending")
			)
			labels.Players.Text = string.format("Alive: %d", numberAttribute("AliveCount"))
			labels.Outcome.Text = "Outcome: " .. stringAttribute("Outcome", "Pending")
			local notice = if presentation:GetAttribute("PreviewOnly") == true then "Match preview" else ""
			if state == "Voting" then
				notice ..= (if notice ~= "" then " | " else "") .. "Vote: stand on one of the 3 pads"
			end
			labels.Notice.Text = notice
			updateCountdown()
		end

		for _, name in
			{ "State", "RoundId", "EndsAt", "MapId", "ScenarioId", "AliveCount", "Outcome", "PreviewOnly" }
		do
			local connection = presentation:GetAttributeChangedSignal(name):Connect(refresh)
			scope:add(function()
				connection:Disconnect()
			end)
		end
		local elapsed = 0
		local heartbeat = RunService.Heartbeat:Connect(function(deltaTime: number)
			elapsed += deltaTime
			if elapsed >= MatchConfig.TickSeconds then
				elapsed %= MatchConfig.TickSeconds
				updateCountdown()
			end
		end)
		scope:add(function()
			heartbeat:Disconnect()
		end)
		local owners: { Instance } = { gui, presentation }
		for _, instance in owners do
			local connection = instance.Destroying:Connect(function()
				scope:destroy()
			end)
			scope:add(function()
				connection:Disconnect()
			end)
		end
		refresh()
		gui.Enabled = true
		return scope
	end, debug.traceback)
	if not ok then
		scope:destroy()
		error(result, 0)
	end
	return result :: Scope.Scope
end

return table.freeze(MatchPreview)
