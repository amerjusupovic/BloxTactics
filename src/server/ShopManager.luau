--[[
	ShopManager.luau
	Server-side shop management and unit placement
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataManager = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)
local Board = require(script.Parent.Board)
local Bench = require(script.Parent.Bench)
local UnitSpawner = require(script.Parent.UnitSpawner)
-- local RemoteEvents = require(script.Parent.RemoteEvents) -- No longer needed, using direct access
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local DataStructures = require(game.ReplicatedStorage.Shared.DataStructures)
local UnitTiering = require(game.ReplicatedStorage.Shared.UnitTiering)
local UnitDatabase = require(game.ReplicatedStorage.Shared.UnitDatabase)
local GameUtils = require(game.ReplicatedStorage.Shared.GameUtils)

local ShopManager = {}

-- Player shop data cache
local playerShops = {}

-- Function to initialize player shop
function ShopManager.initializePlayerShop(userId: number)
	local playerData = PlayerDataManager.getPlayerData(userId)
	if not playerData then return end
	
	-- Check if player already has a shop state in their data
	if playerData.shopState and playerData.shopState.units and #playerData.shopState.units > 0 then
		-- Use existing shop state
		playerShops[userId] = {
			units = playerData.shopState.units,
			lastRefresh = playerData.shopState.lastRefresh
		}
		print("Restored existing shop for player " .. userId .. " with " .. #playerData.shopState.units .. " units")
	else
		-- Generate new shop
		local shopUnits = Shop.generateShop(playerData.level)
		playerShops[userId] = {
			units = shopUnits,
			lastRefresh = os.time()
		}
		
		-- Save shop state to player data
		playerData.shopState = {
			units = shopUnits,
			lastRefresh = os.time()
		}
		PlayerDataManager.savePlayerData(userId)
		print("Generated new shop for player " .. userId)
	end
	
	-- Send shop to client
	ShopManager.sendShopToClient(userId)
end

-- Function to send shop to client
function ShopManager.sendShopToClient(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	if not player then return end
	
	local shopData = playerShops[userId]
	if not shopData then return end
	
	local playerData = PlayerDataManager.getPlayerData(userId)
	if not playerData then return end
	
	-- Update shop units with star indicators
	local updatedShopUnits = Shop.updateShopWithStarIndicators(shopData.units, playerData.boardState, playerData.benchState)
	
	local updateShopEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("UpdateShop")
	if updateShopEvent then
		updateShopEvent:FireClient(player, updatedShopUnits)
		print("Sent shop update to client for user: " .. userId)
	else
		warn("UpdateShop RemoteEvent not found!")
	end
end

-- Function to handle unit purchase
function ShopManager.handleUnitPurchase(userId: number, shopIndex: number)
	local player = Players:GetPlayerByUserId(userId)
	if not player then return false end
	
	local playerData = PlayerDataManager.getPlayerData(userId)
	if not playerData then return false end
	
	local shopData = playerShops[userId]
	if not shopData then return false end
	
	-- Validate shop index
	if shopIndex < 1 or shopIndex > #shopData.units then
		return false
	end
	
	local unit = shopData.units[shopIndex]
	if not unit then return false end
	
	-- Check if unit is already sold out
	if unit.soldOut then
		ShopManager.sendNotification(userId, "This unit is already sold out!", 3)
		return false
	end
	
	-- Check if player has enough gold
	if playerData.gold < unit.cost then
		-- Send insufficient funds message
		ShopManager.sendNotification(userId, "Insufficient gold! Need " .. unit.cost .. " gold.", 3)
		return false
	end
	
	-- Check for tier-up possibility
	local tierUpResult = UnitTiering.calculateTierUpResult(playerData.boardState, playerData.benchState, unit.id)
	
	if tierUpResult then
		-- Perform tier-up combination
		local success = ShopManager.performTierUp(userId, unit, tierUpResult)
		if success then
			-- Mark unit as sold out
			unit.soldOut = true
			
			-- Check for automatic combinations after tier-up
			ShopManager.checkAndPerformAutomaticCombinations(userId)
			
			-- Save player data
			PlayerDataManager.savePlayerData(userId)
			
			-- Update client
			ShopManager.sendShopToClient(userId)
			ShopManager.sendBoardUpdate(userId)
			ShopManager.sendBenchUpdate(userId)
			-- Immediately push updated player stats so gold/etc reflect new state after combination
			ShopManager.sendPlayerDataUpdate(userId)
			ShopManager.sendNotification(userId, "Unit combined to tier " .. tierUpResult .. "!", 3)
			
			return true
		end
	end
	
	-- No tier-up possible, place normally
	-- Check if bench has space
	if Bench.isBenchFull(playerData.benchState) then
		-- Check if board has capacity first
		if Board.isBoardFull(playerData.boardState) then
			ShopManager.sendNotification(userId, "Board is full! Max units: " .. playerData.boardState.maxUnits, 3)
			return false
		end
		
		-- Try to place on board
		local availablePosition = Board.getAvailablePositions(playerData.boardState)[1]
		if not availablePosition then
			ShopManager.sendNotification(userId, "No space on board or bench!", 3)
			return false
		end
		
		-- Place on board
		if Board.placeUnit(playerData.boardState, unit, availablePosition) then
			-- Deduct gold
			PlayerDataManager.spendGold(userId, unit.cost)
			
			-- Spawn physical unit on board
			UnitSpawner.spawnUnitOnBoard(userId, unit, availablePosition)
			
			-- Mark unit as sold out instead of removing it
			unit.soldOut = true
			
			-- Update shop state in player data
			local currentPlayerData = PlayerDataManager.getPlayerData(userId)
			if currentPlayerData then
				currentPlayerData.shopState = {
					units = shopData.units,
					lastRefresh = shopData.lastRefresh
				}
			end
			
			-- Check for automatic combinations after placement
			ShopManager.checkAndPerformAutomaticCombinations(userId)
			
			-- Save player data
			PlayerDataManager.savePlayerData(userId)
			
			-- Update client
			ShopManager.sendShopToClient(userId)
			ShopManager.sendBoardUpdate(userId)
			ShopManager.sendNotification(userId, "Unit placed on board!", 2)
			
			-- Send updated player data to client
			ShopManager.sendPlayerDataUpdate(userId)
			
			return true
		end
	else
		-- Place on bench
		local success, uniqueUnitId = Bench.addUnit(playerData.benchState, unit)
		if success then
			-- Deduct gold
			PlayerDataManager.spendGold(userId, unit.cost)
			
			-- Find the bench slot where the unit was placed
			local benchSlot = Bench.getUnitSlot(playerData.benchState, uniqueUnitId)
			if benchSlot then
				-- Spawn physical unit on bench
				UnitSpawner.spawnUnitOnBench(userId, unit, benchSlot)
			end
			
			-- Mark unit as sold out instead of removing it
			unit.soldOut = true
			
			-- Update shop state in player data
			local currentPlayerData = PlayerDataManager.getPlayerData(userId)
			if currentPlayerData then
				currentPlayerData.shopState = {
					units = shopData.units,
					lastRefresh = shopData.lastRefresh
				}
			end
			
			-- Check for automatic combinations after placement
			ShopManager.checkAndPerformAutomaticCombinations(userId)
			
			-- Save player data
			PlayerDataManager.savePlayerData(userId)
			
			-- Update client
			ShopManager.sendShopToClient(userId)
			ShopManager.sendBenchUpdate(userId)
			ShopManager.sendNotification(userId, "Unit placed on bench!", 2)
			
			-- Send updated player data to client
			ShopManager.sendPlayerDataUpdate(userId)
			
			return true
		end
	end
	
	return false
end

-- Function to check and perform automatic combinations
function ShopManager.checkAndPerformAutomaticCombinations(userId: number)
	local playerData = PlayerDataManager.getPlayerData(userId)
	if not playerData then return end
	
	-- Check for automatic combinations
	local combination = UnitTiering.checkForAutomaticCombinations(playerData.boardState, playerData.benchState)
	
	while combination do
		-- Find units to combine
		local unitsToCombine = UnitTiering.findUnitsToCombine(playerData.boardState, playerData.benchState, combination.unitId, combination.targetTier)
		
		if #unitsToCombine > 0 then
			-- Remove the units that will be combined
			local removedPositions = UnitTiering.removeUnitsForCombination(playerData.boardState, playerData.benchState, unitsToCombine)
			
			-- Remove physical units from board
			for _, position in ipairs(removedPositions) do
				UnitSpawner.removeUnitFromBoard(userId, position)
			end
			
			-- Remove physical units from bench
			for _, unit in ipairs(unitsToCombine) do
				if unit.slot then -- This is a bench unit
					UnitSpawner.removeUnitFromBench(userId, unit.slot)
				end
			end
			
			-- Create the new higher tier unit
			local newUnit = UnitDatabase.createUnit(combination.unitId, combination.targetTier)
			if newUnit then
				-- Place the new unit on bench (prefer bench over board for automatic combinations)
				local success, uniqueUnitId = Bench.addUnit(playerData.benchState, newUnit)
				if success then
					local benchSlot = Bench.getUnitSlot(playerData.benchState, uniqueUnitId)
					if benchSlot then
						UnitSpawner.spawnUnitOnBench(userId, newUnit, benchSlot)
					end
				else
					-- Try to place on board if bench is full
					if not Board.isBoardFull(playerData.boardState) then
						local availablePosition = Board.getAvailablePositions(playerData.boardState)[1]
						if availablePosition and Board.placeUnit(playerData.boardState, newUnit, availablePosition) then
							UnitSpawner.spawnUnitOnBoard(userId, newUnit, availablePosition)
						end
					else
						-- Board is full, unit is lost (this is expected behavior for auto-combinations)
						print("Board is full, auto-combined unit " .. newUnit.name .. " was lost")
					end
				end
				
				-- Send notification
				ShopManager.sendNotification(userId, "Automatic combination! Created tier " .. combination.targetTier .. " " .. newUnit.name .. "!", 3)
			end
		end
		
		-- Check for more combinations
		combination = UnitTiering.checkForAutomaticCombinations(playerData.boardState, playerData.benchState)
	end
	
	-- Update clients after all combinations
	ShopManager.sendBoardUpdate(userId)
	ShopManager.sendBenchUpdate(userId)
end

-- Function to send board update to client
function ShopManager.sendBoardUpdate(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	if not player then return end
	
	local playerData = PlayerDataManager.getPlayerData(userId)
	if not playerData then return end
	
	local updateBoardEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("UpdateBoard")
	if updateBoardEvent then
		updateBoardEvent:FireClient(player, playerData.boardState)
		print("Sent board update to client for user: " .. userId)
	else
		warn("UpdateBoard RemoteEvent not found!")
	end
end

-- Function to send bench update to client
function ShopManager.sendBenchUpdate(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	if not player then return end
	
	local playerData = PlayerDataManager.getPlayerData(userId)
	if not playerData then return end
	
	local updateBenchEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("UpdateBench")
	if updateBenchEvent then
		updateBenchEvent:FireClient(player, playerData.benchState)
		print("Sent bench update to client for user: " .. userId)
	else
		warn("UpdateBench RemoteEvent not found!")
	end
end

-- Function to send notification to client
function ShopManager.sendNotification(userId: number, message: string, duration: number)
	local player = Players:GetPlayerByUserId(userId)
	if not player then return end
	
	local notificationEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("ShowNotification")
	if notificationEvent then
		notificationEvent:FireClient(player, message, duration)
		print("Sent notification to client for user: " .. userId .. ": " .. message)
	else
		warn("ShowNotification RemoteEvent not found!")
	end
end

-- Function to send player data update to client
function ShopManager.sendPlayerDataUpdate(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	if not player then return end
	
	local playerData = PlayerDataManager.getPlayerData(userId)
	if not playerData then return end
	
	local updatePlayerDataEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("UpdatePlayerData")
	if updatePlayerDataEvent then
		updatePlayerDataEvent:FireClient(player, playerData)
		print("Sent player data update to client for user: " .. userId)
	else
		warn("UpdatePlayerData RemoteEvent not found!")
	end
end

-- Function to refresh shop
function ShopManager.refreshShop(userId: number)
	local playerData = PlayerDataManager.getPlayerData(userId)
	if not playerData then return false end
	
	-- Check if player has enough gold for refresh
	local refreshCost = Shop.getRefreshCost(playerData.level)
	if playerData.gold < refreshCost then
		ShopManager.sendNotification(userId, "Insufficient gold for refresh! Need " .. refreshCost .. " gold.", 3)
		return false
	end
	
	-- Deduct gold
	PlayerDataManager.spendGold(userId, refreshCost)
	
	-- Generate new shop
	local shopUnits = Shop.generateShop(playerData.level)
	playerShops[userId] = {
		units = shopUnits,
		lastRefresh = os.time()
	}
	
	-- Update shop state in player data
	playerData.shopState = {
		units = shopUnits,
		lastRefresh = os.time()
	}
	
	-- Send to client
	ShopManager.sendShopToClient(userId)
	ShopManager.sendNotification(userId, "Shop refreshed!", 2)
	
	-- Send updated player data to client
	ShopManager.sendPlayerDataUpdate(userId)
	
	return true
end

-- Function to get player shop
function ShopManager.getPlayerShop(userId: number)
	return playerShops[userId]
end

-- Function to handle unit movement
function ShopManager.handleUnitMove(userId: number, fromPosition: Vector2, toPosition: Vector2): boolean
	local playerData = PlayerDataManager.getPlayerData(userId)
	if not playerData then return false end
	
	-- Determine movement type based on positions
	local fromBench = fromPosition.X < 0
	local toBench = toPosition.X < 0
	
	print("Movement type detection:")
	print("  fromPosition:", fromPosition, "fromBench:", fromBench)
	print("  toPosition:", toPosition, "toBench:", toBench)
	
	local success = false
	if fromBench and toBench then
		-- Bench to Bench movement
		print("  Detected: Bench to Bench movement")
		success = ShopManager.handleBenchToBenchMove(userId, fromPosition, toPosition)
	elseif fromBench and not toBench then
		-- Bench to Board movement
		print("  Detected: Bench to Board movement")
		success = ShopManager.handleBenchToBoardMove(userId, fromPosition, toPosition)
	elseif not fromBench and toBench then
		-- Board to Bench movement
		print("  Detected: Board to Bench movement")
		success = ShopManager.handleBoardToBenchMove(userId, fromPosition, toPosition)
	else
		-- Board to Board movement
		print("  Detected: Board to Board movement")
		success = ShopManager.handleBoardToBoardMove(userId, fromPosition, toPosition)
	end
	
	-- If the move was successful, update PVP frames if the player is in a challenge
	if success then
		local PVPChallengeManager = require(script.Parent.PVPChallengeManager)
		PVPChallengeManager.updatePVPFramesForPlayer(userId)
	end
	
	return success
end

-- Function to handle board-to-board movement
function ShopManager.handleBoardToBoardMove(userId: number, fromPosition: Vector2, toPosition: Vector2): boolean
	local playerData = PlayerDataManager.getPlayerData(userId)
	if not playerData then return false end
	
	-- Validate positions
	if not Board.isValidPosition(fromPosition) or not Board.isValidPosition(toPosition) then
		ShopManager.sendNotification(userId, "Invalid position!", 3)
		return false
	end
	
	-- Check if source position has a unit
	local sourceUnit = Board.getUnitAtPosition(playerData.boardState, fromPosition)
	print("Board-to-board movement:")
	print("  fromPosition:", fromPosition)
	print("  sourceUnit:", sourceUnit and sourceUnit.name or "nil")
	print("  Board grid contents:")
	for pos, unit in pairs(playerData.boardState.grid) do
		print("    Position:", pos, "Position type:", typeof(pos), "Unit:", unit.name)
	end
	print("  Trying to get unit at position:", fromPosition, "Position type:", typeof(fromPosition))
	print("  Direct grid access:", playerData.boardState.grid[fromPosition] and playerData.boardState.grid[fromPosition].name or "nil")
	
	-- Check if the position exists as a string key
	local positionString = tostring(fromPosition)
	print("  Position as string:", positionString)
	print("  String key access:", playerData.boardState.grid[positionString] and playerData.boardState.grid[positionString].name or "nil")
	if not sourceUnit then
		ShopManager.sendNotification(userId, "No unit at source position!", 3)
		return false
	end
	
	-- Check if destination is occupied
	local targetUnit = Board.getUnitAtPosition(playerData.boardState, toPosition)
	
	if targetUnit then
		-- Swap units
		local success = Board.swapUnits(playerData.boardState, fromPosition, toPosition)
		if success then
			-- Update physical units
			UnitSpawner.removeUnitFromBoard(userId, fromPosition)
			UnitSpawner.removeUnitFromBoard(userId, toPosition)
			UnitSpawner.spawnUnitOnBoard(userId, sourceUnit, toPosition)
			UnitSpawner.spawnUnitOnBoard(userId, targetUnit, fromPosition)
		else
			ShopManager.sendNotification(userId, "Failed to swap units!", 3)
			return false
		end
	else
		-- Simple move
		local success = Board.moveUnit(playerData.boardState, fromPosition, toPosition)
		if success then
			-- Update physical units
			UnitSpawner.removeUnitFromBoard(userId, fromPosition)
			UnitSpawner.spawnUnitOnBoard(userId, sourceUnit, toPosition)
		else
			ShopManager.sendNotification(userId, "Failed to move unit!", 3)
			return false
		end
	end
		
	-- Save player data
	PlayerDataManager.savePlayerData(userId)
	
	-- Update client
	ShopManager.sendBoardUpdate(userId)
	ShopManager.sendNotification(userId, "Unit moved successfully!", 2)
	
	return true
end

-- Function to handle bench-to-bench movement
function ShopManager.handleBenchToBenchMove(userId: number, fromPosition: Vector2, toPosition: Vector2): boolean
	local playerData = PlayerDataManager.getPlayerData(userId)
	if not playerData then return false end
	
	-- Extract bench slots
	local fromSlot = math.abs(fromPosition.X)
	local toSlot = math.abs(toPosition.X)
	
	print("Bench-to-bench movement:")
	print("  fromPosition:", fromPosition, "fromSlot:", fromSlot)
	print("  toPosition:", toPosition, "toSlot:", toSlot)
	
	-- Check if source slot has a unit
	local sourceUnit = Bench.getUnitAtSlot(playerData.benchState, fromSlot)
	if not sourceUnit then
		ShopManager.sendNotification(userId, "No unit at source bench slot!", 3)
		return false
	end
	
	-- Check if destination slot is occupied
	local targetUnit = Bench.getUnitAtSlot(playerData.benchState, toSlot)
	
	if targetUnit then
		-- Swap units between bench slots
		local success = Bench.swapUnits(playerData.benchState, fromSlot, toSlot)
		if success then
			-- Update physical units
			UnitSpawner.removeUnitFromBench(userId, fromSlot)
			UnitSpawner.removeUnitFromBench(userId, toSlot)
			UnitSpawner.spawnUnitOnBench(userId, sourceUnit, toSlot)
			UnitSpawner.spawnUnitOnBench(userId, targetUnit, fromSlot)
			
			-- Save player data
			PlayerDataManager.savePlayerData(userId)
			
			-- Update client
			ShopManager.sendBenchUpdate(userId)
			ShopManager.sendNotification(userId, "Units swapped on bench!", 2)
			
			return true
		end
	else
		-- Move unit to empty bench slot
		local success = Bench.moveUnitToSlot(playerData.benchState, fromSlot, toSlot)
		if success then
			-- Update physical units - move the existing unit between bench slots
			UnitSpawner.moveUnitBetweenBenchSlots(userId, fromSlot, toSlot)
			
			-- Save player data
			PlayerDataManager.savePlayerData(userId)
			
			-- Update client
			ShopManager.sendBenchUpdate(userId)
			ShopManager.sendNotification(userId, "Unit moved on bench!", 2)
			
			return true
		end
	end
	
	ShopManager.sendNotification(userId, "Failed to move unit on bench!", 3)
	return false
end

-- Function to handle board-to-bench movement
function ShopManager.handleBoardToBenchMove(userId: number, fromPosition: Vector2, toPosition: Vector2): boolean
	local playerData = PlayerDataManager.getPlayerData(userId)
	if not playerData then return false end
	
	-- Validate board position
	if not Board.isValidPosition(fromPosition) then
		ShopManager.sendNotification(userId, "Invalid board position!", 3)
		return false
	end
	
	-- Extract bench slot
	local benchSlot = math.abs(toPosition.X)
	
	-- Check if board position has a unit
	local boardUnit = Board.getUnitAtPosition(playerData.boardState, fromPosition)
	if not boardUnit then
		ShopManager.sendNotification(userId, "No unit at board position!", 3)
		return false
	end
	
	-- Check if bench slot is occupied
	local benchUnit = Bench.getUnitAtSlot(playerData.benchState, benchSlot)
	
	if benchUnit then
		-- Swap: board unit to bench, bench unit to board
		local boardSuccess = Board.removeUnit(playerData.boardState, fromPosition)
		local benchSuccess = Bench.removeUnitFromSlot(playerData.benchState, benchSlot)
		
		if boardSuccess and benchSuccess then
			-- Add units to their new positions
			Board.placeUnit(playerData.boardState, benchUnit, fromPosition)
			Bench.placeUnitInSlot(playerData.benchState, boardUnit, benchSlot)
			
			-- Update physical units
			UnitSpawner.removeUnitFromBoard(userId, fromPosition)
			UnitSpawner.removeUnitFromBench(userId, benchSlot)
			UnitSpawner.spawnUnitOnBoard(userId, benchUnit, fromPosition)
			UnitSpawner.spawnUnitOnBench(userId, boardUnit, benchSlot)
			
			-- Save player data
			PlayerDataManager.savePlayerData(userId)
			
			-- Update client (send bench update first, then board update)
			ShopManager.sendBenchUpdate(userId)
			wait(0.1) -- Small delay to ensure bench update is processed first
			ShopManager.sendBoardUpdate(userId)
			ShopManager.sendNotification(userId, "Units swapped between board and bench!", 2)
			
			return true
		end
	else
		-- Move board unit to empty bench slot
		local boardSuccess = Board.removeUnit(playerData.boardState, fromPosition)
		if boardSuccess then
			local benchSuccess = Bench.placeUnitInSlot(playerData.benchState, boardUnit, benchSlot)
			if benchSuccess then
				-- Update physical units
				UnitSpawner.removeUnitFromBoard(userId, fromPosition)
				UnitSpawner.spawnUnitOnBench(userId, boardUnit, benchSlot)
				
				-- Save player data
				PlayerDataManager.savePlayerData(userId)
				
				-- Update client (send bench update first, then board update)
				ShopManager.sendBenchUpdate(userId)
				wait(0.1) -- Small delay to ensure bench update is processed first
				ShopManager.sendBoardUpdate(userId)
				ShopManager.sendNotification(userId, "Unit moved from board to bench!", 2)
				
				return true
			end
		end
	end
	
	ShopManager.sendNotification(userId, "Failed to move unit from board to bench!", 3)
	return false
end

-- Function to handle bench-to-board movement
function ShopManager.handleBenchToBoardMove(userId: number, fromPosition: Vector2, toPosition: Vector2): boolean
	local playerData = PlayerDataManager.getPlayerData(userId)
	if not playerData then return false end
	
	-- Validate board position
	if not Board.isValidPosition(toPosition) then
		ShopManager.sendNotification(userId, "Invalid board position!", 3)
		return false
	end
	
	-- Extract bench slot from fromPosition (X is negative bench slot)
	local benchSlot = math.abs(fromPosition.X)
	
	-- Check if bench slot has a unit
	local benchUnit = Bench.getUnitAtSlot(playerData.benchState, benchSlot)
	if not benchUnit then
		ShopManager.sendNotification(userId, "No unit at bench slot!", 3)
		return false
	end
	
	-- Check if board position is occupied
	local boardUnit = Board.getUnitAtPosition(playerData.boardState, toPosition)
	
	if boardUnit then
		-- Swap: bench unit to board, board unit to bench
		local success = Bench.removeUnitFromSlot(playerData.benchState, benchSlot)
		if success then
			-- Add board unit to bench
			local benchSuccess, newBenchSlot = Bench.addUnit(playerData.benchState, boardUnit)
			if benchSuccess then
				-- Place bench unit on board
				Board.placeUnit(playerData.boardState, benchUnit, toPosition)
				
				-- Update physical units
				UnitSpawner.removeUnitFromBench(userId, benchSlot)
				UnitSpawner.removeUnitFromBoard(userId, toPosition)
				UnitSpawner.spawnUnitOnBoard(userId, benchUnit, toPosition)
				UnitSpawner.spawnUnitOnBench(userId, boardUnit, newBenchSlot)
				
				-- Save player data
				PlayerDataManager.savePlayerData(userId)
				
				-- Update client (send bench update first, then board update)
				ShopManager.sendBenchUpdate(userId)
				wait(0.1) -- Small delay to ensure bench update is processed first
				ShopManager.sendBoardUpdate(userId)
				ShopManager.sendNotification(userId, "Units swapped successfully!", 2)
				
				return true
			end
		end
	else
		-- Simple move: bench unit to board
		local success = Bench.removeUnitFromSlot(playerData.benchState, benchSlot)
		if success then
			print("Removed unit from bench slot", benchSlot)
			
			-- Check if board has capacity first
			if Board.isBoardFull(playerData.boardState) then
				-- Put the unit back on the bench since board is full
				Bench.placeUnitInSlot(playerData.benchState, benchUnit, benchSlot)
				ShopManager.sendNotification(userId, "Board is full! Max units: " .. playerData.boardState.maxUnits, 3)
				return false
			end
			
			-- Place unit on board
			local placeSuccess = Board.placeUnit(playerData.boardState, benchUnit, toPosition)
			if placeSuccess then
				print("Placed unit on board at position", toPosition)
				
				-- Update physical units
				UnitSpawner.removeUnitFromBench(userId, benchSlot)
				UnitSpawner.spawnUnitOnBoard(userId, benchUnit, toPosition)
				
				-- Save player data
				PlayerDataManager.savePlayerData(userId)
				
				-- Update client (send bench update first, then board update)
				ShopManager.sendBenchUpdate(userId)
				wait(0.1) -- Small delay to ensure bench update is processed first
				ShopManager.sendBoardUpdate(userId)
				ShopManager.sendNotification(userId, "Unit moved from bench to board!", 2)
				
				return true
			else
				print("Failed to place unit on board at position", toPosition)
				-- Put the unit back on the bench since placement failed
				Bench.placeUnitInSlot(playerData.benchState, benchUnit, benchSlot)
				ShopManager.sendNotification(userId, "Cannot place unit at that position!", 3)
				return false
			end
		else
			print("Failed to remove unit from bench slot", benchSlot)
		end
	end
	
	ShopManager.sendNotification(userId, "Failed to move unit from bench!", 3)
	return false
end

-- Function to handle unit selling
function ShopManager.handleUnitSell(userId: number, unitId: string, position: Vector2): boolean
	local playerData = PlayerDataManager.getPlayerData(userId)
	if not playerData then return false end
	
	-- Check if this is a bench unit sell (position.X < 0 indicates bench)
	if position.X < 0 then
		return ShopManager.handleBenchUnitSell(userId, unitId, position)
	else
		return ShopManager.handleBoardUnitSell(userId, unitId, position)
	end
end

-- Function to handle board unit selling
function ShopManager.handleBoardUnitSell(userId: number, unitId: string, position: Vector2): boolean
	local playerData = PlayerDataManager.getPlayerData(userId)
	if not playerData then return false end
	
	-- Validate position
	if not Board.isValidPosition(position) then
		ShopManager.sendNotification(userId, "Invalid position!", 3)
		return false
	end
	
	-- Check if position has a unit
	local unit = Board.getUnitAtPosition(playerData.boardState, position)
	if not unit then
		ShopManager.sendNotification(userId, "No unit at position!", 3)
		return false
	end
	
	-- Verify unit ID matches
	if unit.id ~= unitId then
		ShopManager.sendNotification(userId, "Unit ID mismatch!", 3)
		return false
	end
	
	-- Calculate sell value (half the cost)
	local sellValue = GameUtils.calculateSellValue(unit.cost)
	
	-- Remove unit from board
	local removedUnit = Board.removeUnit(playerData.boardState, position)
	if removedUnit then
		-- Add gold to player
		PlayerDataManager.addGold(userId, sellValue)
		
		-- Remove physical unit
		UnitSpawner.removeUnitFromBoard(userId, position)
		
		-- Save player data
		PlayerDataManager.savePlayerData(userId)
		
		-- Update client (refresh shop for star indicators & gold, player stats, then board)
		ShopManager.sendShopToClient(userId)
		ShopManager.sendPlayerDataUpdate(userId)
		ShopManager.sendBoardUpdate(userId)
		ShopManager.sendNotification(userId, "Unit sold for " .. sellValue .. " gold!", 2)
		
		return true
	else
		ShopManager.sendNotification(userId, "Failed to sell unit!", 3)
		return false
	end
end

-- Function to handle bench unit selling
function ShopManager.handleBenchUnitSell(userId: number, unitId: string, position: Vector2): boolean
	local playerData = PlayerDataManager.getPlayerData(userId)
	if not playerData then return false end
	
	-- Extract bench slot from position (X is negative bench slot)
	local benchSlot = math.abs(position.X)
	
	-- Check if bench slot has a unit
	local unit = Bench.getUnitAtSlot(playerData.benchState, benchSlot)
	if not unit then
		ShopManager.sendNotification(userId, "No unit at bench slot!", 3)
		return false
	end
	
	-- Verify unit ID matches
	if unit.id ~= unitId then
		ShopManager.sendNotification(userId, "Unit ID mismatch!", 3)
		return false
	end
	
	-- Calculate sell value (half the cost)
	local sellValue = GameUtils.calculateSellValue(unit.cost)
	
	-- Remove unit from bench
	local success = Bench.removeUnitFromSlot(playerData.benchState, benchSlot)
	if success then
		-- Add gold to player
		PlayerDataManager.addGold(userId, sellValue)
		
		-- Remove physical unit
		UnitSpawner.removeUnitFromBench(userId, benchSlot)
		
		-- Save player data
		PlayerDataManager.savePlayerData(userId)
		
		-- Update client (refresh shop for star indicators & gold, player stats, then bench)
		ShopManager.sendShopToClient(userId)
		ShopManager.sendPlayerDataUpdate(userId)
		ShopManager.sendBenchUpdate(userId)
		ShopManager.sendNotification(userId, "Unit sold for " .. sellValue .. " gold!", 2)
		
		return true
	else
		ShopManager.sendNotification(userId, "Failed to sell unit!", 3)
		return false
	end
end

-- Function to handle level up (buy experience)
function ShopManager.handleLevelUp(userId: number): boolean
	local playerData = PlayerDataManager.getPlayerData(userId)
	if not playerData then return false end
	
	-- Check if player is already at max level
	if playerData.level >= Constants.MAX_LEVEL then
		ShopManager.sendNotification(userId, "Already at maximum level!", 3)
		return false
	end
	
	-- Check if player has enough gold
	if playerData.gold < Constants.LEVEL_UP_COST then
		ShopManager.sendNotification(userId, "Insufficient gold! Need " .. Constants.LEVEL_UP_COST .. " gold.", 3)
		return false
	end
	
	-- Deduct gold
	PlayerDataManager.spendGold(userId, Constants.LEVEL_UP_COST)
	
	-- Add experience
	PlayerDataManager.addExperience(userId, Constants.LEVEL_UP_EXPERIENCE)
	
	-- Check if player leveled up
	local newPlayerData = PlayerDataManager.getPlayerData(userId)
	local levelGained = newPlayerData.level - playerData.level
	
	-- Generate new shop with updated level
	local shopUnits = Shop.generateShop(newPlayerData.level)
	playerShops[userId] = {
		units = shopUnits,
		lastRefresh = os.time()
	}
	
	-- Save player data
	PlayerDataManager.savePlayerData(userId)
	
	-- Update client
	ShopManager.sendShopToClient(userId)
	ShopManager.sendNotification(userId, "Gained " .. Constants.LEVEL_UP_EXPERIENCE .. " experience! Cost: " .. Constants.LEVEL_UP_COST .. " gold", 2)
	
	-- If player leveled up, show special notification and update board max units
	if levelGained > 0 then
		-- Update board max units based on new level
		local Board = require(script.Parent.Board)
		Board.updateMaxUnits(newPlayerData.boardState, newPlayerData.level)
		
		ShopManager.sendNotification(userId, "Level up! You are now level " .. newPlayerData.level .. "!", 3)
		ShopManager.sendNotification(userId, "Board capacity increased to " .. newPlayerData.boardState.maxUnits .. " units!", 3)
	end
	
	-- Send updated player data to client
	ShopManager.sendPlayerDataUpdate(userId)
	
	return true
end

-- Function to perform tier-up combination
function ShopManager.performTierUp(userId: number, purchasedUnit: any, targetTier: number): boolean
	local playerData = PlayerDataManager.getPlayerData(userId)
	if not playerData then return false end
	
	-- Find units to combine
	local unitsToCombine = UnitTiering.findUnitsToCombine(playerData.boardState, playerData.benchState, purchasedUnit.id, targetTier)
	
	-- Add the purchased unit to the combination
	table.insert(unitsToCombine, purchasedUnit)
	
	-- Remove the units that will be combined
	local removedPositions = UnitTiering.removeUnitsForCombination(playerData.boardState, playerData.benchState, unitsToCombine)
	
	-- Remove physical units
	for _, position in ipairs(removedPositions) do
		UnitSpawner.removeUnitFromBoard(userId, position)
	end
	
	-- Also remove bench units that were combined
	for _, unit in ipairs(unitsToCombine) do
		if unit.slot then -- This is a bench unit
			UnitSpawner.removeUnitFromBench(userId, unit.slot)
		end
	end
	
	-- Create the new higher tier unit
	local newUnit = UnitDatabase.createUnit(purchasedUnit.id, targetTier)
	if not newUnit then return false end
	
	-- Deduct gold for the purchased unit
	PlayerDataManager.spendGold(userId, purchasedUnit.cost)
	
	-- Place the new unit on bench (prefer bench over board for tier-ups)
	local success, uniqueUnitId = Bench.addUnit(playerData.benchState, newUnit)
	if success then
		local benchSlot = Bench.getUnitSlot(playerData.benchState, uniqueUnitId)
		if benchSlot then
			UnitSpawner.spawnUnitOnBench(userId, newUnit, benchSlot)
		end
		return true
	else
		-- Try to place on board if bench is full
		if not Board.isBoardFull(playerData.boardState) then
			local availablePosition = Board.getAvailablePositions(playerData.boardState)[1]
			if availablePosition and Board.placeUnit(playerData.boardState, newUnit, availablePosition) then
				UnitSpawner.spawnUnitOnBoard(userId, newUnit, availablePosition)
				return true
			end
		end
		-- Board is full, tier-up failed
		return false
	end
	
	return false
end

-- Function to cleanup player data
function ShopManager.cleanupPlayer(userId: number)
	playerShops[userId] = nil
end

return ShopManager
