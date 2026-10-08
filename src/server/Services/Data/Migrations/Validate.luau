--!strict
local Config = require("@game/ReplicatedStorage/Shared/Config/Data")
local Validation = require("@game/ReplicatedStorage/Shared/Registry/Validation")
local Validate = {}
type Record = { [string]: any }

local function record(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	for key in value :: { [unknown]: unknown } do
		if type(key) ~= "string" then
			return false
		end
	end
	return true
end

local function integer(value: unknown): boolean
	return Validation.integer(value, 0, Config.MaxInteger)
end

local function nonnegative(value: unknown): boolean
	return type(value) == "number" and Validation.finite(value) and value >= 0 and value <= Config.MaxInteger
end

local function token(value: unknown): boolean
	return type(value) == "string" and #value > 0 and #value <= Config.MaxStringLength
end

local function array(value: unknown, limit: number, predicate: (unknown) -> boolean): boolean
	if type(value) ~= "table" then
		return false
	end
	local count, maximum = 0, 0
	for index, item in value :: { [unknown]: unknown } do
		count += 1
		if not Validation.integer(index, 1, limit) or not predicate(item) then
			return false
		end
		maximum = math.max(maximum, index :: number)
	end
	return maximum == count and count <= limit
end

local function ids(value: unknown, limit: number): boolean
	local seen: { [string]: boolean } = {}
	return array(value, limit, function(item: unknown): boolean
		if not Validation.id(item) or seen[item :: string] then
			return false
		end
		seen[item :: string] = true
		return true
	end)
end

local function inventory(value: unknown): boolean
	if not record(value) then
		return false
	end
	local data = value :: Record
	for _, name in { "Gears", "Armours", "Classes" } do
		if not ids(data[name], Config.MaxCollectionEntries) then
			return false
		end
	end
	if not record(data.Utilities) then
		return false
	end
	for id, quantity in data.Utilities do
		if not Validation.id(id) or not Validation.integer(quantity, 0, Config.UtilityCap) then
			return false
		end
	end
	return true
end

local function loadout(value: unknown, owned: Record): boolean
	if not record(value) then
		return false
	end
	local data = value :: Record
	if not ids(data.Gears, Config.GearSlots) then
		return false
	end
	for _, id in data.Gears do
		if table.find(owned.Gears, id) == nil then
			return false
		end
	end
	for _, pair in { { "Armour", "Armours" }, { "Class", "Classes" } } do
		local id = data[pair[1]]
		if id ~= nil and (not Validation.id(id) or table.find(owned[pair[2]], id) == nil) then
			return false
		end
	end
	return true
end

local function namedNumbers(value: unknown, names: { string }, predicate: (unknown) -> boolean): boolean
	if not record(value) then
		return false
	end
	local data = value :: Record
	for _, name in names do
		if not predicate(data[name]) then
			return false
		end
	end
	return true
end

local function journals(data: Record): boolean
	if not record(data.ProcessedTransactions) or not record(data.ProcessedReceiptIds) then
		return false
	end
	for id, entry in data.ProcessedTransactions do
		if not token(id) or not record(entry) then
			return false
		end
		if not integer(entry.Revision) or entry.Revision > data.Revision or not token(entry.Fingerprint) then
			return false
		end
	end
	for id, processed in data.ProcessedReceiptIds do
		if not token(id) or type(processed) ~= "boolean" then
			return false
		end
	end
	return true
end

local function pickTokens(value: unknown): boolean
	local seen: { [string]: boolean } = {}
	return array(value, Config.MaxCollectionEntries, function(item: unknown): boolean
		if not record(item) then
			return false
		end
		local entry = item :: Record
		if not token(entry.TokenId) or seen[entry.TokenId] then
			return false
		end
		seen[entry.TokenId] = true
		return (entry.MapId == nil or Validation.id(entry.MapId))
			and (entry.ScenarioId == nil or Validation.id(entry.ScenarioId))
	end)
end

--[=[ Validates an already serialization-checked copy without mutating or reconciling it. ]=]
function Validate.profile(value: unknown): boolean
	if not record(value) then
		return false
	end
	local data = value :: Record
	if data.SchemaVersion ~= Config.SchemaVersion or data.Gems ~= nil then
		return false
	end
	if not integer(data.Revision) or not nonnegative(data.Coins) or not nonnegative(data.TotalXP) then
		return false
	end
	if
		not namedNumbers(data.Stats, { "Kills", "Assists", "Survives", "Rounds", "DonatedRobux" }, integer)
	then
		return false
	end
	if not nonnegative(data.Stats.Damage) or not inventory(data.Inventory) then
		return false
	end
	if data.Inventory.Gems ~= nil or not loadout(data.Loadout, data.Inventory) then
		return false
	end
	if not namedNumbers(data.Wheel, { "FreeSpinRemainingSeconds", "PendingPaidSpins" }, nonnegative) then
		return false
	end
	if
		not integer(data.Wheel.PendingPaidSpins)
		or data.Wheel.FreeSpinRemainingSeconds > Config.DefaultFreeSpinRemainingSeconds
	then
		return false
	end
	if not namedNumbers(data.Boosts, { "CoinExpiresAt", "XpExpiresAt" }, nonnegative) then
		return false
	end
	for _, name in { "Quests", "DialogueFlags", "Settings" } do
		if not record(data[name]) then
			return false
		end
	end
	return pickTokens(data.PendingPickTokens) and journals(data)
end

return table.freeze(Validate)
