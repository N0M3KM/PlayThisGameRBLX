--!strict
local Domain = require("@game/ReplicatedStorage/Shared/Contracts/DomainInterfaces")
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Scope = require("@game/ReplicatedStorage/Shared/Util/Scope")
local Types = require("./LoadoutService/Types")
local ToolGrantGuard = {}
export type Dependencies = {
	player: (number) -> Player?,
	players: Domain.PlayerStateService,
	Templates: Instance,
	catalog: (Types.Category, string) -> Result.Result<Types.Definition>,
	onCharacterGranted: ((number, number, number) -> Result.Result<boolean>)?,
	onGranted: ((number, number, number, number, Tool) -> Result.Result<boolean>)?,
	onClear: ((number) -> ())?,
}
export type Api = {
	grant: (Payloads.LoadoutSnapshot, number) -> Result.Result<boolean>,
	validate: (number, number, number, number) -> Result.Result<Tool>,
	clear: (number) -> (),
	destroy: () -> (),
}
type Record = {
	Snapshot: Payloads.LoadoutSnapshot,
	Generation: number,
	Character: Model,
	Backpack: Backpack,
	Tools: { Tool },
	Scope: Scope.Scope,
}
local OWNER_ATTRIBUTE = "PTGCombatOwned"
local function synchronous<T>(callback: () -> T): Result.Result<T>
	local thread = coroutine.create(callback)
	local ok, value = coroutine.resume(thread)
	if coroutine.status(thread) ~= "dead" then
		pcall(coroutine.close, thread)
		return Result.failure("Unavailable")
	end
	return if ok then Result.success(value) else Result.failure("Unavailable")
end

