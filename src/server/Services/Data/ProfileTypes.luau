--!strict
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")

export type JsonValue = boolean | number | string | { JsonValue } | { [string]: JsonValue }
export type JsonMap = { [string]: JsonValue }
export type PickToken = { TokenId: string, MapId: string?, ScenarioId: string? }
export type Profile = {
	[string]: unknown,
	SchemaVersion: number,
	Revision: number,
	Coins: number,
	TotalXP: number,
	Stats: {
		Kills: number,
		Assists: number,
		Damage: number,
		Survives: number,
		Rounds: number,
		DonatedRobux: number,
	},
	Inventory: Payloads.Inventory,
	Loadout: { Gears: { string }, Armour: string?, Class: string? },
	Wheel: { FreeSpinRemainingSeconds: number, PendingPaidSpins: number },
	Boosts: { CoinExpiresAt: number, XpExpiresAt: number },
	PendingPickTokens: { PickToken },
	Quests: JsonMap,
	DialogueFlags: JsonMap,
	ProcessedTransactions: { [string]: { Revision: number, Fingerprint: string } },
	ProcessedReceiptIds: { [string]: boolean },
	Settings: JsonMap,
}

return table.freeze({})
