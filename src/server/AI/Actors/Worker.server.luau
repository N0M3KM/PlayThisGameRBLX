--!strict
-- Disabled template. The brain host clones this under one bounded server Actor.
local Publisher = require("@game/ServerScriptService/Server/AI/SnapshotPublisher")
local Brain = require("@game/ServerScriptService/Server/AI/Brain")
local DroidAI = require("@game/ReplicatedStorage/Shared/Contracts/DroidAI")
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local actor = script:GetActor()
assert(actor, "Worker requires Actor")
local outcome = actor:WaitForChild("Outcome", 5)
assert(outcome and outcome:IsA("BindableEvent"), "Worker requires outcome channel")
local brain = Brain.new()
local known: { [string]: Payloads.EntityRef } = {}

actor:BindToMessageParallel("Decide", function(jobId: number, shared: SharedTable, ids: SharedTable)
	local began = os.clock()
	local decisions: { Payloads.BrainDecision } = {}
	local failures = 0
	local ok = pcall(function()
		local frame = (Publisher.decode(shared) :: unknown) :: DroidAI.Frame
		local present: { [string]: number } = {}
		for _, agent in frame.Agents do
			present[agent.Entity.Id] = agent.Entity.Generation
		end
		for id, entity in known do
			if entity.RoundId ~= frame.RoundId or present[id] ~= entity.Generation then
				brain.remove(entity)
				known[id] = nil
			end
		end
		for _, id in ids do
			local result = brain.decide(frame, id :: string)
			if result.Ok then
				known[id :: string] = result.Value.Entity
				table.insert(decisions, result.Value)
			else
				failures += 1
			end
		end
	end)
	if not ok then
		failures += 1
	end
	local packet = Publisher.encode(decisions, 4096)
	local elapsed = (os.clock() - began) * 1000
	-- BindableEvent and DataModel writes are performed only after switching to serial.
	task.synchronize()
	if packet.Ok then
		outcome:Fire(jobId, packet.Value, elapsed, failures, not ok)
	else
		outcome:Fire(jobId, nil, elapsed, failures + 1, true)
	end
end)
outcome:Fire("Ready")
