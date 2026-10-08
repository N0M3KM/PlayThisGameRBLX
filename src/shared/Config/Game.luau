--!strict
-- Confirmed values are separated from owner-review proposals; nothing grants rewards yet.
return table.freeze({
	RoundDurationSeconds = 240,
	BossDeadlineSeconds = 240,
	IntermissionSeconds = 15,
	VotingSeconds = 15,
	LoadingSeconds = 10,
	PreRoundSeconds = 10,
	ResultsSeconds = 10,
	BossCelebrationSeconds = 10,
	BaseDroidCap = 50,
	DroidRespawnSeconds = 10,
	UtilityCap = 100,
	GearSlots = 3,
	FreeSpinCooldownSeconds = 900,
	BossHpMultiplier = 50,
	RewardPolicy = table.freeze({ NonBoss = "KillerOnly", Boss = "ProportionalAllContributors" }),
	MultiplierCombineMode = "SumBonus",
	Features = table.freeze({ Gems = false, LobbyInteractables = false, AdditionalEvents = false }),
	Proposals = table.freeze({
		Approved = false,
		XpPerLevel = 100, -- D-21: requires pacing tests.
		OrdinaryXpPerHp = 0.2,
		BossXP = 100,
		BossScaleMultiplier = 2,
		BaseWalkSpeed = 16,
		WalkSpeedHardCap = 32,
		SpeedBoostCombineMode = "Strongest",
	}),
	Foundation = table.freeze({
		StudioOnly = true,
		AutomaticLoop = false,
		DrainSeconds = 0,
		LogCapacity = 100,
		ReadinessTimeoutSeconds = 10,
	}),
})
