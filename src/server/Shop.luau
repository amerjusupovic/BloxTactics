--[[
	Shop.luau
	Shop system for purchasing units
]]

local DataStructures = require(game.ReplicatedStorage.Shared.DataStructures)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local UnitDatabase = require(game.ReplicatedStorage.Shared.UnitDatabase)
local UnitTiering = require(game.ReplicatedStorage.Shared.UnitTiering)
local ShopData = DataStructures.ShopData
local Unit = DataStructures.Unit

local Shop = {}

--[[
	Expanded shop odds by level (percentage chance for each cost tier 1-10)
	Requirement: "at each level, you can see units at that cost" -> cost tier == player level must have non-zero odds.
	Costs above the player's level have 0 odds. Lower tiers retain diminishing but still present odds.

	NOTE: Currently the UnitDatabase only defines units up to cost 4. For newly added cost tiers (5-10), the fallback logic
	below ensures that if a selected cost has no available units, we gracefully fall back to the nearest lower (then higher)
	cost that has units so the shop always fills to size.

	Distributions (each sums to 100):
	Level 1: 100
	Level 2: 80 / 20
	Level 3: 70 / 20 / 10
	Level 4: 60 / 20 / 12 / 8
	Level 5: 50 / 22 / 13 / 10 / 5
	Level 6: 40 / 20 / 13 / 11 / 9 / 7
	Level 7: 32 / 18 / 12 / 11 / 10 / 9 / 8
	Level 8: 26 / 16 / 12 / 11 / 10 / 9 / 8 / 8
	Level 9: 20 / 14 / 11 / 11 / 10 / 9 / 9 / 8 / 8
	Level10: 15 / 12 / 11 / 11 / 10 / 9 / 9 / 8 / 8 / 7
]]
local SHOP_ODDS_BY_LEVEL = {
	[1] =  { [1] = 100, [2] = 0,  [3] = 0,  [4] = 0,  [5] = 0,  [6] = 0, [7] = 0, [8] = 0, [9] = 0, [10] = 0 },
	[2] =  { [1] = 80,  [2] = 20, [3] = 0,  [4] = 0,  [5] = 0,  [6] = 0, [7] = 0, [8] = 0, [9] = 0, [10] = 0 },
	[3] =  { [1] = 70,  [2] = 20, [3] = 10, [4] = 0,  [5] = 0,  [6] = 0, [7] = 0, [8] = 0, [9] = 0, [10] = 0 },
	[4] =  { [1] = 60,  [2] = 20, [3] = 12, [4] = 8,  [5] = 0,  [6] = 0, [7] = 0, [8] = 0, [9] = 0, [10] = 0 },
	[5] =  { [1] = 50,  [2] = 22, [3] = 13, [4] = 10, [5] = 5,  [6] = 0, [7] = 0, [8] = 0, [9] = 0, [10] = 0 },
	[6] =  { [1] = 40,  [2] = 20, [3] = 13, [4] = 11, [5] = 9,  [6] = 7, [7] = 0, [8] = 0, [9] = 0, [10] = 0 },
	[7] =  { [1] = 32,  [2] = 18, [3] = 12, [4] = 11, [5] = 10, [6] = 9, [7] = 8, [8] = 0, [9] = 0, [10] = 0 },
	[8] =  { [1] = 26,  [2] = 16, [3] = 12, [4] = 11, [5] = 10, [6] = 9, [7] = 8, [8] = 8, [9] = 0, [10] = 0 },
	[9] =  { [1] = 20,  [2] = 14, [3] = 11, [4] = 11, [5] = 10, [6] = 9, [7] = 9, [8] = 8, [9] = 8, [10] = 0 },
	[10] = { [1] = 15,  [2] = 12, [3] = 11, [4] = 11, [5] = 10, [6] = 9, [7] = 9, [8] = 8, [9] = 8, [10] = 7 }
}

local MAX_COST_TIER = 10

-- Function to get shop odds for a specific level
function Shop.getShopOdds(level: number): {[number]: number}
	return SHOP_ODDS_BY_LEVEL[level] or SHOP_ODDS_BY_LEVEL[1]
end

