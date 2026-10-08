--!strict
local Sync = {}

--[=[ Trusted ports must finish synchronously. Close a yielding callback before it can resume stale work. ]=]
function Sync.call<T>(callback: () -> T): T
	local thread = coroutine.create(callback)
	local ok, value = coroutine.resume(thread)
	if coroutine.status(thread) ~= "dead" then
		coroutine.close(thread)
		error("Droid callback yielded", 0)
	end
	if not ok then
		error("Droid callback failed", 0)
	end
	return (value :: unknown) :: T
end

function Sync.run(callback: () -> ())
	Sync.call(function()
		callback()
		return true
	end)
end

return table.freeze(Sync)
