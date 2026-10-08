--!strict
local Domain = require("@game/ReplicatedStorage/Shared/Contracts/DomainInterfaces")
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Scope = require("@game/ReplicatedStorage/Shared/Util/Scope")
local Calculator = require("@game/ReplicatedStorage/Shared/Util/Combat/StatModifier")
local StatusTypes = require("./StatusEffectService/Types")
local RigAdapter = {}
export type Dependencies = {
	model: (Payloads.EntityRef) -> Model?,
	current: (Payloads.EntityRef) -> boolean,
	stats: Domain.StatService,
	MaxImpulse: number,
}
export type Api = {
	controlLocked: (Payloads.EntityRef) -> boolean,
	refresh: (Payloads.EntityRef) -> (),
	controls: (Payloads.EntityRef, StatusTypes.Controls) -> (),
	knockback: (Payloads.EntityRef, Vector3) -> Result.Result<boolean>,
	clear: (Payloads.EntityRef) -> (),
	clearRound: (number) -> (),
	destroy: () -> (),
}
type Binding = {
	Entity: Payloads.EntityRef,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Scope: Scope.Scope,
	WalkSpeed: number,
	JumpPower: number,
	JumpHeight: number,
	MaxHealth: number,
	AutoRotate: boolean,
	PlatformStand: boolean,
	Controls: StatusTypes.Controls,
	Network: { Automatic: boolean, Owner: Player? }?,
}
local function key(entity: Payloads.EntityRef): string
	return string.format("%d:%d:%s", entity.RoundId, entity.Generation, entity.Id)
end

