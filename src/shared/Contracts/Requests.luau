--!strict
-- Draft canonical command payloads. The server supplies player identity and authoritative context.
local Payloads = require("./Payloads")
local Result = require("./Result")

export type ItemCategory = "Gear" | "Utility" | "Armour" | "Class"
export type PurchaseItem = {
	RequestId: string,
	Category: ItemCategory,
	ItemId: string,
	Quantity: number,
}
export type EquipLoadout = {
	RequestId: string,
	Category: "Gear" | "Armour" | "Class",
	ItemId: string,
	GearSlot: number?,
}
export type RoundCommand = {
	RequestId: string,
	RoundId: number,
	CharacterGeneration: number,
	GearSlot: number,
}
export type UseGear = RoundCommand & {
	AimOrigin: Payloads.Point?,
	AimDirection: Payloads.Point?,
}
export type ReloadGear = RoundCommand
export type UseAbility = RoundCommand
export type UseUtility = Payloads.UtilityIntent
export type RequestFreeSpin = { RequestId: string }
export type SpendPaidSpin = { RequestId: string }
export type SubmitPick = {
	RequestId: string,
	EntitlementId: string,
	MapId: string,
	ScenarioId: string,
}
export type OpenDialogue = { RequestId: string, NpcId: string, CharacterGeneration: number }
export type ChooseDialogue = {
	RequestId: string,
	SessionId: string,
	ChoiceId: string,
	CharacterGeneration: number,
}
export type CloseDialogue = { RequestId: string, SessionId: string }
export type DebugCommand = { RequestId: string, CommandId: string, RoundId: number? }
-- Acknowledgements carry correlation and status. State and committed rewards come from their owner.
export type CommandResult = { RequestId: string, Result: Result.Result<boolean> }

return table.freeze({ Version = 0, Frozen = false })
