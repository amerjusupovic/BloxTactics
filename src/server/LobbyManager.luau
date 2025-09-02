--[[
	LobbyManager.luau
	Manages multiple game lobbies, automatically creating new ones when needed
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Terrain = workspace.Terrain

local LobbyManager = {}

-- Lobby configuration
local MAX_PLAYERS_PER_LOBBY = 8
local LOBBY_SPACING = 1000 -- Distance between lobbies

-- Lobby storage
local lobbies = {} -- {lobbyId = lobbyData}
local playerLobbies = {} -- {playerId = lobbyId}
local nextLobbyId = 1

-- Lobby data structure
local LobbyData = {
	lobbyId = 0,
	players = {}, -- {playerId = player}
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
	local lobbyWorkspace = Instance.new("Folder")
	lobbyWorkspace.Name = "Lobby_" .. lobbyId
	
	-- Clone the baseplate
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		local success, clonedBaseplate = pcall(function()
			return baseplate:Clone()
		end)
		if success and clonedBaseplate then
			clonedBaseplate.Parent = lobbyWorkspace
			print("Successfully cloned baseplate for lobby " .. lobbyId)
		else
			warn("Failed to clone baseplate for lobby " .. lobbyId)
		end
	end
	
	-- Note: Lighting and Terrain services cannot be cloned
	-- They will use the global services instead
	
	-- Clone other important workspace objects
	for _, child in pairs(Workspace:GetChildren()) do
		if child.Name ~= "Baseplate" and 
		   child.Name ~= "SpawnPoints" and 
		   child.Name ~= "Players" and
		   child.Name ~= "Camera" and
		   child.Name ~= "Terrain" and
		   child.Name ~= "Lighting" then
			
			local success, clonedChild = pcall(function()
				return child:Clone()
			end)
			
			if success and clonedChild then
				clonedChild.Parent = lobbyWorkspace
				print("Successfully cloned " .. child.Name .. " for lobby " .. lobbyId)
			else
				warn("Failed to clone " .. child.Name .. " for lobby " .. lobbyId)
			end
		end
	end
	
	-- Create SpawnPoints folder for this lobby
	local spawnPoints = Instance.new("Folder")
	spawnPoints.Name = "SpawnPoints"
	spawnPoints.Parent = lobbyWorkspace
	
	-- Position the lobby workspace by moving cloned objects
	-- Calculate the offset for this lobby
	local lobbyOffset = Vector3.new(
		lobbyId * LOBBY_SPACING, -- X position (spread lobbies horizontally)
		0, -- Y position (ground level)
		0  -- Z position
	)
	
	-- Move all cloned objects to the lobby position
	for _, child in pairs(lobbyWorkspace:GetChildren()) do
		if child:IsA("BasePart") then
			child.Position = child.Position + lobbyOffset
		elseif child:IsA("Model") then
			child:PivotTo(CFrame.new(child:GetPivot().Position + lobbyOffset))
		end
	end
	
	print("Created lobby workspace " .. lobbyId .. " at position " .. tostring(lobbyOffset))
	return lobbyWorkspace
end

-- Function to create a new lobby
function LobbyManager.createLobby(): number
	local lobbyId = nextLobbyId
	nextLobbyId = nextLobbyId + 1
	
	-- Create lobby data
	local lobbyData = {
		lobbyId = lobbyId,
		players = {},
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
	
	-- Handle level up
	local levelUpEvent = remoteEventsFolder:WaitForChild("LevelUp")
	levelUpEvent.OnServerEvent:Connect(function(player)
		print("Player " .. player.Name .. " attempting to level up")
		ShopManager.handleLevelUp(player.UserId)
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
	acceptChallengeEvent.OnServerEvent:Connect(function(player)
		print("Player " .. player.Name .. " accepting challenge")
		PVPChallengeManager.acceptChallenge(player.UserId)
	end)
	
	local rejectChallengeEvent = remoteEventsFolder:WaitForChild("RejectChallenge")
	rejectChallengeEvent.OnServerEvent:Connect(function(player)
		print("Player " .. player.Name .. " rejecting challenge")
		PVPChallengeManager.rejectChallenge(player.UserId)
	end)
	
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
		if #lobbyData.players < MAX_PLAYERS_PER_LOBBY then
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
	if #lobbyData.players >= MAX_PLAYERS_PER_LOBBY then
		warn("Lobby " .. lobbyId .. " is full, cannot add player " .. player.Name)
		return false
	end
	
	-- Add player to lobby
	lobbyData.players[playerId] = player
	playerLobbies[playerId] = lobbyId
	
	-- Move player to lobby workspace
	local character = player.Character
	if character then
		character.Parent = lobbyData.workspace
		
		-- Position player at spawn point
		local spawnPoint = lobbyData.workspace:FindFirstChild("SpawnPoint")
		if spawnPoint then
			character:PivotTo(spawnPoint.CFrame + Vector3.new(0, 5, 0))
		end
	end
	
	-- Initialize player in lobby
	LobbyManager.initializePlayerInLobby(playerId, player, lobbyData)
	
	print("Added player " .. player.Name .. " to lobby " .. lobbyId .. " (Total: " .. #lobbyData.players .. "/" .. MAX_PLAYERS_PER_LOBBY .. ")")
	return true
end

-- Function to initialize a player in a specific lobby
function LobbyManager.initializePlayerInLobby(playerId: number, player: Player, lobbyData: any)
	-- Create the player's arena structure
	local grassArena = lobbyData.arenaSpawner:createGrassArena(playerId, player.Name)
	if not grassArena then
		warn("Failed to create arena for player " .. player.Name .. " in lobby " .. lobbyData.lobbyId)
		return
	end
	
	-- Initialize player data and shop for this player
	print("Initializing player data and shop for " .. player.Name .. " in lobby " .. lobbyData.lobbyId)
	
	-- Load or create player data
	local PlayerDataManager = require(script.Parent.PlayerData)
	local playerData = PlayerDataManager.getPlayerData(playerId)
	if not playerData then
		print("Creating new player data for " .. player.Name)
		playerData = PlayerDataManager.loadPlayerData(playerId, player.Name)
	end
	
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
	
	-- Send initial player data to client
	print("Sending initial player data to " .. player.Name)
	local updatePlayerDataEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("UpdatePlayerData")
	updatePlayerDataEvent:FireClient(player, playerData)
	
	print("Created arena for player " .. player.Name .. " in lobby " .. lobbyData.lobbyId)
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
	
	print("Removed player " .. playerId .. " from lobby " .. lobbyId .. " (Remaining: " .. #lobbyData.players .. ")")
	
	-- Check if lobby is empty and can be cleaned up
	if #lobbyData.players == 0 then
		LobbyManager.cleanupEmptyLobby(lobbyId)
	end
end

-- Function to cleanup an empty lobby
function LobbyManager.cleanupEmptyLobby(lobbyId: number)
	local lobbyData = lobbies[lobbyId]
	if not lobbyData then
		return
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
		stats.totalPlayers = stats.totalPlayers + #lobbyData.players
		
		table.insert(stats.lobbyDetails, {
			lobbyId = lobbyId,
			playerCount = #lobbyData.players,
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
