--!strict
export type Definition = { Id: string }
export type Validator<T> = (definition: T) -> { string }
export type Registry<T> = {
	add: (self: Registry<T>, definition: T) -> (),
	get: (self: Registry<T>, id: string) -> T?,
	all: (self: Registry<T>) -> { T },
	seal: (self: Registry<T>) -> (),
}
local Registry = {}

--[=[ Domain registry; discovery/validation run before any consumer starts. ]=]
function Registry.new<T>(idOf: (T) -> string, validate: Validator<T>, freeze: (T) -> ()): Registry<T>
	local definitions: { [string]: T } = {}
	local sealed = false
	return {
		add = function(_self: Registry<T>, definition: T)
			assert(not sealed, "Registry is sealed")
			local id = idOf(definition)
			assert(id ~= "" and definitions[id] == nil, `Duplicate or empty definition Id: {id}`)
			local errors = validate(definition)
			assert(#errors == 0, `Invalid definition {id}: {table.concat(errors, "; ")}`)
			freeze(definition)
			definitions[id] = definition
		end,
		get = function(_self: Registry<T>, id: string): T?
			return definitions[id]
		end,
		all = function(_self: Registry<T>): { T }
			local ids: { string } = {}
			for id in definitions do
				table.insert(ids, id)
			end
			table.sort(ids)
			local result: { T } = {}
			for _, id in ids do
				table.insert(result, definitions[id])
			end
			return result
		end,
		seal = function(_self: Registry<T>)
			sealed = true
		end,
	}
end

return table.freeze(Registry)
