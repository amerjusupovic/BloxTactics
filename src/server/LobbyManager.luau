--[[
	LobbyManager.luau
	Manages multiple game lobbies, automatically creating new ones when needed
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Terrain = workspace.Terrain

local LobbyManager = {}
-- Throttle tables for arena selection persistence (shared across handler invocations)
local _lastArenaSaveTimes: {[number]: number} = {}
local _pendingArenaSaves: {[number]: boolean} = {}
local ARENA_SAVE_THROTTLE = 30 -- seconds between forced arena selection saves

-- Lobby configuration
local MAX_PLAYERS_PER_LOBBY = Constants.MAX_PLAYERS_PER_LOBBY

-- Lobby storage
local lobbies = {} -- {lobbyId = lobbyData}
local playerLobbies = {} -- {playerId = lobbyId}
local nextLobbyId = 1

-- Lobby data structure
local LobbyData = {
	lobbyId = 0,
	players = {}, -- {playerId = player}
	playerCount = 0, -- Track actual number of players
	workspace = nil, -- The cloned workspace folder for this lobby
	spawnPoints = nil, -- The SpawnPoints folder for this lobby
	arenaSpawner = nil, -- ArenaSpawner instance for this lobby
	boardDetection = nil, -- BoardDetection instance for this lobby
	shopManager = nil, -- ShopManager instance for this lobby
	playerDataManager = nil, -- PlayerDataManager instance for this lobby
	unitSpawner = nil, -- UnitSpawner instance for this lobby
	pvpChallengeManager = nil, -- PVPChallengeManager instance for this lobby
}

-- Function to create a new lobby workspace
local function createLobbyWorkspace(lobbyId: number): Folder
	-- Instead of creating a separate workspace, we'll create a folder in the main workspace
	-- that contains the lobby's SpawnPoints, and position arenas at different locations
	local lobbyFolder = Instance.new("Folder")
	lobbyFolder.Name = "Lobby_" .. lobbyId
	
	-- Create SpawnPoints folder for this lobby
	local spawnPoints = Instance.new("Folder")
	spawnPoints.Name = "SpawnPoints"
	spawnPoints.Parent = lobbyFolder
	
	-- Parent the lobby folder to the main workspace
	lobbyFolder.Parent = workspace
	
	print("Created lobby folder " .. lobbyId .. " in main workspace")
	return lobbyFolder
end

-- Function to create a new lobby
function LobbyManager.createLobby(): number
	local lobbyId = nextLobbyId
	nextLobbyId = nextLobbyId + 1
	
	-- Create lobby data
	local lobbyData = {
		lobbyId = lobbyId,
		players = {},
		playerCount = 0,
		workspace = createLobbyWorkspace(lobbyId),
		spawnPoints = nil,
		arenaSpawner = nil,
		boardDetection = nil,
		shopManager = nil,
		playerDataManager = nil,
		unitSpawner = nil,
		pvpChallengeManager = nil
	}
	
	-- Get the SpawnPoints folder from the lobby workspace
	lobbyData.spawnPoints = lobbyData.workspace:FindFirstChild("SpawnPoints")
	
	-- Initialize lobby-specific managers
	LobbyManager.initializeLobbyManagers(lobbyData)
	
	-- Store the lobby
	lobbies[lobbyId] = lobbyData
	
	print("Created new lobby " .. lobbyId .. " with " .. MAX_PLAYERS_PER_LOBBY .. " player capacity")
	return lobbyId
end

-- Function to initialize managers for a specific lobby
function LobbyManager.initializeLobbyManagers(lobbyData: any)
	-- Create lobby-specific instances of managers
	local lobbyFolder = Instance.new("Folder")
	lobbyFolder.Name = "LobbyManagers_" .. lobbyData.lobbyId
	lobbyFolder.Parent = lobbyData.workspace
	
	-- Initialize ArenaSpawner for this lobby
	local ArenaSpawner = require(script.Parent.ArenaSpawner)
	lobbyData.arenaSpawner = ArenaSpawner.new(lobbyData.workspace, lobbyData.spawnPoints)
	
	-- Initialize other managers (they work globally but need to be loaded)
	local ShopManager = require(script.Parent.ShopManager)
	local PlayerDataManager = require(script.Parent.PlayerData)
	
	-- Note: These managers work globally but will be initialized per-player
	-- when players join the lobby
	
	print("Initialized managers for lobby " .. lobbyData.lobbyId)
end

-- Function to set up server-side RemoteEvent handlers
function LobbyManager.setupRemoteEventHandlers()
	local RemoteEvents = require(script.Parent.RemoteEvents)
	local ShopManager = require(script.Parent.ShopManager)
	local PlayerDataManager = require(script.Parent.PlayerData)
	local UnitSpawner = require(script.Parent.UnitSpawner)
	local PVPChallengeManager = require(script.Parent.PVPChallengeManager)
	
	-- Get RemoteEvents
	local remoteEventsFolder = game.ReplicatedStorage:WaitForChild("RemoteEvents")
	
	-- Handle unit purchase
	local purchaseUnitEvent = remoteEventsFolder:WaitForChild("PurchaseUnit")
	purchaseUnitEvent.OnServerEvent:Connect(function(player, shopIndex)
		print("Player " .. player.Name .. " attempting to purchase unit at shop index " .. shopIndex)
		ShopManager.handleUnitPurchase(player.UserId, shopIndex)
	end)
	
	-- Handle shop refresh
	local refreshShopEvent = remoteEventsFolder:WaitForChild("RefreshShop")
	refreshShopEvent.OnServerEvent:Connect(function(player)
		print("Player " .. player.Name .. " refreshing shop")
		ShopManager.refreshShop(player.UserId)
	end)
	
	-- Handle level up (supports size parameter: "small"|"big")
	local levelUpEvent = remoteEventsFolder:WaitForChild("LevelUp")
	levelUpEvent.OnServerEvent:Connect(function(player, size)
		local sizeStr = (typeof(size) == "string" and size) or "small"
		print("Player " .. player.Name .. " attempting to level up (" .. sizeStr .. ")")
		ShopManager.handleLevelUp(player.UserId, sizeStr)
	end)
	
	-- Handle unit movement
	local moveUnitEvent = remoteEventsFolder:WaitForChild("MoveUnit")
	moveUnitEvent.OnServerEvent:Connect(function(player, fromPosition, toPosition)
		print("Player " .. player.Name .. " moving unit from " .. tostring(fromPosition) .. " to " .. tostring(toPosition))
		ShopManager.handleUnitMove(player.UserId, fromPosition, toPosition)
	end)
	
	-- Handle unit selling
	local sellUnitEvent = remoteEventsFolder:WaitForChild("SellUnit")
	sellUnitEvent.OnServerEvent:Connect(function(player, unitId, position)
		print("Player " .. player.Name .. " selling unit " .. unitId .. " at position " .. tostring(position))
		ShopManager.handleUnitSell(player.UserId, unitId, position)
	end)
	
	-- Handle player data reset (for testing)
	local resetPlayerDataEvent = remoteEventsFolder:WaitForChild("ResetPlayerData")
	resetPlayerDataEvent.OnServerEvent:Connect(function(player)
		print("Player " .. player.Name .. " resetting player data")
		local success = PlayerDataManager.resetPlayerData(player.UserId)
		if success then
			-- Send updated player data to client after reset
			local playerData = PlayerDataManager.getPlayerData(player.UserId)
			if playerData then
				local updatePlayerDataEvent = remoteEventsFolder:WaitForChild("UpdatePlayerData")
				updatePlayerDataEvent:FireClient(player, playerData)
				
				-- Also send empty board and bench states to clear the UI
				local updateBoardEvent = remoteEventsFolder:WaitForChild("UpdateBoard")
				local updateBenchEvent = remoteEventsFolder:WaitForChild("UpdateBench")
				if updateBoardEvent then
					updateBoardEvent:FireClient(player, playerData.boardState)
				end
				if updateBenchEvent then
					updateBenchEvent:FireClient(player, playerData.benchState)
				end
			end
		end
	end)
	
	-- Handle player data requests
	local updatePlayerDataEvent = remoteEventsFolder:WaitForChild("UpdatePlayerData")
	updatePlayerDataEvent.OnServerEvent:Connect(function(player)
		print("Player " .. player.Name .. " requesting player data")
		local playerData = PlayerDataManager.getPlayerData(player.UserId)
		if playerData then
			updatePlayerDataEvent:FireClient(player, playerData)
		end
	end)
	
	-- Handle PVP challenge requests
	local challengePlayerEvent = remoteEventsFolder:WaitForChild("ChallengePlayer")
	challengePlayerEvent.OnServerEvent:Connect(function(player, targetPlayerId)
		print("Player " .. player.Name .. " challenging player " .. targetPlayerId)
		PVPChallengeManager.createChallenge(player.UserId, targetPlayerId)
	end)
	
	-- Handle PVP challenge responses
	local acceptChallengeEvent = remoteEventsFolder:WaitForChild("AcceptChallenge")
	acceptChallengeEvent.OnServerEvent:Connect(function(player, challengerId)
		print("Player " .. player.Name .. " accepting challenge from " .. challengerId)
		PVPChallengeManager.acceptChallenge(player.UserId)
	end)
	
	local rejectChallengeEvent = remoteEventsFolder:WaitForChild("RejectChallenge")
	rejectChallengeEvent.OnServerEvent:Connect(function(player, challengerId)
		print("Player " .. player.Name .. " rejecting challenge from " .. challengerId)
		PVPChallengeManager.rejectChallenge(player.UserId)
	end)
	
	-- Handle battle start (when countdown ends)
	local startBattleEvent = remoteEventsFolder:WaitForChild("StartBattle")
	startBattleEvent.OnServerEvent:Connect(function(player, challengeId)
		print("Player " .. player.Name .. " requesting battle start for challenge " .. challengeId)
		PVPChallengeManager.startBattle(challengeId)
	end)

	-- Handle arena switching
	local switchArenaEvent = remoteEventsFolder:FindFirstChild(Constants.REMOTE_EVENT_NAMES.SWITCH_ARENA)
	if switchArenaEvent then
		switchArenaEvent.OnServerEvent:Connect(function(player, newArenaName)
			print("Player " .. player.Name .. " requested arena switch to '" .. tostring(newArenaName) .. "'")
			if typeof(newArenaName) ~= "string" then return end

			-- Normalize request (handle frames named VolcanicArenaFrame without space)
			local function normalize(s: string): string
				return s:lower():gsub("%s+", ""):gsub("_", "")
			end
			local inputOriginal = newArenaName
			local arenasFolder = game.ReplicatedStorage:FindFirstChild("Arenas")
			if arenasFolder then
				local normalizedInput = normalize(newArenaName)
				for _, child in ipairs(arenasFolder:GetChildren()) do
					if normalize(child.Name) == normalizedInput then
						if child.Name ~= newArenaName then
							print("Resolved arena name '" .. newArenaName .. "' -> '" .. child.Name .. "'")
						end
						newArenaName = child.Name
						break
					end
				end
			end

			-- Validate template exists after normalization
			if not arenasFolder or not arenasFolder:FindFirstChild(newArenaName) then
				warn("Invalid arena switch request - template missing: " .. tostring(inputOriginal))
				return
			end
			-- Update player data
			local PlayerDataManager = require(script.Parent.PlayerData)
			local data = PlayerDataManager.getPlayerData(player.UserId)
			if not data then return end
			data.selectedArenaName = newArenaName
			data.lastUpdated = os.time()
			-- Decide whether to persist immediately or throttle
			local now = os.time()
			local last = _lastArenaSaveTimes[player.UserId] or 0
			if now - last >= ARENA_SAVE_THROTTLE then
				local saved = PlayerDataManager.savePlayerData(player.UserId)
				if saved then
					_lastArenaSaveTimes[player.UserId] = now
				end
			else
				if not _pendingArenaSaves[player.UserId] then
					_pendingArenaSaves[player.UserId] = true
					spawn(function()
						local delayRemaining = ARENA_SAVE_THROTTLE - (now - last)
						wait(math.clamp(delayRemaining, 5, ARENA_SAVE_THROTTLE))
						local latestData = PlayerDataManager.getPlayerData(player.UserId)
						if latestData then
							local saved2 = PlayerDataManager.savePlayerData(player.UserId)
							if saved2 then
								_lastArenaSaveTimes[player.UserId] = os.time()
							end
						end
						_pendingArenaSaves[player.UserId] = false
					end)
				end
			end
			-- Perform physical switch
			local lobbyData = LobbyManager.getPlayerLobby(player.UserId)
			if lobbyData and lobbyData.arenaSpawner then
				local success = lobbyData.arenaSpawner:switchArenaForPlayer(player.UserId, newArenaName)
				if success then
					-- Resend player data so client can update checkmark
					local updatePlayerDataEvent2 = remoteEventsFolder:WaitForChild("UpdatePlayerData")
					updatePlayerDataEvent2:FireClient(player, data)
					-- Optional notification
					local notify = remoteEventsFolder:FindFirstChild(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
					if notify then
						notify:FireClient(player, "Arena switched to " .. newArenaName, 2)
					end
				end
			end
		end)
	end
	
	print("Server-side RemoteEvent handlers set up successfully!")
end

-- Function to find or create a lobby for a player
function LobbyManager.findOrCreateLobbyForPlayer(playerId: number): number
	-- Check if player is already in a lobby
	if playerLobbies[playerId] then
		return playerLobbies[playerId]
	end
	
	-- Find a lobby with available space
	for lobbyId, lobbyData in pairs(lobbies) do
		if lobbyData.playerCount < MAX_PLAYERS_PER_LOBBY then
			return lobbyId
		end
	end
	
	-- No available lobbies, create a new one
	return LobbyManager.createLobby()
end

-- Function to add a player to a lobby
function LobbyManager.addPlayerToLobby(playerId: number, player: Player): boolean
	local lobbyId = LobbyManager.findOrCreateLobbyForPlayer(playerId)
	local lobbyData = lobbies[lobbyId]
	
	if not lobbyData then
		warn("Failed to find lobby " .. lobbyId .. " for player " .. player.Name)
		return false
	end
	
	-- Check if lobby is full
	if lobbyData.playerCount >= MAX_PLAYERS_PER_LOBBY then
		warn("Lobby " .. lobbyId .. " is full, cannot add player " .. player.Name)
		return false
	end
	
	-- Add player to lobby
	lobbyData.players[playerId] = player
	lobbyData.playerCount = lobbyData.playerCount + 1
	playerLobbies[playerId] = lobbyId
	
	-- Get the current player count for this lobby for positioning
	local playerIndex = lobbyData.playerCount
	
	-- Initialize player in lobby (this creates the arena and player folder)
	LobbyManager.initializePlayerInLobby(playerId, player, lobbyData, playerIndex)
	
	-- Position player at lobby location in main workspace (don't move character to lobby workspace)
	spawn(function()
		-- Wait for character to spawn
		local character = player.Character or player.CharacterAdded:Wait()
		
		-- Keep character in main workspace, just position it at the lobby location
		-- Use the same positioning logic as ArenaSpawner for consistency
		local lobbyId = lobbyData.lobbyId
		
		-- Calculate character position in the same 2x3 grid layout as arenas
		-- Grid layout: 2 rows (Z), 3 columns (X)
		-- Z = ARENA_SPACING/2: Players 1, 2, 3 (front row)
		-- Z = -ARENA_SPACING/2: Players 4, 5, 6 (back row)
		-- X positions: -ARENA_SPACING, 0, ARENA_SPACING (left, center, right)
		local row = math.floor((playerIndex - 1) / 3)  -- 0 or 1 (which Z level)
		local column = (playerIndex - 1) % 3  -- 0, 1, or 2 (which X position)
		
		local lobbyCenter = Vector3.new(
			(lobbyId - 1) * Constants.LOBBY_SPACING + (column - 1) * Constants.ARENA_SPACING, -- X: lobby offset + grid X position
			5, -- Slightly above ground
			(row == 0) and Constants.ARENA_SPACING/2 or -Constants.ARENA_SPACING/2 -- Z: ARENA_SPACING/2 for front row, -ARENA_SPACING/2 for back row
		)
		character:PivotTo(CFrame.new(lobbyCenter))
		
		print("Positioned character for " .. player.Name .. " at lobby " .. lobbyId .. " location in main workspace: " .. tostring(lobbyCenter))
	end)
	
	-- Initialize board detection for this player after arena is created
	spawn(function()
		wait(3) -- Wait for arena to be fully created
		local BoardDetection = require(script.Parent.BoardDetection)
		BoardDetection.initializeForPlayer(playerId, player.Name, lobbyData)
	end)
	
	print("Added player " .. player.Name .. " to lobby " .. lobbyId .. " (Total: " .. lobbyData.playerCount .. "/" .. MAX_PLAYERS_PER_LOBBY .. ")")
	return true
end

-- Function to initialize a player in a specific lobby
function LobbyManager.initializePlayerInLobby(playerId: number, player: Player, lobbyData: any, playerIndex: number)
	-- Load or create player data FIRST so arena spawner can use selectedArenaName
	local PlayerDataManager = require(script.Parent.PlayerData)
	local playerData = PlayerDataManager.getPlayerData(playerId)
	if not playerData then
		print("[LobbyManager] Loading player data before arena spawn for " .. player.Name)
		playerData = PlayerDataManager.loadPlayerData(playerId, player.Name)
	end

	-- Now create the player's arena structure using their saved selection
	local playerArena = lobbyData.arenaSpawner:createPlayerArena(playerId, player.Name, playerIndex)
	if not playerArena then
		warn("Failed to create arena for player " .. player.Name .. " in lobby " .. lobbyData.lobbyId)
		return
	end

	print("Initializing shop for " .. player.Name .. " in lobby " .. lobbyData.lobbyId)
	
	-- Initialize shop for this player
	local ShopManager = require(script.Parent.ShopManager)
	local shopData = ShopManager.getPlayerShop(playerId)
	if not shopData then
		print("Creating new shop for " .. player.Name)
		ShopManager.initializePlayerShop(playerId)
	end
	
	-- Send initial shop data to client
	print("Sending shop data to " .. player.Name)
	ShopManager.sendShopToClient(playerId)
	
	-- Send initial player data to client (after arena has spawned with correct selection)
	print("Sending initial player data (arena selection: " .. tostring(playerData.selectedArenaName) .. ") to " .. player.Name)
	local updatePlayerDataEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("UpdatePlayerData")
	updatePlayerDataEvent:FireClient(player, playerData)
	
	-- Send board and bench updates to client
	local updateBoardEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("UpdateBoard")
	local updateBenchEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("UpdateBench")
	if updateBoardEvent then
		updateBoardEvent:FireClient(player, playerData.boardState)
	end
	if updateBenchEvent then
		updateBenchEvent:FireClient(player, playerData.benchState)
	end
	
	-- Spawn existing units on the physical board/bench
	spawn(function()
		wait(2) -- Wait for arena to be fully created
		local UnitSpawner = require(script.Parent.UnitSpawner)
		UnitSpawner.spawnExistingUnits(playerId, playerData)
	end)
	
	print("Created arena '" .. playerArena.Name .. "' for player " .. player.Name .. " in lobby " .. lobbyData.lobbyId)
end

-- Function to remove a player from their lobby
function LobbyManager.removePlayerFromLobby(playerId: number)
	local lobbyId = playerLobbies[playerId]
	if not lobbyId then
		return
	end
	
	local lobbyData = lobbies[lobbyId]
	if not lobbyData then
		return
	end
	
	-- Remove player from lobby
	lobbyData.players[playerId] = nil
	playerLobbies[playerId] = nil
	
	-- Cleanup player resources using the arena spawner
	lobbyData.arenaSpawner:removeArena(playerId)
	
	print("Removed player " .. playerId .. " from lobby " .. lobbyId .. " (Remaining: " .. lobbyData.playerCount .. ")")
	
	-- Check if lobby is empty and can be cleaned up
	if lobbyData.playerCount == 0 then
		LobbyManager.cleanupEmptyLobby(lobbyId)
	end
end

-- Function to cleanup an empty lobby
function LobbyManager.cleanupEmptyLobby(lobbyId: number)
	local lobbyData = lobbies[lobbyId]
	if not lobbyData then
		return
	end
	
	-- Cleanup the baseplate for this lobby
	if lobbyData.arenaSpawner then
		lobbyData.arenaSpawner:cleanupLobbyBaseplate(lobbyId)
	end
	
	-- Destroy the lobby workspace
	if lobbyData.workspace then
		lobbyData.workspace:Destroy()
	end
	
	-- Remove from lobbies table
	lobbies[lobbyId] = nil
	
	print("Cleaned up empty lobby " .. lobbyId)
end

-- Function to get lobby info for a player
function LobbyManager.getPlayerLobby(playerId: number): any
	local lobbyId = playerLobbies[playerId]
	if not lobbyId then
		return nil
	end
	
	return lobbies[lobbyId]
end

-- Function to get a player's arena directly (to avoid circular dependencies)
function LobbyManager.getPlayerArena(playerId: number): Instance?
	local lobbyId = playerLobbies[playerId]
	if not lobbyId then
		return nil
	end
	
	local lobbyData = lobbies[lobbyId]
	if not lobbyData or not lobbyData.spawnPoints then
		return nil
	end
	
	return lobbyData.spawnPoints:FindFirstChild(tostring(playerId))
end

-- Function to get all lobbies
function LobbyManager.getAllLobbies(): {any}
	return lobbies
end

-- Function to get lobby statistics
function LobbyManager.getLobbyStats(): {any}
	local stats = {
		totalLobbies = 0,
		totalPlayers = 0,
		lobbyDetails = {}
	}
	
	for lobbyId, lobbyData in pairs(lobbies) do
		stats.totalLobbies = stats.totalLobbies + 1
		stats.totalPlayers = stats.totalPlayers + lobbyData.playerCount
		
		table.insert(stats.lobbyDetails, {
			lobbyId = lobbyId,
			playerCount = lobbyData.playerCount,
			maxPlayers = MAX_PLAYERS_PER_LOBBY,
			players = lobbyData.players
		})
	end
	
	return stats
end

-- Initialize lobby system
function LobbyManager.init()
	print("Lobby Manager initialized - Max players per lobby: " .. MAX_PLAYERS_PER_LOBBY)
	
	-- Set up server-side RemoteEvent handlers
	LobbyManager.setupRemoteEventHandlers()
	
	-- Create initial lobby
	LobbyManager.createLobby()
	
	-- Set up player joining/leaving handlers
	Players.PlayerAdded:Connect(function(player)
		LobbyManager.addPlayerToLobby(player.UserId, player)
	end)
	
	Players.PlayerRemoving:Connect(function(player)
		LobbyManager.removePlayerFromLobby(player.UserId)
	end)
	
	print("Lobby Manager setup complete")
end

return LobbyManager
