--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Result = require(Shared.Contracts.Result)
local Boundary = require(Shared.Contracts.Boundary)
local Schemas = require(Shared.Contracts.RequestSchemas)
local Gateway = require("@game/ServerScriptService/Server/Services/Combat/CombatGateway")
local CombatRemoteBinding = {}
export type Binding = { destroy: () -> () }
local ACTIONS: { Gateway.Action } = { "UseGear", "ReloadGear", "UseAbility" }
table.freeze(ACTIONS)
local NAMES = table.freeze({ "UseGear", "ReloadGear", "UseAbility", "CommandResult" })
local owners: { [Instance]: boolean } = {}
setmetatable(owners, { __mode = "k" })

local function preflight(folder: Folder): Result.Result<{ [string]: RemoteEvent }>
	if folder.Parent ~= Shared or folder.Name ~= "Remotes" then
		return Result.failure("InvalidRequest")
	end
	local folderCount = 0
	for _, child in Shared:GetChildren() do
		if child.Name == "Remotes" then
			folderCount += 1
		end
	end
	if folderCount ~= 1 then
		return Result.failure("WrongState")
	end
	local existing: { [string]: RemoteEvent } = {}
	for _, child in folder:GetChildren() do
		if table.find(NAMES, child.Name) then
			if existing[child.Name] then
				return Result.failure("WrongState")
			end
			if not child:IsA("RemoteEvent") then
				return Result.failure("InvalidRequest")
			end
			existing[child.Name] = child
		end
	end
	return Result.success(existing)
end

--[=[ Explicit C-owned binding. CommandResult is shared and survives normal teardown. ]=]
function CombatRemoteBinding.bind(folder: Folder, gateway: Gateway.Gateway): Result.Result<Binding>
	if not folder:IsA("Folder") then
		return Result.failure("InvalidRequest")
	end
	if owners[folder] then
		return Result.failure("WrongState")
	end
	local inspected = preflight(folder)
	if not inspected.Ok then
		return Result.failure(inspected.Code)
	end
	owners[folder] = true
	local events = inspected.Value
	local created: { RemoteEvent } = {}
	local connections: { RBXScriptConnection } = {}
	local destroyed = false
	local function disconnect()
		for _, connection in connections do
			connection:Disconnect()
		end
		connections = {}
	end
	local function destroyCreated(preserveAck: boolean)
		for _, endpoint in created do
			if
				not preserveAck
				or endpoint == events.UseGear
				or endpoint == events.ReloadGear
				or endpoint == events.UseAbility
			then
				endpoint:Destroy()
			end
		end
		created = {}
	end
	local setup = pcall(function()
		for _, name in NAMES do
			if not events[name] then
				local endpoint = Instance.new("RemoteEvent")
				endpoint.Name = name
				table.insert(created, endpoint)
				events[name] = endpoint
				endpoint.Parent = folder
			end
		end
		local resultEvent = events.CommandResult
		for _, action in ACTIONS do
			local connection = events[action].OnServerEvent:Connect(function(player: Player, input: unknown)
				if destroyed or player.Parent ~= Players then
					return
				end
				-- The endpoint supplies identity; shape/rate checks precede any echoed data.
				local ok, outcome = pcall(function()
					return gateway.handle(player.UserId, action :: Gateway.Action, input)
				end)
				if not ok or (not outcome.Ok and outcome.Code == "RateLimited") then
					return
				end
				if destroyed or player.Parent ~= Players or not Boundary.plain(input) then
					return
				end
				local requestId = rawget(input :: { [string]: unknown }, "RequestId")
				if not Boundary.token(requestId) then
					return
				end
				local response = Schemas.commandResult({ RequestId = requestId, Result = outcome })
				if response.Ok then
					pcall(resultEvent.FireClient, resultEvent, player, response.Value)
				end
			end)
			table.insert(connections, connection)
		end
	end)
	if not setup then
		destroyed = true
		disconnect()
		destroyCreated(false)
		owners[folder] = nil
		return Result.failure("Unavailable")
	end
	local binding: Binding = {
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			disconnect()
			destroyCreated(true)
			owners[folder] = nil
		end,
	}
	return Result.success(table.freeze(binding))
end

return table.freeze(CombatRemoteBinding)
