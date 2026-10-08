--!strict
local Snapshot = require("../Contracts/Assets/MapSnapshot")
local Validation = require("./Validation")
local MapValidator = {}
function MapValidator.validate(map: Snapshot.Map, policy: Snapshot.Policy): { string }
	assert(Validation.finite(policy.MaxCoordinate) and policy.MaxCoordinate > 0, "Invalid coordinate policy")
	assert(Validation.finite(policy.RecoveryHeight), "Invalid recovery policy")
	local errors: { string } = {}
	local function issue(field: string, expected: string)
		table.insert(errors, `{map.Path}.{field}: expected {expected}`)
	end
	if not map.IsModel then
		issue("ClassName", "Model")
	end
	if not Validation.id(map.Id) then
		issue("MapId", "stable snake_case ID")
	end
	if not map.HasGeometry then
		issue("Geometry", "Folder")
	end
	local ids: { [string]: boolean } = {}
	local function spawns(label: string, values: { Snapshot.Spawn }, minimum: number)
		if #values < minimum then
			issue(label, `at least {minimum} BaseParts`)
		end
		for index, spawn in values do
			local path = `{label}[{index}]`
			if not Validation.id(spawn.Id) or ids[spawn.Id] then
				issue(`{path}.SpawnId`, "unique snake_case ID")
			end
			ids[spawn.Id] = true
			if not spawn.Anchored then
				issue(`{path}.Anchored`, "true")
			end
			if not spawn.HasTag then
				issue(`{path}.Tag`, label == "PlayerSpawns" and "PlayerSpawn" or "DroidSpawn")
			end
			if not Validation.point(spawn.Position, policy.MaxCoordinate) then
				issue(`{path}.Position`, "finite bounded position")
			end
		end
	end
	spawns("PlayerSpawns", map.PlayerSpawns, 1)
	spawns("DroidSpawns", map.DroidSpawns, 2)
	local recovery = map.RecoveryPoint
	if
		not recovery
		or not Validation.point(recovery, policy.MaxCoordinate)
		or recovery.Y <= policy.RecoveryHeight
	then
		issue("Bounds.RecoveryPoint", "finite position above RecoveryHeight")
	end
	if recovery and map.RecoveryAnchored ~= true then
		issue("Bounds.RecoveryPoint.Anchored", "true")
	end
	for _, path in map.UnsafeDescendants do
		issue(path, "no scripts or remotes in map assets")
	end
	return errors
end
return table.freeze(MapValidator)
