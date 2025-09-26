--[[
	PVPChallengeManager.luau
	Manages PVP challenges between players
]]

local Players = game:GetService("Players")
local _ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = require(script.Parent.RemoteEvents)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local BattleManager = require(script.Parent.BattleManager)

local PVPChallengeManager = {}

-- Active challenges storage
local activeChallenges = {} -- {challengeId = challengeData}
local playerChallenges = {} -- {playerId = challengeId}

-- Challenge data structure
local _ChallengeData = {
	challengerId = nil,
	challengedId = nil,
	challengeTime = nil,
	status = "pending", -- "pending", "accepted", "rejected", "expired", "battling", "completed"
	battlePreparationTime = nil,
	battleStartTime = nil,
	battleId = nil -- Reference to the battle in BattleManager
}

-- Generate unique challenge ID
local function generateChallengeId(): string
	return "challenge_" .. os.time() .. "_" .. math.random(1000, 9999)
end

-- Helper function to find a player's arena without circular dependencies
function PVPChallengeManager.findPlayerArena(playerId: number): Instance?
	-- Search through all lobbies in workspace to find the player's arena
	for _, lobby in pairs(game.Workspace:GetChildren()) do
		if lobby.Name:find("Lobby_") then
			local spawnPoints = lobby:FindFirstChild("SpawnPoints")
			if spawnPoints then
				local playerFolder = spawnPoints:FindFirstChild(tostring(playerId))
				if playerFolder then
					-- Return any arena (child with "Arena" in the name), not just Grass Arena
					for _, child in pairs(playerFolder:GetChildren()) do
						if child.Name:find("Arena") then
							print("DEBUG: Found arena '" .. child.Name .. "' for player " .. playerId)
							return child
						end
					end
					-- Debug: List all children if no arena found
					warn("DEBUG: No arena found for player " .. playerId .. " in folder " .. playerFolder.Name)
					warn("Available children in player folder:")
					for _, child in pairs(playerFolder:GetChildren()) do
						warn("  - " .. child.Name .. " (" .. child.ClassName .. ")")
					end
				else
					warn("DEBUG: Player folder not found for player " .. playerId .. " in lobby " .. lobby.Name)
				end
			else
				warn("DEBUG: SpawnPoints not found in lobby " .. lobby.Name)
			end
		end
	end
	warn("DEBUG: No arena found for player " .. playerId .. " in any lobby")
	return nil
end

-- Helper function to check if arena has required battle components
function PVPChallengeManager.ensureArenaBattleComponents(arena: Instance, playerName: string)
	if not arena then 
		warn("Arena is nil for player: " .. playerName)
		return 
	end
	
	-- Check if Enemy Unit Board exists
	local enemyUnitBoard = arena:FindFirstChild("Enemy Unit Board")
	if not enemyUnitBoard then
		warn("Enemy Unit Board not found in arena for player: " .. playerName)
		warn("Arena name: " .. arena.Name .. ", Arena type: " .. arena.ClassName)
		warn("Available children in arena:")
		for _, child in pairs(arena:GetChildren()) do
			warn("  - " .. child.Name .. " (" .. child.ClassName .. ")")
		end
		return
	end
	
	print("Enemy Unit Board found for player: " .. playerName)
end

-- Check if player is already in a challenge
function PVPChallengeManager.isPlayerInChallenge(playerId: number): boolean
	return playerChallenges[playerId] ~= nil
end

-- Check if player can be challenged
function PVPChallengeManager.canPlayerBeChallenged(playerId: number): boolean
	local player = Players:GetPlayerByUserId(playerId)
	if not player then
		return false
	end
	
	-- Check if player is already in a challenge
	if PVPChallengeManager.isPlayerInChallenge(playerId) then
		return false
	end
	
	-- Check if player is in a battle
	if BattleManager.isPlayerInBattle(playerId) then
		return false
	end

	-- Check if player is in battle preparation (accepted challenge not yet started)
	if PVPChallengeManager.isPlayerInBattlePreparation(playerId) then
		return false
	end
	
	return true
