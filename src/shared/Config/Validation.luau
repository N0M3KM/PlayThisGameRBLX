--!strict
-- Technical draft boundary limits, not gameplay balance.
return table.freeze({
	MaxInteger = 9007199254740991,
	MaxTokenLength = 64,
	MaxCoordinate = 100000,
	MaxIntentFields = 7,
	MaxCommandFields = 8,
	DirectionMagnitudeTolerance = 0.001,
	MaxSnapshotDefinitions = 256,
	MaxSnapshotFields = 16,
	MaxBoardEntries = 50,
})
