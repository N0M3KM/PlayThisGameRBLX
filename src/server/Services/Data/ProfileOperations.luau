--!strict
local Domain = require("@game/ReplicatedStorage/Shared/Contracts/DomainInterfaces")
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Service = require("@game/ReplicatedStorage/Shared/Contracts/Service")
local ProfileTypes = require("./ProfileTypes")

export type Command = {
	TransactionId: string,
	UserId: number,
	ExpectedRevision: number,
	Reason: Payloads.EconomyReason,
	Fingerprint: string,
}
export type Mutator = (ProfileTypes.Profile) -> Result.Result<boolean>
export type Guard = () -> boolean
export type BoostSnapshot = { CoinExpiresAt: number, XpExpiresAt: number }
export type Boundary = Domain.DataService & {
	ApplyMutation: (
		Service.Interface,
		Command,
		Mutator,
		Guard?
	) -> Result.Result<Payloads.TransactionReceipt>,
	ReadBoosts: (Service.Interface, number) -> Result.Result<BoostSnapshot>,
}
export type Engine = {
	execute: (Command, Mutator, Guard?) -> Result.Result<Payloads.TransactionReceipt>,
}

--[=[ Trusted server-only callbacks must be synchronous. Never bind these to client payloads. ]=]
return table.freeze({})