end

-- Create a new challenge
function PVPChallengeManager.createChallenge(challengerId: number, challengedId: number): string?
	print("DEBUG: Creating challenge from challenger ID:", challengerId, "to challenged ID:", challengedId)
	
	-- Validate players
	if not PVPChallengeManager.canPlayerBeChallenged(challengerId) then
		warn("DEBUG: Challenger cannot be challenged:", challengerId)
		return nil
	end
	
	if not PVPChallengeManager.canPlayerBeChallenged(challengedId) then
		warn("DEBUG: Challenged player cannot be challenged:", challengedId)
		return nil
	end

	-- At this point canPlayerBeChallenged already prevents creating a challenge if either
	-- player is currently in a battle (BattleManager.isPlayerInBattle). This ensures no
	-- challenge UI will be sent while in battle.
	
	-- Create challenge data
	local challengeId = generateChallengeId()
	local challenge = {
		challengerId = challengerId,
		challengedId = challengedId,
		challengeTime = os.time(),
		status = "pending",
		battlePreparationTime = nil,
		battleStartTime = nil,
		battleId = nil
	}
	
	-- Store challenge
	activeChallenges[challengeId] = challenge
	playerChallenges[challengerId] = challengeId
	playerChallenges[challengedId] = challengeId
	
	print("DEBUG: Challenge stored with ID:", challengeId, "Challenger:", challengerId, "Challenged:", challengedId)
	
	-- Send challenge notification to challenged player
	local challengedPlayer = Players:GetPlayerByUserId(challengedId)
	if challengedPlayer then
		local challengerPlayer = Players:GetPlayerByUserId(challengerId)
		local challengerName = challengerPlayer and challengerPlayer.Name or "Unknown Player"
		
		print("Sending challenge notification to player:", challengedPlayer.Name)
		print("Challenger:", challengerName, "ID:", challengerId)
		
		local challengeEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
		challengeEvent:FireClient(challengedPlayer, challengerName .. " has challenged you to a battle!", 10)
		
		-- Send challenge request UI
		local challengeRequestEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_CHALLENGE_REQUEST)
		print("Firing ShowChallengeRequest event to player:", challengedPlayer.Name)
		
		-- Get challenger's level from player data
		local PlayerDataManager = require(script.Parent.PlayerData)
		local challengerData = PlayerDataManager.getPlayerData(challengerId)
		local challengerLevel = challengerData and challengerData.level or 1
		
		challengeRequestEvent:FireClient(challengedPlayer, challengerId, challengerName, challengerLevel)
		print("ShowChallengeRequest event fired successfully")
	else
		warn("Challenged player not found for ID:", challengedId)
	end
	
	print("Challenge created: " .. challengeId .. " from " .. challengerId .. " to " .. challengedId)
	return challengeId
end

-- Accept a challenge
function PVPChallengeManager.acceptChallenge(challengedId: number): boolean
	print("DEBUG: Accept challenge called for challenged player ID:", challengedId)
	
	local challengeId = playerChallenges[challengedId]
	if not challengeId then
		warn("DEBUG: No challenge found for challenged player ID:", challengedId)
		return false
	end
	
	print("DEBUG: Found challenge ID:", challengeId)
	
	local challenge = activeChallenges[challengeId]
	if not challenge or challenge.status ~= "pending" then
		warn("DEBUG: Challenge not found or not pending. Status:", challenge and challenge.status or "nil")
		return false
	end

	-- Prevent acceptance if either player entered a battle in the meantime
	if BattleManager.isPlayerInBattle(challenge.challengerId) or BattleManager.isPlayerInBattle(challenge.challengedId) then
		warn("DEBUG: Cannot accept challenge because one or both players are currently in a battle")
		-- Safety: mark as expired/rejected to free players
		challenge.status = "expired"
		PVPChallengeManager.cleanupChallenge(challengeId)
		return false
	end
	
	-- Update challenge status
	challenge.status = "accepted"
	challenge.battlePreparationTime = os.time()
	
	-- Notify both players
	local challengerPlayer = Players:GetPlayerByUserId(challenge.challengerId)
	local challengedPlayer = Players:GetPlayerByUserId(challenge.challengedId)
	
	if challengerPlayer then
		local challengeAcceptedEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
		challengeAcceptedEvent:FireClient(challengerPlayer, "Your challenge was accepted! Battle preparation starting...", 5)
		
		-- Show PVP frames for challenger
		PVPChallengeManager.showPVPFramesForPlayer(challengerPlayer, challengeId)
	end
	
	if challengedPlayer then
		local challengeAcceptedEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
		challengeAcceptedEvent:FireClient(challengedPlayer, "Challenge accepted! Battle preparation starting...", 5)
		
		-- Show PVP frames for challenged player
		PVPChallengeManager.showPVPFramesForPlayer(challengedPlayer, challengeId)
	end
	
	print("Challenge accepted: " .. challengeId)
	return true
