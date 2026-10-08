--!strict
export type DataTable = { [string | number]: unknown }
local DeepFreeze = {}
local readMetatable = (getmetatable :: unknown) :: (unknown) -> unknown

--[=[ Rejects cycles/nonserializable values, then freezes every nested table. ]=]
function DeepFreeze.freeze(data: DataTable): DataTable
	local active: { [DataTable]: boolean } = {}
	local finished: { [DataTable]: boolean } = {}
	local validated: { DataTable } = {}
	local function visit(current: DataTable)
		assert(readMetatable(current) == nil, "Config must use plain tables without metatables")
		assert(not active[current], "Config contains a cycle")
		if finished[current] then
			return
		end
		active[current] = true
		for key, value in current do
			assert(type(key) == "string" or type(key) == "number", "Invalid config key")
			if type(key) == "number" then
				assert(key == key and math.abs(key) < math.huge, "Nonfinite config key")
			end
			local kind = type(value)
			if kind == "table" then
				visit(value :: DataTable)
			elseif kind == "number" then
				local numberValue = value :: number
				assert(
					numberValue == numberValue and math.abs(numberValue) < math.huge,
					"Nonfinite config number"
				)
			else
				assert(
					kind == "string" or kind == "boolean",
					"Config must contain data, not functions/Instances"
				)
			end
		end
		active[current] = nil
		finished[current] = true
		table.insert(validated, current)
	end
	visit(data)
	-- A failed validation leaves the caller's data untouched, including already visited children.
	for _, current in validated do
		if not table.isfrozen(current) then
			table.freeze(current)
		end
	end
	return data
end

return table.freeze(DeepFreeze)
