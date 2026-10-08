--!strict
-- Deterministic storage fixture. This does not execute or prove ProfileService/DataStores.
local ProfileAdapter = require("@game/ServerScriptService/Server/Services/Data/ProfileAdapter")
local Template = require("@game/ServerScriptService/Server/Services/Data/ProfileTemplate")
local Types = require("@game/ServerScriptService/Server/Services/Data/ProfileTypes")

export type Fixture = {
	Store: ProfileAdapter.Store,
	setFailure: (boolean) -> (),
	readSaved: (string) -> Types.Profile?,
}
local MemoryProfileStore = {}

--[=[ Owns isolated copies, per-key session exclusion and explicit failure injection. ]=]
function MemoryProfileStore.new(): Fixture
	local saved: { [string]: Types.Profile } = {}
	local owners: { [string]: ProfileAdapter.RawProfile } = {}
	local failing = false
	local store: ProfileAdapter.Store = {
		LoadProfileAsync = function(_self, key, _notReleased)
			if owners[key] then
				return nil
			end
			local active, released = true, false
			local releaseListeners: { [() -> ()]: boolean } = {}
			local hopListeners: { [() -> ()]: boolean } = {}
			local tags: { [string]: unknown } = {}
			local function connect(
				listeners: { [() -> ()]: boolean },
				callback: () -> ()
			): ProfileAdapter.Connection
				listeners[callback] = true
				return {
					Disconnect = function(_connection)
						listeners[callback] = nil
					end,
				}
			end
			local raw: ProfileAdapter.RawProfile
			raw = {
				Data = Template.clone(saved[key] or Template.new()),
				MetaData = { MetaTagsLatest = {} },
				IsActive = function(_profile)
					return active
				end,
				AddUserId = function(_profile, _userId) end,
				SetMetaTag = function(_profile, tag, value)
					tags[tag] = value
				end,
				Save = function(_profile)
					assert(not failing, "Injected save failure before write")
					assert(active, "Session is inactive")
					local validated = Template.validate(raw.Data)
					assert(validated.Ok, "Invalid fixture profile")
					saved[key] = Template.clone(validated.Value)
					raw.MetaData.MetaTagsLatest = table.clone(tags)
				end,
				Release = function(_profile)
					if released then
						return
					end
					released, active = true, false
					owners[key] = nil
					-- Failure injection leaves only the last confirmed snapshot saved.
					for callback in releaseListeners do
						callback()
					end
					for callback in hopListeners do
						callback()
					end
					table.clear(releaseListeners)
					table.clear(hopListeners)
				end,
				ListenToRelease = function(_profile, callback)
					return connect(releaseListeners, callback)
				end,
				ListenToHopReady = function(_profile, callback)
					if released then
						callback()
					end
					return connect(hopListeners, callback)
				end,
			}
			owners[key] = raw
			return raw
		end,
	}
	return {
		Store = store,
		setFailure = function(value)
			failing = value
		end,
		readSaved = function(key)
			local profile = saved[key]
			return if profile then Template.clone(profile) else nil
		end,
	}
end

return table.freeze(MemoryProfileStore)
