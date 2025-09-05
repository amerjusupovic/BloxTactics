--[[
	ArenaSpawner.luau
	Handles spawning and managing arenas for players
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(game.ReplicatedStorage.Shared.Constants)

local ArenaSpawner = {}

-- Track baseplates for each lobby
local lobbyBaseplates = {} -- {lobbyId = baseplate}

-- Constructor
function ArenaSpawner.new(workspace, spawnPoints)
	local self = setmetatable({}, {__index = ArenaSpawner})
	self.workspace = workspace
	self.spawnPoints = spawnPoints
	return self
end

-- Function to create a baseplate for a lobby if it doesn't exist
function ArenaSpawner:createLobbyBaseplate(lobbyId: number): BasePart?
	-- Check if baseplate already exists for this lobby
	if lobbyBaseplates[lobbyId] then
		return lobbyBaseplates[lobbyId]
	end
	
	-- Don't create baseplate for lobby 1 since it already exists at (0, 0, 0)
	if lobbyId == 1 then
		return nil
	end
	
	-- Find the existing baseplate in the workspace
	local existingBaseplate = workspace:FindFirstChild("Baseplate")
	if not existingBaseplate then
		warn("No existing baseplate found in workspace")
		return nil
	end
	
	-- Clone the existing baseplate
	local baseplate = existingBaseplate:Clone()
	baseplate.Name = "LobbyBaseplate_" .. lobbyId
	
	-- Position the cloned baseplate for this lobby
	local baseplatePosition = Vector3.new(
		(lobbyId - 1) * Constants.LOBBY_SPACING, -- Start second lobby at 2000, third at 4000, etc.
		0, -- Same Y level as original baseplate
		0 -- Center of the lobby area
	)
	baseplate.Position = baseplatePosition
	
	-- Parent the baseplate to the workspace
	baseplate.Parent = workspace
	
	-- Store the baseplate reference
	lobbyBaseplates[lobbyId] = baseplate
	
	print("Cloned baseplate for lobby " .. lobbyId .. " at position " .. tostring(baseplatePosition))
	return baseplate
end

-- Function to create a grass arena for a player
function ArenaSpawner:createGrassArena(playerId: number, playerName: string, playerIndex: number): Model?
	local spawnPoints = self.spawnPoints
	if not spawnPoints then
		warn("No spawn points folder found for arena creation")
		return nil
	end
	
	-- Create player folder if it doesn't exist
	local playerFolder = spawnPoints:FindFirstChild(tostring(playerId))
	if not playerFolder then
		playerFolder = Instance.new("Folder")
		playerFolder.Name = tostring(playerId)
		playerFolder.Parent = spawnPoints
		print("Created player folder for " .. playerName .. " (ID: " .. playerId .. ")")
	end
	
	-- Get the Grass Arena model from ReplicatedStorage
	local grassArenaModel = ReplicatedStorage:FindFirstChild("Arenas"):FindFirstChild("Grass Arena")
	if not grassArenaModel then
		warn("Grass Arena model not found in ReplicatedStorage.Arenas")
		return nil
	end
	
	-- Clone the existing Grass Arena model
	print("Cloning Grass Arena for player " .. playerName)
	local clonedArena = grassArenaModel:Clone()
	clonedArena.Name = "Grass Arena"
	
	-- Position the arena for this player based on lobby ID
	-- Each lobby gets a different position to avoid overlap
	-- Use the lobby ID from the spawnPoints parent folder name
	local lobbyFolder = self.spawnPoints.Parent
	local lobbyId = 1 -- Default to lobby 1
	if lobbyFolder and lobbyFolder.Name:find("Lobby_") then
		lobbyId = tonumber(lobbyFolder.Name:match("Lobby_(%d+)")) or 1
	end
	
	-- Ensure baseplate exists for this lobby (except lobby 1 which uses existing baseplate)
	if lobbyId > 1 then
		self:createLobbyBaseplate(lobbyId)
	end
	
	-- Use the playerIndex passed from the lobby manager for positioning
	-- This ensures arena positioning is synchronized with lobby player counts
	
	-- Calculate arena position in a 2x3 grid layout
	-- Grid layout: 2 rows (Z), 3 columns (X)
	-- Z = ARENA_SPACING/2: Players 1, 2, 3 (front row)
	-- Z = -ARENA_SPACING/2: Players 4, 5, 6 (back row)
	-- X positions: -ARENA_SPACING, 0, ARENA_SPACING (left, center, right)
	local row = math.floor((playerIndex - 1) / 3)  -- 0 or 1 (which Z level)
	local column = (playerIndex - 1) % 3  -- 0, 1, or 2 (which X position)
	
	-- Calculate arena position relative to the lobby baseplate
	local arenaPosition = Vector3.new(
		(lobbyId - 1) * Constants.LOBBY_SPACING + (column - 1) * Constants.ARENA_SPACING, -- X: lobby offset + grid X position
		Constants.GROUND_LEVEL, -- Slightly above the baseplate
		(row == 0) and Constants.ARENA_SPACING/2 or -Constants.ARENA_SPACING/2 -- Z: ARENA_SPACING/2 for front row, -ARENA_SPACING/2 for back row
	)
	
	-- Set the arena position
	if clonedArena:IsA("Model") then
		-- For Models, use PivotTo to set the position
		clonedArena:PivotTo(CFrame.new(arenaPosition))
		
		-- Also ensure the PrimaryPart is set if it exists
		if not clonedArena.PrimaryPart then
			-- Try to find a suitable primary part
			for _, child in pairs(clonedArena:GetChildren()) do
				if child:IsA("BasePart") then
					clonedArena.PrimaryPart = child
					break
				end
			end
		end
	else
		-- If it's a folder, try to position its children
		for _, child in pairs(clonedArena:GetChildren()) do
			if child:IsA("BasePart") then
				child.Position = child.Position + arenaPosition
			end
		end
	end
	
	-- Parent the cloned arena to the player folder
	clonedArena.Parent = playerFolder
	
	
	-- Ensure Enemy Unit Board exists
	local enemyUnitBoard = clonedArena:FindFirstChild("Enemy Unit Board")
	if not enemyUnitBoard then
		enemyUnitBoard = Instance.new("Folder")
		enemyUnitBoard.Name = "Enemy Unit Board"
		enemyUnitBoard.Parent = clonedArena
		
		-- Create hexes for the enemy board (same structure as regular board)
		for enemyRow = 1, 4 do
			for enemyCol = 1, 7 do
				local hex = Instance.new("Part")
				hex.Name = string.format("Hex_%d_%d", enemyRow, enemyCol)
				hex.Size = Vector3.new(4, 0.2, 4)
				hex.Material = Enum.Material.Neon
				hex.BrickColor = BrickColor.new("Bright red")
				hex.Anchored = true
				hex.CanCollide = false
				hex.Transparency = 0.7
				
				-- Position hexes in a grid pattern
				local hexPosition = Vector3.new(
					(enemyCol - 4) * 5, -- Center around 0, spacing of 5
					0.1, -- Slightly above ground
					(enemyRow - 2.5) * 5 -- Center around 0, spacing of 5
				)
				
				-- Offset for enemy board (to the right of the regular board)
				hexPosition = hexPosition + Vector3.new(20, 0, 0)
				
				hex.Position = hexPosition
				hex.Parent = enemyUnitBoard
			end
		end
		
		print("Created Enemy Unit Board with hexes for player " .. playerName)
	end
	
	-- Debug: Print the actual position after cloning
	local actualPosition
	if clonedArena:IsA("Model") then
		actualPosition = clonedArena:GetPivot().Position
	else
		actualPosition = arenaPosition
	end
	
	print("Successfully cloned Grass Arena for player " .. playerName .. " at position " .. tostring(arenaPosition))
	print("Actual arena position: " .. tostring(actualPosition))
	return clonedArena
end

-- Function to remove arena for a player
function ArenaSpawner:removeArena(playerId: number)
	local spawnPoints = self.spawnPoints
	if not spawnPoints then
		return
	end
	
	local playerFolder = spawnPoints:FindFirstChild(tostring(playerId))
	if playerFolder then
		playerFolder:Destroy()
		print("Removed arena for player ID: " .. playerId)
	end
	
	-- Check if this was the last arena in the lobby and cleanup baseplate if needed
	local lobbyFolder = self.spawnPoints.Parent
	if lobbyFolder and lobbyFolder.Name:find("Lobby_") then
		local lobbyId = tonumber(lobbyFolder.Name:match("Lobby_(%d+)")) or 1
		local remainingArenas = 0
		
		-- Count remaining arenas in this lobby
		for _, child in pairs(spawnPoints:GetChildren()) do
			if child:FindFirstChild("Grass Arena") then
				remainingArenas = remainingArenas + 1
			end
		end
		
		-- If no arenas left and this lobby has a custom baseplate (not lobby 1), cleanup the baseplate
		if remainingArenas == 0 and lobbyId > 1 and lobbyBaseplates[lobbyId] then
			lobbyBaseplates[lobbyId]:Destroy()
			lobbyBaseplates[lobbyId] = nil
			print("Cleaned up baseplate for lobby " .. lobbyId .. " - no more arenas")
		end
	end
end

-- Function to get arena for a player
function ArenaSpawner:getArena(playerId: number): Folder?
	local spawnPoints = self.spawnPoints
	if not spawnPoints then
		return nil
	end
	
	local playerFolder = spawnPoints:FindFirstChild(tostring(playerId))
	if not playerFolder then
		return nil
	end
	
	return playerFolder:FindFirstChild("Grass Arena")
end

-- Function to get enemy board for a player
function ArenaSpawner:getEnemyBoard(playerId: number): Folder?
	local grassArena = self:getArena(playerId)
	if not grassArena then
		return nil
	end
	
	-- Look for Enemy Unit Board folder in the cloned arena
	return grassArena:FindFirstChild("Enemy Unit Board")
end

-- Function to get a specific hex on the player's board
function ArenaSpawner:getBoardHex(playerId: number, row: number, col: number): Part?
	local grassArena = self:getArena(playerId)
	if not grassArena then
		return nil
	end
	
	local hexName = string.format("Hex_%d_%d", row, col)
	return grassArena:FindFirstChild(hexName)
end

-- Function to get a specific hex on the enemy board
function ArenaSpawner:getEnemyHex(playerId: number, row: number, col: number): Part?
	local enemyBoard = self:getEnemyBoard(playerId)
	if not enemyBoard then
		return nil
	end
	
	local hexName = string.format("Hex_%d_%d", row, col)
	return enemyBoard:FindFirstChild(hexName)
end

-- Function to get a specific bench spot
function ArenaSpawner:getBenchSpot(userId: number, benchIndex: number): Part?
	local grassArena = self:getArena(userId)
	if not grassArena then
		return nil
	end
	
	local benchName = string.format("Bench_%d", benchIndex)
	return grassArena:FindFirstChild(benchName)
end

-- Function to cleanup baseplate for a specific lobby
function ArenaSpawner:cleanupLobbyBaseplate(lobbyId: number)
	-- Don't cleanup baseplate for lobby 1 since it's the original baseplate
	if lobbyId == 1 then
		return
	end
	
	if lobbyBaseplates[lobbyId] then
		lobbyBaseplates[lobbyId]:Destroy()
		lobbyBaseplates[lobbyId] = nil
		print("Cleaned up baseplate for lobby " .. lobbyId)
	end
end

-- Initialize arena spawning for all existing players
function ArenaSpawner.init()
	print("Arena Spawner initialized - will clone existing arena models from ReplicatedStorage")
end

return ArenaSpawner