end

-- Reject a challenge
function PVPChallengeManager.rejectChallenge(challengedId: number): boolean
	local challengeId = playerChallenges[challengedId]
	if not challengeId then
		return false
	end
	
	local challenge = activeChallenges[challengeId]
	if not challenge or challenge.status ~= "pending" then
		return false
	end
	
	-- Update challenge status
	challenge.status = "rejected"
	
	-- Notify challenger
	local challengerPlayer = Players:GetPlayerByUserId(challenge.challengerId)
	if challengerPlayer then
		local challengeRejectedEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
		challengeRejectedEvent:FireClient(challengerPlayer, "Your challenge was rejected.", 5)
	end
	
	-- Clean up challenge
	PVPChallengeManager.cleanupChallenge(challengeId)
	
	print("Challenge rejected: " .. challengeId)
	return true
end

-- Show PVP frames for a player
function PVPChallengeManager.showPVPFramesForPlayer(player: Player, challengeId: string)
	print("DEBUG: Showing PVP frames for player: " .. player.Name .. " (ID: " .. player.UserId .. ")")
	
	-- Get player data to populate the frames
	local PlayerDataManager = require(script.Parent.PlayerData)
	local playerData = PlayerDataManager.getPlayerData(player.UserId)
	
	if not playerData then
		warn("DEBUG: Player data not found for user: " .. player.UserId)
		return
	end
	
	print("DEBUG: Player data found, board units: " .. playerData.boardState.currentUnits .. ", bench units: " .. playerData.benchState.currentCapacity)
	
	-- Send PVP frames to client with current board and bench state
	local showPVPFramesEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_PVP_FRAMES)
	showPVPFramesEvent:FireClient(player, challengeId, playerData.boardState, playerData.benchState, Constants.BATTLE_PREPARATION_TIME)
	
	print("DEBUG: PVP frames event sent to player: " .. player.Name)
end

