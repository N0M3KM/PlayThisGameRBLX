--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local Service = require(Shared.Contracts.Service)
local Scope = require(Shared.Util.Scope)
local Config = require(Shared.Config.Match)
local Limits = require(Shared.Config.Validation)
local Maps = require(Shared.Config.Maps)
local Validation = require(Shared.Registry.Validation)
local Interface = require(script.Parent.Interface)
local AssetValidator = require(script.Parent.Parent.MapValidator)
local Lifecycle = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceLifecycle)
local Implementation = {}

local function dense(values: unknown, minimum: number): boolean
	if type(values) ~= "table" then
		return false
	end
	local entries = values :: { [unknown]: unknown }
	local length = #entries
	if length < minimum then
		return false
	end
	local count = 0
	for key in entries do
		if not Validation.integer(key, 1, length) then
			return false
		end
		count += 1
	end
	return count == length
end

local function copyPoints(points: { Payloads.Point }): { Payloads.Point }?
	local copy: { Payloads.Point } = {}
	for _, point in points do
		if not Validation.point(point, Config.MapCoordinateLimit) then
			return nil
		end
		table.insert(copy, table.freeze({ X = point.X, Y = point.Y, Z = point.Z }))
	end
	return table.freeze(copy)
end

function Implementation.new(): Interface.Interface
	local scope = Scope.new()
	local context: Payloads.MapContext? = nil
	local currentScope: Scope.Scope? = nil
	local function unload()
		local owned = currentScope
		currentScope, context = nil, nil
		if owned then
			owned:destroy()
		end
	end
	local facade = Lifecycle.new("MapService", scope, { Stop = unload })
	local result = (facade :: unknown) :: Interface.Interface
	local function positions(model: Model, name: string, tag: string): { Payloads.Point }
		local folder = model:FindFirstChild(name)
		assert(folder and folder:IsA("Folder"), `Map is missing {name}`)
		local children = folder:GetChildren()
		table.sort(children, function(a, b)
			return a.Name < b.Name
		end)
		local points: { Payloads.Point } = {}
		for _, marker in children do
			if marker:IsA("BasePart") then
				marker:SetAttribute("SpawnId", marker.Name)
				CollectionService:AddTag(marker, tag)
				table.insert(
					points,
					table.freeze({ X = marker.Position.X, Y = marker.Position.Y, Z = marker.Position.Z })
				)
			end
		end
		return table.freeze(points)
	end
	result.Load = function(
		self: Service.Interface,
		roundId: number,
		mapId: string
	): Result.Result<Payloads.MapContext>
		if not self:IsStarted() then
			return Result.failure("NotReady")
		end
		if not Validation.integer(roundId, 1, Limits.MaxInteger) or not Validation.id(mapId) then
			return Result.failure("InvalidRequest")
		end
		local definition = Maps.ById[mapId]
		if not definition then
			return Result.failure("UnknownId")
		end
		if context then
			return Result.failure("WrongState")
		end
		local assets = ServerStorage:FindFirstChild("Assets")
		local templates = if assets then assets:FindFirstChild("Maps") else nil
		local playable = if templates then templates:FindFirstChild("Playable") else nil
		local template = if playable then playable:FindFirstChild(definition.AssetId) else nil
		if not template or not template:IsA("Model") then
			return Result.failure("Unavailable")
		end
		local childScope = scope:child()
		local outcome = table.pack(pcall(function()
			local clone = template:Clone()
			childScope:add(function()
				clone:Destroy()
			end)
			clone.Name = `Round_{roundId}_{mapId}`
			clone:SetAttribute("MapId", mapId)
			clone:SetAttribute("RoundId", roundId)
			local location = Config.MapPosition
			clone:PivotTo(CFrame.new(location.X, location.Y, location.Z))
			local players = positions(clone, "PlayerSpawns", "PlayerSpawn")
			local droids = positions(clone, "DroidSpawns", "DroidSpawn")
			local errors = AssetValidator.validate(
				clone,
				{ MaxCoordinate = Config.MapCoordinateLimit, RecoveryHeight = Config.RecoveryHeight }
			)
			assert(#errors == 0, table.concat(errors, "; "))
			currentScope = childScope
			context = table.freeze({
				MapId = mapId,
				RoundId = roundId,
				PlayerSpawns = players,
				DroidSpawns = droids,
			})
			clone.Parent = Workspace
		end))
		if not outcome[1] then
			childScope:destroy()
			currentScope, context = nil, nil
			warn(`Map load failed: {tostring(outcome[2])}`)
			return Result.failure("Unavailable")
		end
		assert(context, "Map load must produce context")
		return Result.success(context)
	end
	result.GetSpawns = function(_self: Service.Interface, roundId: number): Result.Result<{ Payloads.Point }>
		if not context or context.RoundId ~= roundId then
			return Result.failure("StaleRound")
		end
		return Result.success(context.PlayerSpawns)
	end
	result.Unload = function(_self: Service.Interface, roundId: number): Result.Result<boolean>
		if context and context.RoundId ~= roundId then
			return Result.failure("StaleRound")
		end
		unload()
		return Result.success(true)
	end
	result.Validate = function(
		_self: Service.Interface,
		map: Payloads.MapDescriptor
	): Result.Result<Payloads.MapDescriptor>
		if type(map) ~= "table" or not Validation.id(map.Id) then
			return Result.failure("InvalidRequest")
		end
		local definition = Maps.ById[map.Id]
		if not definition then
			return Result.failure("InvalidRequest")
		end
		if not dense(map.PlayerSpawns, 1) or not dense(map.DroidSpawns, 2) or not dense(map.DroidPool, 1) then
			return Result.failure("InvalidRequest")
		end
		local players = copyPoints(map.PlayerSpawns)
		local droids = copyPoints(map.DroidSpawns)
		if not players or not droids then
			return Result.failure("InvalidRequest")
		end
		local allowed: { [string]: boolean } = {}
		for _, id in definition.DroidPool do
			allowed[id] = true
		end
		local seen: { [string]: boolean } = {}
		local pool: { string } = {}
		for _, id in map.DroidPool do
			if not Validation.id(id) or not allowed[id] or seen[id] then
				return Result.failure("InvalidRequest")
			end
			seen[id] = true
			table.insert(pool, id)
		end
		if #pool ~= #definition.DroidPool then
			return Result.failure("InvalidRequest")
		end
		return Result.success(table.freeze({
			Id = map.Id,
			PlayerSpawns = players,
			DroidSpawns = droids,
			DroidPool = table.freeze(pool),
		}))
	end
	return result
end
return table.freeze(Implementation)
