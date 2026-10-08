--!strict
local AI = require("@game/ReplicatedStorage/Shared/Config/AI")
local Domain = require("@game/ReplicatedStorage/Shared/Contracts/DomainInterfaces")
local DroidAI = require("@game/ReplicatedStorage/Shared/Contracts/DroidAI")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
export type Dependencies = {
	clock: () -> number,
	workerTemplate: Script,
	parent: Instance,
	Config: AI.Config,
}
export type Api = Domain.DroidBrainHost & {
	configureFrame: (DroidAI.Frame) -> Result.Result<boolean>,
	metrics: () -> DroidAI.Metrics,
}
return table.freeze({})
