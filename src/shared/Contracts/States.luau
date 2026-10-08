--!strict
-- Draft enums. Contracts v1 is not frozen until the M1 gate passes.
export type RoundState =
	"Idle"
	| "Intermission"
	| "Voting"
	| "Loading"
	| "Teleport"
	| "PreRound"
	| "Active"
	| "Resolution"
	| "Results"
export type PlayerState = "Lobby" | "InRound" | "Dead" | "Spectating"
export type Outcome = "Survived" | "NoSurvivors" | "BossDefeated" | "BossTimeout" | "Aborted"
export type EventState = "Created" | "Starting" | "Running" | "Stopping" | "Stopped"
export type DroidState = "Spawning" | "Alive" | "Dead" | "Respawning" | "ReturningToPool"
export type Faction = "Hostile" | "Player" | "Allied"

return table.freeze({
	Version = 0,
	Frozen = false,
	Round = table.freeze({
		Idle = "Idle",
		Intermission = "Intermission",
		Voting = "Voting",
		Loading = "Loading",
		Teleport = "Teleport",
		PreRound = "PreRound",
		Active = "Active",
		Resolution = "Resolution",
		Results = "Results",
	}),
	Player = table.freeze({ Lobby = "Lobby", InRound = "InRound", Dead = "Dead", Spectating = "Spectating" }),
	Event = table.freeze({
		Created = "Created",
		Starting = "Starting",
		Running = "Running",
		Stopping = "Stopping",
		Stopped = "Stopped",
	}),
	Droid = table.freeze({
		Spawning = "Spawning",
		Alive = "Alive",
		Dead = "Dead",
		Respawning = "Respawning",
		ReturningToPool = "ReturningToPool",
	}),
	Faction = table.freeze({ Hostile = "Hostile", Player = "Player", Allied = "Allied" }),
	Outcome = table.freeze({
		Survived = "Survived",
		NoSurvivors = "NoSurvivors",
		BossDefeated = "BossDefeated",
		BossTimeout = "BossTimeout",
		Aborted = "Aborted",
	}),
})
