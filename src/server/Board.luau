--[[
	Board.luau
	Board state management and unit placement
]]

local DataStructures = require(game.ReplicatedStorage.Shared.DataStructures)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local BoardState = DataStructures.BoardState
local Unit = DataStructures.Unit

local Board = {}

-- Function to create a new board state
function Board.createBoardState(): BoardState
	return {
		grid = {},
		maxUnits = Constants.MAX_BOARD_UNITS,
		currentUnits = 0
	}
end

-- Function to check if a position is valid on the board
function Board.isValidPosition(position: Vector2): boolean
	return position.X >= 0 and position.X < Constants.BOARD_WIDTH and
		   position.Y >= 0 and position.Y < Constants.BOARD_HEIGHT
end

-- Function to check if a position is occupied
function Board.isPositionOccupied(boardState: BoardState, position: Vector2): boolean
	if not boardState or not boardState.grid then
		return false
	end
	
	-- Try direct access first
	if boardState.grid[position] ~= nil then
		return true
	end
	
	-- If direct access fails, search by value
	for gridPos, _ in pairs(boardState.grid) do
		if typeof(gridPos) == "Vector2" and gridPos.X == position.X and gridPos.Y == position.Y then
			return true
		end
	end
	
	return false
end

-- Function to place a unit on the board
function Board.placeUnit(boardState: BoardState, unit: Unit, position: Vector2): boolean
	-- Validate board state
	if not boardState or not boardState.grid then
		warn("Invalid board state in placeUnit")
		return false
	end
	
	-- Validate position
	if not Board.isValidPosition(position) then
		return false
	end
	
	-- Check if position is occupied
	if Board.isPositionOccupied(boardState, position) then
		return false
	end
	
	-- Check if board is full (with null safety)
	if not boardState.currentUnits then
		boardState.currentUnits = 0
	end
	if not boardState.maxUnits then
		boardState.maxUnits = Constants.MAX_BOARD_UNITS
	end
	
	if boardState.currentUnits >= boardState.maxUnits then
		return false
	end
	
	-- Place unit
	boardState.grid[position] = unit
	unit.position = position
	boardState.currentUnits = boardState.currentUnits + 1
	
	return true
end

-- Function to remove a unit from the board
function Board.removeUnit(boardState: BoardState, position: Vector2): Unit?
	if not boardState or not boardState.grid then
		return nil
	end
	
	-- Try direct access first
	local unit = boardState.grid[position]
	if unit then
		boardState.grid[position] = nil
		unit.position = nil
		if boardState.currentUnits then
			boardState.currentUnits = math.max(0, boardState.currentUnits - 1)
		end
		return unit
	end
	
	-- If direct access fails, search by value
	for gridPos, gridUnit in pairs(boardState.grid) do
		if typeof(gridPos) == "Vector2" and gridPos.X == position.X and gridPos.Y == position.Y then
			boardState.grid[gridPos] = nil
			gridUnit.position = nil
			if boardState.currentUnits then
				boardState.currentUnits = math.max(0, boardState.currentUnits - 1)
			end
			return gridUnit
		end
	end
	
	return nil
end

-- Function to move a unit on the board
function Board.moveUnit(boardState: BoardState, fromPosition: Vector2, toPosition: Vector2): boolean
	-- Validate positions
	if not Board.isValidPosition(fromPosition) or not Board.isValidPosition(toPosition) then
		return false
	end
	
	-- Check if source position has a unit
	local unit = Board.getUnitAtPosition(boardState, fromPosition)
	if not unit then
		return false
	end
	
	-- Check if destination is occupied
	if Board.isPositionOccupied(boardState, toPosition) then
		return false
	end
	
	-- Move unit
	local removedUnit = Board.removeUnit(boardState, fromPosition)
	if removedUnit then
		boardState.grid[toPosition] = unit
		unit.position = toPosition
		boardState.currentUnits = boardState.currentUnits + 1  -- Add back since removeUnit decremented it
		return true
	end
	
	return false
end

-- Function to swap units on the board
function Board.swapUnits(boardState: BoardState, position1: Vector2, position2: Vector2): boolean
	-- Validate positions
	if not Board.isValidPosition(position1) or not Board.isValidPosition(position2) then
		return false
	end
	
	-- Get units from both positions
	local unit1 = Board.getUnitAtPosition(boardState, position1)
	local unit2 = Board.getUnitAtPosition(boardState, position2)
	
	-- Check if both positions have units
	if not unit1 or not unit2 then
		return false
	end
	
	-- Swap units
	local removedUnit1 = Board.removeUnit(boardState, position1)
	local removedUnit2 = Board.removeUnit(boardState, position2)
	
	if removedUnit1 and removedUnit2 then
		boardState.grid[position1] = unit2
		boardState.grid[position2] = unit1
		unit1.position = position2
		unit2.position = position1
		boardState.currentUnits = boardState.currentUnits + 2  -- Add back since removeUnit decremented it twice
		return true
	end
	
	return false
end

-- Function to get unit at position
function Board.getUnitAtPosition(boardState: BoardState, position: Vector2): Unit?
	-- Try direct access first
	local unit = boardState.grid[position]
	if unit then
		return unit
	end
	
	-- If direct access fails, search by value
	for gridPos, gridUnit in pairs(boardState.grid) do
		if typeof(gridPos) == "Vector2" and gridPos.X == position.X and gridPos.Y == position.Y then
			return gridUnit
		end
	end
	
	return nil
end

-- Function to get all units on board
function Board.getAllUnits(boardState: BoardState): {Unit}
	local units = {}
	for position, unit in pairs(boardState.grid) do
		table.insert(units, unit)
	end
	return units
end

-- Function to get board state as grid
function Board.getBoardGrid(boardState: BoardState): {[Vector2]: Unit?}
	return boardState.grid
end

-- Function to clear the board
function Board.clearBoard(boardState: BoardState): {Unit}
	local removedUnits = {}
	for position, unit in pairs(boardState.grid) do
		table.insert(removedUnits, unit)
		unit.position = nil
	end
	
	boardState.grid = {}
	boardState.currentUnits = 0
	
	return removedUnits
end

-- Function to check if board is empty
function Board.isBoardEmpty(boardState: BoardState): boolean
	if not boardState or not boardState.currentUnits then
		return true
	end
	return boardState.currentUnits == 0
end

-- Function to check if board is full
function Board.isBoardFull(boardState: BoardState): boolean
	if not boardState or not boardState.currentUnits or not boardState.maxUnits then
		return false
	end
	return boardState.currentUnits >= boardState.maxUnits
end

-- Function to get available positions on board
function Board.getAvailablePositions(boardState: BoardState): {Vector2}
	local availablePositions = {}
	
	for x = 0, Constants.BOARD_WIDTH - 1 do
		for y = 0, Constants.BOARD_HEIGHT - 1 do
			local position = Vector2.new(x, y)
			if not Board.isPositionOccupied(boardState, position) then
				table.insert(availablePositions, position)
			end
		end
	end
	
	return availablePositions
end

-- Function to validate board state
function Board.validateBoardState(boardState: BoardState): boolean
	-- Check if current units count matches actual units
	local actualUnitCount = 0
	for _, unit in pairs(boardState.grid) do
		actualUnitCount = actualUnitCount + 1
	end
	
	return actualUnitCount == boardState.currentUnits
end

return Board
