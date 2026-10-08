--!strict
export type Entry = { Level: string, Tag: string, Message: string, Time: number }
export type Logger = {
	log: (self: Logger, level: string, tag: string, message: string) -> (),
	entries: (self: Logger) -> { Entry },
}
local Logger = {}

--[=[ A bounded diagnostic buffer with injectable clock/output. ]=]
function Logger.new(capacity: number, clock: () -> number, sink: (Entry) -> ()): Logger
	assert(capacity >= 1 and capacity % 1 == 0, "Invalid log capacity")
	local buffer: { Entry } = {}
	return {
		log = function(_self: Logger, level: string, tag: string, message: string)
			local entry = table.freeze({ Level = level, Tag = tag, Message = message, Time = clock() })
			table.insert(buffer, entry)
			if #buffer > capacity then
				table.remove(buffer, 1)
			end
			sink(entry)
		end,
		entries = function(_self: Logger): { Entry }
			return table.clone(buffer)
		end,
	}
end

return table.freeze(Logger)
