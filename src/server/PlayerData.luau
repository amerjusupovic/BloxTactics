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
		arenaOwnership = table.clone(Constants.DEFAULT_OWNED_ARENAS), -- map of arena name -> true if owned
		boardState = {
			grid = {},
			maxUnits = 3, -- Level 1 + 2 = 3 units max
			currentUnits = 0
		},
		benchState = {
			units = {},
			maxCapacity = Constants.BENCH_CAPACITY,
			currentCapacity = 0
		},
		streak = 0,
		wins = 0, -- total lifetime wins
		lastUpdated = os.time(),
		selectedArenaName = Constants.DEFAULT_ARENA_NAME -- default arena
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
		
		-- Update board max units based on current level (for existing players)
		if playerData.level then
			local Board = require(script.Parent.Board)
			Board.updateMaxUnits(playerData.boardState, playerData.level)
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

		-- Ensure wins counter exists
		if not playerData.wins then
			playerData.wins = 0
		end

		-- Ensure arenaOwnership structure exists & default arena owned
		if not playerData.arenaOwnership then
			playerData.arenaOwnership = table.clone(Constants.DEFAULT_OWNED_ARENAS)
		else
			playerData.arenaOwnership[Constants.DEFAULT_ARENA_NAME] = true
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
		wins = playerData.wins or 0,
		lastUpdated = playerData.lastUpdated,
		selectedArenaName = playerData.selectedArenaName,
		arenaOwnership = playerData.arenaOwnership or table.clone(Constants.DEFAULT_OWNED_ARENAS)
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
		-- Skip ephemeral reinforcement units (e.g., Tank)
		if unit.id == "tank" then
			continue
		end
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
		-- Skip ephemeral reinforcement units just in case
		if unit.id == "tank" then
			continue
		end
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
		wins = serialized.wins or 0,
		lastUpdated = serialized.lastUpdated,
		selectedArenaName = serialized.selectedArenaName or Constants.DEFAULT_ARENA_NAME,
		arenaOwnership = serialized.arenaOwnership or table.clone(Constants.DEFAULT_OWNED_ARENAS)
	}

	-- Guarantee default arena is owned
	playerData.arenaOwnership[Constants.DEFAULT_ARENA_NAME] = true
	
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
	
	-- Try a couple retries to mitigate transient DataStore hiccups
	local attempts = 0
	local lastErr
	while attempts < 3 do
		attempts += 1
		local ok, err = pcall(function()
			playerDataStore:SetAsync(tostring(userId), serializedData)
		end)
		if ok then
			return true
		else
			lastErr = err
			warn(string.format("[PlayerData] Save attempt %d failed for user %d: %s", attempts, userId, tostring(err)))
			wait(0.5 * attempts) -- brief backoff
		end
	end

	warn("Failed to save player data for user " .. userId .. ": " .. tostring(lastErr))
	return false
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
	
	local oldLevel = playerData.level or 1
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

	-- If level increased, immediately update board capacity so placement respects new cap
	if playerData.level > oldLevel then
		local ok, err = pcall(function()
			local Board = require(script.Parent.Board)
			if playerData.boardState then
				Board.updateMaxUnits(playerData.boardState, playerData.level)
			end
		end)
		if not ok then
			warn("[PlayerData] Failed to update board max units after level up for user " .. tostring(userId) .. ": " .. tostring(err))
		end
	end
	
	playerData.lastUpdated = os.time()
	return true
end

-- Process a battle result updating win/loss streaks and returning structured result
-- winnerId: userId of winner (can be nil for draw)
-- loserId: userId of loser (can be nil for draw)
-- Returns table or nil if data missing: { winnerId, loserId, winnerLevel, loserLevel, winnerStreak }
function PlayerDataManager.processBattleResult(winnerId: number?, loserId: number?)
	-- NOTE: Draws currently grant no rewards and do not modify streaks.
	-- If future design wants partial rewards for draws, adjust this logic.
	-- Draw case: reset both streaks (basic approach) and abort rewards
	if not winnerId or not loserId then
		if winnerId == nil and loserId == nil then
			-- full draw: attempt to reset streaks if both players present
			return nil
		end
		return nil
	end

	local winnerData = playerDataCache[winnerId]
	local loserData = playerDataCache[loserId]
	if not winnerData or not loserData then
		return nil
	end

	-- Update streaks: increment winner streak, reset loser streak
	winnerData.streak = (winnerData.streak or 0) + 1
	loserData.streak = 0
	-- Increment total wins counter for winner
	winnerData.wins = (winnerData.wins or 0) + 1
	winnerData.lastUpdated = os.time()
	loserData.lastUpdated = os.time()

	return {
		winnerId = winnerId,
		loserId = loserId,
		winnerLevel = winnerData.level or 1,
		loserLevel = loserData.level or 1,
		winnerStreak = winnerData.streak or 0
	}
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
	-- Save immediately when player leaves; keep cache for BindToClose backup
	local saved = PlayerDataManager.savePlayerData(userId)
	if not saved then
		warn("[PlayerData] Save on PlayerRemoving failed for user " .. userId)
	end
	-- Optionally remove from cache later; keeping it allows BindToClose flush
end

-- Connect events
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Ensure data is flushed on server shutdown
game:BindToClose(function()
	-- Give a small window to save all cached player data
	for userId, _ in pairs(playerDataCache) do
		PlayerDataManager.savePlayerData(userId)
	end
	-- Yield briefly to allow requests to complete
	wait(2)
end)

-- Start auto-save
PlayerDataManager.startAutoSave()

return PlayerDataManager
