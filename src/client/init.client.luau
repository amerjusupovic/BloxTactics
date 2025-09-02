--[[
	init.client.luau
	Main client initialization
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- Load client modules
local UI = require(script.Parent.Client.UI)
local PVPChallengeUI = require(script.Parent.Client.PVPChallengeUI)
local ChallengePromptUI = require(script.Parent.Client.ChallengePromptUI)

-- Load shared modules
local Constants = require(game.ReplicatedStorage.Shared.Constants)

local player = Players.LocalPlayer

print("BloxTactics Client initialized for " .. player.Name)

-- Wait for RemoteEvents to be created
local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")

-- Get RemoteEvents
local updatePlayerDataEvent = remoteEventsFolder:WaitForChild(Constants.REMOTE_EVENT_NAMES.UPDATE_PLAYER_DATA)

-- Set up RemoteEvent handlers
local function setupRemoteEventHandlers()
	-- Handle player data updates
	updatePlayerDataEvent.OnClientEvent:Connect(function(playerData)
		-- Update UI with new player data
		print("Received player data update from server")
		print("Player data received:", playerData)
		if playerData then
			print("Gold:", playerData.gold, "Level:", playerData.level, "Exp:", playerData.experience)
			UI.updatePlayerStats(playerData)
		else
			warn("Received nil player data from server!")
		end
	end)
	
	-- Handle shop updates
	local updateShopEvent = remoteEventsFolder:WaitForChild(Constants.REMOTE_EVENT_NAMES.UPDATE_SHOP)
	updateShopEvent.OnClientEvent:Connect(function(shopUnits)
		UI.updateShopDisplay(shopUnits)
	end)
	
	-- Handle board updates
	local updateBoardEvent = remoteEventsFolder:WaitForChild(Constants.REMOTE_EVENT_NAMES.UPDATE_BOARD)
	updateBoardEvent.OnClientEvent:Connect(function(boardState)
		UI.updateBoardDisplay(boardState)
	end)
	
	-- Handle bench updates
	local updateBenchEvent = remoteEventsFolder:WaitForChild(Constants.REMOTE_EVENT_NAMES.UPDATE_BENCH)
	updateBenchEvent.OnClientEvent:Connect(function(benchState)
		UI.updateBenchDisplay(benchState)
	end)
	
	-- Handle notifications
	local showNotificationEvent = remoteEventsFolder:WaitForChild(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
	showNotificationEvent.OnClientEvent:Connect(function(message, duration)
		UI.showNotification(message, duration)
	end)
end

-- Set up keybind handlers
local function setupKeybindHandlers()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then 
			print("Input was processed by game, ignoring keybind")
			return 
		end
		
		if input.KeyCode == Enum.KeyCode.F then
			print("F key pressed - toggling shop...")
			UI.toggleShop()
		elseif input.KeyCode == Enum.KeyCode.C then
			print("C key pressed - toggling board...")
			UI.toggleBoard()
		elseif input.KeyCode == Enum.KeyCode.R then
			print("R key pressed - resetting player data...")
			-- Reset player data (for testing)
			UI.resetPlayerData()
		elseif input.KeyCode == Enum.KeyCode.Escape then
			print("Escape key pressed - clearing selection...")
			-- Clear unit selection
			UI.clearSelection()
		end
	end)
	
	print("Keybind handler connected successfully!")
end

-- Request player data from server
local function requestPlayerData()
	updatePlayerDataEvent:FireServer()
end

-- Initialize client systems
local function initializeClient()
	print("Initializing BloxTactics client systems...")
	
	-- Create main UI
	print("Creating main UI...")
	UI.createMainUI()
	print("Main UI created successfully!")
	
	-- Initialize PVP Challenge UI
	print("Initializing PVP Challenge UI...")
	PVPChallengeUI.init()
	print("PVP Challenge UI initialized!")
	
	-- Initialize Challenge Prompt UI
	print("Initializing Challenge Prompt UI...")
	ChallengePromptUI.init()
	print("Challenge Prompt UI initialized!")
	
	-- Set up RemoteEvent handlers
	print("Setting up RemoteEvent handlers...")
	setupRemoteEventHandlers()
	print("RemoteEvent handlers set up successfully!")
	
	-- Set up keybind handlers
	print("Setting up keybind handlers...")
	setupKeybindHandlers()
	print("Keybind handlers set up successfully!")
	
	-- Request initial player data
	print("Requesting initial player data...")
	requestPlayerData()
	print("Initial player data requested!")
	
	print("Client systems initialized!")
end

-- Initialize the client
initializeClient()