--!strict
local Config = require("@game/ReplicatedStorage/Shared/Config/Data")
local Serializable = {}

--[=[ Copies only plain JSON-compatible values, rejecting cycles and mixed/sparse tables. ]=]
function Serializable.copy(value: unknown): unknown?
	local ancestors: { [any]: boolean } = {}
	local count = 0
	local function visit(current: unknown, depth: number): (unknown?, boolean)
		count += 1
		if count > Config.MaxEntries or depth > Config.MaxDepth then
			return nil, false
		end
		if type(current) == "number" then
			return current, current == current and math.abs(current) <= Config.MaxInteger
		elseif type(current) == "string" then
			return current, #current <= Config.MaxStringLength
		elseif type(current) == "boolean" then
			return current, true
		elseif type(current) ~= "table" then
			return nil, false
		end
		local entries = current :: { [any]: unknown }
		if getmetatable(entries :: any) ~= nil then
			return nil, false
		end
		if ancestors[entries] then
			return nil, false
		end
		ancestors[entries] = true
		local copy: { [any]: unknown } = {}
		local stringKeys, numericKeys, maximum = 0, 0, 0
		for key, child in entries do
			if type(key) == "string" and #key > 0 and #key <= Config.MaxStringLength then
				stringKeys += 1
			elseif type(key) == "number" and key % 1 == 0 and key >= 1 and key <= Config.MaxEntries then
				numericKeys += 1
				maximum = math.max(maximum, key)
			else
				return nil, false
			end
			local owned, ok = visit(child, depth + 1)
			if not ok then
				return nil, false
			end
			copy[key] = owned
		end
		ancestors[entries] = nil
		if (stringKeys > 0 and numericKeys > 0) or maximum ~= numericKeys then
			return nil, false
		end
		return copy, true
	end
	local owned, ok = visit(value, 0)
	return if ok then owned else nil
end

return table.freeze(Serializable)
