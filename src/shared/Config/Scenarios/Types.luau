--!strict
export type ScenarioDefinition = {
	Id: string,
	DisplayName: string,
	Weight: number,
	DroidMultiplier: number,
	RewardMultiplier: number,
	EventMinimum: number,
	EventMaximum: number,
	DisasterMinimum: number,
	DisasterMaximum: number,
	BossCount: number,
}

return table.freeze({})
