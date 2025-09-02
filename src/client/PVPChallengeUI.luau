--[[
	PVPChallengeUI.luau
	Client-side PVP challenge UI management
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- Load shared modules
local Constants = require(game.ReplicatedStorage.Shared.Constants)

local PVPChallengeUI = {}

-- UI elements
local challengeRequestFrame = nil
local battlePreparationFrame = nil
local currentChallengeId = nil
local preparationTimer = nil

-- Create challenge request UI
function PVPChallengeUI.createChallengeRequestUI()
	if challengeRequestFrame then
		challengeRequestFrame:Destroy()
	end
	
	-- Create main frame
	challengeRequestFrame = Instance.new("Frame")
	challengeRequestFrame.Name = "ChallengeRequestFrame"
	challengeRequestFrame.Size = UDim2.new(0, 400, 0, 200)
	challengeRequestFrame.Position = UDim2.new(0.5, -200, 0.5, -100)
	challengeRequestFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	challengeRequestFrame.BorderSizePixel = 0
	challengeRequestFrame.ZIndex = 10
	
	-- Create corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = challengeRequestFrame
	
	-- Create title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0, 50)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "PVP Challenge Request"
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = challengeRequestFrame
	
	-- Create challenger name label
	local challengerLabel = Instance.new("TextLabel")
	challengerLabel.Name = "ChallengerLabel"
	challengerLabel.Size = UDim2.new(1, 0, 0, 30)
	challengerLabel.Position = UDim2.new(0, 0, 0, 60)
	challengerLabel.BackgroundTransparency = 1
	challengerLabel.Text = "Unknown Player wants to challenge you!"
	challengerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	challengerLabel.TextScaled = true
	challengerLabel.Font = Enum.Font.Gotham
	challengerLabel.Parent = challengeRequestFrame
	
	-- Create accept button
	local acceptButton = Instance.new("TextButton")
	acceptButton.Name = "AcceptButton"
	acceptButton.Size = UDim2.new(0.4, 0, 0, 40)
	acceptButton.Position = UDim2.new(0.1, 0, 0, 120)
	acceptButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
	acceptButton.Text = "Accept"
	acceptButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	acceptButton.TextScaled = true
	acceptButton.Font = Enum.Font.GothamBold
	acceptButton.Parent = challengeRequestFrame
	
	-- Create accept button corner
	local acceptCorner = Instance.new("UICorner")
	acceptCorner.CornerRadius = UDim.new(0, 8)
	acceptCorner.Parent = acceptButton
	
	-- Create reject button
	local rejectButton = Instance.new("TextButton")
	rejectButton.Name = "RejectButton"
	rejectButton.Size = UDim2.new(0.4, 0, 0, 40)
	rejectButton.Position = UDim2.new(0.5, 0, 0, 120)
	rejectButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
	rejectButton.Text = "Reject"
	rejectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	rejectButton.TextScaled = true
	rejectButton.Font = Enum.Font.GothamBold
	rejectButton.Parent = challengeRequestFrame
	
	-- Create reject button corner
	local rejectCorner = Instance.new("UICorner")
	rejectCorner.CornerRadius = UDim.new(0, 8)
	rejectCorner.Parent = rejectButton
	
	-- Set up button events
	acceptButton.MouseButton1Click:Connect(function()
		PVPChallengeUI.acceptChallenge()
	end)
	
	rejectButton.MouseButton1Click:Connect(function()
		PVPChallengeUI.rejectChallenge()
	end)
	
	-- Add to PlayerGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	challengeRequestFrame.Parent = playerGui
	
	-- Hide initially
	challengeRequestFrame.Visible = false
	
	return challengeRequestFrame
end

-- Create battle preparation UI
function PVPChallengeUI.createBattlePreparationUI()
	if battlePreparationFrame then
		battlePreparationFrame:Destroy()
	end
	
	-- Create main frame
	battlePreparationFrame = Instance.new("Frame")
	battlePreparationFrame.Name = "BattlePreparationFrame"
	battlePreparationFrame.Size = UDim2.new(0, 300, 0, 150)
	battlePreparationFrame.Position = UDim2.new(0.5, -150, 0.1, 0)
	battlePreparationFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	battlePreparationFrame.BorderSizePixel = 0
	battlePreparationFrame.ZIndex = 10
	
	-- Create corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = battlePreparationFrame
	
	-- Create title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0, 40)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Battle Preparation"
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = battlePreparationFrame
	
	-- Create timer label
	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "TimerLabel"
	timerLabel.Size = UDim2.new(1, 0, 0, 40)
	timerLabel.Position = UDim2.new(0, 0, 0, 50)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = "Time remaining: 10s"
	timerLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
	timerLabel.TextScaled = true
	timerLabel.Font = Enum.Font.GothamBold
	timerLabel.Parent = battlePreparationFrame
	
	-- Create instruction label
	local instructionLabel = Instance.new("TextLabel")
	instructionLabel.Name = "InstructionLabel"
	instructionLabel.Size = UDim2.new(1, 0, 0, 40)
	instructionLabel.Position = UDim2.new(0, 0, 0, 100)
	instructionLabel.BackgroundTransparency = 1
	instructionLabel.Text = "Arrange your units on the board!"
	instructionLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	instructionLabel.TextScaled = true
	instructionLabel.Font = Enum.Font.Gotham
	instructionLabel.Parent = battlePreparationFrame
	
	-- Add to PlayerGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	battlePreparationFrame.Parent = playerGui
	
	-- Hide initially
	battlePreparationFrame.Visible = false
	
	return battlePreparationFrame
