--!strict
-- Primitive validator fixture only; not a playable map or authored design.
local CollectionService = game:GetService("CollectionService")
local Fixture = {}
function Fixture.create(id: string): Model
	local model = Instance.new("Model")
	model.Name = id
	model:SetAttribute("MapId", id)
	local function folder(name: string): Folder
		local result = Instance.new("Folder")
		result.Name = name
		result.Parent = model
		return result
	end
	local function part(parent: Folder, name: string, position: Vector3, tag: string?): Part
		local result = Instance.new("Part")
		result.Name = name
		result.Anchored = true
		result.CanCollide = false
		result.CanQuery = false
		result.CanTouch = false
		result.Size = Vector3.new(2, 1, 2)
		result.Position = position
		if tag then
			result:SetAttribute("SpawnId", name)
			CollectionService:AddTag(result, tag)
		end
		result.Parent = parent
		return result
	end
	folder("Geometry")
	part(folder("PlayerSpawns"), "player_1", Vector3.new(0, 5, 0), "PlayerSpawn")
	local droidSpawns = folder("DroidSpawns")
	part(droidSpawns, "droid_1", Vector3.new(20, 5, 0), "DroidSpawn")
	part(droidSpawns, "droid_2", Vector3.new(-20, 5, 0), "DroidSpawn")
	part(folder("Bounds"), "RecoveryPoint", Vector3.new(0, 10, 0), nil)
	return model
end
return table.freeze(Fixture)
