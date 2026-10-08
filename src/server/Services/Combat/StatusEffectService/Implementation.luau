--!strict
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Service = require("@game/ReplicatedStorage/Shared/Contracts/Service")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Scope = require("@game/ReplicatedStorage/Shared/Util/Scope")
local Calculator = require("@game/ReplicatedStorage/Shared/Util/Combat/StatModifier")
local Types = require("./Types")
local Implementation = {}
type Entry = {
	Entity: Payloads.EntityRef,
	Source: string,
	StatSource: string,
	Definition: Types.Definition,
	ExpiresAt: number,
	Scope: Scope.Scope,
}
type Record = { Entity: Payloads.EntityRef, Entries: { [string]: Entry } }
local function key(entity: Payloads.EntityRef): string
	return string.format("%d:%d:%s", entity.RoundId, entity.Generation, entity.Id)
end

--[=[ Source replacement owns one expiry timer; late callbacks cannot remove a newer effect.
	Stun/ragdoll force a zero speed factor. Rig controls are restored after final removal.
	Definitions and scheduling are injected; this service invents no durations or tuning.
]=]
function Implementation.new(deps: Types.Dependencies): Types.Api
	local definitions: { [string]: Types.Definition } = {}
	for id, definition in deps.definitions do
		local modifiers: { Payloads.StatModifier } = {}
		for _, modifier in definition.Modifiers do
			assert(Calculator.valid(modifier), "Invalid status modifier")
			table.insert(modifiers, table.freeze(table.clone(modifier)))
		end
		definitions[id] = table.freeze({
			Modifiers = table.freeze(modifiers),
			Stun = definition.Stun,
			Ragdoll = definition.Ragdoll,
		})
	end
	local records: { [string]: Record } = {}
	local initialized, started, destroyed = false, false, false
	local sequence = 0
	local function controls(record: Record)
		local stunned, ragdolled = false, false
		for _, entry in record.Entries do
			stunned = stunned or entry.Definition.Stun == true
			ragdolled = ragdolled or entry.Definition.Ragdoll == true
		end
		if deps.movement then
			pcall(deps.movement, record.Entity, { Stunned = stunned, Ragdolled = ragdolled })
		end
	end
	local function remove(record: Record, sourceId: string): boolean
		local entry = record.Entries[sourceId]
		if not entry then
			return false
		end
		record.Entries[sourceId] = nil
		entry.Scope:destroy()
		controls(record)
		if next(record.Entries) == nil then
			records[key(record.Entity)] = nil
		end
		return true
	end
	local function clear(entity: Payloads.EntityRef): Result.Result<boolean>
		local record = records[key(entity)]
		if not record then
			return Result.success(false)
		end
		local sources = {}
		for source in record.Entries do
			table.insert(sources, source)
		end
		for _, source in sources do
			remove(record, source)
		end
		return Result.success(true)
	end
	local function clearAll(roundId: number?)
		local pending = {}
		for _, record in records do
			if roundId == nil or record.Entity.RoundId == roundId then
				table.insert(pending, record.Entity)
			end
		end
		for _, entity in pending do
			clear(entity)
		end
	end
	local function schedule(record: Record, entry: Entry)
		local cancel: (() -> ())? = nil
		local release = entry.Scope:add(function()
			if cancel then
				cancel()
			end
		end)
		cancel = deps.after(math.max(0, entry.ExpiresAt - deps.clock()), function()
			cancel = nil
			release()
			if record.Entries[entry.Source] ~= entry then
				return
			end
			if not deps.current(entry.Entity) then
				clear(entry.Entity)
			elseif deps.clock() >= entry.ExpiresAt then
				remove(record, entry.Source)
			else
				schedule(record, entry)
			end
		end)
	end
	local self: Types.Api = {
		Name = "StatusEffectService",
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
			started = false
			clearAll(nil)
		end,
		Destroy = function(_self: Service.Interface)
			started = false
			destroyed = true
			clearAll(nil)
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
		Apply = function(
			_self: Service.Interface,
			entity: Payloads.EntityRef,
			statusId: string,
			sourceId: string,
			duration: number
		): Result.Result<boolean>
			if not started then
				return Result.failure("NotReady")
			end
			if not deps.current(entity) then
				return Result.failure("StaleRound")
			end
			local definition = definitions[statusId]
			if not definition then
				return Result.failure("UnknownId")
			end
			local now = deps.clock()
			if
				#sourceId == 0
				or not Calculator.finite(duration)
				or duration <= 0
				or not Calculator.finite(now + duration)
			then
				return Result.failure("InvalidRequest")
			end
			sequence += 1
			local statSource = string.format("status:%d:%s", sequence, sourceId)
			local owner = Scope.new()
			owner:add(function()
				deps.stats:RemoveSource(entity, statSource)
			end)
			local modifiers = table.clone(definition.Modifiers)
			if definition.Stun or definition.Ragdoll then
				table.insert(
					modifiers,
					{ SourceId = statSource, Stat = "WalkSpeed", Mode = "Multiply", Value = 0 }
				)
			end
			for _, modifier in modifiers do
				local applied = deps.stats:Add(entity, {
					SourceId = statSource,
					Stat = modifier.Stat,
					Mode = modifier.Mode,
					Value = modifier.Value,
				})
				if not applied.Ok then
					owner:destroy()
					return Result.failure(applied.Code)
				end
			end
			if not deps.current(entity) then
				owner:destroy()
				return Result.failure("StaleRound")
			end
			local record = records[key(entity)]
				or { Entity = table.freeze(table.clone(entity)), Entries = {} }
			local previous = record.Entries[sourceId]
			local entry: Entry = {
				Entity = record.Entity,
				Source = sourceId,
				StatSource = statSource,
				Definition = definition,
				ExpiresAt = now + duration,
				Scope = owner,
			}
			record.Entries[sourceId] = entry
			records[key(entity)] = record
			local ok = pcall(schedule, record, entry)
			if not ok then
				record.Entries[sourceId] = previous
				owner:destroy()
				if next(record.Entries) == nil then
					records[key(entity)] = nil
				end
				return Result.failure("Unavailable")
			end
			if previous then
				previous.Scope:destroy()
			end
			controls(record)
			return Result.success(true)
		end,
		Remove = function(
			_self: Service.Interface,
			entity: Payloads.EntityRef,
			sourceId: string
		): Result.Result<boolean>
			local record = records[key(entity)]
			return Result.success(if record then remove(record, sourceId) else false)
		end,
		Clear = function(_self: Service.Interface, entity: Payloads.EntityRef): Result.Result<boolean>
			return clear(entity)
		end,
		ClearRound = function(_self: Service.Interface, roundId: number)
			clearAll(roundId)
		end,
	}
	return self
end
return table.freeze(Implementation)
