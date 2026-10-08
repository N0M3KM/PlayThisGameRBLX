--!strict
-- The only framework boundary aware of Knit; callers inject the installed package.
export type Service = { Name: string }
export type StartPromise = { await: (self: StartPromise) -> (boolean, unknown) }
export type KnitApi = {
	CreateService: (Service) -> Service,
	GetService: (string) -> Service,
	Start: () -> StartPromise,
}
local KnitAdapter = {}
function KnitAdapter.new(knit: KnitApi)
	return {
		createService = function(definition: Service): Service
			return knit.CreateService(definition)
		end,
		getService = function(name: string): Service
			return knit.GetService(name)
		end,
		start = function()
			local ok, message = knit.Start():await()
			assert(ok, tostring(message))
		end,
	}
end
return table.freeze(KnitAdapter)
