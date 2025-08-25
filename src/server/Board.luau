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
	return boardState.grid[position] ~= nil
end

-- Function to place a unit on the board
function Board.placeUnit(boardState: BoardState, unit: Unit, position: Vector2): boolean
	-- Validate position
	if not Board.isValidPosition(position) then
		return false
	end
	
	-- Check if position is occupied
	if Board.isPositionOccupied(boardState, position) then
		return false
	end
	
	-- Check if board is full
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
	local unit = boardState.grid[position]
	if unit then
		boardState.grid[position] = nil
		unit.position = nil
		boardState.currentUnits = boardState.currentUnits - 1
		return unit
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
	local unit = boardState.grid[fromPosition]
	if not unit then
		return false
	end
	
	-- Check if destination is occupied
	if Board.isPositionOccupied(boardState, toPosition) then
		return false
	end
	
	-- Move unit
	boardState.grid[fromPosition] = nil
	boardState.grid[toPosition] = unit
	unit.position = toPosition
	
	return true
end

-- Function to get unit at position
function Board.getUnitAtPosition(boardState: BoardState, position: Vector2): Unit?
	return boardState.grid[position]
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
	return boardState.currentUnits == 0
end

-- Function to check if board is full
function Board.isBoardFull(boardState: BoardState): boolean
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
