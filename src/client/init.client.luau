--[[
	init.client.luau
	Main client initialization
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- Load client modules
local UI = require(script.Parent.Client.UI)

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
		UI.updatePlayerStats(playerData)
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
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.F then
			UI.toggleShop()
		elseif input.KeyCode == Enum.KeyCode.C then
			UI.toggleBoard()
		end
	end)
end

-- Request player data from server
local function requestPlayerData()
	updatePlayerDataEvent:FireServer()
end

-- Initialize client systems
local function initializeClient()
	print("Initializing BloxTactics client systems...")
	
	-- Create main UI
	UI.createMainUI()
	
	-- Set up RemoteEvent handlers
	setupRemoteEventHandlers()
	
	-- Set up keybind handlers
	setupKeybindHandlers()
	
	-- Request initial player data
	requestPlayerData()
	
	print("Client systems initialized!")
end

-- Initialize the client
initializeClient()