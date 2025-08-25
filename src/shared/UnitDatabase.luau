--[[
	UnitDatabase.luau
	Unit definitions and base stats
]]

local DataStructures = require(script.Parent.DataStructures)
local Unit = DataStructures.Unit
local UnitStats = DataStructures.UnitStats

local UnitDatabase = {}

-- Base unit definitions
local BASE_UNITS = {
	-- Tier 1 Units
	{
		id = "warrior",
		name = "Warrior",
		cost = 1,
		baseStats = {
			health = 100,
			attack = 15,
			attackSpeed = 1.0,
			range = 1,
			armor = 5,
			magicResist = 5
		},
		abilities = {
			-- Will be implemented later
		}
	},
	{
		id = "archer",
		name = "Archer",
		cost = 1,
		baseStats = {
			health = 80,
			attack = 12,
			attackSpeed = 1.2,
			range = 3,
			armor = 3,
			magicResist = 3
		},
		abilities = {
			-- Will be implemented later
		}
	},
	{
		id = "mage",
		name = "Mage",
		cost = 1,
		baseStats = {
			health = 70,
			attack = 18,
			attackSpeed = 0.8,
			range = 2,
			armor = 2,
			magicResist = 8
		},
		abilities = {
			-- Will be implemented later
		}
	},
	
	-- Tier 2 Units
	{
		id = "knight",
		name = "Knight",
		cost = 2,
		baseStats = {
			health = 150,
			attack = 20,
			attackSpeed = 0.9,
			range = 1,
			armor = 10,
			magicResist = 8
		},
		abilities = {
			-- Will be implemented later
		}
	},
	{
		id = "ranger",
		name = "Ranger",
		cost = 2,
		baseStats = {
			health = 120,
			attack = 18,
			attackSpeed = 1.4,
			range = 4,
			armor = 5,
			magicResist = 5
		},
		abilities = {
			-- Will be implemented later
		}
	},
	
	-- Tier 3 Units
	{
		id = "paladin",
		name = "Paladin",
		cost = 3,
		baseStats = {
			health = 200,
			attack = 25,
			attackSpeed = 0.8,
			range = 1,
			armor = 15,
			magicResist = 12
		},
		abilities = {
			-- Will be implemented later
		}
	}
}

-- Tier multipliers for stats
local TIER_MULTIPLIERS = {
	[1] = 1.0,   -- Base stats
	[2] = 1.5,   -- 50% increase
	[3] = 2.25   -- 125% increase from base
}

-- Function to get unit by ID
function UnitDatabase.getUnitById(id: string): Unit?
	for _, unitData in pairs(BASE_UNITS) do
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
	for _, unitData in pairs(BASE_UNITS) do
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
		attackSpeed = baseStats.attackSpeed, -- Attack speed doesn't scale with tier
		range = baseStats.range,
		armor = math.floor(baseStats.armor * multiplier),
		magicResist = math.floor(baseStats.magicResist * multiplier)
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
		id = id,
		name = baseUnit.name,
		cost = baseUnit.cost,
		tier = tier,
		stats = stats,
		abilities = baseUnit.abilities,
		position = nil,
		items = {}
	}
end

return UnitDatabase