-- Start battle after preparation time
function PVPChallengeManager.startBattle(challengeId: string): boolean
	local challenge = activeChallenges[challengeId]
	if not challenge then
		warn("Cannot start battle - challenge not found: " .. challengeId)
		return false
	end
	
	-- Check if battle has already started
	if challenge.status == "battling" then
		print("Battle already started for challenge: " .. challengeId)
		return true
	end
	
	-- Check if challenge is in the correct state
	if challenge.status ~= "accepted" then
		warn("Cannot start battle - challenge not accepted: " .. challengeId .. " (status: " .. challenge.status .. ")")
		return false
	end
	
	-- Update challenge status
	challenge.status = "battling"
	challenge.battleStartTime = os.time()
	
	-- Get both players
	local challengerPlayer = Players:GetPlayerByUserId(challenge.challengerId)
	local challengedPlayer = Players:GetPlayerByUserId(challenge.challengedId)
	
	if not challengerPlayer or not challengedPlayer then
		warn("One or both players not found for battle: " .. challengeId)
		return false
	end
	
	print("Starting battle between " .. challengerPlayer.Name .. " and " .. challengedPlayer.Name)
	
	-- Find the challenged player's arena
	local challengedArena = PVPChallengeManager.findPlayerArena(challengedPlayer.UserId)
	if not challengedArena then
		warn("Could not find challenged player's arena for " .. challengedPlayer.Name)
		return false
	end
	
	-- Teleport both players to the challenged player's board
	PVPChallengeManager.teleportPlayersToBattle(challengerPlayer, challengedPlayer)
	
	-- Populate both players' units on the board
	PVPChallengeManager.populateBattleBoards(challengerPlayer, challengedPlayer)
	
	-- Start the actual battle using BattleManager
	-- IMPORTANT: BattleManager collects team1 units from the challenged player's arena (their own board)
	-- and team2 units from the enemy board (which we populate with the challenger's units).
	-- Therefore, to align winner logic (team1Defeated => challenger wins; team2Defeated => challenged wins)
	-- we must pass challengedId as player1Id and challengerId as player2Id.
	-- Previously these were reversed which caused winner attribution to flip and produced invalid winner IDs for rewards.
	local battleId = BattleManager.startBattle(challengeId, challenge.challengedId, challenge.challengerId, challengedArena, function(winnerId)
		-- Battle end callback - spawn to avoid blocking
		spawn(function()
			wait(1) -- Small delay to ensure battle state is properly updated
			PVPChallengeManager.endBattle(challengeId, winnerId)
		end)
	end)
	if not battleId then
		warn("Failed to start battle for challenge: " .. challengeId)
		challenge.status = "accepted" -- Reset status
		return false
	end
	
	-- Store battle ID in challenge
	challenge.battleId = battleId
	
	-- Notify both players that battle is starting
	local battleStartEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
	battleStartEvent:FireClient(challengerPlayer, "Battle starting! Good luck!", 3)
	battleStartEvent:FireClient(challengedPlayer, "Battle starting! Good luck!", 3)
	
	-- Send battle start signal to both players
	local startBattleEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.START_BATTLE)
	startBattleEvent:FireClient(challengerPlayer, challengeId)
	startBattleEvent:FireClient(challengedPlayer, challengeId)
	
	print("Battle started: " .. challengeId .. " with battle ID: " .. battleId)
	return true
end