--[=[ C-owned Tool identity is private server state; attributes alone never authorize usage. ]=]
function ToolGrantGuard.new(deps: Dependencies): Api
	local records: { [number]: Record } = {}
	local destroyed = false
	local function clear(userId: number)
		local record = records[userId]
		records[userId] = nil
		if record then
			record.Scope:destroy()
			if deps.onClear then
				synchronous(function()
					(deps.onClear :: (number) -> ())(userId)
					return true
				end)
			end
		end
	end
	local function live(userId: number, record: Record): boolean
		local player = deps.player(userId)
		local state = deps.players:Get(userId)
		local humanoid = record.Character:FindFirstChildOfClass("Humanoid")
		return player ~= nil
			and player.Character == record.Character
			and state.Ok
			and state.Value.State == "InRound"
			and state.Value.RoundId == record.Snapshot.RoundId
			and state.Value.CharacterGeneration == record.Generation
			and humanoid ~= nil
			and humanoid.Health > 0
	end
	local function validate(
		userId: number,
		roundId: number,
		generation: number,
		slot: number,
		equipped: boolean
	): Result.Result<Tool>
		local record = records[userId]
		if
			not record
			or record.Snapshot.RoundId ~= roundId
			or record.Generation ~= generation
			or not live(userId, record)
		then
			return Result.failure("WrongState")
		end
		local tool = record.Tools[slot]
		if equipped and tool and tool.Parent ~= record.Character then
			return Result.failure("WrongState")
		end
		if not tool or (tool.Parent ~= record.Backpack and tool.Parent ~= record.Character) then
			return Result.failure("NotOwned")
		end
		if
			tool:GetAttribute("UserId") ~= userId
			or tool:GetAttribute("RoundId") ~= roundId
			or tool:GetAttribute("CharacterGeneration") ~= generation
			or tool:GetAttribute("GearSlot") ~= slot
			or tool:GetAttribute("DefinitionId") ~= record.Snapshot.GearIds[slot]
			or tool:GetAttribute(OWNER_ATTRIBUTE) ~= true
		then
			return Result.failure("NotOwned")
		end
		return Result.success(tool)
	end
	return table.freeze({
		validate = function(
			userId: number,
			roundId: number,
			generation: number,
			slot: number
		): Result.Result<Tool>
			return validate(userId, roundId, generation, slot, true)
		end,
		clear = clear,
		grant = function(snapshot: Payloads.LoadoutSnapshot, generation: number): Result.Result<boolean>
			if destroyed then
				return Result.failure("NotReady")
			end
			local userId = snapshot.UserId
			local existing = records[userId]
			if
				existing
				and existing.Snapshot.RoundId == snapshot.RoundId
				and existing.Generation == generation
				and live(userId, existing)
			then
				for slot in existing.Tools do
					if not validate(userId, snapshot.RoundId, generation, slot, false).Ok then
						return Result.failure("NotOwned")
					end
				end
				return Result.success(true)
			end
			clear(userId)
			local player = deps.player(userId)
			local character = if player then player.Character else nil
			local backpack = if player then player:FindFirstChildOfClass("Backpack") else nil
			if not player or not character or not backpack then
				return Result.failure("NotReady")
			end
			local owner = Scope.new()
			local record: Record = {
				Snapshot = snapshot,
				Generation = generation,
				Character = character,
				Backpack = backpack,
				Tools = {},
				Scope = owner,
			}
			if not live(userId, record) then
				owner:destroy()
				return Result.failure("WrongState")
			end
			for slot, id in snapshot.GearIds do
				local catalogOk, definition = pcall(deps.catalog, "Gear" :: Types.Category, id)
				if not catalogOk then
					owner:destroy()
					return Result.failure("Unavailable")
				end
				local template = if definition.Ok and definition.Value.AssetId
					then deps.Templates:FindFirstChild(definition.Value.AssetId)
					else nil
				if not template or not template:IsA("Tool") then
					owner:destroy()
					return Result.failure("UnknownId")
				end
				local cloneOk, tool = pcall(template.Clone, template)
				if not cloneOk or not tool or not tool:IsA("Tool") then
					owner:destroy()
					return Result.failure("Unavailable")
				end
				owner:add(function()
					tool:Destroy()
				end)
				for _, child in tool:GetDescendants() do
					if child:IsA("Script") or child:IsA("LocalScript") then
						child:Destroy()
					end
				end
				tool.CanBeDropped = false
				tool:SetAttribute(OWNER_ATTRIBUTE, true)
				tool:SetAttribute("UserId", userId)
				tool:SetAttribute("RoundId", snapshot.RoundId)
				tool:SetAttribute("CharacterGeneration", generation)
				tool:SetAttribute("GearSlot", slot)
				tool:SetAttribute("DefinitionId", id)
				record.Tools[slot] = tool
			end
			if not live(userId, record) then
				owner:destroy()
				return Result.failure("StaleRound")
			end
			records[userId] = record
			local function inspect(child: Instance)
				if not child:IsA("Tool") or child:GetAttribute(OWNER_ATTRIBUTE) ~= true then
					return
				end
				local slot = table.find(record.Tools, child)
				if not slot or not live(userId, record) then
					child:Destroy()
				end
			end
			local containers: { Instance } = { backpack, character }
			for _, container in containers do
				local connection = container.ChildAdded:Connect(inspect)
				owner:add(function()
					connection:Disconnect()
				end)
				for _, child in container:GetChildren() do
					inspect(child)
				end
			end
			local removing = player.CharacterRemoving:Connect(function(removed)
				if removed == character then
					clear(userId)
				end
			end)
			owner:add(function()
				removing:Disconnect()
			end)
			local left = player.AncestryChanged:Connect(function()
				if not player.Parent then
					clear(userId)
				end
			end)
			owner:add(function()
				left:Disconnect()
			end)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local died = humanoid.Died:Connect(function()
					clear(userId)
				end)
				owner:add(function()
					died:Disconnect()
				end)
			end
			for _, tool in record.Tools do
				tool.Parent = backpack
			end
			if deps.onCharacterGranted then
				local outcome = synchronous(function(): Result.Result<boolean>
					return (deps.onCharacterGranted :: (number, number, number) -> Result.Result<boolean>)(
						userId,
						snapshot.RoundId,
						generation
					)
				end)
				if
					not outcome.Ok
					or not outcome.Value.Ok
					or not outcome.Value.Value
					or records[userId] ~= record
					or not live(userId, record)
				then
					if records[userId] == record then
						clear(userId)
					else
						owner:destroy()
					end
					return Result.failure("Unavailable")
				end
			end
			if deps.onGranted then
				for slot, tool in record.Tools do
					local outcome = synchronous(function(): Result.Result<boolean>
						return (
							deps.onGranted :: (number, number, number, number, Tool) -> Result.Result<boolean>
						)(userId, snapshot.RoundId, generation, slot, tool)
					end)
					if
						not outcome.Ok
						or not outcome.Value.Ok
						or not outcome.Value.Value
						or records[userId] ~= record
						or not live(userId, record)
					then
						if records[userId] == record then
							clear(userId)
						else
							owner:destroy()
						end
						return Result.failure("Unavailable")
					end
				end
			end
			if records[userId] ~= record or not live(userId, record) then
				if records[userId] == record then
					clear(userId)
				else
					owner:destroy()
				end
				return Result.failure("StaleRound")
			end
			return Result.success(true)
		end,
		destroy = function()
			destroyed = true
			local ids = {}
			for userId in records do
				table.insert(ids, userId)
			end
			for _, userId in ids do
				clear(userId)
			end
		end,
	})
end
return table.freeze(ToolGrantGuard)
