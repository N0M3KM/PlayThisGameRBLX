--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.Data)
local Service = require(Shared.Contracts.Service)
local active: { [Service.Interface]: boolean } = {}
local bound = false
local ShutdownRegistry = {}

--[=[ Roblox has no UnbindToClose: one callback holds only currently started services. ]=]
function ShutdownRegistry.add(service: Service.Interface): () -> ()
	active[service] = true
	if not bound then
		bound = true
		game:BindToClose(function()
			local pending = 0
			for current in active do
				pending += 1
				task.spawn(function()
					local ok = pcall(function()
						current:Stop()
					end)
					pending -= 1
					if not ok then
						warn("DataService shutdown callback failed")
					end
				end)
			end
			local deadline = os.clock() + Config.ShutdownTimeoutSeconds
			while pending > 0 and os.clock() < deadline do
				task.wait(Config.ProfilePollIntervalSeconds)
			end
		end)
	end
	return function()
		active[service] = nil
	end
end

return table.freeze(ShutdownRegistry)
