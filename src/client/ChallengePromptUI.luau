--[[
	ChallengePromptUI.luau
	Shows challenge prompt when entering another player's board area
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Load shared modules
local Constants = require(game.ReplicatedStorage.Shared.Constants)

local ChallengePromptUI = {}

-- UI elements
local challengePromptFrame = nil
local currentBoardOwnerId = nil
local currentBoardOwnerName = nil

-- Create challenge prompt UI
function ChallengePromptUI.createChallengePromptUI()
	if challengePromptFrame then
		challengePromptFrame:Destroy()
	end
	
	-- Create main frame
	challengePromptFrame = Instance.new("Frame")
	challengePromptFrame.Name = "ChallengePromptFrame"
	challengePromptFrame.Size = UDim2.new(0, 350, 0, 120)
	challengePromptFrame.Position = UDim2.new(0.5, -175, 0.8, 0)
	challengePromptFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	challengePromptFrame.BorderSizePixel = 0
	challengePromptFrame.ZIndex = 5
	
	-- Create corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = challengePromptFrame
	
	-- Create border
	local border = Instance.new("UIStroke")
	border.Color = Color3.fromRGB(100, 100, 100)
	border.Thickness = 2
	border.Parent = challengePromptFrame
	
	-- Create title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0, 30)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Challenge Player"
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = challengePromptFrame
	
	-- Create description
	local descriptionLabel = Instance.new("TextLabel")
	descriptionLabel.Name = "DescriptionLabel"
	descriptionLabel.Size = UDim2.new(1, 0, 0, 30)
	descriptionLabel.Position = UDim2.new(0, 0, 0, 35)
	descriptionLabel.BackgroundTransparency = 1
	descriptionLabel.Text = "You are in Unknown Player's board area"
	descriptionLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	descriptionLabel.TextScaled = true
	descriptionLabel.Font = Enum.Font.Gotham
	descriptionLabel.Parent = challengePromptFrame
	
	-- Create challenge button
	local challengeButton = Instance.new("TextButton")
	challengeButton.Name = "ChallengeButton"
	challengeButton.Size = UDim2.new(0.8, 0, 0, 35)
	challengeButton.Position = UDim2.new(0.1, 0, 0, 75)
	challengeButton.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
	challengeButton.Text = "Challenge to Battle"
	challengeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	challengeButton.TextScaled = true
	challengeButton.Font = Enum.Font.GothamBold
	challengeButton.Parent = challengePromptFrame
	
	-- Create button corner
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 6)
	buttonCorner.Parent = challengeButton
	
	-- Set up button events
	challengeButton.MouseButton1Click:Connect(function()
		ChallengePromptUI.challengeBoardOwner()
	end)
	
	-- Add to PlayerGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	challengePromptFrame.Parent = playerGui
	
	-- Hide initially
	challengePromptFrame.Visible = false
	
	return challengePromptFrame
end

-- Show challenge prompt
function ChallengePromptUI.showChallengePrompt(boardOwnerId: number, boardOwnerName: string)
	if not challengePromptFrame then
		ChallengePromptUI.createChallengePromptUI()
	end
	
	currentBoardOwnerId = boardOwnerId
	currentBoardOwnerName = boardOwnerName
	
	-- Update description
	local descriptionLabel = challengePromptFrame:FindFirstChild("DescriptionLabel")
	if descriptionLabel then
		descriptionLabel.Text = "You are in " .. boardOwnerName .. "'s board area"
	end
	
	-- Show the frame with animation
	challengePromptFrame.Visible = true
	challengePromptFrame.Position = UDim2.new(0.5, -175, 1, 0)
	
	local tween = TweenService:Create(
		challengePromptFrame,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.5, -175, 0.8, 0)}
	)
	tween:Play()
end

-- Hide challenge prompt
function ChallengePromptUI.hideChallengePrompt()
	if not challengePromptFrame then
		return
	end
	
	currentBoardOwnerId = nil
	currentBoardOwnerName = nil
	
	-- Hide with animation
	local tween = TweenService:Create(
		challengePromptFrame,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Position = UDim2.new(0.5, -175, 1, 0)}
	)
	
	tween.Completed:Connect(function()
		challengePromptFrame.Visible = false
	end)
	
	tween:Play()
end

-- Challenge the board owner
function ChallengePromptUI.challengeBoardOwner()
	if not currentBoardOwnerId then
		return
	end
	
	-- Send challenge event to server
	local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
	local challengePlayerEvent = remoteEventsFolder:WaitForChild(Constants.REMOTE_EVENT_NAMES.CHALLENGE_PLAYER)
	challengePlayerEvent:FireServer(currentBoardOwnerId)
	
	-- Hide the prompt
	ChallengePromptUI.hideChallengePrompt()
end

-- Initialize Challenge Prompt UI
function ChallengePromptUI.init()
	-- Create UI elements
	ChallengePromptUI.createChallengePromptUI()
	
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
