--[[
	BoardDetection.luau
	Detects when players enter other players' board areas
]]

local Players = game:GetService("Players")
local _ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = require(script.Parent.RemoteEvents)
local Constants = require(game.ReplicatedStorage.Shared.Constants)

local BoardDetection = {}

-- Player board areas storage
local playerBoardAreas = {} -- {playerId = boardArea}

-- Create board area for a player
function BoardDetection.createBoardArea(playerId: number, playerName: string, lobbyData: any)
	-- Find the player's arena in the lobby's SpawnPoints
	local spawnPoints = lobbyData and lobbyData.spawnPoints
	if not spawnPoints then
		warn("SpawnPoints not found in lobby for player " .. playerName)
		return nil
	end
	
	local playerFolder = spawnPoints:FindFirstChild(tostring(playerId))
	if not playerFolder then
		warn("Player folder not found for " .. playerName .. " in lobby")
		return nil
	end
	
	local grassArena = playerFolder:FindFirstChild("Grass Arena")
	if not grassArena then
		warn("Grass Arena not found for player " .. playerName .. " in lobby")
		return nil
	end
	
	-- Create a detection zone around the board
	local detectionZone = Instance.new("Part")
	detectionZone.Name = "BoardDetectionZone"
	detectionZone.Size = Constants.BOARD_DETECTION_ZONE_SIZE
	
	-- Get the position of the arena (handle both Model and Folder cases)
	local arenaPosition
	if grassArena:IsA("Model") then
		-- For Models, use GetPivot() to get the center position
		arenaPosition = grassArena:GetPivot().Position
	else
		-- For Folders, try to find a part to get position from
		local firstPart = grassArena:FindFirstChildOfClass("BasePart")
		if firstPart then
			arenaPosition = firstPart.Position
		else
			-- Fallback to origin if no parts found
			arenaPosition = Vector3.new(0, 0, 0)
		end
	end
	
	-- Position the zone at character height with forward offset
	detectionZone.Position = Vector3.new(
		arenaPosition.X, 
		Constants.BOARD_DETECTION_ZONE_HEIGHT, 
		arenaPosition.Z + Constants.BOARD_DETECTION_ZONE_FORWARD_OFFSET
	)
	detectionZone.Anchored = true
	detectionZone.CanCollide = false
	detectionZone.Transparency = 1 -- Invisible
	detectionZone.Parent = grassArena
	
	print("Created detection zone for player " .. playerName .. " at position " .. tostring(detectionZone.Position) .. " with radius " .. Constants.BOARD_DETECTION_ZONE_RADIUS)
	
	-- Create a folder to store the detection zone
	local boardArea = Instance.new("Folder")
	boardArea.Name = "BoardArea"
	boardArea.Parent = grassArena
	
	detectionZone.Parent = boardArea
	
	-- Store reference
	playerBoardAreas[playerId] = boardArea
	
	-- Set up detection
	BoardDetection.setupDetectionZone(detectionZone, playerId, playerName)
	
	return boardArea
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
		
		-- Check if player is within the circular detection zone
		local playerPos = humanoidRootPart.Position
		local zonePos = detectionZone.Position
		
		-- Calculate distance from zone center
		local distance = (playerPos - zonePos).Magnitude
		local radius = Constants.BOARD_DETECTION_ZONE_RADIUS
		
		return distance <= radius
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
	-- Note: This function is called before the lobby system is fully set up
	-- Individual player board detection will be initialized when they join lobbies
	print("Board Detection system initialized - waiting for players to join lobbies")
end

-- Function to initialize board detection for a specific player (called after lobby setup)
function BoardDetection.initializeForPlayer(playerId: number, playerName: string, lobbyData: any)
	-- Wait a bit for the arena to be fully created
	spawn(function()
		wait(1)
		BoardDetection.createBoardArea(playerId, playerName, lobbyData)
	end)
end

return BoardDetection
