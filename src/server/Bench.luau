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
	
	-- Add unit to bench
	benchState.units[unitId] = unit
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
	local slotIndex = 1
	for id, unit in pairs(benchState.units) do
		if id == unitId then
			return slotIndex
		end
		slotIndex = slotIndex + 1
	end
	return nil
end

-- Function to get a unit at a specific bench slot
function Bench.getUnitAtSlot(benchState: BenchState, slot: number): Unit?
	local slotIndex = 1
	for unitId, unit in pairs(benchState.units) do
		if slotIndex == slot then
			return unit
		end
		slotIndex = slotIndex + 1
	end
	return nil
end

-- Function to remove a unit from a specific bench slot
function Bench.removeUnitFromSlot(benchState: BenchState, slot: number): boolean
	local slotIndex = 1
	for unitId, unit in pairs(benchState.units) do
		if slotIndex == slot then
			benchState.units[unitId] = nil
			benchState.currentCapacity = benchState.currentCapacity - 1
			return true
		end
		slotIndex = slotIndex + 1
	end
	return false
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
