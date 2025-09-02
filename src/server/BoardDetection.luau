--[[
	BoardDetection.luau
	Detects when players enter other players' board areas
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = require(script.Parent.RemoteEvents)
local Constants = require(game.ReplicatedStorage.Shared.Constants)

local BoardDetection = {}

-- Player board areas storage
local playerBoardAreas = {} -- {playerId = boardArea}

-- Create board area for a player
function BoardDetection.createBoardArea(playerId: number, playerName: string)
	-- TODO: Update to work with lobby system - ArenaSpawner is now instance-based
	-- Use ArenaSpawner to get the Grass Arena
	-- local ArenaSpawner = require(script.Parent.ArenaSpawner)
	-- local grassArena = ArenaSpawner.getArena(playerId)
	-- if not grassArena then
	-- 	warn("Grass Arena not found for player " .. playerId .. " - arena may not be created yet")
	-- 	return nil
	-- end
	
	-- Temporary: Return nil until BoardDetection is updated for lobby system
	warn("BoardDetection.createBoardArea is temporarily disabled - needs lobby system integration")
	return nil
	
	-- TODO: BoardDetection temporarily disabled for lobby system integration
	-- Create a detection zone around the board
	-- local detectionZone = Instance.new("Part")
	-- detectionZone.Name = "BoardDetectionZone"
	-- detectionZone.Size = Vector3.new(80, 30, 80) -- Larger detection zone for better coverage
	-- 
	-- -- Get the position of the arena (handle both Model and Folder cases)
	-- local arenaPosition
	-- if grassArena:IsA("Model") then
	-- 	-- For Models, use GetPivot() to get the center position
	-- 	arenaPosition = grassArena:GetPivot().Position
	-- else
	-- 	-- For Folders, try to find a part to get position from
	-- 	local firstPart = grassArena:FindFirstChildOfClass("BasePart")
	-- 	if firstPart then
	-- 	-- 	arenaPosition = firstPart.Position
	-- 	else
	-- 	-- 	-- Fallback to origin if no parts found
	-- 	-- 	arenaPosition = Vector3.new(0, 0, 0)
	-- 	-- end
	-- end
	-- 
	-- detectionZone.Position = arenaPosition
	-- detectionZone.Anchored = true
	-- detectionZone.CanCollide = false
	-- detectionZone.Transparency = 1 -- Invisible
	-- detectionZone.Parent = grassArena
	-- 
	-- print("Created detection zone for player " .. playerName .. " at position " .. tostring(arenaPosition))
	-- 
	-- -- Create a folder to store the detection zone
	-- local boardArea = Instance.new("Folder")
	-- boardArea.Name = "BoardArea"
	-- boardArea.Parent = grassArena
	-- 
	-- detectionZone.Parent = boardArea
	-- 
	-- -- Store reference
	-- playerBoardAreas[playerId] = boardArea
	-- 
	-- -- Set up detection
	-- BoardDetection.setupDetectionZone(detectionZone, playerId, playerName)
	-- 
	-- return boardArea
end

-- Set up detection zone for a player's board
function BoardDetection.setupDetectionZone(detectionZone: Part, boardOwnerId: number, boardOwnerName: string)
	local playersInZone = {}
	
	-- Function to check if a player is in the zone
	local function isPlayerInZone(player: Player): boolean
		local character = player.Character
		if not character then return false end
		
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then return false end
		
		-- Check if player is within the detection zone bounds
		local playerPos = humanoidRootPart.Position
		local zonePos = detectionZone.Position
		local zoneSize = detectionZone.Size
		
		-- Check if player is within the rectangular bounds of the zone
		local halfSize = zoneSize / 2
		return math.abs(playerPos.X - zonePos.X) <= halfSize.X and
			   math.abs(playerPos.Y - zonePos.Y) <= halfSize.Y and
			   math.abs(playerPos.Z - zonePos.Z) <= halfSize.Z
	end
	
	-- Function to handle player entering zone
	local function onPlayerEnterZone(player: Player)
		if player.UserId == boardOwnerId then
			return -- Don't challenge yourself
		end
		
		if playersInZone[player.UserId] then
			return -- Already in zone
		end
		
		playersInZone[player.UserId] = true
		
		-- Show challenge prompt to the player
		local showChallengePromptEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_CHALLENGE_PROMPT)
		if showChallengePromptEvent then
			showChallengePromptEvent:FireClient(player, boardOwnerId, boardOwnerName)
		end
		
		print("Player " .. player.Name .. " entered " .. boardOwnerName .. "'s board area")
	end
	
	-- Function to handle player leaving zone
	local function onPlayerLeaveZone(player: Player)
		if not playersInZone[player.UserId] then
			return
		end
		
		playersInZone[player.UserId] = nil
		
		-- Hide challenge prompt
		local hideChallengePromptEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.HIDE_CHALLENGE_PROMPT)
		if hideChallengePromptEvent then
			hideChallengePromptEvent:FireClient(player)
		end
		
		print("Player " .. player.Name .. " left " .. boardOwnerName .. "'s board area")
	end
	
	-- Check for players in zone periodically
	spawn(function()
		while detectionZone.Parent do
			wait(0.5) -- Check every 0.5 seconds
			
			-- Check all players
			for _, player in pairs(Players:GetPlayers()) do
				if isPlayerInZone(player) then
					if not playersInZone[player.UserId] then
						onPlayerEnterZone(player)
					end
				else
					if playersInZone[player.UserId] then
						onPlayerLeaveZone(player)
					end
				end
			end
		end
	end)
end

-- Remove board area for a player
function BoardDetection.removeBoardArea(playerId: number)
	local boardArea = playerBoardAreas[playerId]
	if boardArea then
		boardArea:Destroy()
		playerBoardAreas[playerId] = nil
	end
end

-- Get board area for a player
function BoardDetection.getBoardArea(playerId: number)
	return playerBoardAreas[playerId]
end

-- Initialize board detection for all existing players
function BoardDetection.init()
	-- Create board areas for existing players
	for _, player in pairs(Players:GetPlayers()) do
		BoardDetection.createBoardArea(player.UserId, player.Name)
	end
	
	-- Set up player joining/leaving handlers
	Players.PlayerAdded:Connect(function(player)
		-- Wait for the arena to be created by ArenaSpawner
		wait(3)
		BoardDetection.createBoardArea(player.UserId, player.Name)
	end)
	
	Players.PlayerRemoving:Connect(function(player)
		BoardDetection.removeBoardArea(player.UserId)
	end)
	
	print("Board Detection system initialized")
end

return BoardDetection
