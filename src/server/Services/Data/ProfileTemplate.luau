--!strict
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Config = require("@game/ReplicatedStorage/Shared/Config/Data")
local Types = require("./ProfileTypes")
local Defaults = require("./Migrations/Defaults")
local Serializable = require("./Migrations/Serializable")
local Validate = require("./Migrations/Validate")
local ProfileTemplate = {}

--[=[ Creates an independent provisional profile, only for a confirmed new session. ]=]
function ProfileTemplate.new(): Types.Profile
	return Defaults.new()
end

--[=[ Returns a detached valid current-schema copy; malformed replacements are rejected. ]=]
function ProfileTemplate.validate(value: unknown): Result.Result<Types.Profile>
	local copy = Serializable.copy(value)
	if not Validate.profile(copy) then
		return Result.failure("InvalidRequest")
	end
	return Result.success(copy :: Types.Profile)
end

--[=[ Trusted copy helper; invalid programmer-owned state fails before persistence. ]=]
function ProfileTemplate.clone(profile: Types.Profile): Types.Profile
	local result = ProfileTemplate.validate(profile)
	assert(result.Ok, "Cannot clone an invalid profile")
	return result.Value
end

local function reconcile(target: { [string]: any }, defaults: { [string]: any })
	for key, value in defaults do
		if target[key] == nil then
			target[key] = value
		elseif type(target[key]) == "table" and type(value) == "table" then
			reconcile(target[key], value)
		end
	end
end

--[=[ Migrates unversioned/schema-0 drafts or reconciles schema 1, preserving safe extras.
	Future and malformed profiles fail; a failed load is never replaced with defaults.
	No elapsed wall clock is applied to the connected-time wheel balance.
]=]
function ProfileTemplate.migrate(value: unknown): Result.Result<Types.Profile>
	local copy = Serializable.copy(value)
	if type(copy) ~= "table" then
		return Result.failure("InvalidRequest")
	end
	local data = copy :: { [string]: any }
	local version = data.SchemaVersion
	if
		version ~= nil
		and (type(version) ~= "number" or version % 1 ~= 0 or version < 0 or version > Config.SchemaVersion)
	then
		return Result.failure("InvalidRequest")
	end
	-- Gems were deferred by the owner and have no active persistent field.
	data.Gems = nil
	if type(data.Inventory) == "table" then
		data.Inventory.Gems = nil
	end
	data.SchemaVersion = Config.SchemaVersion
	local defaults = Defaults.new() :: { [string]: any }
	-- Reconcile missing named fields only; invalid existing values still fail validation.
	reconcile(data, defaults)
	if not Validate.profile(data) then
		return Result.failure("InvalidRequest")
	end
	return Result.success(data :: Types.Profile)
end

return table.freeze(ProfileTemplate)
