--!strict
-- Technical bounds and provisional combat tuning. TODO(owner): R-18/D-26 playtests.
return table.freeze({
	MaxTrackedPlayers = 100,
	RateCapacity = 12,
	RateRefillPerSecond = 8,
	MaxRequestIds = 256,
	MaxEntitiesPerRound = 512,
	MaxFactsPerEntity = 2048,
	MaxContributorsPerEntity = 100,
	MaxRoundPlayers = 100,
	MaxActiveCasts = 512,
	MaxShotsPerRound = 10000,
	UnitTolerance = 0.001,
	MaxImpulse = 10000,
	MaxReserveAmmo = 10000,
	MaxOriginDistance = 6,
	MaxMeleeTargets = 16,
	TuningApproved = false,
	-- Missing source tuning is explicit; mechanics require injected values.
	MissingTuningDecision = "TODO(owner): gun cadence/reload/speed/range, melee cadence/geometry/knockback, balloon jump",
})
