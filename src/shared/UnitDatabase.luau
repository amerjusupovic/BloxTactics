--[[
	UnitDatabase.luau
	Unit definitions and database management
]]

local DataStructures = require(script.Parent.DataStructures)
local Unit = DataStructures.Unit
local UnitStats = DataStructures.UnitStats

local UnitDatabase = {}

-- Base unit definitions
local BASE_UNITS = {
	{
		id = "knight",
		name = "Knight",
		cost = 3,
		imageAssetId = "rbxassetid://120796668963757", -- Stock knight image
		baseStats = {
			health = 100,
			attack = 25,
			armor = 15,
			magicResist = 10,
			attackSpeed = 1.0,
			range = 1
		},
		abilities = {}
	},
	{
		id = "warrior",
		name = "Warrior",
		cost = 1,
		imageAssetId = "rbxassetid://99667859237167", -- Warrior image
		baseStats = {
			health = 60,
			attack = 15,
			armor = 5,
			magicResist = 5,
			attackSpeed = 1.2,
			range = 1
		},
		abilities = {}
	},
	{
		id = "archer",
		name = "Archer",
		cost = 2,
		imageAssetId = "rbxassetid://122049079845272", -- Archer image
		baseStats = {
			health = 50,
			attack = 20,
			armor = 3,
			magicResist = 3,
			attackSpeed = 1.5,
			range = 3
		},
		abilities = {}
	},
	{
		id = "mage",
		name = "Mage",
		cost = 4,
		imageAssetId = "rbxassetid://135628423497794", -- Placeholder hex image
		baseStats = {
			health = 40,
			attack = 35,
			armor = 2,
			magicResist = 20,
			attackSpeed = 0.8,
			range = 2
		},
		abilities = {}
	},
	{
		id = "tank",
		name = "Tank",
		cost = 5,
		imageAssetId = "rbxassetid://135628423497794", -- Placeholder hex image
		baseStats = {
			health = 150,
			attack = 20,
			armor = 25,
			magicResist = 15,
			attackSpeed = 0.7,
			range = 1
		},
		abilities = {}
	}
}

-- Tier multipliers for unit stats
local TIER_MULTIPLIERS = {
	[1] = 1.0,
	[2] = 1.5,
	[3] = 2.25
}

-- Function to get unit by ID
function UnitDatabase.getUnitById(id: string): Unit?
	for _, unitData in ipairs(BASE_UNITS) do
		if unitData.id == id then
			return unitData
		end
	end
	return nil
end

-- Function to get all units
function UnitDatabase.getAllUnits(): {Unit}
	return BASE_UNITS
end

-- Function to get units by cost
function UnitDatabase.getUnitsByCost(cost: number): {Unit}
	local units = {}
	for _, unitData in ipairs(BASE_UNITS) do
		if unitData.cost == cost then
			table.insert(units, unitData)
		end
	end
	return units
end

-- Function to calculate unit stats based on tier
function UnitDatabase.calculateUnitStats(baseStats: UnitStats, tier: number): UnitStats
	local multiplier = TIER_MULTIPLIERS[tier] or 1.0
	
	return {
		health = math.floor(baseStats.health * multiplier),
		attack = math.floor(baseStats.attack * multiplier),
		armor = math.floor(baseStats.armor * multiplier),
		magicResist = math.floor(baseStats.magicResist * multiplier),
		attackSpeed = baseStats.attackSpeed,
		range = baseStats.range
	}
end

-- Function to create a unit instance
function UnitDatabase.createUnit(id: string, tier: number): Unit?
	local baseUnit = UnitDatabase.getUnitById(id)
	if not baseUnit then
		return nil
	end
	
	local stats = UnitDatabase.calculateUnitStats(baseUnit.baseStats, tier)
	
	return {
		id = baseUnit.id,
		name = baseUnit.name,
		cost = baseUnit.cost,
		tier = tier,
		stats = stats,
		abilities = baseUnit.abilities,
		position = nil,
		imageAssetId = baseUnit.imageAssetId
	}
end

return UnitDatabase
