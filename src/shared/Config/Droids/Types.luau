--!strict

export type Melee = {
	Damage: number,
	CooldownSeconds: number?,
}

export type DroidDefinition = {
	Id: string,
	DisplayName: string,
	AssetId: string,
	SpawnWeight: number,
	MaxHP: number,
	Melee: Melee,
	Abilities: { string },
	Maps: { string },
	EventOnly: boolean,
	BulletImmune: boolean,
	XPProposal: number,
	AbilityParams: { [string]: number },
	TuningTodo: { string },
}

return table.freeze({})
