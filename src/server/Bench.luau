--[[
	Bench.luau
	Bench state management for storing unused units
]]

local DataStructures = require(game.ReplicatedStorage.Shared.DataStructures)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local BenchState = DataStructures.BenchState
local Unit = DataStructures.Unit

local Bench = {}

-- Function to create a new bench state
function Bench.createBenchState(): BenchState
	return {
		units = {},
		maxCapacity = Constants.BENCH_CAPACITY,
		currentCapacity = 0
	}
end

-- Function to add a unit to the bench
function Bench.addUnit(benchState: BenchState, unit: Unit): (boolean, string?)
	-- Check if bench is full
	if benchState.currentCapacity >= benchState.maxCapacity then
		return false, nil
	end
	
	-- Generate unique ID for the unit
	local unitId = unit.id .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
	
	-- Find the next available slot
	local nextSlot = benchState.currentCapacity + 1
	
	-- Add unit to bench with slot information
	benchState.units[unitId] = unit
	unit.slot = nextSlot -- Store slot information in the unit
	benchState.currentCapacity = benchState.currentCapacity + 1
	
	return true, unitId
end

-- Function to remove a unit from the bench
function Bench.removeUnit(benchState: BenchState, unitId: string): Unit?
	local unit = benchState.units[unitId]
	if unit then
		benchState.units[unitId] = nil
		benchState.currentCapacity = benchState.currentCapacity - 1
		return unit
	end
	return nil
end

-- Function to get a unit from the bench
function Bench.getUnit(benchState: BenchState, unitId: string): Unit?
	return benchState.units[unitId]
end

-- Function to get all units on the bench
function Bench.getAllUnits(benchState: BenchState): {Unit}
	local units = {}
	for unitId, unit in pairs(benchState.units) do
		table.insert(units, unit)
	end
	return units
end

-- Function to check if bench is full
function Bench.isBenchFull(benchState: BenchState): boolean
	return benchState.currentCapacity >= benchState.maxCapacity
end

-- Function to check if bench is empty
function Bench.isBenchEmpty(benchState: BenchState): boolean
	return benchState.currentCapacity == 0
end

-- Function to get available capacity
function Bench.getAvailableCapacity(benchState: BenchState): number
	return benchState.maxCapacity - benchState.currentCapacity
end

-- Function to clear the bench
function Bench.clearBench(benchState: BenchState): {Unit}
	local removedUnits = {}
	for unitId, unit in pairs(benchState.units) do
		table.insert(removedUnits, unit)
	end
	
	benchState.units = {}
	benchState.currentCapacity = 0
	
	return removedUnits
end

-- Function to find units by type
function Bench.findUnitsByType(benchState: BenchState, unitType: string): {Unit}
	local foundUnits = {}
	for unitId, unit in pairs(benchState.units) do
		if unit.id == unitType then
			table.insert(foundUnits, unit)
		end
	end
	return foundUnits
end

-- Function to get the bench slot number for a unit
function Bench.getUnitSlot(benchState: BenchState, unitId: string): number?
	for id, unit in pairs(benchState.units) do
		if id == unitId then
			return unit.slot
		end
	end
	return nil
end

-- Function to get a unit at a specific bench slot
function Bench.getUnitAtSlot(benchState: BenchState, slot: number): Unit?
	for unitId, unit in pairs(benchState.units) do
		if unit.slot == slot then
			return unit
		end
	end
	return nil
end

-- Function to remove a unit from a specific bench slot
function Bench.removeUnitFromSlot(benchState: BenchState, slot: number): boolean
	for unitId, unit in pairs(benchState.units) do
		if unit.slot == slot then
			benchState.units[unitId] = nil
			benchState.currentCapacity = benchState.currentCapacity - 1
			return true
		end
	end
	return false
end

-- Function to place a unit in a specific bench slot
function Bench.placeUnitInSlot(benchState: BenchState, unit: Unit, slot: number, existingUnitId: string?): boolean
	-- Check if slot is valid
	if slot < 1 or slot > benchState.maxCapacity then
		return false
	end
	
	-- Use existing unit ID if provided, otherwise generate new one
	local unitId = existingUnitId or (unit.id .. "_" .. os.time() .. "_" .. math.random(1000, 9999))
	
	-- Add unit to bench with slot information
	benchState.units[unitId] = unit
	unit.slot = slot -- Store slot information in the unit
	benchState.currentCapacity = benchState.currentCapacity + 1
	
	return true
end

-- Function to move a unit from one slot to another
function Bench.moveUnitToSlot(benchState: BenchState, fromSlot: number, toSlot: number): boolean
	-- Check if slots are valid
	if fromSlot < 1 or fromSlot > benchState.maxCapacity or toSlot < 1 or toSlot > benchState.maxCapacity then
		return false
	end
	
	-- Get unit from source slot
	local unit = Bench.getUnitAtSlot(benchState, fromSlot)
	if not unit then
		return false
	end
	
	-- Find the unit ID by iterating through units in order
	local unitId = nil
	local slotIndex = 1
	local unitIds = {}
	for id, _ in pairs(benchState.units) do
		table.insert(unitIds, id)
	end
	table.sort(unitIds) -- Sort to ensure consistent order
	
	for _, id in ipairs(unitIds) do
		if slotIndex == fromSlot then
			unitId = id
			break
		end
		slotIndex = slotIndex + 1
	end
	
	-- Remove from source slot
	local removeSuccess = Bench.removeUnitFromSlot(benchState, fromSlot)
	if not removeSuccess then
		return false
	end
	
	-- Add to destination slot with the same unit ID
	return Bench.placeUnitInSlot(benchState, unit, toSlot, unitId)
end

-- Function to swap units between two bench slots
function Bench.swapUnits(benchState: BenchState, slot1: number, slot2: number): boolean
	-- Check if slots are valid
	if slot1 < 1 or slot1 > benchState.maxCapacity or slot2 < 1 or slot2 > benchState.maxCapacity then
		return false
	end
	
	-- Get units from both slots
	local unit1 = Bench.getUnitAtSlot(benchState, slot1)
	local unit2 = Bench.getUnitAtSlot(benchState, slot2)
	
	-- Find unit IDs by iterating through units in order
	local unit1Id = nil
	local unit2Id = nil
	local unitIds = {}
	for id, _ in pairs(benchState.units) do
		table.insert(unitIds, id)
	end
	table.sort(unitIds) -- Sort to ensure consistent order
	
	local slotIndex = 1
	for _, id in ipairs(unitIds) do
		if slotIndex == slot1 then
			unit1Id = id
		elseif slotIndex == slot2 then
			unit2Id = id
		end
		slotIndex = slotIndex + 1
	end
	
	-- Remove units from both slots
	local remove1Success = Bench.removeUnitFromSlot(benchState, slot1)
	local remove2Success = Bench.removeUnitFromSlot(benchState, slot2)
	
	if not remove1Success or not remove2Success then
		return false
	end
	
	-- Place units in opposite slots with preserved IDs
	local place1Success = Bench.placeUnitInSlot(benchState, unit1, slot2, unit1Id)
	local place2Success = Bench.placeUnitInSlot(benchState, unit2, slot1, unit2Id)
	
	return place1Success and place2Success
end

-- Function to validate bench state
function Bench.validateBenchState(benchState: BenchState): boolean
	-- Check if current capacity matches actual units
	local actualUnitCount = 0
	for _, unit in pairs(benchState.units) do
		actualUnitCount = actualUnitCount + 1
	end
	
	return actualUnitCount == benchState.currentCapacity
end

return Bench
