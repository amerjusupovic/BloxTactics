--[[
	Shop.luau
	Shop system for purchasing units
]]

local DataStructures = require(game.ReplicatedStorage.Shared.DataStructures)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local UnitDatabase = require(game.ReplicatedStorage.Shared.UnitDatabase)
local ShopData = DataStructures.ShopData
local Unit = DataStructures.Unit

local Shop = {}

-- Shop odds by level (percentage chance for each cost tier)
local SHOP_ODDS_BY_LEVEL = {
	[1] = { [1] = 100, [2] = 0, [3] = 0, [4] = 0, [5] = 0 },
	[2] = { [1] = 80, [2] = 20, [3] = 0, [4] = 0, [5] = 0 },
	[3] = { [1] = 75, [2] = 25, [3] = 0, [4] = 0, [5] = 0 },
	[4] = { [1] = 55, [2] = 30, [3] = 15, [4] = 0, [5] = 0 },
	[5] = { [1] = 45, [2] = 33, [3] = 20, [4] = 2, [5] = 0 },
	[6] = { [1] = 25, [2] = 40, [3] = 30, [4] = 5, [5] = 0 },
	[7] = { [1] = 19, [2] = 30, [3] = 35, [4] = 15, [5] = 1 },
	[8] = { [1] = 15, [2] = 20, [3] = 35, [4] = 25, [5] = 5 },
	[9] = { [1] = 10, [2] = 15, [3] = 25, [4] = 35, [5] = 15 },
	[10] = { [1] = 5, [2] = 10, [3] = 20, [4] = 40, [5] = 25 }
}

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
		totalWeight = totalWeight + weight
		costWeights[cost] = weight
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
	
	-- Get units of the selected cost
	local availableUnits = UnitDatabase.getUnitsByCost(selectedCost)
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
function Shop.getRefreshCost(): number
	return Constants.SHOP_REFRESH_COST
end

-- Function to validate unit purchase
function Shop.validatePurchase(playerGold: number, unitCost: number): boolean
	return playerGold >= unitCost
end

return Shop
