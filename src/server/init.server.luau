--[[
	init.server.luau
	Main server initialization
]]

-- Load all server modules
local PlayerDataManager = require(script.Parent.Server.PlayerData)
local Shop = require(script.Parent.Server.Shop)
local Board = require(script.Parent.Server.Board)
local Bench = require(script.Parent.Server.Bench)
local RemoteEvents = require(script.Parent.Server.RemoteEvents)
local ShopManager = require(script.Parent.Server.ShopManager)
local UnitSpawner = require(script.Parent.Server.UnitSpawner)
local Players = game:GetService("Players")

-- Load shared modules
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local DataStructures = require(game.ReplicatedStorage.Shared.DataStructures)

print("BloxTactics Server initialized successfully!")

-- Set up RemoteEvent handlers
local function setupRemoteEventHandlers()
	local purchaseUnitEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.PURCHASE_UNIT)
	local placeUnitEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.PLACE_UNIT)
	local moveUnitEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.MOVE_UNIT)
	local sellUnitEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SELL_UNIT)
	local refreshShopEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.REFRESH_SHOP)
	local updatePlayerDataEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.UPDATE_PLAYER_DATA)

	-- Purchase unit handler
purchaseUnitEvent.OnServerEvent:Connect(function(player, unitIndex)
	local userId = player.UserId
	
	-- Handle unit purchase through ShopManager
	local success = ShopManager.handleUnitPurchase(userId, unitIndex)
	
	if success then
		print("Player " .. player.Name .. " successfully purchased unit at index " .. unitIndex)
	else
		print("Player " .. player.Name .. " failed to purchase unit at index " .. unitIndex)
	end
end)

	-- Place unit handler
	placeUnitEvent.OnServerEvent:Connect(function(player, unitId, position)
		local userId = player.UserId
		local playerData = PlayerDataManager.getPlayerData(userId)

		if not playerData then
			return
		end

		-- Handle unit placement logic here
		-- This will be implemented in Phase 3
		print("Player " .. player.Name .. " attempted to place unit " .. unitId .. " at position " .. tostring(position))
	end)

	-- Move unit handler
	moveUnitEvent.OnServerEvent:Connect(function(player, fromPosition, toPosition)
		local userId = player.UserId
		local playerData = PlayerDataManager.getPlayerData(userId)

		if not playerData then
			return
		end

		-- Handle unit movement logic here
		-- This will be implemented in Phase 3
		print("Player " .. player.Name .. " attempted to move unit from " .. tostring(fromPosition) .. " to " .. tostring(toPosition))
	end)

	-- Sell unit handler
	sellUnitEvent.OnServerEvent:Connect(function(player, unitId)
		local userId = player.UserId
		local playerData = PlayerDataManager.getPlayerData(userId)

		if not playerData then
			return
		end

		-- Handle unit selling logic here
		-- This will be implemented in Phase 3
		print("Player " .. player.Name .. " attempted to sell unit " .. unitId)
	end)

	-- Refresh shop handler
	refreshShopEvent.OnServerEvent:Connect(function(player)
		local userId = player.UserId
		local playerData = PlayerDataManager.getPlayerData(userId)

		if not playerData then
			return
		end

		-- Handle shop refresh logic here
		-- This will be implemented in Phase 2
		print("Player " .. player.Name .. " attempted to refresh shop")
	end)

	-- Update player data handler (for client requests)
	updatePlayerDataEvent.OnServerEvent:Connect(function(player)
		local userId = player.UserId
		local playerData = PlayerDataManager.getPlayerData(userId)

		if playerData then
			-- Send updated player data to client
			updatePlayerDataEvent:FireClient(player, playerData)
		end
	end)
end

-- Set up player handlers
local function setupPlayerHandlers()
	-- Player joining
	Players.PlayerAdded:Connect(function(player)
		local userId = player.UserId
		print("Player " .. player.Name .. " joined, initializing shop...")
		
		-- Initialize shop after a short delay to ensure player data is loaded
		wait(1)
		ShopManager.initializePlayerShop(userId)
	end)
	
	-- Player leaving
	Players.PlayerRemoving:Connect(function(player)
		local userId = player.UserId
		ShopManager.cleanupPlayer(userId)
		UnitSpawner.clearPlayerUnits(userId)
	end)
end

-- Initialize game systems
local function initializeGame()
	print("Initializing BloxTactics game systems...")
	
	-- Set up RemoteEvent handlers
	setupRemoteEventHandlers()
	
	-- Set up player joining/leaving handlers
	setupPlayerHandlers()
	
	print("Game systems initialized!")
end

-- Initialize the game
initializeGame()