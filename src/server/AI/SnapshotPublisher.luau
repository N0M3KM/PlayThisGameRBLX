--!strict
local AI = require("@game/ReplicatedStorage/Shared/Config/AI")
local DroidAI = require("@game/ReplicatedStorage/Shared/Contracts/DroidAI")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Publisher = {}
type Data = { [string | number]: unknown }
local readMetatable = (getmetatable :: unknown) :: (unknown) -> unknown

local function finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

--[=[ Only detached finite scalar trees cross Actor boundaries; no Instances or callbacks. ]=]
function Publisher.encode(value: unknown, maxNodes: number): Result.Result<SharedTable>
	local active: { [Data]: boolean } = {}
	local count = 0
	local function visit(current: unknown, depth: number): SharedTable
		assert(type(current) == "table" and depth <= 12, "Invalid snapshot tree")
		local data = current :: Data
		assert(readMetatable(data) == nil and not active[data], "Cyclic snapshot")
		active[data] = true
		local output = SharedTable.new()
		for k, v in data do
			count += 1
			assert(count <= maxNodes, "Snapshot capacity")
			assert(
				type(k) == "string" or (type(k) == "number" and finite(k) and k > 0 and k % 1 == 0),
				"Invalid key"
			)
			if type(v) == "table" then
				output[k] = visit(v, depth + 1)
			elseif type(v) == "number" then
				assert(finite(v), "Nonfinite snapshot")
				output[k] = v
			else
				assert(type(v) == "string" or type(v) == "boolean", "Invalid snapshot scalar")
				output[k] = v
			end
		end
		active[data] = nil
		return SharedTable.cloneAndFreeze(output, false)
	end
	local ok, encoded = pcall(visit, value, 0)
	return if ok then Result.success(encoded :: SharedTable) else Result.failure("InvalidRequest")
end

--[=[ Worker-local frozen copies permit the pure brain to consume its ordinary table contract. ]=]
function Publisher.decode(value: SharedTable): Data
	local function visit(current: SharedTable): Data
		local output: Data = {}
		for k, v in current do
			output[k] = if typeof(v) == "SharedTable" then visit(v :: SharedTable) else v
		end
		return table.freeze(output)
	end
	return visit(value)
end

function Publisher.publish(frame: DroidAI.Frame, config: AI.Config): Result.Result<SharedTable>
	if
		frame.Version ~= 1
		or not finite(frame.Now)
		or frame.Now < 0
		or frame.RoundId < 1
		or frame.RoundId % 1 ~= 0
		or frame.Sequence < 1
		or frame.Sequence % 1 ~= 0
		or #frame.Agents > config.MaxAgents
		or #frame.Targets > config.MaxTargets
	then
		return Result.failure("InvalidRequest")
	end
	local ids: { [string]: boolean } = {}
	local pairsCount = 0
	for _, agent in frame.Agents do
		if
			ids[agent.Entity.Id]
			or agent.Entity.RoundId ~= frame.RoundId
			or agent.Entity.Generation < 1
			or agent.Entity.Generation % 1 ~= 0
			or #agent.Entity.Id == 0
			or #agent.Entity.Id > 128
		then
			return Result.failure("InvalidRequest")
		end
		ids[agent.Entity.Id] = true
		if #agent.Abilities > config.MaxAbilitiesPerAgent then
			return Result.failure("LimitReached")
		end
		for _ in agent.Visible do
			pairsCount += 1
		end
		if pairsCount > config.MaxPairs then
			return Result.failure("LimitReached")
		end
	end
	local maxNodes = config.MaxAgents * (32 + config.MaxAbilitiesPerAgent * 16)
		+ config.MaxTargets * 32
		+ config.MaxPairs * 2
		+ 128
	return Publisher.encode(frame, maxNodes)
end
return table.freeze(Publisher)
