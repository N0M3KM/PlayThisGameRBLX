--!strict
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Config = require("@game/ReplicatedStorage/Shared/Config/Data")
local ProfileTypes = require("./ProfileTypes")
local ProfileTemplate = require("./ProfileTemplate")

export type Connection = { Disconnect: (Connection) -> () }
export type RawProfile = {
	Data: unknown,
	MetaData: { MetaTagsLatest: { [string]: unknown } },
	IsActive: (RawProfile) -> boolean,
	AddUserId: (RawProfile, number) -> (),
	SetMetaTag: (RawProfile, string, unknown) -> (),
	Save: (RawProfile) -> (),
	Release: (RawProfile) -> (),
	ListenToRelease: (RawProfile, () -> ()) -> Connection,
	ListenToHopReady: (RawProfile, () -> ()) -> Connection,
}
export type Store = { LoadProfileAsync: (Store, string, (number?, string?) -> string) -> RawProfile? }
export type Runtime = {
	clock: () -> number,
	wait: (number) -> (),
	spawn: (() -> ()) -> (),
	token: () -> string,
	loadTimeout: number,
	pollInterval: number,
	maxPendingLoads: number,
}
export type Session = {
	read: () -> ProfileTypes.Profile,
	replace: (ProfileTypes.Profile) -> Result.Result<boolean>,
	isActive: () -> boolean,
	onLost: (() -> ()) -> () -> (),
	saveConfirmed: (number) -> Result.Result<boolean>,
	release: (number) -> Result.Result<boolean>,
}
export type Adapter = {
	Mode: "Mock" | "Live",
	load: (number, (() -> boolean)?, number?) -> Result.Result<Session>,
	destroy: (number) -> Result.Result<boolean>,
}

local ProfileAdapter = {}
local SAVE_TAG = "PTG_SaveConfirmation"
type RawOwner = {
	isActive: () -> boolean,
	onLost: (() -> ()) -> () -> (),
	beginRelease: () -> (),
	release: (number) -> Result.Result<boolean>,
}

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

