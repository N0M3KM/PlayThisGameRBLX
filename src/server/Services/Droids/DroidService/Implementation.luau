--!strict
local Http = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Result = require(Shared.Contracts.Result)
local Payloads = require(Shared.Contracts.Payloads)
local DroidAI = require(Shared.Contracts.DroidAI)
local Service = require(Shared.Contracts.Service)
local Definitions = require(Shared.Config.Droids)
local Maps = require(Shared.Config.Maps)
local Config = require(Shared.Config.DroidRuntime)
local GameConfig = require(Shared.Config.Game)
local Validation = require(Shared.Registry.Validation)
local WeightedRandom = require(Shared.Util.WeightedRandom)
local Scope = require(Shared.Util.Scope)
local Lifecycle = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceLifecycle)
local Pool = require(script.Parent.Parent.DroidPool)
local Policy = require(script.Parent.Parent.SpawnPolicy)
local Types = require(script.Parent.Types)
local Sync = require(script.Parent.Sync)
type Slot = {
	Id: number,
	Generation: number,
	LastSpawn: number?,
	Record: Types.Record?,
	Scope: Scope.Scope?,
	DueAt: number?,
	Ordinary: boolean,
	Event: boolean?,
	OwnerUserId: number?,
}
local Implementation = {}

--[=[ One serial lifecycle table owns independent respawn deadlines; no per-droid scheduler connection. ]=]
function Implementation.new(deps: Types.Dependencies): Types.Api
	local owner = Scope.new()
	local pool = Pool.new(deps.Templates, deps.Storage, Config.MaxPooledRigs)
	owner:add(pool.destroy)
	local slots: { [number]: Slot } = {}
	local setup: Types.Setup? = nil
	local cap, sequence, closedRound, epoch = 0, 0, 0, 0
	local identity = Http:GenerateGUID(false):gsub("%-", "")
	local busy, stopping = false, false
	local function locked<T>(callback: () -> Result.Result<T>): Result.Result<T>
		if busy or stopping then
			return Result.failure("WrongState")
		end
		busy = true
		local ok, response = pcall(callback)
		busy = false
		return if ok then response else Result.failure("Unavailable")
	end
	local function clock(): number
		local now = Sync.call(deps.clock)
		assert(Validation.finite(now) and now >= 0, "Invalid droid clock")
		return now
	end
	local function random(): number
		return Sync.call(deps.random)
	end
	local function players(roundId: number): { Payloads.Point }
		return Sync.call(function()
			return deps.players(roundId)
		end)
	end
	local function active(roundId: number): boolean
		return Sync.call(function()
			return deps.active(roundId)
		end)
	end
	local function ownerActive(ownerId: number, roundId: number): boolean
		return Sync.call(function()
			return deps.ownerActive(ownerId, roundId)
		end)
	end
	local function unregister(entity: Payloads.EntityRef)
		pcall(function()
			Sync.run(function()
				deps.unregister(entity)
			end)
		end)
	end
	local function notify(kind: string, entity: Payloads.EntityRef)
		local callback = deps.lifecycle
		if callback then
			pcall(function()
				Sync.run(function()
					callback(kind, entity)
				end)
			end)
		end
	end
	local function release(slot: Slot)
		local record, scope = slot.Record, slot.Scope
		slot.Record, slot.Scope = nil, nil
		if scope then
			scope:destroy()
		end
		if record then
			unregister(record.Entity)
			pool.release(record.Model)
			notify("Despawned", record.Entity)
		end
	end
	local function stop()
		if stopping then
			return
		end
		stopping = true
		epoch += 1
		local previous = setup
		setup, cap = nil, 0
		if previous then
			closedRound = math.max(closedRound, previous.Context.RoundId)
		end
		for _, slot in slots do
			slot.DueAt = nil
			release(slot)
		end
		table.clear(slots)
		stopping = false
	end
	local facade = Lifecycle.new("DroidService", owner, { Stop = stop })
	local api = (facade :: unknown) :: Types.Api
	local function newSlot(ordinary: boolean): Slot
		sequence += 1
		local slot: Slot = { Id = sequence, Generation = 0, Ordinary = ordinary }
		slots[sequence] = slot
		return slot
	end
	local function death(slot: Slot)
		local record, current = slot.Record, setup
		if not record or not current then
			return
		end
		release(slot)
		notify("Died", record.Entity)
		if setup ~= current or slots[slot.Id] ~= slot then
			return
		end
		if slot.Ordinary then
			local ok, now = pcall(clock)
			slot.DueAt = if ok then now + GameConfig.DroidRespawnSeconds else nil
		else
			slots[slot.Id] = nil
		end
	end
	local function spawn(
		slot: Slot,
		definitionId: string,
		faction: "Hostile" | "Allied",
		ownerId: number?,
		marker: number?
	): Result.Result<Payloads.EntityRef>
		local current = setup
		local definition = Definitions.ById[definitionId]
		if not current or not definition or not active(current.Context.RoundId) or setup ~= current then
			return Result.failure("NotReady")
		end
		if
			slot.Ordinary and (definition.EventOnly or not table.find(definition.Maps, current.Context.MapId))
		then
			return Result.failure("InvalidRequest")
		end
		local selected = if marker
			then Result.success(marker)
			else Policy.select(
				current.Context.DroidSpawns,
				slot.LastSpawn,
				players(current.Context.RoundId),
				Config.MinimumSpawnDistance,
				random
			)
		if not selected.Ok then
			return Result.failure(selected.Code)
		end
		if setup ~= current then
			return Result.failure("StaleRound")
		end
		local point = current.Context.DroidSpawns[selected.Value]
		if not point or selected.Value == slot.LastSpawn then
			return Result.failure("InvalidRequest")
		end
		local lifetimeAt = if ownerId then clock() + Config.AllyLifetimeSeconds else nil
		if setup ~= current then
			return Result.failure("StaleRound")
		end
		local acquired = pool.acquire(definition.AssetId)
		if not acquired.Ok then
			return Result.failure(acquired.Code)
		end
		local model = acquired.Value
		local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
		slot.Generation += 1
		local entity = table.freeze({
			Id = `droid_{identity}_{slot.Id}`,
			RoundId = current.Context.RoundId,
			Generation = slot.Generation,
		})
		model.Name = entity.Id
		model:SetAttribute("DefinitionId", definitionId)
		model:SetAttribute("RoundId", entity.RoundId)
		model:SetAttribute("Generation", entity.Generation)
		model:SetAttribute("Faction", faction)
		humanoid.MaxHealth, humanoid.Health, humanoid.WalkSpeed =
			definition.MaxHP, definition.MaxHP, Config.WalkSpeed
		model:PivotTo(CFrame.new(point.X, point.Y + Config.SpawnLift, point.Z))
		local record: Types.Record = {
			Entity = entity,
			Definition = definition,
			Model = model,
			Humanoid = humanoid,
			Root = root,
			Faction = faction,
			OwnerUserId = ownerId,
			LastSpawn = selected.Value,
			LifetimeAt = lifetimeAt,
		}
		local scoped = owner:child()
		local ok = pcall(function()
			model.Parent = deps.Parent
			root:SetNetworkOwner(nil)
			local registered = Sync.call(function()
				return deps.register(record)
			end)
			assert(registered.Ok and registered.Value, "Combat registration failed")
		end)
		if not ok or setup ~= current then
			unregister(entity)
			scoped:destroy()
			pool.release(model)
			return Result.failure("Unavailable")
		end
		slot.Record, slot.Scope, slot.LastSpawn, slot.DueAt = record, scoped, selected.Value, nil
		local died = humanoid.Died:Connect(function()
			if slot.Record == record then
				death(slot)
			end
		end)
		scoped:add(function()
			died:Disconnect()
		end)
		local ancestry = model.AncestryChanged:Connect(function()
			if slot.Record == record and not model:IsDescendantOf(workspace) then
				death(slot)
			end
		end)
		scoped:add(function()
			ancestry:Disconnect()
		end)
		notify("Spawned", entity)
		if setup ~= current or slots[slot.Id] ~= slot or slot.Record ~= record or not api:IsStarted() then
			if slot.Record == record then
				release(slot)
			end
			return Result.failure("StaleRound")
		end
		return Result.success(entity)
	end
	local function find(entity: Payloads.EntityRef): Slot?
		for _, slot in slots do
			local record = slot.Record
			if
				record
				and record.Entity.Id == entity.Id
				and record.Entity.Generation == entity.Generation
				and record.Entity.RoundId == entity.RoundId
			then
				return slot
			end
		end
		return nil
	end
	local function manualInternal(
		request: Payloads.SpawnRequest,
		ownerId: number?
	): Result.Result<Payloads.EntityRef>
		if
			not api:IsStarted()
			or not setup
			or request.RoundId ~= setup.Context.RoundId
			or request.MapId ~= setup.Context.MapId
		then
			return Result.failure("WrongState")
		end
		local current = setup
		local definition = Definitions.ById[request.DefinitionId]
		if not definition or request.BossInstanceId then
			return Result.failure("UnknownId")
		end
		if request.Faction ~= (if ownerId then "Allied" else "Hostile") then
			return Result.failure("InvalidRequest")
		end
		if ownerId and definition.EventOnly then
			return Result.failure("InvalidRequest")
		end
		local total, allies, ordinary, events = 0, 0, 0, 0
		for _, slot in slots do
			total += 1
			if ownerId and slot.OwnerUserId == ownerId then
				allies += 1
			end
			if slot.Event then
				events += 1
			elseif not slot.OwnerUserId then
				ordinary += 1
			end
		end
		if total >= Config.MaxEntities or (ownerId and allies >= Config.MaxAlliesPerOwner) then
			return Result.failure("LimitReached")
		end
		if
			not ownerId
			and (
				(definition.EventOnly and events >= Config.MaxEventEntities)
				or (not definition.EventOnly and ordinary >= cap)
			)
		then
			return Result.failure("LimitReached")
		end
		if ownerId and not ownerActive(ownerId, request.RoundId) then
			return Result.failure("NotOwned")
		end
		if setup ~= current then
			return Result.failure("StaleRound")
		end
		local marker = tonumber(request.SpawnId:match("^spawn_(%d+)$") or request.SpawnId)
		if not marker or not Validation.integer(marker, 1, #setup.Context.DroidSpawns) then
			return Result.failure("InvalidRequest")
		end
		local slot = newSlot(false)
		slot.Event, slot.OwnerUserId = definition.EventOnly, ownerId
		local ok, response = pcall(spawn, slot, request.DefinitionId, request.Faction, ownerId, marker)
		if not ok or not response.Ok then
			release(slot)
			slots[slot.Id] = nil
		end
		return if ok then response else Result.failure("Unavailable")
	end
	local function manual(request: Payloads.SpawnRequest, ownerId: number?): Result.Result<Payloads.EntityRef>
		return locked(function()
			return manualInternal(request, ownerId)
		end)
	end
	local function startSpawning(roundId: number, mapId: string): Result.Result<boolean>
		if not api:IsStarted() or setup or roundId <= closedRound then
			return Result.failure("WrongState")
		end
		if workspace.FallenPartsDestroyHeight >= Config.RecoveryHeight then
			return Result.failure("InvalidRequest")
		end
		local revision = epoch
		local loaded = Sync.call(function()
			return deps.map(roundId, mapId)
		end)
		if not loaded.Ok then
			return Result.failure(loaded.Code)
		end
		if epoch ~= revision or not api:IsStarted() or setup or roundId <= closedRound then
			return Result.failure("StaleRound")
		end
		local context, map = loaded.Value.Context, Maps.ById[mapId]
		if not map or context.RoundId ~= roundId or context.MapId ~= mapId or #context.DroidSpawns < 2 then
			return Result.failure("InvalidRequest")
		end
		local bounded = Policy.cap(
			loaded.Value.MapRate,
			loaded.Value.ScenarioMultiplier,
			loaded.Value.EventMultiplier,
			Config.MaxEntities
		)
		if not bounded.Ok then
			return Result.failure(bounded.Code)
		end
		local now = clock()
		if epoch ~= revision or not api:IsStarted() or setup or roundId <= closedRound then
			return Result.failure("StaleRound")
		end
		setup, cap = loaded.Value, bounded.Value
		for _ = 1, cap do
			newSlot(true).DueAt = now
		end
		return Result.success(true)
	end
	api.StartSpawning = function(
		_self: Service.Interface,
		roundId: number,
		mapId: string
	): Result.Result<boolean>
		return locked(function()
			return startSpawning(roundId, mapId)
		end)
	end
	api.StopRound = function(_self: Service.Interface, roundId: number): Result.Result<boolean>
		if setup and setup.Context.RoundId ~= roundId then
			return Result.failure("StaleRound")
		end
		stop()
		return Result.success(true)
	end
	api.Spawn = function(_self: Service.Interface, request: Payloads.SpawnRequest)
		return manual(request, nil)
	end
	api.Summon = function(_self: Service.Interface, request: Payloads.SpawnRequest, ownerId: number)
		return manual(request, ownerId)
	end
	api.Despawn = function(
		_self: Service.Interface,
		entity: Payloads.EntityRef,
		_reason: string
	): Result.Result<boolean>
		local slot = find(entity)
		if not slot then
			return Result.failure("StaleRound")
		end
		release(slot)
		slots[slot.Id] = nil
		return Result.success(true)
	end
	api.Query = function(
		_self: Service.Interface,
		entity: Payloads.EntityRef
	): Result.Result<Payloads.TargetSnapshot>
		local slot = find(entity)
		local record = if slot then slot.Record else nil
		if not record then
			return Result.failure("StaleRound")
		end
		local position = record.Root.Position
		return Result.success({
			Entity = record.Entity,
			Position = { X = position.X, Y = position.Y, Z = position.Z },
			Hp = record.Humanoid.Health,
			Faction = record.Faction,
		})
	end
	api.records = function(): { Types.Record }
		local records = {}
		for _, slot in slots do
			if slot.Record then
				table.insert(records, slot.Record)
			end
		end
		return records
	end
	api.snapshots = function()
		local result: { DroidAI.Target } = {}
		for _, record in api.records() do
			local snapshot = api:Query(record.Entity)
			if snapshot.Ok then
				local value = snapshot.Value
				local target: DroidAI.Target = {
					Entity = value.Entity,
					Position = value.Position,
					Hp = value.Hp,
					Faction = value.Faction,
					Structure = false,
				}
				table.insert(result, target)
			end
		end
		return result
	end
	local function step()
		local current = setup
		if not current or not api:IsStarted() or not active(current.Context.RoundId) or setup ~= current then
			return
		end
		local now, spawned = clock(), 0
		local map = Maps.ById[current.Context.MapId]
		for _, slot in slots do
			if setup ~= current or not api:IsStarted() then
				return
			end
			local record = slot.Record
			if record then
				if record.Humanoid.Health <= 0 then
					death(slot)
				elseif
					record.OwnerUserId
					and (
						not ownerActive(record.OwnerUserId, current.Context.RoundId)
						or (record.LifetimeAt and now >= record.LifetimeAt)
					)
				then
					release(slot)
					slots[slot.Id] = nil
				elseif record.Root.Position.Y < Config.RecoveryHeight then
					local selected = Policy.select(
						current.Context.DroidSpawns,
						slot.LastSpawn,
						players(current.Context.RoundId),
						Config.MinimumSpawnDistance,
						random
					)
					if setup ~= current or slot.Record ~= record then
						return
					end
					if selected.Ok then
						local point = current.Context.DroidSpawns[selected.Value]
						record.Model:PivotTo(CFrame.new(point.X, point.Y + Config.SpawnLift, point.Z))
						record.Root.AssemblyLinearVelocity = Vector3.zero
						record.Root.AssemblyAngularVelocity = Vector3.zero
						slot.LastSpawn = selected.Value
					else
						death(slot)
					end
				end
			elseif slot.Ordinary and slot.DueAt and now >= slot.DueAt and spawned < Config.SpawnBatchSize then
				local entries: { WeightedRandom.Entry } = {}
				for _, definition in Definitions.Definitions do
					if not definition.EventOnly and table.find(definition.Maps, map.Id) then
						table.insert(entries, { Id = definition.Id, Weight = definition.SpawnWeight })
					end
				end
				if #entries > 0 then
					local id = WeightedRandom.pick(entries, random)
					local ok = pcall(spawn, slot, id, "Hostile" :: "Hostile", nil, nil)
					if not ok then
						release(slot)
					end
					spawned += 1
				end
			end
		end
	end
	api.step = function()
		locked(function()
			step()
			return Result.success(true)
		end)
	end
	api.metrics = function()
		local alive, total, pending = 0, 0, 0
		for _, slot in slots do
			total += 1
			if slot.Record then
				alive += 1
			elseif slot.DueAt then
				pending += 1
			end
		end
		return { Alive = alive, Slots = total, Cap = cap, Pooled = pool.count(), PendingRespawns = pending }
	end
	return api
end
return table.freeze(Implementation)
