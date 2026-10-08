--!strict
local Config = require("@game/ReplicatedStorage/Shared/Config/Data")
export type Category = "Gears" | "Armours" | "Classes" | "Utilities"
export type Acquisition = "Shop" | "Wheel" | "Admin"
export type Product = {
	Id: string,
	Category: Category,
	Acquisition: Acquisition,
	Price: number?,
}
export type Catalog = { get: (id: string) -> Product? }
local ShopCatalog = {}

function ShopCatalog.validId(id: string): boolean
	return #id > 0 and #id <= Config.MaxTransactionIdLength and string.match(id, "^[a-z][a-z0-9_]*$") ~= nil
end

--[=[ Copies trusted definitions, rejects ambiguous entries, and freezes the price boundary. ]=]
function ShopCatalog.new(definitions: { Product }): Catalog
	local products: { [string]: Product } = {}
	for _, definition in definitions do
		assert(ShopCatalog.validId(definition.Id), "Invalid shop content id")
		assert(products[definition.Id] == nil, "Duplicate shop content id")
		assert(
			definition.Category == "Gears"
				or definition.Category == "Armours"
				or definition.Category == "Classes"
				or definition.Category == "Utilities",
			"Invalid inventory category"
		)
		assert(
			definition.Acquisition == "Shop"
				or definition.Acquisition == "Wheel"
				or definition.Acquisition == "Admin",
			"Invalid acquisition"
		)
		local price = definition.Price
		assert(
			definition.Acquisition ~= "Shop"
				or (price ~= nil and price == price and price >= 0 and price <= Config.MaxInteger),
			"Invalid shop price"
		)
		products[definition.Id] = table.freeze({
			Id = definition.Id,
			Category = definition.Category,
			Acquisition = definition.Acquisition,
			Price = price,
		})
	end
	return table.freeze({
		get = function(id: string): Product?
			return products[id]
		end,
	})
end

--[=[ Exact baseline acquisition values from docs/CONTENT-CATALOG.md, not combat definitions.
	No dependency on C/F implementations is needed; their eventual catalog can be injected.
]=]
function ShopCatalog.fromBaseline(): Catalog
	return ShopCatalog.new({
		{ Id = "push", Category = "Gears", Acquisition = "Shop", Price = 100 },
		{ Id = "classic_sword", Category = "Gears", Acquisition = "Shop", Price = 250 },
		{ Id = "fish_sword", Category = "Gears", Acquisition = "Shop", Price = 700 },
		{ Id = "hunter_rifle", Category = "Gears", Acquisition = "Shop", Price = 1500 },
		{ Id = "ak47", Category = "Gears", Acquisition = "Shop", Price = 7500 },
		{ Id = "lightsaber", Category = "Gears", Acquisition = "Wheel" },
		{ Id = "crystal_laser_cannon", Category = "Gears", Acquisition = "Wheel" },
		{ Id = "green_balloon", Category = "Gears", Acquisition = "Shop", Price = 5000 },
		{ Id = "speed_coil", Category = "Gears", Acquisition = "Shop", Price = 3500 },
		{ Id = "ammo_box", Category = "Utilities", Acquisition = "Shop", Price = 50 },
		{ Id = "bloxy_cola", Category = "Utilities", Acquisition = "Shop", Price = 50 },
		{ Id = "landmine", Category = "Utilities", Acquisition = "Shop", Price = 150 },
		{ Id = "turret", Category = "Utilities", Acquisition = "Shop", Price = 750 },
		{ Id = "normal_vest", Category = "Armours", Acquisition = "Shop", Price = 1500 },
		{ Id = "ghost_vest", Category = "Armours", Acquisition = "Shop", Price = 22222 },
		{ Id = "overseer_vest", Category = "Armours", Acquisition = "Admin" },
		{ Id = "none", Category = "Classes", Acquisition = "Shop", Price = 0 },
		{ Id = "warrior", Category = "Classes", Acquisition = "Shop", Price = 1200 },
		{ Id = "ranger", Category = "Classes", Acquisition = "Shop", Price = 2300 },
	})
end

return table.freeze(ShopCatalog)
