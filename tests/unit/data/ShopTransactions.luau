--!strict
-- Prepared regression cases; not a substitute for Studio save/round-entry evidence.
local Inventory = require("../../../src/server/Services/Data/InventoryService")
local ShopCatalog = require("../../../src/server/Services/Data/ShopCatalog")
local Template = require("../../../src/server/Services/Data/ProfileTemplate")

local catalog = ShopCatalog.fromBaseline()
local function product(id: string): ShopCatalog.Product
	local value = catalog.get(id)
	assert(value, "Missing exact baseline product")
	return value
end

do
	assert(product("push").Price == 100, "Shop inventory regression failed")
	assert(product("ghost_vest").Price == 22222, "Shop inventory regression failed")
	assert(product("none").Price == 0, "Shop inventory regression failed")
	assert(product("lightsaber").Acquisition == "Wheel", "Shop inventory regression failed")
	assert(product("overseer_vest").Acquisition == "Admin", "Shop inventory regression failed")
	assert(catalog.get("unknown") == nil, "Shop inventory regression failed")
	local duplicateDefinitions: { ShopCatalog.Product } = {
		{ Id = "push", Category = "Gears", Acquisition = "Shop", Price = 100 },
		{ Id = "push", Category = "Gears", Acquisition = "Shop", Price = 0 },
	}
	local ok = pcall(ShopCatalog.new, duplicateDefinitions)
	assert(not ok, "Ambiguous prices must fail construction")
end

do
	local profile = Template.new()
	profile.Inventory.Utilities.ammo_box = 99
	assert(
		Inventory.grantCandidate(profile, product("ammo_box"), 1, false).Ok,
		"Shop inventory regression failed"
	)
	local capped = Inventory.grantCandidate(profile, product("ammo_box"), 1, false)
	assert(not capped.Ok and capped.Code == "LimitReached", "Shop inventory regression failed")
	assert(profile.Inventory.Utilities.ammo_box == 100, "Shop inventory regression failed")
	assert(
		Inventory.grantCandidate(profile, product("ammo_box"), 50, true).Ok,
		"Shop inventory regression failed"
	)
	assert(profile.Inventory.Utilities.ammo_box == 100, "Trusted grant clamps")
	local invalid = Inventory.grantCandidate(profile, product("ammo_box"), 0.5, true)
	assert(not invalid.Ok and invalid.Code == "InvalidRequest", "Shop inventory regression failed")
	assert(profile.Inventory.Utilities.ammo_box == 100, "Shop inventory regression failed")
end

do
	local profile = Template.new()
	assert(Inventory.grantCandidate(profile, product("push"), 1, true).Ok, "Shop inventory regression failed")
	local duplicate = Inventory.grantCandidate(profile, product("push"), 1, false)
	assert(not duplicate.Ok and duplicate.Code == "LimitReached", "Shop inventory regression failed")
	assert(#profile.Inventory.Gears == 1, "Unique purchases cannot stack")
	local nonUtility = Inventory.consumeCandidate(profile, product("push"), 1)
	assert(not nonUtility.Ok and nonUtility.Code == "InvalidRequest", "Shop inventory regression failed")
	local missing = Inventory.consumeCandidate(profile, product("ammo_box"), 1)
	assert(not missing.Ok and missing.Code == "NotOwned", "Shop inventory regression failed")
	assert(
		Inventory.grantCandidate(profile, product("ammo_box"), 2, true).Ok,
		"Shop inventory regression failed"
	)
	assert(Inventory.consumeCandidate(profile, product("ammo_box"), 1).Ok, "Shop inventory regression failed")
	assert(profile.Inventory.Utilities.ammo_box == 1, "Shop inventory regression failed")
	local excessive = Inventory.consumeCandidate(profile, product("ammo_box"), 2)
	assert(not excessive.Ok and excessive.Code == "NotOwned", "Shop inventory regression failed")
	assert(profile.Inventory.Utilities.ammo_box == 1, "Failed consume does not change ownership")
end

return true