-- Teleport both players to the challenged player's board
function PVPChallengeManager.teleportPlayersToBattle(challengerPlayer: Player, challengedPlayer: Player)
	print("Teleporting players to battle arena...")
	
	-- Find the challenged player's arena using the lobby system
	local challengedArena = PVPChallengeManager.findPlayerArena(challengedPlayer.UserId)
	
	if not challengedArena then
		warn("Could not find challenged player's arena for " .. challengedPlayer.Name)
		return
	end
	
	-- Ensure the arena has the required battle components
	PVPChallengeManager.ensureArenaBattleComponents(challengedArena, challengedPlayer.Name)
	
	-- Get the arena's center position
	local arenaCenter
	if challengedArena:IsA("Model") then
		arenaCenter = challengedArena:GetPivot().Position
	else
		-- If it's a folder, calculate center from children
		local totalPosition = Vector3.new(0, 0, 0)
		local partCount = 0
		for _, child in pairs(challengedArena:GetDescendants()) do
			if child:IsA("BasePart") then
				totalPosition = totalPosition + child.Position
				partCount = partCount + 1
			end
		end
		if partCount > 0 then
			arenaCenter = totalPosition / partCount
		else
			arenaCenter = Vector3.new(0, 5, 0)
		end
	end
	
	-- Add forward offset to the z value of arenaCenter
	arenaCenter = Vector3.new(arenaCenter.X, arenaCenter.Y, arenaCenter.Z + Constants.PLAYER_SPAWN_FORWARD_OFFSET)
	
	-- Teleport challenger to challenged player's arena
	if challengerPlayer.Character then
		local humanoidRootPart = challengerPlayer.Character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			humanoidRootPart.CFrame = CFrame.new(arenaCenter + Vector3.new(0, 5, 0))
			print("Teleported challenger " .. challengerPlayer.Name .. " to battle arena at " .. tostring(arenaCenter))
		else
			warn("Could not find HumanoidRootPart for challenger " .. challengerPlayer.Name)
		end
	else
		warn("Challenger " .. challengerPlayer.Name .. " has no character")
	end
	
	-- Teleport challenged player to their own arena (in case they're not there)
	if challengedPlayer.Character then
		local humanoidRootPart = challengedPlayer.Character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			humanoidRootPart.CFrame = CFrame.new(arenaCenter + Vector3.new(0, 5, 0))
			print("Teleported challenged player " .. challengedPlayer.Name .. " to battle arena at " .. tostring(arenaCenter))
		else
			warn("Could not find HumanoidRootPart for challenged player " .. challengedPlayer.Name)
		end
	else
		warn("Challenged player " .. challengedPlayer.Name .. " has no character")
	end
	
	print("Battle teleportation completed")
end

-- Populate both players' units on the board
function PVPChallengeManager.populateBattleBoards(challengerPlayer: Player, challengedPlayer: Player)
	print("Populating battle boards...")
	
	-- Get player data for both players
	local PlayerDataManager = require(script.Parent.PlayerData)
	local challengerData = PlayerDataManager.getPlayerData(challengerPlayer.UserId)
	local challengedData = PlayerDataManager.getPlayerData(challengedPlayer.UserId)
	
	if not challengerData or not challengedData then
		warn("Could not get player data for one or both players")
		return
	end
	
	print("Challenger " .. challengerPlayer.Name .. " has " .. challengerData.boardState.currentUnits .. " units on board")
	print("Challenged " .. challengedPlayer.Name .. " has " .. challengedData.boardState.currentUnits .. " units on board")
	
	-- Find the challenged player's arena using the helper function
	local challengedArena = PVPChallengeManager.findPlayerArena(challengedPlayer.UserId)
	if not challengedArena then
		warn("Could not find challenged player's arena for " .. challengedPlayer.Name)
		return
	end
	
	-- Ensure the arena has the required battle components
	PVPChallengeManager.ensureArenaBattleComponents(challengedArena, challengedPlayer.Name)
	
	-- Get the enemy unit board
	local enemyUnitBoard = challengedArena:FindFirstChild("Enemy Unit Board")
	if not enemyUnitBoard then
		warn("Could not find Enemy Unit Board in challenged player's arena after ensuring components")
		return
	end
	
	-- Populate challenger's units on the enemy board
	PVPChallengeManager.populateEnemyBoard(enemyUnitBoard, challengerData.boardState)
	
	-- Update challenged player's board with their current PVP board state
	-- This will be handled by the client when they receive the battle start signal
	
	print("Battle boards populated successfully")
end

-- Populate enemy board with challenger's units
function PVPChallengeManager.populateEnemyBoard(enemyBoard: Instance, boardState: any)
	print("Populating enemy board with challenger's units...")
	
	-- Clear existing enemy units
	for _, child in pairs(enemyBoard:GetChildren()) do
		if child:IsA("Model") and child.Name:find("EnemyUnit_") then
			child:Destroy()
		end
	end
	
	-- Place challenger's units on the enemy board
	local unitsPlaced = 0
	for position, unit in pairs(boardState.grid) do
		if position and unit then
			PVPChallengeManager.placeEnemyUnit(enemyBoard, unit, position)
			unitsPlaced = unitsPlaced + 1
		end
	end
	
	print("Placed " .. unitsPlaced .. " enemy units on the board")
end

-- Place a single enemy unit on the board
function PVPChallengeManager.placeEnemyUnit(enemyBoard: Instance, unit: any, position: Vector2)
	-- Find the appropriate hex on the enemy board
	-- Convert from 0-based coordinates to 1-based hex names
	local hexName = string.format("Hex_%d_%d", position.Y + 1, position.X + 1)
	local hex = enemyBoard:FindFirstChild(hexName)
	
	if hex then
		-- Get the actual unit model from UnitSpawner
		local UnitSpawner = require(script.Parent.UnitSpawner)
		local unitModel = UnitSpawner.getUnitModel(unit.name)
		
		if unitModel then
			-- Clone the actual unit model
			local enemyUnit = unitModel:Clone()
			enemyUnit.Name = "EnemyUnit_" .. unit.id
			enemyUnit.Parent = hex
			
			-- Scale unit based on tier
			local UnitDatabase = require(game.ReplicatedStorage.Shared.UnitDatabase)
			local sizeScale = UnitDatabase.calculateUnitSizeScale(unit.tier)
			
			-- Scale the entire model using the top-level Scale property
			enemyUnit:ScaleTo(sizeScale)
			
			-- Position the unit at the hex location
			local hexCFrame = hex.CFrame
			local unitSize = enemyUnit:GetExtentsSize()
			local unitHeight = unitSize.Y
			local heightOffset = unitHeight / 2
			
			-- Create CFrame with position and rotation to face forward
			local adjustedCFrame = CFrame.new(hexCFrame.Position + Vector3.new(0, heightOffset, 0)) * CFrame.Angles(0, 0, 0)
			enemyUnit:PivotTo(adjustedCFrame)
			
			-- Store unit data in the model
			enemyUnit:SetAttribute("UnitId", unit.id)
			enemyUnit:SetAttribute("UnitName", unit.name)
			enemyUnit:SetAttribute("UnitTier", unit.tier)
			enemyUnit:SetAttribute("PositionX", position.X)
			enemyUnit:SetAttribute("PositionY", position.Y)
			
			print("Placed actual enemy unit " .. unit.name .. " at hex " .. hexName .. " (position " .. tostring(position) .. ")")
		else
			warn("Could not find unit model for " .. unit.name .. " - using placeholder")
			-- Fallback to simple placeholder if unit model not found
			local enemyUnit = Instance.new("Model")
			enemyUnit.Name = "EnemyUnit_" .. unit.id
			enemyUnit.Parent = hex
			
			local part = Instance.new("Part")
			part.Name = "UnitPart"
			part.Size = Vector3.new(2, 2, 2)
			-- Use a neutral color to avoid red placeholders lingering in gameplay
			part.BrickColor = BrickColor.new("Medium stone grey")
			part.Material = Enum.Material.Neon
			part.Parent = enemyUnit
			
			part.CFrame = hex.CFrame + Vector3.new(0, 2, 0)
			print("Placed placeholder enemy unit " .. unit.name .. " at hex " .. hexName)
		end
	else
		warn("Could not find hex " .. hexName .. " on enemy board for unit " .. unit.name)
	end
end

-- End battle and determine winner (called by BattleManager)
function PVPChallengeManager.endBattle(challengeId: string, winnerId: number?): boolean
	local challenge = activeChallenges[challengeId]
	if not challenge or challenge.status ~= "battling" then
		return false
	end
	
	-- Update challenge status
	challenge.status = "completed"
	
	-- Determine winner and loser
	local _loserId = winnerId and ((winnerId == challenge.challengerId) and challenge.challengedId or challenge.challengerId) or nil

	local challengerPlayer = Players:GetPlayerByUserId(challenge.challengerId)
	local challengedPlayer = Players:GetPlayerByUserId(challenge.challengedId)

	-- Integrate rewards using CombatRewards & PlayerDataManager
	-- This section processes win/loss, updates streaks, applies calculated XP & gold, and notifies players
	local PlayerDataManager = require(script.Parent.PlayerData)
	local CombatRewards = require(game.ReplicatedStorage.Shared.CombatRewards)

	if winnerId and _loserId then
		-- Process streaks and collect levels/streak for reward calculation
		local resultInfo = PlayerDataManager.processBattleResult(winnerId, _loserId)
		if resultInfo then
			local rewards = CombatRewards.applyBattleRewards(resultInfo.winnerId, resultInfo.loserId, resultInfo.winnerLevel, resultInfo.loserLevel, resultInfo.winnerStreak, PlayerDataManager)

			-- Record win for leaderboard
			local okLeaderboard, errLeaderboard = pcall(function()
				local WinsLeaderboard = require(script.Parent.WinsLeaderboard)
				WinsLeaderboard.recordWin(resultInfo.winnerId)
			end)
			if not okLeaderboard then
				warn("[PVPChallengeManager] Failed to record win for leaderboard: " .. tostring(errLeaderboard))
			end

			-- Persist rewards immediately to reduce risk of data loss if players leave right away
			local winnerSaved = PlayerDataManager.savePlayerData(resultInfo.winnerId)
			local loserSaved = PlayerDataManager.savePlayerData(resultInfo.loserId)
			if not winnerSaved or not loserSaved then
				warn(string.format("[PVPChallengeManager] Immediate save after rewards failed (winnerSaved=%s, loserSaved=%s)", tostring(winnerSaved), tostring(loserSaved)))
			end

			-- Notify winner
			local winnerPlayer = Players:GetPlayerByUserId(resultInfo.winnerId)
			if winnerPlayer then
				local battleEndEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
				battleEndEvent:FireClient(winnerPlayer, string.format("Victory! +%d XP, +%d Gold (Streak %d)", rewards.winner.experience, rewards.winner.gold, resultInfo.winnerStreak), 6)
			end

			-- Notify loser
			local loserPlayer = Players:GetPlayerByUserId(resultInfo.loserId)
			if loserPlayer then
				local battleEndEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
				battleEndEvent:FireClient(loserPlayer, string.format("Defeat. +%d XP, +%d Gold", rewards.loser.experience, rewards.loser.gold), 6)
			end

			-- Immediately push updated player data for both players so UI reflects new gold/XP/streak
			local updatePlayerDataEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.UPDATE_PLAYER_DATA)
			if updatePlayerDataEvent then
				local winnerData = PlayerDataManager.getPlayerData(resultInfo.winnerId)
				local loserData = PlayerDataManager.getPlayerData(resultInfo.loserId)
				local winnerPlayer2 = Players:GetPlayerByUserId(resultInfo.winnerId)
				local loserPlayer2 = Players:GetPlayerByUserId(resultInfo.loserId)
				if winnerPlayer2 and winnerData then updatePlayerDataEvent:FireClient(winnerPlayer2, winnerData) end
				if loserPlayer2 and loserData then updatePlayerDataEvent:FireClient(loserPlayer2, loserData) end
			else
				warn("[PVPChallengeManager] UpdatePlayerData event not found when attempting to push battle reward updates")
			end
		else
			-- Fallback notifications if resultInfo missing
			if challengerPlayer then
				local battleEndEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
				if winnerId == challenge.challengerId then
					battleEndEvent:FireClient(challengerPlayer, "Victory! (Rewards unavailable)", 5)
				else
					battleEndEvent:FireClient(challengerPlayer, "Defeat! (Rewards unavailable)", 5)
				end
			end
			if challengedPlayer then
				local battleEndEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
				if winnerId == challenge.challengedId then
					battleEndEvent:FireClient(challengedPlayer, "Victory! (Rewards unavailable)", 5)
				else
					battleEndEvent:FireClient(challengedPlayer, "Defeat! (Rewards unavailable)", 5)
				end
			end
		end
	else
		-- Draw case: notify both players
		if challengerPlayer then
			local battleEndEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
			battleEndEvent:FireClient(challengerPlayer, "Draw! No rewards granted.", 5)
		end
		if challengedPlayer then
			local battleEndEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
			battleEndEvent:FireClient(challengedPlayer, "Draw! No rewards granted.", 5)
		end

		-- Even in a draw, push current player data (streaks might be reset in future logic)
		local updatePlayerDataEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.UPDATE_PLAYER_DATA)
		if updatePlayerDataEvent then
			if challengerPlayer then
				local cData = PlayerDataManager.getPlayerData(challenge.challengerId)
				if cData then updatePlayerDataEvent:FireClient(challengerPlayer, cData) end
			end
			if challengedPlayer then
				local dData = PlayerDataManager.getPlayerData(challenge.challengedId)
				if dData then updatePlayerDataEvent:FireClient(challengedPlayer, dData) end
			end
		end
	end
	
	-- Clean up challenge
	PVPChallengeManager.cleanupChallenge(challengeId)
	
	print("Battle ended: " .. challengeId .. " - Winner: " .. (winnerId or "Draw"))
	return true
