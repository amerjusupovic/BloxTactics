--[[
	BoardDetection.luau
	Detects when players enter other players' board areas
]]

local Players = game:GetService("Players")
local _ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = require(script.Parent.RemoteEvents)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local BattleManager = require(script.Parent.BattleManager)
local PVPChallengeManager = require(script.Parent.PVPChallengeManager)

local BoardDetection = {}

-- Player board areas storage
local playerBoardAreas = {} -- {playerId = boardArea}

-- Create board area for a player
function BoardDetection.createBoardArea(playerId: number, playerName: string, lobbyData: any)
	-- If an old board area exists (e.g., after arena switch), clean it up first
	local existing = playerBoardAreas[playerId]
	if existing then
		if existing.Parent then
			existing:Destroy()
		end
		playerBoardAreas[playerId] = nil
	end

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
	
	local grassArena
	for _, child in pairs(playerFolder:GetChildren()) do
		if child.Name:match("%sArena$") then
			grassArena = child
			break
		end
	end
	-- Fallback: accept any child containing 'Arena' if strict match failed (handles names like 'VolcanicArena')
	if not grassArena then
		for _, child in pairs(playerFolder:GetChildren()) do
			if string.find(child.Name, "Arena") then
				grassArena = child
				break
			end
		end
	end
	if not grassArena then
		warn("Arena not found for player " .. playerName .. " in lobby")
		return nil
	end
	
	-- Create a detection zone around the board
	local detectionZone = Instance.new("Part")
	detectionZone.Name = "BoardDetectionZone"
	detectionZone.Size = Constants.BOARD_DETECTION_ZONE_SIZE

	-- Compute arena pivot and forward to place zone with correct orientation
	local arenaPos: Vector3
	local forward: Vector3 = Vector3.new(0, 0, 1)
	if grassArena:IsA("Model") then
		local pivot = grassArena:GetPivot()
		arenaPos = pivot.Position
		forward = pivot.LookVector -- model's forward
	else
		-- For Folders, try to find a part to get position from
		local firstPart = grassArena:FindFirstChildOfClass("BasePart")
		if firstPart then
			arenaPos = firstPart.Position
			-- Approximate forward as +Z in world if no model rotation
		else
			arenaPos = Vector3.new(0, 0, 0)
		end
	end

	-- Position the zone at fixed height with forward offset relative to arena orientation
	local zonePos = Vector3.new(arenaPos.X, Constants.BOARD_DETECTION_ZONE_HEIGHT, arenaPos.Z)
	zonePos += forward.Unit * Constants.BOARD_DETECTION_ZONE_FORWARD_OFFSET
	detectionZone.Position = zonePos
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
	-- Track players currently inside the zone
	-- playersInZone[playerId] = true/false (presence)
	-- promptShown[playerId] = true if a challenge prompt was sent to that player
	local playersInZone: {[number]: boolean} = {}
	local promptShown: {[number]: boolean} = {}

	-- Helper: check if a player is within the detection radius
	local function isPlayerInZone(player: Player): boolean
		local character = player.Character
		if not character then return false end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then return false end
		local distance = (hrp.Position - detectionZone.Position).Magnitude
		return distance <= Constants.BOARD_DETECTION_ZONE_RADIUS
	end

	-- Helper: determines if we are allowed to show a challenge prompt between visitor and board owner
	local function canShowPromptFor(player: Player): boolean
		-- Never show for the board owner themselves
		if player.UserId == boardOwnerId then return false end
		-- Suppress if either the visiting player OR the board owner is currently in a battle
		if BattleManager.isPlayerInBattle(player.UserId) then return false end
		if BattleManager.isPlayerInBattle(boardOwnerId) then return false end
		-- Suppress if either is in battle preparation phase
		if PVPChallengeManager.isPlayerInBattlePreparation(player.UserId) then return false end
		if PVPChallengeManager.isPlayerInBattlePreparation(boardOwnerId) then return false end
		return true
	end

	local function showPrompt(player: Player)
		local showEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_CHALLENGE_PROMPT)
		if showEvent then
			showEvent:FireClient(player, boardOwnerId, boardOwnerName)
			promptShown[player.UserId] = true
			print(string.format("[BoardDetection] Show challenge prompt to %s for board owner %s", player.Name, boardOwnerName))
		end
	end

	local function hidePrompt(player: Player)
		if not promptShown[player.UserId] then return end
		local hideEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.HIDE_CHALLENGE_PROMPT)
		if hideEvent then
			hideEvent:FireClient(player)
			print(string.format("[BoardDetection] Hide challenge prompt from %s (battle state change or exit)", player.Name))
		end
		promptShown[player.UserId] = nil
	end

	local function onEnter(player: Player)
		if playersInZone[player.UserId] then return end
		playersInZone[player.UserId] = true
		print(string.format("Player %s entered %s's board area", player.Name, boardOwnerName))
		if canShowPromptFor(player) then
			showPrompt(player)
		else
			-- Explicitly ensure any lingering prompt is hidden (safety)
			hidePrompt(player)
		end
	end

	local function onLeave(player: Player)
		if not playersInZone[player.UserId] then return end
		playersInZone[player.UserId] = nil
		hidePrompt(player)
		print(string.format("Player %s left %s's board area", player.Name, boardOwnerName))
	end

	-- Periodic zone & state evaluation
	spawn(function()
		while detectionZone.Parent do
			wait(0.5)
			local boardOwnerInBattle = BattleManager.isPlayerInBattle(boardOwnerId)
			local boardOwnerInPrep = PVPChallengeManager.isPlayerInBattlePreparation(boardOwnerId)
			for _, player in pairs(Players:GetPlayers()) do
				local inside = isPlayerInZone(player)
				if inside then
					if not playersInZone[player.UserId] then
						onEnter(player)
					else
						-- Already inside; ensure prompt visibility matches current battle/preparation state
						local allowed = (not boardOwnerInBattle and not boardOwnerInPrep) and canShowPromptFor(player)
						if allowed and not promptShown[player.UserId] then
							showPrompt(player)
						elseif (not allowed) and promptShown[player.UserId] then
							hidePrompt(player)
						end
					end
				else
					if playersInZone[player.UserId] then
						onLeave(player)
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
