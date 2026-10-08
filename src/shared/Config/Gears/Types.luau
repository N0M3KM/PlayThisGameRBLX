--!strict
export type Category = "Melee" | "Gun" | "Booster"
export type Acquisition = "Shop" | "Wheel"
export type Ability = {
	Id: string,
	InputAction: string,
	CooldownSeconds: number,
}
export type GearDefinition = {
	Id: string,
	DisplayName: string,
	AssetId: string,
	Category: Category,
	Strategy: Category,
	Acquisition: Acquisition,
	Price: number?,
	Damage: number?,
	LoadedAmmo: number?,
	ReserveAmmo: number?,
	Effects: { string }?,
	Ability: Ability?,
	WalkSpeedMultiplier: number?,
	JumpMultiplierTodo: string?,
}

return table.freeze({})