end

-- Clean up a challenge
function PVPChallengeManager.cleanupChallenge(challengeId: string)
	local challenge = activeChallenges[challengeId]
	if not challenge then
		return
	end
	
	-- Remove from player challenges
	playerChallenges[challenge.challengerId] = nil
	playerChallenges[challenge.challengedId] = nil
	
	-- Remove from active challenges
	activeChallenges[challengeId] = nil
end

-- Get challenge data for a player
function PVPChallengeManager.getPlayerChallenge(playerId: number): any?
	local challengeId = playerChallenges[playerId]
	if not challengeId then
		return nil
	end
	
	return activeChallenges[challengeId]
end

-- Update PVP frames for a player if they're in a challenge
function PVPChallengeManager.updatePVPFramesForPlayer(playerId: number)
	local challenge = PVPChallengeManager.getPlayerChallenge(playerId)
	if not challenge or challenge.status ~= "accepted" then
		-- Player is not in an active challenge, no need to update PVP frames
		return
	end
	
	local player = Players:GetPlayerByUserId(playerId)
	if not player then
		return
	end
	
	-- Get current player data
	local PlayerDataManager = require(script.Parent.PlayerData)
	local playerData = PlayerDataManager.getPlayerData(playerId)
	if not playerData then
		return
	end
	
	-- Send updated PVP frames to the player
	local updatePVPFramesEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.UPDATE_PVP_FRAMES)
	updatePVPFramesEvent:FireClient(player, playerData.boardState, playerData.benchState)
	
	print("Updated PVP frames for player:", player.Name, "in challenge:", challenge.challengerId .. "_" .. challenge.challengedId)
