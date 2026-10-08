--!strict
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Service = require("@game/ReplicatedStorage/Shared/Contracts/Service")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Calculator = require("@game/ReplicatedStorage/Shared/Util/Combat/StatModifier")
local Types = require("./Types")
local Implementation = {}
type Record = { Entity: Payloads.EntityRef, Modifiers: { Payloads.StatModifier } }

function Implementation.key(entity: Payloads.EntityRef): string
	return string.format("%d:%d:%s", entity.RoundId, entity.Generation, entity.Id)
end

--[=[ Stores detached source layers against exact entity generations. ]=]
function Implementation.new(deps: Types.Dependencies): Types.Api
	assert(Calculator.finite(deps.Policy.WalkSpeedCap) and deps.Policy.WalkSpeedCap >= 0, "Invalid speed cap")
	local policy = table.freeze(table.clone(deps.Policy))
	local records: { [string]: Record } = {}
	local initialized, started, destroyed = false, false, false
	local function notify(entity: Payloads.EntityRef)
		if deps.changed then
			pcall(deps.changed, entity)
		end
	end
	local function clear(entity: Payloads.EntityRef): Result.Result<boolean>
		local key = Implementation.key(entity)
		local had = records[key] ~= nil
		records[key] = nil
		if had then
			notify(entity)
		end
		return Result.success(had)
	end
	local function clearAll()
		local previous = records
		records = {}
		for _, record in previous do
			notify(record.Entity)
		end
	end
	local self: Types.Api = {
		Name = "StatService",
		IsStub = false,
		Init = function(_self: Service.Interface)
			if not destroyed then
				initialized = true
			end
		end,
		Start = function(_self: Service.Interface)
			if initialized and not destroyed then
				started = true
			end
		end,
		Stop = function(_self: Service.Interface)
			clearAll()
			started = false
		end,
		Destroy = function(_self: Service.Interface)
			clearAll()
			started = false
			destroyed = true
		end,
		IsStarted = function(_self: Service.Interface): boolean
			return started
		end,
		Call = function(
			_self: Service.Interface,
			_command: string,
			_arguments: Service.Arguments?
		): Service.StubResult
			return { Ok = false, Code = "NotReady" }
		end,
		Add = function(
			_self: Service.Interface,
			entity: Payloads.EntityRef,
			modifier: Payloads.StatModifier
		): Result.Result<boolean>
			if not started then
				return Result.failure("NotReady")
			end
			if not deps.current(entity) then
				return Result.failure("StaleRound")
			end
			if not Calculator.valid(modifier) then
				return Result.failure("InvalidRequest")
			end
			local base = deps.base(entity)
			if not base.Ok then
				return Result.failure(base.Code)
			end
			if base.Value[modifier.Stat] == nil then
				return Result.failure("UnknownId")
			end
			local key = Implementation.key(entity)
			local record: Record = records[key]
				or { Entity = table.freeze(table.clone(entity)), Modifiers = {} }
			local candidate = table.clone(record.Modifiers)
			for index = #candidate, 1, -1 do
				local existing = candidate[index]
				if
					existing.SourceId == modifier.SourceId
					and existing.Stat == modifier.Stat
					and existing.Mode == modifier.Mode
				then
					table.remove(candidate, index)
				end
			end
			table.insert(candidate, table.freeze(table.clone(modifier)))
			local resolved = Calculator.resolve(base.Value, candidate, policy)
			if not resolved.Ok then
				return Result.failure(resolved.Code)
			end
			if not deps.current(entity) then
				return Result.failure("StaleRound")
			end
			record.Modifiers = candidate
			records[key] = record
			notify(entity)
			return Result.success(true)
		end,
		RemoveSource = function(
			_self: Service.Interface,
			entity: Payloads.EntityRef,
			sourceId: string
		): Result.Result<boolean>
			local record = records[Implementation.key(entity)]
			local removed = false
			if record then
				for index = #record.Modifiers, 1, -1 do
					if record.Modifiers[index].SourceId == sourceId then
						table.remove(record.Modifiers, index)
						removed = true
					end
				end
				if #record.Modifiers == 0 then
					records[Implementation.key(entity)] = nil
				end
			end
			if removed then
				notify(entity)
			end
			return Result.success(removed)
		end,
		Resolve = function(
			_self: Service.Interface,
			entity: Payloads.EntityRef
		): Result.Result<Calculator.Stats>
			if not started then
				return Result.failure("NotReady")
			end
			if not deps.current(entity) then
				clear(entity)
				return Result.failure("StaleRound")
			end
			local base = deps.base(entity)
			if not base.Ok then
				return Result.failure(base.Code)
			end
			if not deps.current(entity) then
				return Result.failure("StaleRound")
			end
			local record = records[Implementation.key(entity)]
			return Calculator.resolve(base.Value, if record then record.Modifiers else {}, policy)
		end,
		Clear = function(_self: Service.Interface, entity: Payloads.EntityRef): Result.Result<boolean>
			return clear(entity)
		end,
		ClearRound = function(_self: Service.Interface, roundId: number)
			local pending = {}
			for _, record in records do
				if record.Entity.RoundId == roundId then
					table.insert(pending, record.Entity)
				end
			end
			for _, entity in pending do
				clear(entity)
			end
		end,
	}
	return self
end
return table.freeze(Implementation)
