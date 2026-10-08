--!strict
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Types = require("./Types")
local Validation = {}
local MAX_INTEGER = 9007199254740991

function Validation.finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

function Validation.ref(ref: Payloads.EntityRef): boolean
	return type(ref) == "table"
		and type(ref.Id) == "string"
		and #ref.Id > 0
		and #ref.Id <= 128
		and type(ref.Generation) == "number"
		and Validation.finite(ref.Generation)
		and ref.Generation >= 1
		and ref.Generation <= MAX_INTEGER
		and ref.Generation % 1 == 0
		and type(ref.RoundId) == "number"
		and Validation.finite(ref.RoundId)
		and ref.RoundId >= 1
		and ref.RoundId <= MAX_INTEGER
		and ref.RoundId % 1 == 0
end

function Validation.key(ref: Payloads.EntityRef): string
	return `{#ref.Id}:{ref.Id}:{ref.Generation}`
end

function Validation.same(first: Payloads.EntityRef, second: Payloads.EntityRef): boolean
	return first.Id == second.Id and first.Generation == second.Generation and first.RoundId == second.RoundId
end

function Validation.entity(entity: Types.Entity, ref: Payloads.EntityRef): boolean
	return Validation.ref(entity.Ref)
		and Validation.same(entity.Ref, ref)
		and Validation.finite(entity.Hp)
		and Validation.finite(entity.MaxHp)
		and entity.Hp >= 0
		and entity.MaxHp > 0
		and entity.MaxHp <= MAX_INTEGER
		and entity.Hp <= entity.MaxHp
		and (entity.Faction == "Hostile" or entity.Faction == "Player" or entity.Faction == "Allied")
		and type(entity.IsBoss) == "boolean"
		and type(entity.BulletImmune) == "boolean"
		and (
			entity.OwnerUserId == nil
			or (
				Validation.finite(entity.OwnerUserId)
				and entity.OwnerUserId ~= 0
				and math.abs(entity.OwnerUserId) <= MAX_INTEGER
				and entity.OwnerUserId % 1 == 0
			)
		)
end

--[=[ Trusted extension points still cannot suspend damage between validation and actuation. ]=]
function Validation.sync<T>(callback: () -> T): (boolean, T?)
	local thread = coroutine.create(callback)
	local ok, value = coroutine.resume(thread)
	if not ok or coroutine.status(thread) ~= "dead" then
		pcall(coroutine.close, thread)
		return false, nil
	end
	return true, value
end

return table.freeze(Validation)
