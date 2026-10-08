--!strict
-- Injectable framework boundary; only the Roblox adapter requires Knit.
export type Service = { Name: string }
export type Adapter = {
	createService: (definition: Service) -> Service,
	getService: (name: string) -> Service,
	start: () -> (),
}
local Framework = {}

function Framework.new(adapter: Adapter): Adapter
	local phase = "Registered"
	local registered: { [string]: boolean } = {}
	return {
		createService = function(definition: Service): Service
			assert(phase == "Registered", "Cannot register services after framework start")
			assert(definition.Name ~= "" and not registered[definition.Name], "Duplicate service name")
			local service = adapter.createService(definition)
			registered[definition.Name] = true
			return service
		end,
		getService = function(name: string): Service
			assert(
				(phase == "Starting" or phase == "Started") and registered[name],
				"Service is not ready or registered"
			)
			return adapter.getService(name)
		end,
		start = function()
			assert(phase == "Registered", "Framework already started or failed")
			phase = "Starting"
			local outcome = table.pack(pcall(adapter.start))
			local ok, message = outcome[1], outcome[2]
			phase = if ok then "Started" else "Failed"
			if not ok then
				error(message, 0)
			end
		end,
	}
end

return table.freeze(Framework)
