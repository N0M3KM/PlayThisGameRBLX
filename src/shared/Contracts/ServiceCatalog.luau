--!strict
-- Every domain has a safe stub; exact request/result types remain a Phase 0 review item.
export type Entry = { Name: string, Group: string, Commands: { string } }
local entries: { Entry } = {
	{
		Name = "GameLoopService",
		Group = "Match",
		Commands = table.freeze({ "GetState", "Advance", "Abort", "ReportBossDeath" }),
	},
	{
		Name = "ScenarioDirector",
		Group = "Match",
		Commands = table.freeze({ "SelectScenario", "SelectEvents", "SelectBosses" }),
	},
	{
		Name = "MapService",
		Group = "Match",
		Commands = table.freeze({ "Load", "Validate", "GetSpawns", "GetContext", "Unload" }),
	},
	{
		Name = "VotingService",
		Group = "Match",
		Commands = table.freeze({ "Open", "Cast", "RemovePlayer", "Resolve", "Close" }),
	},
	{
		Name = "PlayerStateService",
		Group = "Match",
		Commands = table.freeze({
			"Get",
			"Transition",
			"SetAfk",
			"GetAlive",
			"EligiblePlayers",
			"IsAfk",
			"BeginRound",
			"ResetRound",
			"ReserveLobby",
			"ValidateLobbyReservation",
			"ReleaseLobby",
		}),
	},
	{ Name = "TeleportService", Group = "Match", Commands = table.freeze({ "ToMap", "ToLobby", "Cancel" }) },
	{
		Name = "DataService",
		Group = "Data",
		Commands = table.freeze({ "OpenSession", "Read", "ReadLoadout", "Transact", "Save", "Release" }),
	},
	{
		Name = "ReplicaPublisher",
		Group = "Data",
		Commands = table.freeze({ "PublishPrivate", "PublishMatch", "PublishBoard", "Remove" }),
	},
	{
		Name = "EconomyService",
		Group = "Data",
		Commands = table.freeze({
			"SettleNonBossKill",
			"SettleBossContributors",
			"SettleSurvival",
			"AwardXP",
			"QueryBalance",
		}),
	},
	{ Name = "ShopService", Group = "Data", Commands = table.freeze({ "Purchase" }) },
	{
		Name = "LoadoutService",
		Group = "Combat",
		Commands = table.freeze({
			"Equip",
			"EquipSelection",
			"SnapshotAndLock",
			"GetLocked",
			"Grant",
			"Unlock",
			"Clear",
			"ClearRound",
		}),
	},
	{
		Name = "DamageService",
		Group = "Combat",
		Commands = table.freeze({
			"BeginRound",
			"Apply",
			"GetLedger",
			"GetContributions",
			"GetRoundStats",
			"ClearRound",
		}),
	},
	{
		Name = "StatService",
		Group = "Combat",
		Commands = table.freeze({ "Add", "RemoveSource", "Resolve", "Clear", "ClearRound" }),
	},
	{
		Name = "StatusEffectService",
		Group = "Combat",
		Commands = table.freeze({ "Apply", "Remove", "Clear", "ClearRound" }),
	},
	{
		Name = "GearService",
		Group = "Combat",
		Commands = table.freeze({ "Use", "Reload", "Ability", "Clear" }),
	},
	{
		Name = "UtilityService",
		Group = "Items",
		Commands = table.freeze({ "Use", "GetRemainingUses", "Clear" }),
	},
	{ Name = "ProjectileService", Group = "Combat", Commands = table.freeze({ "Cast", "CancelRound" }) },
	{
		Name = "DroidService",
		Group = "Droids",
		Commands = table.freeze({ "StartSpawning", "Spawn", "Despawn", "Summon", "Query", "StopRound" }),
	},
	{
		Name = "DroidBrainHost",
		Group = "Droids",
		Commands = table.freeze({ "PublishSnapshot", "Schedule", "CollectDecisions", "StopRound" }),
	},
	{ Name = "EventService", Group = "Events", Commands = table.freeze({ "StartPlan", "StopAll", "Query" }) },
	{
		Name = "BossCoordinator",
		Group = "Events",
		Commands = table.freeze({ "SpawnRequired", "TrackDeath", "StopRound", "ObserveDeaths" }),
	},
	{ Name = "DestructionService", Group = "Events", Commands = table.freeze({ "Explode" }) },
	{ Name = "LeaderboardService", Group = "Lobby", Commands = table.freeze({ "Submit", "GetTop50" }) },
	{
		Name = "MonetizationService",
		Group = "Lobby",
		Commands = table.freeze({ "ProcessReceipt", "QueryPass" }),
	},
	{
		Name = "WheelService",
		Group = "Lobby",
		Commands = table.freeze({ "RequestFreeSpin", "SpendPaidSpin", "CheckpointOnlineCooldown" }),
	},
	{
		Name = "PickQueue",
		Group = "Lobby",
		Commands = table.freeze({ "SubmitSelection", "TakeNextEligible", "Restore" }),
	},
	{ Name = "DialogueService", Group = "NPC", Commands = table.freeze({ "Open", "Choose", "Close" }) },
	{ Name = "QuestService", Group = "NPC", Commands = table.freeze({ "Accept", "Progress", "Complete" }) },
	{ Name = "AdminDebugService", Group = "Debug", Commands = table.freeze({ "ExecuteAllowlisted" }) },
}
for _, entry in entries do
	table.freeze(entry)
end
return table.freeze(entries)
