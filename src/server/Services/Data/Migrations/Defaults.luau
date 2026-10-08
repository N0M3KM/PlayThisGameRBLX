--!strict
local Config = require("@game/ReplicatedStorage/Shared/Config/Data")
local Types = require("../ProfileTypes")
local Defaults = {}

--[=[ Returns independent provisional starting data; no purchased content is granted. ]=]
function Defaults.new(): Types.Profile
	return {
		SchemaVersion = Config.SchemaVersion,
		Revision = 0,
		Coins = Config.DefaultCoins,
		TotalXP = Config.DefaultTotalXP,
		Stats = { Kills = 0, Assists = 0, Damage = 0, Survives = 0, Rounds = 0, DonatedRobux = 0 },
		Inventory = { Gears = {}, Utilities = {}, Armours = {}, Classes = {} },
		Loadout = { Gears = {} },
		Wheel = { FreeSpinRemainingSeconds = Config.DefaultFreeSpinRemainingSeconds, PendingPaidSpins = 0 },
		Boosts = { CoinExpiresAt = 0, XpExpiresAt = 0 },
		PendingPickTokens = {},
		Quests = {},
		DialogueFlags = {},
		ProcessedTransactions = {},
		ProcessedReceiptIds = {},
		Settings = {},
	}
end

return table.freeze(Defaults)
