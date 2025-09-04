--[[
	ChallengePromptUI.luau
	Shows challenge prompt when entering another player's board area
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Load shared modules
local Constants = require(game.ReplicatedStorage.Shared.Constants)

local ChallengePromptUI = {}

-- UI elements
local challengeFrame = nil
local challengeLabel = nil
local currentBoardOwnerId = nil
local _currentBoardOwnerName = nil

-- Get the existing ChallengeFrame from ReplicatedStorage
local function getChallengeFrame()
	if challengeFrame then
		return challengeFrame
	end
		
	-- Wait for the UI to be available in ReplicatedStorage
	local existingUI = ReplicatedStorage:WaitForChild("BloxTacticsUITemplate")
	local mainFrame = existingUI:WaitForChild("MainFrame")
	local templateChallengeFrame = mainFrame:WaitForChild("ChallengeFrame")
	
	-- Clone the ChallengeFrame to the client's PlayerGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	
	challengeFrame = templateChallengeFrame:Clone()
	
	-- Create a ScreenGui container for proper UI rendering
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ChallengePromptScreenGui"
	screenGui.Parent = playerGui
	
	challengeFrame.Parent = screenGui
	
	-- Use scale-based sizing with proper centering
	challengeFrame.AnchorPoint = Vector2.new(0.5, 0.5)  -- Center anchor
	challengeFrame.Position = UDim2.new(0.5, 0, 0.5, 0)  -- Center of screen
	
	-- Get the ChallengeLabel
	challengeLabel = challengeFrame:WaitForChild("ChallengeLabel")
	
	-- Get the YesButton and set up click handler
	local yesButton = challengeFrame:FindFirstChild("YesButton")
	if yesButton then
		yesButton.MouseButton1Click:Connect(function()
			ChallengePromptUI.challengeBoardOwner()
		end)
	else
		print("DEBUG: YesButton not found!")
	end
	
	-- Get the NoButton and set up click handler
	local noButton = challengeFrame:FindFirstChild("NoButton")
	if noButton then
		noButton.MouseButton1Click:Connect(function()
			ChallengePromptUI.hideChallengePrompt()
		end)
	else
		print("DEBUG: NoButton not found!")
	end
	
	-- Hide initially
	challengeFrame.Visible = false
	
	return challengeFrame
end

-- Show challenge prompt
function ChallengePromptUI.showChallengePrompt(boardOwnerId: number, boardOwnerName: string)
	
	if not challengeFrame then
		getChallengeFrame()
	end
	
	currentBoardOwnerId = boardOwnerId
	_currentBoardOwnerName = boardOwnerName
	
	-- Update the challenge label text
	if challengeLabel then
		challengeLabel.Text = "Challenge " .. boardOwnerName .. "?"
	else
	end
	
	-- Show the frame
	if challengeFrame then
		challengeFrame.Visible = true
	else
		print("DEBUG: challengeFrame is nil, cannot show")
	end
end

-- Hide challenge prompt
function ChallengePromptUI.hideChallengePrompt()
	
	if not challengeFrame then
		return
	end
	
	currentBoardOwnerId = nil
	_currentBoardOwnerName = nil
	
	-- Hide the frame
	challengeFrame.Visible = false
end

-- Challenge the board owner
function ChallengePromptUI.challengeBoardOwner()
	if not currentBoardOwnerId then
		print("DEBUG: No current board owner ID to challenge")
		return
	end
	
	print("DEBUG: Challenging board owner:", currentBoardOwnerId, "Name:", _currentBoardOwnerName)
	
	-- Send challenge event to server
	local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
	local challengePlayerEvent = remoteEventsFolder:WaitForChild(Constants.REMOTE_EVENT_NAMES.CHALLENGE_PLAYER)
	challengePlayerEvent:FireServer(currentBoardOwnerId)
	
	print("DEBUG: Challenge event sent to server for player ID:", currentBoardOwnerId)
	
	-- Hide the prompt
	ChallengePromptUI.hideChallengePrompt()
end

-- Initialize Challenge Prompt UI
function ChallengePromptUI.init()
	-- Get the existing ChallengeFrame
	getChallengeFrame()
	
	-- Set up RemoteEvent handlers
	local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
	
	-- Handle showing challenge prompt
	local showChallengePromptEvent = remoteEventsFolder:WaitForChild(Constants.REMOTE_EVENT_NAMES.SHOW_CHALLENGE_PROMPT)
	showChallengePromptEvent.OnClientEvent:Connect(function(boardOwnerId, boardOwnerName)
		ChallengePromptUI.showChallengePrompt(boardOwnerId, boardOwnerName)
	end)
	
	-- Handle hiding challenge prompt
	local hideChallengePromptEvent = remoteEventsFolder:WaitForChild(Constants.REMOTE_EVENT_NAMES.HIDE_CHALLENGE_PROMPT)
	hideChallengePromptEvent.OnClientEvent:Connect(function()
		ChallengePromptUI.hideChallengePrompt()
	end)
	
	print("Challenge Prompt UI initialized")
end

return ChallengePromptUI
