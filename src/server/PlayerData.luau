--[[
	PlayerData.luau
	Player data management and persistence
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataStructures = require(game.ReplicatedStorage.Shared.DataStructures)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local GameUtils = require(game.ReplicatedStorage.Shared.GameUtils)
type PlayerData = DataStructures.PlayerData
type BoardState = DataStructures.BoardState
type BenchState = DataStructures.BenchState
type ShopState = DataStructures.ShopState

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
		-- Deserialize the data from DataStore
		local playerData = PlayerDataManager.deserializePlayerData(data)
		
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
-- Function to serialize player data for DataStore
function PlayerDataManager.serializePlayerData(playerData: PlayerData): {[string]: any}
	local serialized = {
		userId = playerData.userId,
		level = playerData.level,
		experience = playerData.experience,
		gold = playerData.gold,
		streak = playerData.streak,
		lastUpdated = playerData.lastUpdated
	}
	
	-- Serialize shop state if it exists
	if playerData.shopState then
		serialized.shopState = {
			units = {},
			lastRefresh = playerData.shopState.lastRefresh
		}
		for i, unit in ipairs(playerData.shopState.units) do
			serialized.shopState.units[i] = {
				id = unit.id,
				name = unit.name,
				cost = unit.cost,
				tier = unit.tier,
				imageAssetId = unit.imageAssetId,
				stats = unit.stats,
				abilities = unit.abilities,
				soldOut = unit.soldOut
			}
		end
	end
	
	-- Serialize board state
	serialized.boardState = {
		grid = {},
		maxUnits = playerData.boardState.maxUnits,
		currentUnits = playerData.boardState.currentUnits
	}
	for position, unit in pairs(playerData.boardState.grid) do
		-- Convert Vector2 to string for storage
		local posKey = tostring(position.X) .. "," .. tostring(position.Y)
		serialized.boardState.grid[posKey] = {
			id = unit.id,
			name = unit.name,
			cost = unit.cost,
			tier = unit.tier,
			imageAssetId = unit.imageAssetId,
			stats = unit.stats,
			abilities = unit.abilities
		}
	end
	
	-- Serialize bench state
	serialized.benchState = {
		units = {},
		maxCapacity = playerData.benchState.maxCapacity,
		currentCapacity = playerData.benchState.currentCapacity
	}
	for unitId, unit in pairs(playerData.benchState.units) do
		serialized.benchState.units[unitId] = {
			id = unit.id,
			name = unit.name,
			cost = unit.cost,
			tier = unit.tier,
			imageAssetId = unit.imageAssetId,
			stats = unit.stats,
			abilities = unit.abilities,
			slot = unit.slot -- Save slot information
		}
	end
	
	return serialized
end

-- Function to deserialize player data from DataStore
function PlayerDataManager.deserializePlayerData(serialized: {[string]: any}): PlayerData
	local playerData = {
		userId = serialized.userId,
		level = serialized.level,
		experience = serialized.experience,
		gold = serialized.gold,
		streak = serialized.streak,
		lastUpdated = serialized.lastUpdated
	}
	
	-- Deserialize shop state if it exists
	if serialized.shopState then
		playerData.shopState = {
			units = {},
			lastRefresh = serialized.shopState.lastRefresh
		}
		for i, unitData in ipairs(serialized.shopState.units) do
			playerData.shopState.units[i] = {
				id = unitData.id,
				name = unitData.name,
				cost = unitData.cost,
				tier = unitData.tier,
				imageAssetId = unitData.imageAssetId,
				stats = unitData.stats,
				abilities = unitData.abilities,
				soldOut = unitData.soldOut
			}
		end
	end
	
	-- Deserialize board state
	playerData.boardState = {
		grid = {},
		maxUnits = serialized.boardState and serialized.boardState.maxUnits or Constants.MAX_BOARD_UNITS,
		currentUnits = serialized.boardState and serialized.boardState.currentUnits or 0
	}
			if serialized.boardState and serialized.boardState.grid then
			for posKey, unitData in pairs(serialized.boardState.grid) do
				-- Convert string back to Vector2
				local parts = {}
				for part in string.gmatch(posKey, "[^,]+") do
					table.insert(parts, tonumber(part))
				end
				
				if #parts >= 2 then
					local position = Vector2.new(parts[1], parts[2])
					
					playerData.boardState.grid[position] = {
						id = unitData.id,
						name = unitData.name,
						cost = unitData.cost,
						tier = unitData.tier,
						imageAssetId = unitData.imageAssetId,
						stats = unitData.stats,
						abilities = unitData.abilities,
						position = position
					}
				else
					warn("Failed to parse position key:", posKey)
				end
			end
		end
	
	-- Deserialize bench state
	playerData.benchState = {
		units = {},
		maxCapacity = serialized.benchState and serialized.benchState.maxCapacity or Constants.BENCH_CAPACITY,
		currentCapacity = serialized.benchState and serialized.benchState.currentCapacity or 0
	}
	if serialized.benchState and serialized.benchState.units then
		for unitId, unitData in pairs(serialized.benchState.units) do
			playerData.benchState.units[unitId] = {
				id = unitData.id,
				name = unitData.name,
				cost = unitData.cost,
				tier = unitData.tier,
				imageAssetId = unitData.imageAssetId,
				stats = unitData.stats,
				abilities = unitData.abilities,
				slot = unitData.slot -- Load slot information
			}
		end
	end
	
	return playerData
end

function PlayerDataManager.savePlayerData(userId: number): boolean
	local playerData = playerDataCache[userId]
	if not playerData then
		return false
	end
	
	playerData.lastUpdated = os.time()
	
	-- Serialize player data before saving
	local serializedData = PlayerDataManager.serializePlayerData(playerData)
	
	local success, error = pcall(function()
		playerDataStore:SetAsync(tostring(userId), serializedData)
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
	
	-- Check for level up with exponential experience requirements
	while playerData.level < Constants.MAX_LEVEL do
		local experienceRequired = GameUtils.getExperienceRequiredForLevel(playerData.level)
		if playerData.experience >= experienceRequired then
			playerData.experience = playerData.experience - experienceRequired
			playerData.level = playerData.level + 1
		else
			break
		end
	end
	
	playerData.lastUpdated = os.time()
	return true
end

-- Function to reset player data (for testing purposes)
function PlayerDataManager.resetPlayerData(userId: number): boolean
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		warn("Player not found for reset: " .. userId)
		return false
	end
	
	-- Clear physical units from the workspace before resetting data
	local UnitSpawner = require(script.Parent.UnitSpawner)
	UnitSpawner.clearPlayerUnits(userId)
	
	-- Remove from data store
	local success, error = pcall(function()
		playerDataStore:RemoveAsync(tostring(userId))
	end)
	
	if not success then
		warn("Failed to remove player data from DataStore for user " .. userId .. ": " .. tostring(error))
		return false
	end
	
	-- Remove from cache
	playerDataCache[userId] = nil
	
	-- Create fresh default player data
	local newPlayerData = createDefaultPlayerData(userId, player.Name)
	playerDataCache[userId] = newPlayerData
	
	print("Player data reset successfully for user: " .. userId .. " - new data created")
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
