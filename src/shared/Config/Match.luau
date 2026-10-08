--!strict
-- Primitive layout and technical budgets; economy and combat tuning remain with their owners.
return table.freeze({
	TickSeconds = 0.25,
	TeleportStaggerSeconds = 0.05,
	CharacterWaitSeconds = 5,
	LoadingWatchdogSeconds = 20,
	RecoveryRetryCount = 2,
	RecoveryDelaySeconds = 2,
	LobbyPosition = table.freeze({ X = 0, Y = 6, Z = 160 }),
	MapPosition = table.freeze({ X = 0, Y = 0, Z = -300 }),
	SpawnLift = 4,
	ZoneHeightTolerance = 8,
	MapCoordinateLimit = 100000,
	RecoveryHeight = -50,
	PreviewOnly = true, -- No profile/reward/combat claim until the domain services replace their stubs.
	DroidPreview = true, -- Studio-only real droids/melee; persistence, player gear and events remain stubbed.
})
