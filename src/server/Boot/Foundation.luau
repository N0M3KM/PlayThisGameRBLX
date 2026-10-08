--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage.Shared
local Framework = require(Shared.Framework.Framework)
local KnitAdapter = require(Shared.Framework.KnitAdapter)
local Catalog = require(Shared.Contracts.ServiceCatalog)
local Scope = require(Shared.Util.Scope)
local ServiceStub = require(script.Parent.Parent.Infrastructure.ServiceStub)
local StubFactories = require(script.Parent.StubFactories)
local Foundation = {}
local started = false
local activeFramework: Framework.Adapter? = nil

--[=[ Studio-only foundation registration. No client methods, receipts or profile sessions. ]=]
function Foundation.start(): { ServiceStub.Stub }
	assert(RunService:IsStudio(), "Foundation stubs are restricted to Studio")
	assert(not started, "Foundation already started")
	started = true
	local knit = require(ReplicatedStorage.Packages.Knit)
	-- Knit's mutable service tables cross one explicit external-library adapter boundary.
	local framework = Framework.new(KnitAdapter.new((knit :: unknown) :: KnitAdapter.KnitApi))
	local scope = Scope.new()
	local stubs: { ServiceStub.Stub } = {}
	local outcome = table.pack(pcall(function()
		for _, entry in Catalog do
			local factory = StubFactories[entry.Name]
			assert(factory, `Missing factory: {entry.Name}`)
			local stub: ServiceStub.Stub = factory()
			assert(stub.Name == entry.Name, "Catalog/factory name mismatch")
			table.insert(stubs, stub)
			scope:add(function()
				stub:Destroy()
			end)
			-- Register the actual facade so dependency resolution retains its typed methods.
			framework.createService((stub :: unknown) :: Framework.Service)
		end
		framework.start()
		-- Knit.Start resolves before spawned KnitStart hooks finish; stub lifecycle is serial here.
		for _, stub in stubs do
			stub:Init()
		end
		for _, stub in stubs do
			stub:Start()
		end
	end))
	if not outcome[1] then
		scope:destroy()
		error(tostring(outcome[2]), 0)
	end
	game:BindToClose(function()
		scope:destroy()
	end)
	activeFramework = framework
	script.Parent.Parent:SetAttribute("FoundationReady", true)
	print(`Foundation ready: {#stubs} safe stubs. Contracts v0; gameplay gate closed.`)
	return stubs
end

--[=[ Runtime fixture access through the adapter; domain callers use their typed Interface. ]=]
function Foundation.resolve(name: string): ServiceStub.Stub
	local framework = activeFramework
	assert(framework, "Foundation is not ready")
	return (framework.getService(name) :: unknown) :: ServiceStub.Stub
end
return table.freeze(Foundation)
