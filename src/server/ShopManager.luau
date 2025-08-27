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
	
	local updateShopEvent = ReplicatedStorage.RemoteEvents:FindFirstChild("UpdateShop")
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
	
	local updateBoardEvent = ReplicatedStorage.RemoteEvents:FindFirstChild("UpdateBoard")
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
	
	local updateBenchEvent = ReplicatedStorage.RemoteEvents:FindFirstChild("UpdateBench")
	if updateBenchEvent then
		updateBenchEvent:FireClient(player, playerData.benchState)
	end
end

-- Function to send notification to client
function ShopManager.sendNotification(userId: number, message: string, duration: number)
	local player = Players:GetPlayerByUserId(userId)
	if not player then return end
	
	local notificationEvent = ReplicatedStorage.RemoteEvents:FindFirstChild("ShowNotification")
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

-- Function to cleanup player data
function ShopManager.cleanupPlayer(userId: number)
	playerShops[userId] = nil
end

return ShopManager