-- Function to generate a random unit based on level
function Shop.generateRandomUnit(level: number): Unit?
	local odds = Shop.getShopOdds(level)

	-- Create a weighted random selection
	local totalWeight = 0
	local costWeights = {}

	for cost, weight in pairs(odds) do
		if weight > 0 then
			totalWeight = totalWeight + weight
			costWeights[cost] = weight
		end
	end

	if totalWeight == 0 then
		return nil
	end

	-- Generate random number
	local randomValue = math.random() * totalWeight
	local currentWeight = 0

	-- Find the selected cost tier
	local selectedCost = 1
	for cost, weight in pairs(costWeights) do
		currentWeight = currentWeight + weight
		if randomValue <= currentWeight then
			selectedCost = cost
			break
		end
	end

	-- Attempt to get units of the selected cost; if none exist, fallback.
	local function getFirstAvailableCost(baseCost: number): number?
		-- Prefer searching downward (more common earlier tiers)
		for c = baseCost, 1, -1 do
			local units = UnitDatabase.getUnitsByCost(c)
			if #units > 0 then
				return c
			end
		end
		-- If absolutely none below, search upward (future-proofing)
		for c = baseCost + 1, MAX_COST_TIER do
			local units = UnitDatabase.getUnitsByCost(c)
			if #units > 0 then
				return c
			end
		end
		return nil
	end

	local resolvedCost = getFirstAvailableCost(selectedCost)
	if not resolvedCost then
		return nil
	end

	local availableUnits = UnitDatabase.getUnitsByCost(resolvedCost)
	if #availableUnits == 0 then
		return nil
	end

	-- Select a random unit
	local selectedUnit = availableUnits[math.random(1, #availableUnits)]

	-- Create a tier 1 unit
	return UnitDatabase.createUnit(selectedUnit.id, 1)
end

-- Function to generate a shop for a player
function Shop.generateShop(level: number): {Unit}
	local shopUnits = {}
	
	for i = 1, Constants.SHOP_SIZE do
		local unit = Shop.generateRandomUnit(level)
		if unit then
			table.insert(shopUnits, unit)
		end
	end
	
	return shopUnits
end

-- Function to refresh shop
function Shop.refreshShop(currentShop: {Unit}, level: number): {Unit}
	return Shop.generateShop(level)
end

-- Function to purchase unit from shop
function Shop.purchaseUnit(shopUnits: {Unit}, unitIndex: number, level: number): (Unit?, {Unit})
	if unitIndex < 1 or unitIndex > #shopUnits then
		return nil, shopUnits
	end
	
	local purchasedUnit = shopUnits[unitIndex]
	
	-- Remove unit from shop
	table.remove(shopUnits, unitIndex)
	
	-- Add a new unit to maintain shop size
	local newUnit = Shop.generateRandomUnit(level)
	if newUnit then
		table.insert(shopUnits, newUnit)
	end
	
	return purchasedUnit, shopUnits
end

-- Function to check if shop can be refreshed
function Shop.canRefreshShop(lastRefresh: number): boolean
	local currentTime = os.time()
	return (currentTime - lastRefresh) >= Constants.SHOP_REFRESH_COOLDOWN
end

-- Function to get shop refresh cost
-- Dynamic refresh cost: base cost (Constants.SHOP_REFRESH_COST) + player level - 1
-- Example: base=2, level 1 => 2; level 5 => 6; level 10 => 11
function Shop.getRefreshCost(level: number): number
	return Constants.SHOP_REFRESH_COST + math.max(0, (level - 1))
end

-- Function to validate unit purchase
function Shop.validatePurchase(playerGold: number, unitCost: number): boolean
	return playerGold >= unitCost
end

-- Function to update shop units with star indicators
function Shop.updateShopWithStarIndicators(shopUnits: {Unit}, boardState: any, benchState: any): {Unit}
	for _, unit in ipairs(shopUnits) do
		if not unit.soldOut then
			local starIndicator = UnitTiering.getStarIndicator(boardState, benchState, unit.id)
			unit.starIndicator = starIndicator
		else
			unit.starIndicator = "none"
		end
	end
	return shopUnits
end

return Shop