end

-- Check for expired challenges and clean them up
function PVPChallengeManager.cleanupExpiredChallenges()
	local currentTime = os.time()
	local expiredChallenges = {}
	
	for challengeId, challenge in pairs(activeChallenges) do
		if challenge.status == "pending" and 
		   (currentTime - challenge.challengeTime) > Constants.CHALLENGE_TIMEOUT then
			table.insert(expiredChallenges, challengeId)
		end
	end
	
	for _, challengeId in ipairs(expiredChallenges) do
		local challenge = activeChallenges[challengeId]
		if challenge then
			-- Notify challenger that challenge expired
			local challengerPlayer = Players:GetPlayerByUserId(challenge.challengerId)
			if challengerPlayer then
				local challengeExpiredEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
				challengeExpiredEvent:FireClient(challengerPlayer, "Challenge expired - no response received.", 5)
			end
			
			PVPChallengeManager.cleanupChallenge(challengeId)
		end
	end
end

-- Start cleanup timer
local function startCleanupTimer()
	spawn(function()
		while true do
			wait(10) -- Check every 10 seconds
			PVPChallengeManager.cleanupExpiredChallenges()
		end
	end)
end

-- Check if a player is currently in the battle preparation phase (challenge accepted, battle not yet started)
function PVPChallengeManager.isPlayerInBattlePreparation(playerId: number): boolean
	for _, challenge in pairs(activeChallenges) do
		if (challenge.challengerId == playerId or challenge.challengedId == playerId) and challenge.status == "accepted" then
			return true
		end
	end
	return false
end

-- Initialize the PVP Challenge Manager
function PVPChallengeManager.init()
	startCleanupTimer()
	print("PVP Challenge Manager initialized")
end

return PVPChallengeManager
