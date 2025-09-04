--[[
	PVPChallengeManager.luau
	Manages PVP challenges between players
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = require(script.Parent.RemoteEvents)
local Constants = require(game.ReplicatedStorage.Shared.Constants)

local PVPChallengeManager = {}

-- Active challenges storage
local activeChallenges = {} -- {challengeId = challengeData}
local playerChallenges = {} -- {playerId = challengeId}

-- Challenge data structure
local ChallengeData = {
	challengerId = nil,
	challengedId = nil,
	challengeTime = nil,
	status = "pending", -- "pending", "accepted", "rejected", "expired"
	battlePreparationTime = nil,
	battleStartTime = nil
}

-- Generate unique challenge ID
local function generateChallengeId(): string
	return "challenge_" .. os.time() .. "_" .. math.random(1000, 9999)
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
	-- This will be implemented when battle system is added
	-- For now, assume they can be challenged
	
	return true
end

-- Create a new challenge
function PVPChallengeManager.createChallenge(challengerId: number, challengedId: number): string?
	-- Validate players
	if not PVPChallengeManager.canPlayerBeChallenged(challengerId) then
		return nil
	end
	
	if not PVPChallengeManager.canPlayerBeChallenged(challengedId) then
		return nil
	end
	
	-- Create challenge data
	local challengeId = generateChallengeId()
	local challenge = {
		challengerId = challengerId,
		challengedId = challengedId,
		challengeTime = os.time(),
		status = "pending",
		battlePreparationTime = nil,
		battleStartTime = nil
	}
	
	-- Store challenge
	activeChallenges[challengeId] = challenge
	playerChallenges[challengerId] = challengeId
	playerChallenges[challengedId] = challengeId
	
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
		challengeRequestEvent:FireClient(challengedPlayer, challengerId, challengerName)
		print("ShowChallengeRequest event fired successfully")
	else
		warn("Challenged player not found for ID:", challengedId)
	end
	
	print("Challenge created: " .. challengeId .. " from " .. challengerId .. " to " .. challengedId)
	return challengeId
end

-- Accept a challenge
function PVPChallengeManager.acceptChallenge(challengedId: number): boolean
	local challengeId = playerChallenges[challengedId]
	if not challengeId then
		return false
	end
	
	local challenge = activeChallenges[challengeId]
	if not challenge or challenge.status ~= "pending" then
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
		
		-- Start battle preparation timer for challenger
		local startBattlePrepEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.START_BATTLE_PREPARATION)
		startBattlePrepEvent:FireClient(challengerPlayer, challengeId, Constants.BATTLE_PREPARATION_TIME)
	end
	
	if challengedPlayer then
		local challengeAcceptedEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
		challengeAcceptedEvent:FireClient(challengedPlayer, "Challenge accepted! Battle preparation starting...", 5)
		
		-- Start battle preparation timer for challenged player
		local startBattlePrepEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.START_BATTLE_PREPARATION)
		startBattlePrepEvent:FireClient(challengedPlayer, challengeId, Constants.BATTLE_PREPARATION_TIME)
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

-- Start battle after preparation time
function PVPChallengeManager.startBattle(challengeId: string): boolean
	local challenge = activeChallenges[challengeId]
	if not challenge or challenge.status ~= "accepted" then
		return false
	end
	
	-- Check if preparation time has elapsed
	local currentTime = os.time()
	if not challenge.battlePreparationTime or 
	   (currentTime - challenge.battlePreparationTime) < Constants.BATTLE_PREPARATION_TIME then
		return false
	end
	
	-- Update challenge status
	challenge.status = "battling"
	challenge.battleStartTime = currentTime
	
	-- Notify both players that battle is starting
	local challengerPlayer = Players:GetPlayerByUserId(challenge.challengerId)
	local challengedPlayer = Players:GetPlayerByUserId(challenge.challengedId)
	
	if challengerPlayer then
		local battleStartEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
		battleStartEvent:FireClient(challengerPlayer, "Battle starting! Good luck!", 3)
		
		-- Send battle start signal
		local startBattleEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.START_BATTLE)
		startBattleEvent:FireClient(challengerPlayer, challengeId)
	end
	
	if challengedPlayer then
		local battleStartEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
		battleStartEvent:FireClient(challengedPlayer, "Battle starting! Good luck!", 3)
		
		-- Send battle start signal
		local startBattleEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.START_BATTLE)
		startBattleEvent:FireClient(challengedPlayer, challengeId)
	end
	
	print("Battle started: " .. challengeId)
	return true
end

-- End battle and determine winner
function PVPChallengeManager.endBattle(challengeId: string, winnerId: number): boolean
	local challenge = activeChallenges[challengeId]
	if not challenge or challenge.status ~= "battling" then
		return false
	end
	
	-- Update challenge status
	challenge.status = "completed"
	
	-- Determine winner and loser
	local loserId = (winnerId == challenge.challengerId) and challenge.challengedId or challenge.challengerId
	
	-- Calculate rewards (this will be implemented when battle system is added)
	-- For now, just notify players
	
	local challengerPlayer = Players:GetPlayerByUserId(challenge.challengerId)
	local challengedPlayer = Players:GetPlayerByUserId(challenge.challengedId)
	
	if challengerPlayer then
		local battleEndEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
		if winnerId == challenge.challengerId then
			battleEndEvent:FireClient(challengerPlayer, "Victory! You won the battle!", 5)
		else
			battleEndEvent:FireClient(challengerPlayer, "Defeat! You lost the battle.", 5)
		end
	end
	
	if challengedPlayer then
		local battleEndEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_NOTIFICATION)
		if winnerId == challenge.challengedId then
			battleEndEvent:FireClient(challengedPlayer, "Victory! You won the battle!", 5)
		else
			battleEndEvent:FireClient(challengedPlayer, "Defeat! You lost the battle.", 5)
		end
	end
	
	-- Clean up challenge
	PVPChallengeManager.cleanupChallenge(challengeId)
	
	print("Battle ended: " .. challengeId .. " - Winner: " .. winnerId)
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
function PVPChallengeManager.getPlayerChallenge(playerId: number): ChallengeData?
	local challengeId = playerChallenges[playerId]
	if not challengeId then
		return nil
	end
	
	return activeChallenges[challengeId]
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

-- Initialize the PVP Challenge Manager
function PVPChallengeManager.init()
	startCleanupTimer()
	print("PVP Challenge Manager initialized")
end

return PVPChallengeManager
