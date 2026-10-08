--!strict
export type MapDefinition = {
	Id: string,
	DisplayName: string,
	AssetId: string,
	SpawnWeight: number,
	SpawnRate: number,
	CoinMultiplier: number,
	XpMultiplier: number,
	DroidPool: { string },
}

return table.freeze({})
