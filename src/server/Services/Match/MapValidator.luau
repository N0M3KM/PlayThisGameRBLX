--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local CollectionService = game:GetService("CollectionService")
local Snapshot = require(Shared.Contracts.Assets.MapSnapshot)
local PureValidator = require(Shared.Registry.MapValidator)
local MapValidator = {}
function MapValidator.validate(model: Instance, policy: Snapshot.Policy): { string }
	local invalidSpawns: { string } = {}
	local function point(part: BasePart): Snapshot.Point
		local position = part.Position
		return { X = position.X, Y = position.Y, Z = position.Z }
	end
	local function spawns(name: string, tag: string): { Snapshot.Spawn }
		local result: { Snapshot.Spawn } = {}
		local folder = model:FindFirstChild(name)
		if not folder or not folder:IsA("Folder") then
			return result
		end
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				local id = child:GetAttribute("SpawnId")
				table.insert(result, {
					Id = if type(id) == "string" then id else "",
					Position = point(child),
					Anchored = child.Anchored,
					HasTag = CollectionService:HasTag(child, tag),
				})
			else
				table.insert(invalidSpawns, `{child:GetFullName()}: expected BasePart spawn marker`)
			end
		end
		return result
	end
	local unsafe: { string } = {}
	for _, descendant in model:GetDescendants() do
		if
			descendant:IsA("LuaSourceContainer")
			or descendant:IsA("RemoteEvent")
			or descendant:IsA("RemoteFunction")
			or descendant:IsA("UnreliableRemoteEvent")
		then
			table.insert(unsafe, descendant:GetFullName())
		end
	end
	local id = model:GetAttribute("MapId")
	local bounds = model:FindFirstChild("Bounds")
	local recovery = if bounds and bounds:IsA("Folder") then bounds:FindFirstChild("RecoveryPoint") else nil
	local geometry = model:FindFirstChild("Geometry")
	local errors = PureValidator.validate({
		Path = model:GetFullName(),
		Id = if type(id) == "string" then id else "",
		IsModel = model:IsA("Model"),
		HasGeometry = geometry ~= nil and geometry:IsA("Folder"),
		PlayerSpawns = spawns("PlayerSpawns", "PlayerSpawn"),
		DroidSpawns = spawns("DroidSpawns", "DroidSpawn"),
		RecoveryPoint = if recovery and recovery:IsA("BasePart") then point(recovery) else nil,
		RecoveryAnchored = if recovery and recovery:IsA("BasePart") then recovery.Anchored else nil,
		UnsafeDescendants = unsafe,
	}, policy)
	for _, issue in invalidSpawns do
		table.insert(errors, issue)
	end
	return errors
end
return table.freeze(MapValidator)
