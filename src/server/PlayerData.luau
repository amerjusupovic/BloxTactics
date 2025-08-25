--[[
	PlayerData.luau
	Player data management and persistence
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataStructures = require(game.ReplicatedStorage.Shared.DataStructures)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local PlayerData = DataStructures.PlayerData
local BoardState = DataStructures.BoardState
local BenchState = DataStructures.BenchState

local PlayerDataManager = {}

-- Data store for player data
local playerDataStore = DataStoreService:GetDataStore("BloxTactics_PlayerData")

-- In-memory player data cache
local playerDataCache = {}

-- Function to create default player data
local function createDefaultPlayerData(userId: number, username: string): PlayerData
	return {
		userId = userId,
		username = username,
		gold = Constants.STARTING_GOLD,
		level = Constants.STARTING_LEVEL,
		experience = 0,
		units = {},
		items = {},
		boardState = {
			grid = {},
			maxUnits = Constants.MAX_BOARD_UNITS,
			currentUnits = 0
		},
		benchState = {
			units = {},
			maxCapacity = Constants.BENCH_CAPACITY,
			currentCapacity = 0
		},
		streak = 0,
		lastUpdated = os.time()
	}
end

-- Function to load player data
function PlayerDataManager.loadPlayerData(userId: number, username: string): PlayerData
	-- Check cache first
	if playerDataCache[userId] then
		return playerDataCache[userId]
	end
	
	-- Try to load from data store
	local success, data = pcall(function()
		return playerDataStore:GetAsync(tostring(userId))
	end)
	
	if success and data then
		-- Validate and update data structure if needed
		local playerData = data
		
		-- Ensure all required fields exist
		if not playerData.boardState then
			playerData.boardState = {
				grid = {},
				maxUnits = Constants.MAX_BOARD_UNITS,
				currentUnits = 0
			}
		end
		
		if not playerData.benchState then
			playerData.benchState = {
				units = {},
				maxCapacity = Constants.BENCH_CAPACITY,
				currentCapacity = 0
			}
		end
		
		if not playerData.streak then
			playerData.streak = 0
		end
		
		playerData.lastUpdated = os.time()
		playerDataCache[userId] = playerData
		return playerData
	else
		-- Create new player data
		local newData = createDefaultPlayerData(userId, username)
		playerDataCache[userId] = newData
		return newData
	end
end

-- Function to save player data
function PlayerDataManager.savePlayerData(userId: number): boolean
	local playerData = playerDataCache[userId]
	if not playerData then
		return false
	end
	
	playerData.lastUpdated = os.time()
	
	local success, error = pcall(function()
		playerDataStore:SetAsync(tostring(userId), playerData)
	end)
	
	if not success then
		warn("Failed to save player data for user " .. userId .. ": " .. tostring(error))
		return false
	end
	
	return true
end

-- Function to get player data
function PlayerDataManager.getPlayerData(userId: number): PlayerData?
	return playerDataCache[userId]
end

-- Function to update player data
function PlayerDataManager.updatePlayerData(userId: number, updates: {[string]: any}): boolean
	local playerData = playerDataCache[userId]
	if not playerData then
		return false
	end
	
	-- Apply updates
	for key, value in pairs(updates) do
		playerData[key] = value
	end
	
	playerData.lastUpdated = os.time()
	return true
end

-- Function to add gold to player
function PlayerDataManager.addGold(userId: number, amount: number): boolean
	local playerData = playerDataCache[userId]
	if not playerData then
		return false
	end
	
	playerData.gold = math.max(0, playerData.gold + amount)
	playerData.lastUpdated = os.time()
	return true
end

-- Function to spend gold
function PlayerDataManager.spendGold(userId: number, amount: number): boolean
	local playerData = playerDataCache[userId]
	if not playerData then
		return false
	end
	
	if playerData.gold < amount then
		return false
	end
	
	playerData.gold = playerData.gold - amount
	playerData.lastUpdated = os.time()
	return true
end

-- Function to add experience
function PlayerDataManager.addExperience(userId: number, amount: number): boolean
	local playerData = playerDataCache[userId]
	if not playerData then
		return false
	end
	
	playerData.experience = playerData.experience + amount
	
	-- Check for level up
	while playerData.experience >= Constants.EXPERIENCE_PER_LEVEL and playerData.level < Constants.MAX_LEVEL do
		playerData.experience = playerData.experience - Constants.EXPERIENCE_PER_LEVEL
		playerData.level = playerData.level + 1
	end
	
	playerData.lastUpdated = os.time()
	return true
end

-- Function to remove player data from cache
function PlayerDataManager.removePlayerData(userId: number): boolean
	if playerDataCache[userId] then
		-- Save before removing
		PlayerDataManager.savePlayerData(userId)
		playerDataCache[userId] = nil
		return true
	end
	return false
end

-- Auto-save function
function PlayerDataManager.startAutoSave()
	spawn(function()
		while true do
			wait(300) -- Save every 5 minutes
			for userId, _ in pairs(playerDataCache) do
				PlayerDataManager.savePlayerData(userId)
			end
		end
	end)
end

-- Player joining handler
local function onPlayerAdded(player: Player)
	local userId = player.UserId
	local username = player.Name
	
	PlayerDataManager.loadPlayerData(userId, username)
end

-- Player leaving handler
local function onPlayerRemoving(player: Player)
	local userId = player.UserId
	
	PlayerDataManager.removePlayerData(userId)
end

-- Connect events
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Start auto-save
PlayerDataManager.startAutoSave()

return PlayerDataManager
