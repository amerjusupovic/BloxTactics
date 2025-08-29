--[[
	UnitTiering.luau
	Unit tiering and combination logic
]]

local DataStructures = require(script.Parent.DataStructures)
local Unit = DataStructures.Unit
local BoardState = DataStructures.BoardState
local BenchState = DataStructures.BenchState

local UnitTiering = {}

-- Maximum tier for units
local MAX_TIER = 3

-- Function to count units of a specific type and tier
function UnitTiering.countUnitsByTypeAndTier(boardState: BoardState, benchState: BenchState, unitId: string, tier: number): number
	local count = 0
	
	-- Count units on board
	if boardState and boardState.grid then
		for _, unit in pairs(boardState.grid) do
			if unit and unit.id == unitId and unit.tier == tier then
				count = count + 1
			end
		end
	end
	
	-- Count units on bench
	if benchState and benchState.units then
		for _, unit in pairs(benchState.units) do
			if unit and unit.id == unitId and unit.tier == tier then
				count = count + 1
			end
		end
	end
	
	return count
end

-- Function to get all units of a specific type
function UnitTiering.getUnitsByType(boardState: BoardState, benchState: BenchState, unitId: string): {Unit}
	local units = {}
	
	-- Get units from board
	if boardState and boardState.grid then
		for _, unit in pairs(boardState.grid) do
			if unit and unit.id == unitId then
				table.insert(units, unit)
			end
		end
	end
	
	-- Get units from bench
	if benchState and benchState.units then
		for _, unit in pairs(benchState.units) do
			if unit and unit.id == unitId then
				table.insert(units, unit)
			end
		end
	end
	
	return units
end

-- Function to check if a unit can be combined to create a higher tier
function UnitTiering.canCombineToTier(boardState: BoardState, benchState: BenchState, unitId: string, targetTier: number): boolean
	if targetTier <= 1 or targetTier > MAX_TIER then
		return false
	end
	
	-- Calculate how many tier 1 units are needed for the target tier
	local unitsNeeded = 3 ^ (targetTier - 1) -- 3 for tier 2, 9 for tier 3
	
	-- Count available tier 1 units
	local tier1Count = UnitTiering.countUnitsByTypeAndTier(boardState, benchState, unitId, 1)
	
	-- If we need tier 2, also count tier 2 units (each tier 2 = 3 tier 1)
	if targetTier == 2 then
		local tier2Count = UnitTiering.countUnitsByTypeAndTier(boardState, benchState, unitId, 2)
		tier1Count = tier1Count + (tier2Count * 3)
	elseif targetTier == 3 then
		local tier2Count = UnitTiering.countUnitsByTypeAndTier(boardState, benchState, unitId, 2)
		local tier3Count = UnitTiering.countUnitsByTypeAndTier(boardState, benchState, unitId, 3)
		tier1Count = tier1Count + (tier2Count * 3) + (tier3Count * 9)
	end
	
	return tier1Count >= unitsNeeded
end

-- Function to calculate the tier that would be created if a unit is purchased
function UnitTiering.calculateTierUpResult(boardState: BoardState, benchState: BenchState, unitId: string): number?
	-- Count existing units by tier
	local tier1Count = UnitTiering.countUnitsByTypeAndTier(boardState, benchState, unitId, 1)
	local tier2Count = UnitTiering.countUnitsByTypeAndTier(boardState, benchState, unitId, 2)
	local tier3Count = UnitTiering.countUnitsByTypeAndTier(boardState, benchState, unitId, 3)
	
	-- Add the unit being purchased (assumed to be tier 1)
	tier1Count = tier1Count + 1
	
	-- Check if we can create tier 3 first (need exactly 9 tier 1 units OR 3 tier 2 units)
	if tier3Count == 0 then
		if tier1Count >= 9 then
			return 3 -- Can create tier 3 from 9 tier 1 units
		elseif tier2Count >= 3 then
			return 3 -- Can create tier 3 from 3 tier 2 units
		end
	end
	
	-- Check if we can create tier 2 (need exactly 3 tier 1 units)
	if tier1Count >= 3 then
		return 2 -- Can create tier 2
	end
	
	return nil -- No tier up possible
end

