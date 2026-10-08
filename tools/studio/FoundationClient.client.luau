--!strict
-- Only foundation.project.json maps this client fixture. No UI, client intents or production replica protocol.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local mode = ReplicatedStorage:WaitForChild("MatchPreviewMode", 5)
if mode and mode:IsA("BoolValue") and mode.Value then
	script:SetAttribute("FoundationBindingStatus", "SkippedMatchPreview")
	return
end
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
assert(Shared, "Foundation shared modules are missing")
local Game = require(Shared.Config.Game)
local Schemas = require(Shared.Contracts.SnapshotSchemas)
local Payloads = require(Shared.Contracts.Payloads)
local Binding = require(Shared.Framework.SnapshotBinding)
local Scope = require(Shared.Util.Scope)
local scope = Scope.new()
local failed = false
script:SetAttribute("FoundationBindingStatus", "Waiting")
local function fail(message: string)
	if failed then
		return
	end
	failed = true
	script:SetAttribute("FoundationBindingStatus", "Failed")
	script:SetAttribute("FoundationBindingFailure", string.sub(message, 1, 1000))
	scope:destroy()
	warn(`Foundation client fixture failed: {string.sub(message, 1, 1000)}`)
end
local fixture =
	ReplicatedStorage:WaitForChild("FoundationSnapshotFixture", Game.Foundation.ReadinessTimeoutSeconds)
if not fixture or not fixture:IsA("Folder") or fixture:GetAttribute("StudioOnly") ~= true then
	fail("Studio snapshot fixture is missing")
	return
end
local binding = Binding.new({
	Validate = Schemas.match,
	RevisionOf = function(value: Payloads.MatchSnapshot): number
		return value.Revision
	end,
	RoundOf = function(value: Payloads.MatchSnapshot): number
		return value.RoundId
	end,
	OnChanged = function(value: Payloads.MatchSnapshot)
		if failed then
			return
		end
		script:SetAttribute("FoundationBindingStatus", "Bound")
		script:SetAttribute("FoundationBindingRevision", value.Revision)
		script:SetAttribute("FoundationBindingState", value.State)
		script:SetAttribute("FoundationBindingRoundId", value.RoundId)
		print(
			`Foundation client observed simulated snapshot {value.Revision}: round {value.RoundId}, {value.State}`
		)
	end,
	OnError = fail,
})
local outcome = table.pack(pcall(binding.bind, function(callback: (unknown) -> ()): () -> ()
	local function receive()
		if failed then
			return
		end
		local encoded = fixture:GetAttribute("Snapshot")
		if encoded == nil then
			return
		end
		if type(encoded) ~= "string" then
			fail("Snapshot attribute must be JSON text")
			return
		end
		local decoded = table.pack(pcall(HttpService.JSONDecode, HttpService, encoded))
		if not decoded[1] or not Schemas.match(decoded[2]).Ok then
			fail("Invalid snapshot attribute")
			return
		end
		callback(decoded[2])
	end
	local connection = fixture:GetAttributeChangedSignal("Snapshot"):Connect(receive)
	-- Subscribe first, then replay current data, so a late client cannot miss the snapshot.
	receive()
	return function()
		connection:Disconnect()
	end
end, scope))
if not outcome[1] then
	scope:destroy()
	fail(tostring(outcome[2]))
	return
end
if failed then
	return
end
local destroyed = fixture.Destroying:Connect(function()
	scope:destroy()
	if not failed then
		script:SetAttribute("FoundationBindingStatus", "Closed")
	end
end)
scope:add(function()
	destroyed:Disconnect()
end)
local removed = script.Destroying:Connect(function()
	scope:destroy()
end)
scope:add(function()
	removed:Disconnect()
end)
local timeout = task.delay(Game.Foundation.ReadinessTimeoutSeconds, function()
	if not binding.read().Ok then
		fail("No validated match snapshot arrived before timeout")
		scope:destroy()
	end
end)
scope:add(function()
	if coroutine.status(timeout) == "suspended" then
		task.cancel(timeout)
	end
end)
