--[[
	UnitTiering.luau
	Unit tiering and combination system
]]

local DataStructures = require(script.Parent.DataStructures)
local Constants = require(script.Parent.Constants)
local Unit = DataStructures.Unit

local UnitTiering = {}

-- Function to check if units can be combined
function UnitTiering.canCombineUnits(units: {Unit}): boolean
	if #units < Constants.UNITS_FOR_TIER_UP then
		return false
	end
	
	-- Check if all units are the same type and tier
	local firstUnit = units[1]
	for _, unit in ipairs(units) do
		if unit.id ~= firstUnit.id or unit.tier ~= firstUnit.tier then
			return false
		end
	end
	
	return true
end

-- Function to combine units into a higher tier
function UnitTiering.combineUnits(units: {Unit}): Unit?
	if not UnitTiering.canCombineUnits(units) then
		return nil
	end
	
	local firstUnit = units[1]
	local newTier = firstUnit.tier + 1
	
	-- Create the new higher tier unit
	local combinedUnit = {
		id = firstUnit.id,
		name = firstUnit.name,
		cost = firstUnit.cost,
		tier = newTier,
		stats = firstUnit.stats, -- Will be recalculated based on tier
		abilities = firstUnit.abilities,
		position = nil,
		items = {} -- Combine items from all units
	}
	
	-- Combine items from all units
	for _, unit in ipairs(units) do
		for itemId, item in pairs(unit.items) do
			combinedUnit.items[itemId] = item
		end
	end
	
	return combinedUnit
end

-- Function to find combinable units in a collection
function UnitTiering.findCombinableUnits(units: {Unit}): {[string]: {Unit}}
	local unitGroups = {}
	
	-- Group units by type and tier
	for _, unit in ipairs(units) do
		local key = unit.id .. "_" .. unit.tier
		if not unitGroups[key] then
			unitGroups[key] = {}
		end
		table.insert(unitGroups[key], unit)
	end
	
	-- Find groups that can be combined
	local combinableGroups = {}
	for key, group in pairs(unitGroups) do
		if #group >= Constants.UNITS_FOR_TIER_UP then
			combinableGroups[key] = group
		end
	end
	
	return combinableGroups
end

-- Function to auto-combine units in a collection
function UnitTiering.autoCombineUnits(units: {Unit}): ({Unit}, {Unit})
	local originalUnits = units
	local newUnits = {}
	local combinedUnits = {}
	
	-- Find combinable groups
	local combinableGroups = UnitTiering.findCombinableUnits(units)
	
	-- Process each combinable group
	for key, group in pairs(combinableGroups) do
		local unitsToCombine = {}
		local remainingUnits = {}
		
		-- Take the required number of units for combination
		for i = 1, Constants.UNITS_FOR_TIER_UP do
			table.insert(unitsToCombine, group[i])
		end
		
		-- Add remaining units to the list
		for i = Constants.UNITS_FOR_TIER_UP + 1, #group do
			table.insert(remainingUnits, group[i])
		end
		
		-- Combine the units
		local combinedUnit = UnitTiering.combineUnits(unitsToCombine)
		if combinedUnit then
			table.insert(combinedUnits, combinedUnit)
		end
		
		-- Add remaining units to new units list
		for _, unit in ipairs(remainingUnits) do
			table.insert(newUnits, unit)
		end
	end
	
	-- Add units that weren't part of any combinable group
	for _, unit in ipairs(originalUnits) do
		local wasUsed = false
		for _, group in pairs(combinableGroups) do
			for _, groupUnit in ipairs(group) do
				if groupUnit == unit then
					wasUsed = true
					break
				end
			end
			if wasUsed then break end
		end
		
		if not wasUsed then
			table.insert(newUnits, unit)
		end
	end
	
	return newUnits, combinedUnits
end

return UnitTiering