-- Function to check if there are any automatic combinations that should happen
function UnitTiering.checkForAutomaticCombinations(boardState: BoardState, benchState: BenchState): {unitId: string, targetTier: number}?
	-- Get all unique unit types
	local unitTypes = {}
	
	-- Collect unit types from board
	if boardState and boardState.grid then
		for _, unit in pairs(boardState.grid) do
			if unit and unit.id then
				unitTypes[unit.id] = true
			end
		end
	end
	
	-- Collect unit types from bench
	if benchState and benchState.units then
		for _, unit in pairs(benchState.units) do
			if unit and unit.id then
				unitTypes[unit.id] = true
			end
		end
	end
	
	-- Check each unit type for automatic combinations
	for unitId, _ in pairs(unitTypes) do
		local tier1Count = UnitTiering.countUnitsByTypeAndTier(boardState, benchState, unitId, 1)
		local tier2Count = UnitTiering.countUnitsByTypeAndTier(boardState, benchState, unitId, 2)
		local tier3Count = UnitTiering.countUnitsByTypeAndTier(boardState, benchState, unitId, 3)
		
		-- Check for tier 3 combination (3 tier 2 units)
		if tier3Count == 0 and tier2Count >= 3 then
			return {unitId = unitId, targetTier = 3}
		end
		
		-- Check for tier 2 combination (3 tier 1 units)
		if tier2Count == 0 and tier1Count >= 3 then
			return {unitId = unitId, targetTier = 2}
		end
	end
	
	return nil
end

-- Function to get the star indicator type for a shop unit
function UnitTiering.getStarIndicator(boardState: BoardState, benchState: BenchState, unitId: string): "none" | "silver" | "gold"
	local tierUpResult = UnitTiering.calculateTierUpResult(boardState, benchState, unitId)
	
	if tierUpResult == 2 then
		return "silver" -- 2 silver stars for tier 2
	elseif tierUpResult == 3 then
		return "gold" -- 3 gold stars for tier 3
	else
		return "none" -- No stars
	end
end

-- Function to find units to combine for tier up
function UnitTiering.findUnitsToCombine(boardState: BoardState, benchState: BenchState, unitId: string, targetTier: number): {Unit}
	local unitsToCombine = {}
	
	-- Get all units of this type
	local allUnits = UnitTiering.getUnitsByType(boardState, benchState, unitId)
	
	-- Sort by tier (prefer lower tiers first for combination)
	table.sort(allUnits, function(a, b)
		return a.tier < b.tier
	end)
	
	-- For tier 2, we need 3 tier 1 units
	if targetTier == 2 then
		local tier1Count = 0
		for _, unit in ipairs(allUnits) do
			if unit.tier == 1 and tier1Count < 3 then
				table.insert(unitsToCombine, unit)
				tier1Count = tier1Count + 1
			end
		end
	-- For tier 3, we need 3 tier 2 units OR 9 tier 1 units
	elseif targetTier == 3 then
		local tier1Count = 0
		local tier2Count = 0
		
		-- Count available units
		for _, unit in ipairs(allUnits) do
			if unit.tier == 2 then
				tier2Count = tier2Count + 1
			end
		end
		
		if tier2Count >= 3 then
			-- Use 3 tier 2 units
			local used = 0
			for _, unit in ipairs(allUnits) do
				if unit.tier == 2 and used < 3 then
					table.insert(unitsToCombine, unit)
					used = used + 1
				end
			end
		else
			-- Use 9 tier 1 units
			for _, unit in ipairs(allUnits) do
				if unit.tier == 1 and tier1Count < 9 then
					table.insert(unitsToCombine, unit)
					tier1Count = tier1Count + 1
				end
			end
		end
	end
	
	return unitsToCombine
end

-- Function to remove units from board/bench for combination
function UnitTiering.removeUnitsForCombination(boardState: BoardState, benchState: BenchState, unitsToRemove: {Unit}): {Vector2}
	local removedPositions = {}
	
	for _, unitToRemove in ipairs(unitsToRemove) do
		-- Search on board
		if boardState and boardState.grid then
			for position, unit in pairs(boardState.grid) do
				if unit == unitToRemove then
					boardState.grid[position] = nil
					unit.position = nil
					if boardState.currentUnits then
						boardState.currentUnits = math.max(0, boardState.currentUnits - 1)
					end
					table.insert(removedPositions, position)
					break
				end
			end
		end
		
		-- Search on bench
		if benchState and benchState.units then
			for unitId, unit in pairs(benchState.units) do
				if unit == unitToRemove then
					benchState.units[unitId] = nil
					if benchState.currentCapacity then
						benchState.currentCapacity = math.max(0, benchState.currentCapacity - 1)
					end
					break
				end
			end
		end
	end
	
	return removedPositions
end

return UnitTiering
