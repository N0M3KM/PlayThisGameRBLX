--!strict
-- Foundation cleanup boundary; a later approved Trove adapter can implement the same API.
export type Cleanup = () -> ()
export type Scope = {
	add: (self: Scope, cleanup: Cleanup) -> Cleanup,
	child: (self: Scope) -> Scope,
	destroy: (self: Scope) -> { string },
	count: (self: Scope) -> number,
	isDestroyed: (self: Scope) -> boolean,
}

local Scope = {}

--[=[ Owns cleanup callbacks. Cleanup is LIFO, idempotent and failure-isolated. ]=]
function Scope.new(): Scope
	local entries: { Cleanup } = {}
	local destroyed = false
	local self: Scope

	local function add(_self: Scope, cleanup: Cleanup): Cleanup
		assert(not destroyed, "Cannot add a resource to a destroyed scope")
		local active = true
		local release: Cleanup
		release = function()
			if not active then
				return
			end
			active = false
			local index = table.find(entries, release)
			if index then
				table.remove(entries, index)
			end
			cleanup()
		end
		table.insert(entries, release)
		return release
	end

	local function destroy(_self: Scope): { string }
		if destroyed then
			return {}
		end
		destroyed = true
		local errors: { string } = {}
		while #entries > 0 do
			local outcome = table.pack(pcall(entries[#entries]))
			local ok, message = outcome[1], outcome[2]
			if not ok then
				table.insert(errors, tostring(message))
			end
		end
		table.clear(entries)
		return errors
	end

	self = {
		add = add,
		destroy = destroy,
		child = function(parent: Scope): Scope
			local child = Scope.new()
			local release = parent:add(function()
				local errors = child:destroy()
				if #errors > 0 then
					error(table.concat(errors, "; "), 0)
				end
			end)
			child:add(function()
				release()
			end)
			return child
		end,
		count = function(_self: Scope): number
			return #entries
		end,
		isDestroyed = function(_self: Scope): boolean
			return destroyed
		end,
	}
	return self
end

return table.freeze(Scope)
