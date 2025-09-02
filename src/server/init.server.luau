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
local PVPChallengeManager = require(script.Parent.Server.PVPChallengeManager)
local BoardDetection = require(script.Parent.Server.BoardDetection)
local ArenaSpawner = require(script.Parent.Server.ArenaSpawner)
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
	local levelUpEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.LEVEL_UP)
	local updatePlayerDataEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.UPDATE_PLAYER_DATA)
	
	-- PVP Challenge events
	local challengePlayerEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.CHALLENGE_PLAYER)
	local acceptChallengeEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.ACCEPT_CHALLENGE)
	local rejectChallengeEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.REJECT_CHALLENGE)

	-- Purchase unit handler
purchaseUnitEvent.OnServerEvent:Connect(function(player, unitIndex)
	local userId = player.UserId
	
	-- Handle unit purchase through ShopManager
	local success = ShopManager.handleUnitPurchase(userId, unitIndex)
	
	if success then
		print("Player " .. player.Name .. " successfully purchased unit at index " .. unitIndex)
		
		-- Send updated player data to client to update gold display
		local playerData = PlayerDataManager.getPlayerData(userId)
		if playerData then
			updatePlayerDataEvent:FireClient(player, playerData)
		end
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

		-- Handle unit movement through ShopManager
		local success = ShopManager.handleUnitMove(userId, fromPosition, toPosition)
		
		if success then
			print("Player " .. player.Name .. " successfully moved unit from " .. tostring(fromPosition) .. " to " .. tostring(toPosition))
		else
			print("Player " .. player.Name .. " failed to move unit from " .. tostring(fromPosition) .. " to " .. tostring(toPosition))
		end
	end)
	
	-- Sell unit handler
	sellUnitEvent.OnServerEvent:Connect(function(player, unitId, position)
		local userId = player.UserId
		local playerData = PlayerDataManager.getPlayerData(userId)

		if not playerData then
			return
		end

		-- Handle unit selling through ShopManager
		local success = ShopManager.handleUnitSell(userId, unitId, position)
		
		if success then
			print("Player " .. player.Name .. " successfully sold unit " .. unitId .. " at position " .. tostring(position))
		else
			print("Player " .. player.Name .. " failed to sell unit " .. unitId .. " at position " .. tostring(position))
		end
	end)

	-- Refresh shop handler
	refreshShopEvent.OnServerEvent:Connect(function(player)
		local userId = player.UserId
		
		-- Handle shop refresh through ShopManager
		local success = ShopManager.refreshShop(userId)
		
		if success then
			print("Player " .. player.Name .. " successfully refreshed shop")
			
			-- Send updated player data to client to update gold display
			local playerData = PlayerDataManager.getPlayerData(userId)
			if playerData then
				updatePlayerDataEvent:FireClient(player, playerData)
			end
		else
			print("Player " .. player.Name .. " failed to refresh shop")
		end
	end)

	-- Level up handler
	levelUpEvent.OnServerEvent:Connect(function(player)
		local userId = player.UserId
		
		-- Handle level up through ShopManager
		local success = ShopManager.handleLevelUp(userId)
		
		if success then
			print("Player " .. player.Name .. " successfully leveled up")
			
			-- Send updated player data to client to update UI
			local playerData = PlayerDataManager.getPlayerData(userId)
			if playerData then
				updatePlayerDataEvent:FireClient(player, playerData)
			end
		else
			print("Player " .. player.Name .. " failed to level up")
		end
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
	
	-- Reset player data handler (for testing)
	local resetPlayerDataEvent = RemoteEvents.getEvent("ResetPlayerData")
	if resetPlayerDataEvent then
		resetPlayerDataEvent.OnServerEvent:Connect(function(player)
			local userId = player.UserId
			local success = PlayerDataManager.resetPlayerData(userId)
			
			if success then
				-- Clear physical units
				UnitSpawner.clearPlayerUnits(userId)
				
				-- Reinitialize player data
				local newPlayerData = PlayerDataManager.loadPlayerData(userId, player.Name)
				
				-- Reinitialize shop
				ShopManager.initializePlayerShop(userId)
				
				-- Send updates to client
				ShopManager.sendBoardUpdate(userId)
				ShopManager.sendBenchUpdate(userId)
				updatePlayerDataEvent:FireClient(player, newPlayerData)
				
				print("Player " .. player.Name .. " data reset successfully")
			else
				print("Failed to reset player " .. player.Name .. " data")
			end
		end)
	end
	
	-- PVP Challenge handlers
	challengePlayerEvent.OnServerEvent:Connect(function(player, targetPlayerId)
		local challengerId = player.UserId
		
		-- Check if target player exists and can be challenged
		if not PVPChallengeManager.canPlayerBeChallenged(targetPlayerId) then
			local notificationEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
			notificationEvent:FireClient(player, "This player cannot be challenged right now.", 5)
			return
		end
		
		-- Check if challenger can issue challenges
		if PVPChallengeManager.isPlayerInChallenge(challengerId) then
			local notificationEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
			notificationEvent:FireClient(player, "You are already in a challenge!", 5)
			return
		end
		
		-- Create the challenge
		local challengeId = PVPChallengeManager.createChallenge(challengerId, targetPlayerId)
		if challengeId then
			local notificationEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
			notificationEvent:FireClient(player, "Challenge sent! Waiting for response...", 5)
		else
			local notificationEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
			notificationEvent:FireClient(player, "Failed to send challenge.", 5)
		end
	end)
	
	acceptChallengeEvent.OnServerEvent:Connect(function(player)
		local challengedId = player.UserId
		local success = PVPChallengeManager.acceptChallenge(challengedId)
		
		if not success then
			local notificationEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
			notificationEvent:FireClient(player, "Failed to accept challenge.", 5)
		end
	end)
	
	rejectChallengeEvent.OnServerEvent:Connect(function(player)
		local challengedId = player.UserId
		local success = PVPChallengeManager.rejectChallenge(challengedId)
		
		if not success then
			local notificationEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
			notificationEvent:FireClient(player, "Failed to reject challenge.", 5)
		end
	end)
end

-- Set up player handlers
local function setupPlayerHandlers()
	-- Player joining
	Players.PlayerAdded:Connect(function(player)
		local userId = player.UserId
		print("Player " .. player.Name .. " joined, initializing arena and shop...")
		
		-- Create the player's arena structure
		local grassArena = ArenaSpawner.createGrassArena(userId, player.Name)
		if not grassArena then
			warn("Failed to create arena for player " .. player.Name)
			return
		end
		
		-- Load player data and restore board state
		local playerData = PlayerDataManager.loadPlayerData(userId, player.Name)
		
		-- Restore physical units on board
		if playerData and playerData.boardState and playerData.boardState.grid then
			for position, unit in pairs(playerData.boardState.grid) do
				UnitSpawner.spawnUnitOnBoard(userId, unit, position)
			end
		end
		
		-- Restore physical units on bench
		if playerData and playerData.benchState and playerData.benchState.units then
			for unitId, unit in pairs(playerData.benchState.units) do
				local benchSlot = Bench.getUnitSlot(playerData.benchState, unitId)
				if benchSlot then
					UnitSpawner.spawnUnitOnBench(userId, unit, benchSlot)
				end
			end
		end
		
		-- Initialize shop after a short delay to ensure player data is loaded
		wait(1)
		ShopManager.initializePlayerShop(userId)
		
		-- Send board and bench updates to client
		ShopManager.sendBoardUpdate(userId)
		ShopManager.sendBenchUpdate(userId)
		
		-- Send player data update to client
		local updatePlayerDataEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.UPDATE_PLAYER_DATA)
		if updatePlayerDataEvent then
			updatePlayerDataEvent:FireClient(player, playerData)
		end
	end)
	
	-- Player leaving
	Players.PlayerRemoving:Connect(function(player)
		local userId = player.UserId
		
		-- Save player data before cleanup
		PlayerDataManager.savePlayerData(userId)
		
		ShopManager.cleanupPlayer(userId)
		UnitSpawner.clearPlayerUnits(userId)
		
		-- Remove the player's arena
		ArenaSpawner.removeArena(userId)
	end)
end

-- Initialize game systems
local function initializeGame()
	print("Initializing BloxTactics game systems...")
	
	-- Initialize PVP Challenge Manager
	PVPChallengeManager.init()
	
	-- Initialize Board Detection system
	BoardDetection.init()
	
	-- Initialize Arena Spawner
	ArenaSpawner.init()
	
	-- Set up RemoteEvent handlers
	setupRemoteEventHandlers()
	
	-- Set up player joining/leaving handlers
	setupPlayerHandlers()
	
	print("Game systems initialized!")
end

-- Initialize the game
initializeGame()