--[=[ R6/R15 share the Humanoid/root contract. Ragdoll uses reversible PlatformStand
	as the primitive fallback; it never breaks Motor6Ds or creates unowned constraints.
	Caller binds existing/future entity generations through its authoritative resolver.
]=]
function RigAdapter.new(deps: Dependencies): Api
	assert(Calculator.finite(deps.MaxImpulse) and deps.MaxImpulse >= 0, "Invalid impulse limit")
	local bindings: { [string]: Binding } = {}
	local destroyed = false
	local function clear(entity: Payloads.EntityRef)
		local identity = key(entity)
		local binding = bindings[identity]
		bindings[identity] = nil
		if binding then
			binding.Scope:destroy()
		end
	end
	local function current(binding: Binding): boolean
		return deps.current(binding.Entity)
			and deps.model(binding.Entity) == binding.Model
			and binding.Model.Parent ~= nil
			and binding.Humanoid.Parent == binding.Model
	end
	local function resolve(entity: Payloads.EntityRef): Binding?
		if destroyed or not deps.current(entity) then
			return nil
		end
		local identity = key(entity)
		local previous = bindings[identity]
		if previous and current(previous) then
			return previous
		end
		clear(entity)
		local model = deps.model(entity)
		if not model or not model.Parent then
			return nil
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or not root:IsA("BasePart") then
			return nil
		end
		local owner = Scope.new()
		local binding: Binding = {
			Entity = table.freeze(table.clone(entity)),
			Model = model,
			Humanoid = humanoid,
			Root = root,
			Scope = owner,
			WalkSpeed = humanoid.WalkSpeed,
			JumpPower = humanoid.JumpPower,
			JumpHeight = humanoid.JumpHeight,
			MaxHealth = humanoid.MaxHealth,
			AutoRotate = humanoid.AutoRotate,
			PlatformStand = humanoid.PlatformStand,
			Controls = { Stunned = false, Ragdolled = false },
		}
		bindings[identity] = binding
		owner:add(function()
			if current(binding) and binding.Network and binding.Root.Parent == model then
				if binding.Root:CanSetNetworkOwnership() then
					if binding.Network.Automatic then
						binding.Root:SetNetworkOwnershipAuto()
					else
						binding.Root:SetNetworkOwner(binding.Network.Owner)
					end
				end
			end
		end)
		owner:add(function()
			if current(binding) and humanoid.Health > 0 then
				humanoid.WalkSpeed = binding.WalkSpeed
				humanoid.JumpPower = binding.JumpPower
				humanoid.JumpHeight = binding.JumpHeight
				humanoid.MaxHealth = binding.MaxHealth
				humanoid.Health = math.min(humanoid.Health, binding.MaxHealth)
				humanoid.AutoRotate = binding.AutoRotate
				humanoid.PlatformStand = binding.PlatformStand
			end
		end)
		local died = humanoid.Died:Connect(function()
			clear(entity)
		end)
		owner:add(function()
			died:Disconnect()
		end)
		local ancestry = model.AncestryChanged:Connect(function()
			if not model.Parent then
				clear(entity)
			end
		end)
		owner:add(function()
			ancestry:Disconnect()
		end)
		return binding
	end
	local function refresh(entity: Payloads.EntityRef)
		local binding = resolve(entity)
		if not binding or binding.Humanoid.Health <= 0 then
			return
		end
		local resolved = deps.stats:Resolve(entity)
		if not current(binding) then
			return
		end
		local locked = binding.Controls.Stunned or binding.Controls.Ragdolled
		binding.Humanoid.WalkSpeed = if locked
			then 0
			elseif resolved.Ok then resolved.Value.WalkSpeed or binding.WalkSpeed
			else binding.WalkSpeed
		binding.Humanoid.JumpPower = if locked
			then 0
			elseif resolved.Ok then resolved.Value.JumpPower or binding.JumpPower
			else binding.JumpPower
		binding.Humanoid.JumpHeight = if locked
			then 0
			elseif resolved.Ok then resolved.Value.JumpHeight or binding.JumpHeight
			else binding.JumpHeight
		local maxHealth = if resolved.Ok then resolved.Value.MaxHP or binding.MaxHealth else binding.MaxHealth
		local oldMax = binding.Humanoid.MaxHealth
		if maxHealth > 0 and maxHealth ~= oldMax then
			binding.Humanoid.MaxHealth = maxHealth
			-- A maximum-HP modifier never grants healing when repeatedly toggled.
			binding.Humanoid.Health = math.min(maxHealth, binding.Humanoid.Health)
		end
		binding.Humanoid.AutoRotate = if locked then false else binding.AutoRotate
		binding.Humanoid.PlatformStand = binding.Controls.Ragdolled or binding.PlatformStand
		if locked then
			binding.Humanoid.Jump = false
		end
	end
	return table.freeze({
		controlLocked = function(entity: Payloads.EntityRef): boolean
			local binding = resolve(entity)
			return binding ~= nil and (binding.Controls.Stunned or binding.Controls.Ragdolled)
		end,
		refresh = refresh,
		controls = function(entity: Payloads.EntityRef, controls: StatusTypes.Controls)
			local binding = resolve(entity)
			if not binding then
				return
			end
			binding.Controls = table.clone(controls)
			refresh(entity)
		end,
		knockback = function(entity: Payloads.EntityRef, impulse: Vector3): Result.Result<boolean>
			if
				not Calculator.finite(impulse.X)
				or not Calculator.finite(impulse.Y)
				or not Calculator.finite(impulse.Z)
				or impulse.Magnitude > deps.MaxImpulse
			then
				return Result.failure("InvalidRequest")
			end
			local binding = resolve(entity)
			if not binding or not current(binding) then
				return Result.failure("StaleRound")
			end
			local ok = pcall(function()
				local canSet = binding.Root:CanSetNetworkOwnership()
				if canSet then
					if not binding.Network then
						binding.Network = {
							Automatic = binding.Root:GetNetworkOwnershipAuto(),
							Owner = binding.Root:GetNetworkOwner(),
						}
					end
					binding.Root:SetNetworkOwner(nil)
				end
				binding.Root:ApplyImpulse(impulse)
			end)
			return if ok then Result.success(true) else Result.failure("Unavailable")
		end,
		clear = clear,
		clearRound = function(roundId: number)
			local pending = {}
			for _, binding in bindings do
				if binding.Entity.RoundId == roundId then
					table.insert(pending, binding.Entity)
				end
			end
			for _, entity in pending do
				clear(entity)
			end
		end,
		destroy = function()
			local previous = bindings
			bindings = {}
			for _, binding in previous do
				binding.Scope:destroy()
			end
			destroyed = true
		end,
	})
end
return table.freeze(RigAdapter)
