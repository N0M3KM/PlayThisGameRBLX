--!strict
local fs = require("@lune/fs")
local Catalog = require("../../../src/shared/Contracts/ServiceCatalog")
local common = { Init = true, Start = true, Stop = true, Destroy = true, Call = true, IsStarted = true }
local count = 0
for _, entry in Catalog do
	local directory = `src/server/Services/{entry.Group}/{entry.Name}`
	local source = fs.readFile(`{directory}/Stub.luau`)
	local interface = fs.readFile(`{directory}/Interface.luau`)
	assert(
		string.find(interface, `DomainInterfaces.{entry.Name}`, 1, true),
		`Missing typed interface: {directory}`
	)
	assert(
		string.find(source, "return function(): Interface.Interface", 1, true),
		`Untyped factory: {directory}`
	)
	local seen: { [string]: boolean } = {}
	for _, command in entry.Commands do
		assert(
			not common[command] and not seen[command],
			`Lifecycle collision/duplicate: {entry.Name}.{command}`
		)
		seen[command] = true
		assert(string.find(source, `{command} = function`, 1, true), `Missing facade: {entry.Name}.{command}`)
		assert(
			string.find(source, `stub:Call("{command}")`, 1, true),
			`Missing safe delegation: {entry.Name}.{command}`
		)
		assert(
			string.find(interface, `"{command}"`, 1, true),
			`Interface/catalog mismatch: {entry.Name}.{command}`
		)
	end
	count += 1
end
assert(count == 29, "Every foundation service requires a typed shell")
print(`PASS {count} typed shell/catalog file checks (static inspection only).`)
return count