end

-- Show challenge request
function PVPChallengeUI.showChallengeRequest(challengerId: number, challengerName: string)
	if not challengeRequestFrame then
		PVPChallengeUI.createChallengeRequestUI()
	end
	
	-- Update challenger name
	local challengerLabel = challengeRequestFrame:FindFirstChild("ChallengerLabel")
	if challengerLabel then
		challengerLabel.Text = challengerName .. " wants to challenge you!"
	end
	
	-- Show the frame
	challengeRequestFrame.Visible = true
	
	-- Store challenger ID for response
	PVPChallengeUI.currentChallengerId = challengerId
end

-- Hide challenge request
function PVPChallengeUI.hideChallengeRequest()
	if challengeRequestFrame then
		challengeRequestFrame.Visible = false
	end
	PVPChallengeUI.currentChallengerId = nil
end

-- Show battle preparation
function PVPChallengeUI.showBattlePreparation(challengeId: string, preparationTime: number)
	if not battlePreparationFrame then
		PVPChallengeUI.createBattlePreparationUI()
	end
	
	currentChallengeId = challengeId
	
	-- Show the frame
	battlePreparationFrame.Visible = true
	
	-- Start countdown timer
	PVPChallengeUI.startPreparationTimer(preparationTime)
end

-- Hide battle preparation
function PVPChallengeUI.hideBattlePreparation()
	if battlePreparationFrame then
		battlePreparationFrame.Visible = false
	end
	currentChallengeId = nil
	
	-- Stop timer
	if preparationTimer then
		preparationTimer:Disconnect()
		preparationTimer = nil
	end
end

-- Start preparation timer
function PVPChallengeUI.startPreparationTimer(duration: number)
	if preparationTimer then
		preparationTimer:Disconnect()
	end
	
	local timeRemaining = duration
	local timerLabel = battlePreparationFrame:FindFirstChild("TimerLabel")
	
	preparationTimer = game:GetService("RunService").Heartbeat:Connect(function()
		if timeRemaining <= 0 then
			PVPChallengeUI.hideBattlePreparation()
			return
		end
		
		if timerLabel then
			timerLabel.Text = "Time remaining: " .. timeRemaining .. "s"
		end
		
		timeRemaining = timeRemaining - 1
	end)
end

-- Accept challenge
function PVPChallengeUI.acceptChallenge()
	if not PVPChallengeUI.currentChallengerId then
		return
	end
	
	-- Send accept event to server
	local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
	local acceptChallengeEvent = remoteEventsFolder:WaitForChild(Constants.REMOTE_EVENT_NAMES.ACCEPT_CHALLENGE)
	acceptChallengeEvent:FireServer()
	
	-- Hide the challenge request
	PVPChallengeUI.hideChallengeRequest()
end

-- Reject challenge
function PVPChallengeUI.rejectChallenge()
	if not PVPChallengeUI.currentChallengerId then
		return
	end
	
	-- Send reject event to server
	local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
	local rejectChallengeEvent = remoteEventsFolder:WaitForChild(Constants.REMOTE_EVENT_NAMES.REJECT_CHALLENGE)
	rejectChallengeEvent:FireServer()
	
	-- Hide the challenge request
	PVPChallengeUI.hideChallengeRequest()
end

-- Challenge another player
function PVPChallengeUI.challengePlayer(targetPlayerId: number)
	local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
	local challengePlayerEvent = remoteEventsFolder:WaitForChild(Constants.REMOTE_EVENT_NAMES.CHALLENGE_PLAYER)
	challengePlayerEvent:FireServer(targetPlayerId)
end

-- Initialize PVP Challenge UI
function PVPChallengeUI.init()
	-- Create UI elements
	PVPChallengeUI.createChallengeRequestUI()
	PVPChallengeUI.createBattlePreparationUI()
	
	-- Set up RemoteEvent handlers
	local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
	
	-- Handle challenge requests
	local showChallengeRequestEvent = remoteEventsFolder:WaitForChild(Constants.REMOTE_EVENT_NAMES.SHOW_CHALLENGE_REQUEST)
	showChallengeRequestEvent.OnClientEvent:Connect(function(challengerId, challengerName)
		PVPChallengeUI.showChallengeRequest(challengerId, challengerName)
	end)
	
	-- Handle battle preparation start
	local startBattlePrepEvent = remoteEventsFolder:WaitForChild(Constants.REMOTE_EVENT_NAMES.START_BATTLE_PREPARATION)
	startBattlePrepEvent.OnClientEvent:Connect(function(challengeId, preparationTime)
		PVPChallengeUI.showBattlePreparation(challengeId, preparationTime)
	end)
	
	-- Handle battle start
	local startBattleEvent = remoteEventsFolder:WaitForChild(Constants.REMOTE_EVENT_NAMES.START_BATTLE)
	startBattleEvent.OnClientEvent:Connect(function(challengeId)
		PVPChallengeUI.hideBattlePreparation()
		-- Battle system will be implemented later
		print("Battle starting for challenge: " .. challengeId)
	end)
	
	print("PVP Challenge UI initialized")
end

return PVPChallengeUI
