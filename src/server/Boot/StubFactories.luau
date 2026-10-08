--!strict
-- Explicit foundation mapping, statically resolved by Rojo/Luau LSP.
local ServiceStub = require(script.Parent.Parent.Infrastructure.ServiceStub)
local Services = script.Parent.Parent.Services
local factories: { [string]: () -> ServiceStub.Stub } = {
	GameLoopService = require(Services.Match.GameLoopService.Stub),
	ScenarioDirector = require(Services.Match.ScenarioDirector.Stub),
	MapService = require(Services.Match.MapService.Stub),
	VotingService = require(Services.Match.VotingService.Stub),
	PlayerStateService = require(Services.Match.PlayerStateService.Stub),
	TeleportService = require(Services.Match.TeleportService.Stub),
	DataService = require(Services.Data.DataService.Stub),
	ReplicaPublisher = require(Services.Data.ReplicaPublisher.Stub),
	EconomyService = require(Services.Data.EconomyService.Stub),
	ShopService = require(Services.Data.ShopService.Stub),
	LoadoutService = require(Services.Combat.LoadoutService.Stub),
	DamageService = require(Services.Combat.DamageService.Stub),
	StatService = require(Services.Combat.StatService.Stub),
	StatusEffectService = require(Services.Combat.StatusEffectService.Stub),
	GearService = require(Services.Combat.GearService.Stub),
	UtilityService = require(Services.Items.UtilityService.Stub),
	ProjectileService = require(Services.Combat.ProjectileService.Stub),
	DroidService = require(Services.Droids.DroidService.Stub),
	DroidBrainHost = require(Services.Droids.DroidBrainHost.Stub),
	EventService = require(Services.Events.EventService.Stub),
	BossCoordinator = require(Services.Events.BossCoordinator.Stub),
	DestructionService = require(Services.Events.DestructionService.Stub),
	LeaderboardService = require(Services.Lobby.LeaderboardService.Stub),
	MonetizationService = require(Services.Lobby.MonetizationService.Stub),
	WheelService = require(Services.Lobby.WheelService.Stub),
	PickQueue = require(Services.Lobby.PickQueue.Stub),
	DialogueService = require(Services.NPC.DialogueService.Stub),
	QuestService = require(Services.NPC.QuestService.Stub),
	AdminDebugService = require(Services.Debug.AdminDebugService.Stub),
}
return table.freeze(factories)
