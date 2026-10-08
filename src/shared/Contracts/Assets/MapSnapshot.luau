--!strict
export type Point = { X: number, Y: number, Z: number }
export type Spawn = { Id: string, Position: Point, Anchored: boolean, HasTag: boolean }
export type Map = {
	Path: string,
	Id: string,
	IsModel: boolean,
	HasGeometry: boolean,
	PlayerSpawns: { Spawn },
	DroidSpawns: { Spawn },
	RecoveryPoint: Point?,
	RecoveryAnchored: boolean?,
	UnsafeDescendants: { string },
}
export type Policy = { MaxCoordinate: number, RecoveryHeight: number }
return table.freeze({ Version = 0, Frozen = false })
