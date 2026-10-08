--!strict
local Domain = require("@game/ReplicatedStorage/Shared/Contracts/DomainInterfaces")
local Service = require("@game/ReplicatedStorage/Shared/Contracts/Service")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local SelectionModule = require("./Selection")
export type Selection = SelectionModule.Value
export type Definition = SelectionModule.Definition
export type Category = SelectionModule.Category
export type Dependencies = {
	data: Domain.DataService,
	players: Domain.PlayerStateService,
	selection: {
		read: (number) -> Result.Result<Selection>,
		write: (number, Selection, string, () -> boolean) -> Result.Result<boolean>,
	},
	catalog: (Category, string) -> Result.Result<Definition>,
	player: (number) -> Player?,
	Templates: Instance,
	requestId: () -> string,
	onCharacterGranted: ((number, number, number) -> Result.Result<boolean>)?,
	onGranted: ((number, number, number, number, Tool) -> Result.Result<boolean>)?,
	onClear: ((number) -> ())?,
}
export type Api = Domain.LoadoutService & {
	ValidateTool: (Service.Interface, number, number, number, number) -> Result.Result<Tool>,
}
return table.freeze({})
