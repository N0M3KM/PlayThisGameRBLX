--!strict
local HttpService = game:GetService("HttpService")
local ProfileAdapter = require("../../Services/Data/ProfileAdapter")
local ProfileTemplate = require("../../Services/Data/ProfileTemplate")
local Config = require("@game/ReplicatedStorage/Shared/Config/Data")

export type ProfileServiceApi = {
	GetProfileStore: (string, unknown) -> ProfileAdapter.Store & { Mock: ProfileAdapter.Store },
}

local ProfileServiceAdapter = {}

local function runtime(): ProfileAdapter.Runtime
	return {
		clock = os.clock,
		wait = function(seconds)
			task.wait(seconds)
		end,
		spawn = function(callback)
			task.spawn(callback)
		end,
		token = function()
			return HttpService:GenerateGUID(false)
		end,
		loadTimeout = Config.ProfileLoadTimeoutSeconds,
		pollInterval = Config.ProfilePollIntervalSeconds,
		maxPendingLoads = Config.MaxPendingProfileLoads,
	}
end

--[=[ Uses the approved package's isolated Mock store; player profiles never touch
	live storage. Inject an already initialized API: requiring this installed package
	itself performs a Studio live-write capability probe, even when Mock is selected.
	This module deliberately does not require ProfileService or trigger that probe.
]=]
function ProfileServiceAdapter.createMock(api: ProfileServiceApi): ProfileAdapter.Adapter
	local store = api.GetProfileStore(Config.ProfileStoreName, ProfileTemplate.new())
	return ProfileAdapter.new(store.Mock, runtime(), "Mock")
end

--[=[ Explicit development-only live factory. Never called by default boot; the
	store name cannot be supplied by callers or pointed at an owner's production data.
]=]
function ProfileServiceAdapter.createLive(api: ProfileServiceApi): ProfileAdapter.Adapter
	assert(
		Config.ProfileStoreName == "PTG_Development_v1",
		"Live adapter requires isolated development storage"
	)
	local store = api.GetProfileStore(Config.ProfileStoreName, ProfileTemplate.new())
	return ProfileAdapter.new(store, runtime(), "Live")
end

return table.freeze(ProfileServiceAdapter)
