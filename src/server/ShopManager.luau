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
local RemoteEvents = require(script.Parent.RemoteEvents)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local DataStructures = require(game.ReplicatedStorage.Shared.DataStructures)

local ShopManager = {}

-- Player shop data cache
local playerShops = {}

-- Function to initialize player shop
function ShopManager.initializePlayerShop(userId: number)
	local playerData = PlayerDataManager.getPlayerData(userId)
	if not playerData then return end
	
	-- Generate initial shop
	local shopUnits = Shop.generateShop(playerData.level)
	playerShops[userId] = {
		units = shopUnits,
		lastRefresh = os.time()
	}
	
	-- Send shop to client
	ShopManager.sendShopToClient(userId)
end

-- Function to send shop to client
function ShopManager.sendShopToClient(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	if not player then return end
	
	local shopData = playerShops[userId]
	if not shopData then return end
	
	local updateShopEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.UPDATE_SHOP)
	if updateShopEvent then
		updateShopEvent:FireClient(player, shopData.units)
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
	
	-- Check if player has enough gold
	if playerData.gold < unit.cost then
		-- Send insufficient funds message
		ShopManager.sendNotification(userId, "Insufficient gold! Need " .. unit.cost .. " gold.", 3)
		return false
	end
	
	-- Check if bench has space
	if Bench.isBenchFull(playerData.benchState) then
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
			
			-- Remove from shop
			table.remove(shopData.units, shopIndex)
			
			-- Add new unit to shop
			local newUnit = Shop.generateRandomUnit(playerData.level)
			if newUnit then
				table.insert(shopData.units, newUnit)
			end
			
			-- Save player data
			PlayerDataManager.savePlayerData(userId)
			
			-- Update client
			ShopManager.sendShopToClient(userId)
			ShopManager.sendBoardUpdate(userId)
			ShopManager.sendNotification(userId, "Unit placed on board!", 2)
			
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
			
			-- Remove from shop
			table.remove(shopData.units, shopIndex)
			
			-- Add new unit to shop
			local newUnit = Shop.generateRandomUnit(playerData.level)
			if newUnit then
				table.insert(shopData.units, newUnit)
			end
			
			-- Save player data
			PlayerDataManager.savePlayerData(userId)
			
			-- Update client
			ShopManager.sendShopToClient(userId)
			ShopManager.sendBenchUpdate(userId)
			ShopManager.sendNotification(userId, "Unit placed on bench!", 2)
			
			return true
		end
	end
	
	return false
end

-- Function to send board update to client
function ShopManager.sendBoardUpdate(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	if not player then return end
	
	local playerData = PlayerDataManager.getPlayerData(userId)
	if not playerData then return end
	
	local updateBoardEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.UPDATE_BOARD)
	if updateBoardEvent then
		updateBoardEvent:FireClient(player, playerData.boardState)
	end
end

-- Function to send bench update to client
function ShopManager.sendBenchUpdate(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	if not player then return end
	
	local playerData = PlayerDataManager.getPlayerData(userId)
	if not playerData then return end
	
	local updateBenchEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.UPDATE_BENCH)
	if updateBenchEvent then
		updateBenchEvent:FireClient(player, playerData.benchState)
	end
end

-- Function to send notification to client
function ShopManager.sendNotification(userId: number, message: string, duration: number)
	local player = Players:GetPlayerByUserId(userId)
	if not player then return end
	
	local notificationEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
	if notificationEvent then
		notificationEvent:FireClient(player, message, duration)
	end
end

-- Function to refresh shop
function ShopManager.refreshShop(userId: number)
	local playerData = PlayerDataManager.getPlayerData(userId)
	if not playerData then return false end
	
	-- Check if player has enough gold for refresh
	local refreshCost = Shop.getRefreshCost()
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
	
	-- Send to client
	ShopManager.sendShopToClient(userId)
	ShopManager.sendNotification(userId, "Shop refreshed!", 2)
	
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
	
	-- Check if this is a bench-to-board move (fromPosition.X < 0 indicates bench)
	if fromPosition.X < 0 then
		return ShopManager.handleBenchToBoardMove(userId, fromPosition, toPosition)
	else
		return ShopManager.handleBoardToBoardMove(userId, fromPosition, toPosition)
	end
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
	if not sourceUnit then
		ShopManager.sendNotification(userId, "No unit at source position!", 3)
		return false
	end
	
	-- Check if destination is occupied
	local targetUnit = Board.getUnitAtPosition(playerData.boardState, toPosition)
	
	-- Move the unit
	local success = Board.moveUnit(playerData.boardState, fromPosition, toPosition)
	if success then
		-- Update physical units
		if targetUnit then
			-- Swap units
			UnitSpawner.removeUnitFromBoard(userId, fromPosition)
			UnitSpawner.removeUnitFromBoard(userId, toPosition)
			UnitSpawner.spawnUnitOnBoard(userId, sourceUnit, toPosition)
			UnitSpawner.spawnUnitOnBoard(userId, targetUnit, fromPosition)
		else
			-- Simple move
			UnitSpawner.removeUnitFromBoard(userId, fromPosition)
			UnitSpawner.spawnUnitOnBoard(userId, sourceUnit, toPosition)
		end
		
		-- Save player data
		PlayerDataManager.savePlayerData(userId)
		
		-- Update client
		ShopManager.sendBoardUpdate(userId)
		ShopManager.sendNotification(userId, "Unit moved successfully!", 2)
		
		return true
	else
		ShopManager.sendNotification(userId, "Failed to move unit!", 3)
		return false
	end
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
			
			-- Place unit on board
			local placeSuccess = Board.placeUnit(playerData.boardState, benchUnit, toPosition)
			if placeSuccess then
				print("Placed unit on board at position", toPosition)
			else
				print("Failed to place unit on board at position", toPosition)
			end
			
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
	local sellValue = math.floor(unit.cost / 2)
	
	-- Remove unit from board
	local removedUnit = Board.removeUnit(playerData.boardState, position)
	if removedUnit then
		-- Add gold to player
		PlayerDataManager.addGold(userId, sellValue)
		
		-- Remove physical unit
		UnitSpawner.removeUnitFromBoard(userId, position)
		
		-- Save player data
		PlayerDataManager.savePlayerData(userId)
		
		-- Update client
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
	local sellValue = math.floor(unit.cost / 2)
	
	-- Remove unit from bench
	local success = Bench.removeUnitFromSlot(playerData.benchState, benchSlot)
	if success then
		-- Add gold to player
		PlayerDataManager.addGold(userId, sellValue)
		
		-- Remove physical unit
		UnitSpawner.removeUnitFromBench(userId, benchSlot)
		
		-- Save player data
		PlayerDataManager.savePlayerData(userId)
		
		-- Update client
		ShopManager.sendBenchUpdate(userId)
		ShopManager.sendNotification(userId, "Unit sold for " .. sellValue .. " gold!", 2)
		
		return true
	else
		ShopManager.sendNotification(userId, "Failed to sell unit!", 3)
		return false
	end
end

-- Function to cleanup player data
function ShopManager.cleanupPlayer(userId: number)
	playerShops[userId] = nil
end

return ShopManager
