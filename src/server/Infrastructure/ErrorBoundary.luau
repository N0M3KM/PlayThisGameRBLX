--!strict
export type Reporter = (tag: string, message: string) -> ()
local ErrorBoundary = {}

--[=[ Runs a scoped operation and reports errors without hiding success/failure. ]=]
function ErrorBoundary.run(tag: string, callback: () -> (), report: Reporter): boolean
	local outcome = table.pack(xpcall(callback, debug.traceback))
	local ok, message = outcome[1], outcome[2]
	if not ok then
		report(tag, tostring(message))
	end
	return ok
end

return table.freeze(ErrorBoundary)
