--!strict
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
export type Pool = {
	acquire: (string) -> Result.Result<Model>,
	release: (Model) -> (),
	count: () -> number,
	destroy: () -> (),
}
local DroidPool = {}

--[=[ Only private leases may return to the pool. Reset happens before every new generation is registered. ]=]
function DroidPool.new(templates: Instance, storage: Instance, maximum: number): Pool
	assert(maximum > 0 and maximum % 1 == 0, "Invalid rig pool bound")
	local folder = Instance.new("Folder")
	folder.Name = "DroidRigPool"
	folder.Parent = storage
	local idle: { [string]: { Model } } = {}
	local leases: { [Model]: string } = {}
	local owned: { [Model]: boolean } = {}
	local count, destroyed = 0, false
	local function discard(model: Model)
		leases[model] = nil
		if owned[model] then
			owned[model] = nil
			count -= 1
		end
		pcall(function()
			model:Destroy()
		end)
	end
	local function evictIdle()
		for _, list in idle do
			local model = table.remove(list)
			if model then
				discard(model)
				return
			end
		end
	end
	return table.freeze({
		acquire = function(id: string): Result.Result<Model>
			if destroyed then
				return Result.failure("NotReady")
			end
			local available = idle[id]
			local rig: Model? = if available then table.remove(available) else nil
			if not rig then
				local template = templates:FindFirstChild(id)
				if not template or not template:IsA("Model") then
					return Result.failure("UnknownId")
				end
				if count >= maximum then
					evictIdle()
					if count >= maximum then
						return Result.failure("LimitReached")
					end
				end
				local cloned = template:Clone()
				owned[cloned], count = true, count + 1
				rig = cloned
			end
			local model = rig :: Model
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart")
			if not humanoid or not root or not root:IsA("BasePart") then
				discard(model)
				return Result.failure("InvalidRequest")
			end
			if humanoid.Health <= 0 or humanoid:GetState() == Enum.HumanoidStateType.Dead then
				local template = templates:FindFirstChild(id)
				local original = if template then template:FindFirstChildOfClass("Humanoid") else nil
				if not original or original.Health <= 0 then
					discard(model)
					return Result.failure("InvalidRequest")
				end
				local replacement = original:Clone()
				humanoid:Destroy()
				replacement.Parent = model
				humanoid = replacement
			end
			for name in model:GetAttributes() do
				model:SetAttribute(name, nil)
			end
			humanoid.BreakJointsOnDeath = false
			humanoid.RequiresNeck = false
			humanoid.PlatformStand, humanoid.Sit, humanoid.AutoRotate = false, false, true
			for _, child in model:GetDescendants() do
				if child:IsA("BasePart") then
					child.Anchored = false
					child.AssemblyLinearVelocity, child.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
				elseif child:IsA("Script") or child:IsA("LocalScript") then
					child:Destroy()
				end
			end
			leases[model] = id
			return Result.success(model)
		end,
		release = function(model: Model)
			local id = leases[model]
			if not id then
				return
			end
			leases[model] = nil
			if destroyed or not model:FindFirstChildOfClass("Humanoid") then
				discard(model)
				return
			end
			local ok = pcall(function()
				model.Parent = folder
			end)
			if not ok then
				discard(model)
				return
			end
			local list = idle[id] or {}
			idle[id] = list
			table.insert(list, model)
		end,
		count = function()
			return count
		end,
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			for model in owned do
				model:Destroy()
			end
			table.clear(leases)
			table.clear(owned)
			table.clear(idle)
			count = 0
			folder:Destroy()
		end,
	})
end
return table.freeze(DroidPool)