--[=[ Injectable ProfileService boundary. Deadlines use runtime.clock's monotonic
	seconds. Caller timeouts never cancel a library coroutine inside UpdateAsync;
	late successful loads are released, and their keys remain reserved meanwhile.
]=]
function ProfileAdapter.new(store: Store, runtime: Runtime, mode: "Mock" | "Live"): Adapter
	assert(
		runtime.loadTimeout > 0 and runtime.pollInterval > 0 and runtime.maxPendingLoads > 0,
		"Profile runtime limits must be positive"
	)
	local closed = false
	local pending: { [number]: boolean } = {}
	local pendingCount = 0
	local owners: { [number]: RawOwner } = {}
	local function before(deadline: number): boolean
		return finite(deadline) and runtime.clock() < deadline
	end
	local function pause(deadline: number)
		runtime.wait(math.max(0, math.min(runtime.pollInterval, deadline - runtime.clock())))
	end
	local function own(userId: number, raw: RawProfile): RawOwner
		local releaseRequested = false
		local releaseObserved = false
		local hopReady = false
		local listening = false
		local listeners: { [() -> ()]: boolean } = {}
		local connections: { Connection } = {}
		local function disconnect()
			for _, connection in connections do
				connection:Disconnect()
			end
			table.clear(connections)
			table.clear(listeners)
		end
		local function isActive(): boolean
			return listening
				and not releaseRequested
				and not releaseObserved
				and not hopReady
				and raw:IsActive()
		end
		local owner: RawOwner
		local function confirmReleased()
			hopReady = true
			if owners[userId] == owner then
				owners[userId] = nil
			end
			disconnect()
		end
		local function track(connection: Connection)
			-- A library listener can fire synchronously while being registered.
			if hopReady then
				connection:Disconnect()
			else
				table.insert(connections, connection)
			end
		end
		local function beginRelease()
			if hopReady or releaseRequested then
				return
			end
			-- Reserve before scheduling: even a yielding library call is dispatched
			-- once, while deadlines and shutdown continue to observe its ownership.
			releaseRequested = true
			runtime.spawn(function()
				pcall(function()
					raw:Release()
				end)
			end)
		end
		owner = {
			isActive = isActive,
			onLost = function(callback)
				if not isActive() then
					pcall(callback)
					return function() end
				end
				listeners[callback] = true
				return function()
					listeners[callback] = nil
				end
			end,
			beginRelease = beginRelease,
			release = function(deadline)
				beginRelease()
				while not hopReady and before(deadline) do
					pause(deadline)
				end
				return if hopReady then Result.success(true) else Result.failure("Unavailable")
			end,
		}
		-- Track every raw profile before migration or any fallible initialization.
		-- A rejected/late load has the same lock ownership as a published session.
		owners[userId] = owner
		local connected = pcall(function()
			track(raw:ListenToHopReady(confirmReleased))
			if not hopReady then
				track(raw:ListenToRelease(function()
					local external = not releaseRequested
					releaseObserved = true
					releaseRequested = true
					if external then
						for callback in listeners do
							pcall(callback)
						end
						table.clear(listeners)
					end
				end))
			end
		end)
		listening = connected
		if not connected then
			beginRelease()
		end
		return owner
	end
	local function wrap(raw: RawProfile, migrated: ProfileTypes.Profile, owner: RawOwner): Session
		local snapshot = migrated
		local saving = false
		local quarantined = false
		local sequence = 0
		local prefix = runtime.token()
		local function isActive(): boolean
			return not quarantined and owner.isActive()
		end
		return {
			read = function()
				return ProfileTemplate.clone(snapshot)
			end,
			replace = function(candidate)
				if not isActive() or saving then
					return Result.failure("WrongState")
				end
				local validated = ProfileTemplate.validate(candidate)
				if not validated.Ok then
					return Result.failure(validated.Code)
				end
				snapshot = validated.Value
				raw.Data = ProfileTemplate.clone(snapshot)
				return Result.success(true)
			end,
			isActive = isActive,
			onLost = function(callback)
				if not isActive() then
					pcall(callback)
					return function() end
				end
				return owner.onLost(callback)
			end,
			saveConfirmed = function(deadline)
				if not isActive() or saving or not before(deadline) then
					return Result.failure("NotReady")
				end
				saving = true
				sequence += 1
				local marker = `{prefix}:{sequence}`
				local ok = pcall(function()
					raw:SetMetaTag(SAVE_TAG, marker)
					raw:Save()
				end)
				while
					ok
					and isActive()
					and before(deadline)
					and raw.MetaData.MetaTagsLatest[SAVE_TAG] ~= marker
				do
					pause(deadline)
				end
				saving = false
				if ok and isActive() and raw.MetaData.MetaTagsLatest[SAVE_TAG] == marker then
					return Result.success(true)
				end
				-- The underlying write may finish later. Fence the session permanently
				-- until release, so subsequent candidates cannot race an unknown save.
				quarantined = true
				return Result.failure("Unavailable")
			end,
			release = owner.release,
		}
	end
	local adapter: Adapter = {
		Mode = mode,
		load = function(userId, cancelled, deadlineOverride)
			local deadline = deadlineOverride or (runtime.clock() + runtime.loadTimeout)
			if
				not finite(userId)
				or userId == 0
				or math.abs(userId) > Config.MaxInteger
				or (mode == "Live" and userId < 0)
				or userId % 1 ~= 0
			then
				return Result.failure("InvalidRequest")
			end
			if closed or pending[userId] or owners[userId] or pendingCount >= runtime.maxPendingLoads then
				return Result.failure("NotReady")
			end
			local function stopped(): boolean
				return closed or not before(deadline) or (cancelled ~= nil and cancelled())
			end
			if stopped() then
				return Result.failure("NotReady")
			end
			pending[userId] = true
			pendingCount += 1
			local finished = false
			local abandoned = false
			local loaded: RawProfile? = nil
			local loadedOwner: RawOwner? = nil
			runtime.spawn(function()
				local ok, profile = pcall(function()
					return store:LoadProfileAsync(`Player_{userId}`, function()
						-- Never displace an existing owner's lock, including crashed sessions.
						return "Cancel"
					end)
				end)
				if ok and profile ~= nil then
					local owner = own(userId, profile)
					if abandoned or stopped() then
						owner.beginRelease()
					else
						loaded = profile
						loadedOwner = owner
					end
				end
				pending[userId] = nil
				pendingCount -= 1
				finished = true
			end)
			while not finished and not stopped() do
				pause(deadline)
			end
			abandoned = true
			local raw = loaded
			local owner = loadedOwner
			if raw == nil or owner == nil then
				return Result.failure("Unavailable")
			end
			local migrationOk, migrated = pcall(ProfileTemplate.migrate, raw.Data)
			if not migrationOk then
				owner.beginRelease()
				return Result.failure("Unavailable")
			end
			if not migrated.Ok then
				owner.beginRelease()
				return Result.failure(migrated.Code)
			end
			if stopped() or not owner.isActive() then
				owner.beginRelease()
				return Result.failure("Unavailable")
			end
			local initialized, session = pcall(function()
				raw.Data = ProfileTemplate.clone(migrated.Value)
				raw:AddUserId(userId)
				return wrap(raw, migrated.Value, owner)
			end)
			if not initialized then
				owner.beginRelease()
				return Result.failure("Unavailable")
			end
			if not session.isActive() then
				owner.beginRelease()
				return Result.failure("Unavailable")
			end
			return Result.success(session)
		end,
		destroy = function(deadline)
			closed = true
			for _, owner in owners do
				owner.beginRelease()
			end
			while (next(owners) ~= nil or pendingCount > 0) and before(deadline) do
				pause(deadline)
			end
			return if next(owners) == nil and pendingCount == 0
				then Result.success(true)
				else Result.failure("Unavailable")
		end,
	}
	return table.freeze(adapter)
end

return table.freeze(ProfileAdapter)
