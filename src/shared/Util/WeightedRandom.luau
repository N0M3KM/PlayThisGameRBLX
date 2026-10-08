--!strict
export type Entry = { Id: string, Weight: number }
export type UnitRandom = () -> number
local WeightedRandom = {}

--[=[ Selects from positive relative weights using an injected [0,1) sample. ]=]
function WeightedRandom.pick(entries: { Entry }, random: UnitRandom): string
	assert(#entries > 0, "Cannot draw from an empty pool")
	local total = 0
	local ids: { [string]: boolean } = {}
	for _, entry in entries do
		assert(entry.Id ~= "" and not ids[entry.Id], "Pool IDs must be nonempty and unique")
		assert(entry.Weight > 0 and entry.Weight < math.huge, "Weight must be positive and finite")
		ids[entry.Id] = true
		total += entry.Weight
	end
	assert(total < math.huge, "Combined weight overflowed")
	local unit = random()
	assert(unit >= 0 and unit < 1, "RNG must produce a finite value in [0,1)")
	local draw = unit * total
	local cumulative = 0
	for _, entry in entries do
		cumulative += entry.Weight
		if draw < cumulative then
			return entry.Id
		end
	end
	return entries[#entries].Id
end

function WeightedRandom.withoutReplacement(entries: { Entry }, count: number, random: UnitRandom): { string }
	assert(count >= 0 and count % 1 == 0 and count <= #entries, "Invalid draw count")
	local pool = table.clone(entries)
	local selected: { string } = {}
	for _ = 1, count do
		local id = WeightedRandom.pick(pool, random)
		table.insert(selected, id)
		for index, entry in pool do
			if entry.Id == id then
				table.remove(pool, index)
				break
			end
		end
	end
	return selected
end

return table.freeze(WeightedRandom)
