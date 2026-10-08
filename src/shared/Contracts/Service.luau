--!strict
-- Draft stub surface, not the full domain-specific Contracts v1 API.
export type Arguments = { [string]: unknown }
export type StubResult = { Ok: false, Code: "NotReady" }
export type Interface = {
	Name: string,
	IsStub: boolean,
	Init: (self: Interface) -> (),
	Start: (self: Interface) -> (),
	Stop: (self: Interface) -> (),
	Destroy: (self: Interface) -> (),
	Call: (self: Interface, command: string, arguments: Arguments?) -> StubResult,
	IsStarted: (self: Interface) -> boolean,
}
return table.freeze({ Version = 0, Frozen = false })
