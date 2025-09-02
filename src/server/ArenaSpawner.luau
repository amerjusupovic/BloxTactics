--[[
	ArenaSpawner.luau
	Clones existing arena models for each player when they join
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(game.ReplicatedStorage.Shared.Constants)

local ArenaSpawner = {}

-- Constructor for creating a new ArenaSpawner instance
function ArenaSpawner.new(workspace: Workspace, spawnPoints: Folder): any
	local self = setmetatable({}, {__index = ArenaSpawner})
	self.workspace = workspace
	self.spawnPoints = spawnPoints
	return self
end

-- Function to create the Grass Arena structure for a player
function ArenaSpawner:createGrassArena(playerId: number, playerName: string): Folder?
	local spawnPoints = self.spawnPoints
	if not spawnPoints then
		-- Create SpawnPoints folder if it doesn't exist
		spawnPoints = Instance.new("Folder")
		spawnPoints.Name = "SpawnPoints"
		spawnPoints.Parent = self.workspace
		print("Created SpawnPoints folder in lobby workspace")
	end
	
	-- Create or get player folder
	local playerFolder = spawnPoints:FindFirstChild(tostring(playerId))
	if not playerFolder then
		playerFolder = Instance.new("Folder")
		playerFolder.Name = tostring(playerId)
		playerFolder.Parent = spawnPoints
		print("Created player folder for " .. playerName .. " (ID: " .. playerId .. ")")
	end
	
	-- Check if Grass Arena already exists
	local grassArena = playerFolder:FindFirstChild("Grass Arena")
	if grassArena then
		print("Grass Arena already exists for player " .. playerName)
		return grassArena
	end
	
	-- Get the existing Grass Arena model from ReplicatedStorage
	local arenasFolder = ReplicatedStorage:FindFirstChild("Arenas")
	if not arenasFolder then
		warn("Arenas folder not found in ReplicatedStorage!")
		return nil
	end
	
	local grassArenaModel = arenasFolder:FindFirstChild("Grass Arena")
	if not grassArenaModel then
		warn("Grass Arena model not found in ReplicatedStorage -> Arenas!")
		return nil
	end
	
	-- Clone the existing Grass Arena model
	print("Cloning Grass Arena for player " .. playerName)
	local clonedArena = grassArenaModel:Clone()
	clonedArena.Name = "Grass Arena"
	
	-- Position the arena for this player
	-- You can adjust the positioning logic based on your needs
	local arenaPosition = Vector3.new(
		(playerId % 10) * 100, -- Spread players out horizontally
		0, -- Ground level
		math.floor(playerId / 10) * 100 -- Spread players out vertically
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

-- Initialize arena spawning for all existing players
function ArenaSpawner.init()
	print("Arena Spawner initialized - will clone existing arena models from ReplicatedStorage")
end

return ArenaSpawner
