--[[
	IncomingChallengeUI.luau
	Handles incoming challenge notifications for PVP challenges
]]

local _Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Load shared modules
local Constants = require(game.ReplicatedStorage.Shared.Constants)

local IncomingChallengeUI = {}

-- UI elements and state
local incomingChallengeFrame = nil
local activeNotifications = {} -- {challengerId = notificationFrame}
local notificationPositions = {} -- Track Y positions for stacking

-- Get the IncomingChallengeFrame container
local function getIncomingChallengeFrame()
	if incomingChallengeFrame then
		return incomingChallengeFrame
	end
	
	-- Wait for the UI to be available in ReplicatedStorage
	local existingUI = ReplicatedStorage:WaitForChild("BloxTacticsUITemplate")
	local mainFrame = existingUI:WaitForChild("MainFrame")
	local templateIncomingChallengeFrame = mainFrame:WaitForChild("IncomingChallengeFrame")
	
	-- Clone the IncomingChallengeFrame to the client's PlayerGui
	local playerGui = _Players.LocalPlayer:WaitForChild("PlayerGui")
	
	incomingChallengeFrame = templateIncomingChallengeFrame:Clone()
	
	-- Create a ScreenGui container for proper UI rendering
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "IncomingChallengeScreenGui"
	screenGui.Parent = playerGui
	
	incomingChallengeFrame.Parent = screenGui
	
	-- Make sure the frame is visible for notifications
	incomingChallengeFrame.Visible = true
	
	return incomingChallengeFrame
end

-- Get the IncomingChallengePrompt template
local function getIncomingChallengePromptTemplate()
	local existingUI = ReplicatedStorage:WaitForChild("BloxTacticsUITemplate")
	local mainFrame = existingUI:WaitForChild("MainFrame")
	local templateIncomingChallengeFrame = mainFrame:WaitForChild("IncomingChallengeFrame")
	return templateIncomingChallengeFrame:WaitForChild("IncomingChallengePrompt")
end

-- Create a new notification
function IncomingChallengeUI.createNotification(challengerId: number, challengerName: string)
	print("IncomingChallengeUI.createNotification called for:", challengerName, "ID:", challengerId)
	
	-- Get the container frame (this will create ScreenGui if needed)
	local containerFrame = getIncomingChallengeFrame()
	if not containerFrame then
		warn("Failed to get IncomingChallengeFrame container!")
		return
	end
	print("Container frame found:", containerFrame.Name)
	
	-- Get the template
	local template = getIncomingChallengePromptTemplate()
	if not template then
		warn("Failed to get IncomingChallengePrompt template!")
		return
	end
	print("Template found:", template.Name)
	
	-- Clone the template
	local notificationFrame = template:Clone()
	notificationFrame.Name = "IncomingChallenge_" .. challengerId
	notificationFrame.Parent = containerFrame
	notificationFrame.Visible = true
	print("Notification frame created and made visible")
	
	-- Update the label text
	local label = notificationFrame:FindFirstChild("IncomingChallengeLabel")
	if label then
		label.Text = "Challenge from " .. challengerName
	end
	
	-- Calculate position for stacking within the 0.2 wide frame
	local baseY = 0.75
	local stackOffset = 0.25
	local notificationCount = 0
	
	-- Count existing notifications
	for _ in pairs(activeNotifications) do
		notificationCount = notificationCount + 1
	end
	
	-- Calculate Y position (stacking from bottom to top)
	local yPosition = baseY - (notificationCount * stackOffset)
	notificationFrame.Position = UDim2.new(0, 0, yPosition, 0)
	
	-- Store position for this notification
	notificationPositions[challengerId] = yPosition
	
	-- Set up button handlers
	local yesButton = notificationFrame:FindFirstChild("YesButton")
	local noButton = notificationFrame:FindFirstChild("NoButton")
	
	if yesButton then
		yesButton.MouseButton1Click:Connect(function()
			IncomingChallengeUI.acceptChallenge(challengerId)
		end)
	end
	
	if noButton then
		noButton.MouseButton1Click:Connect(function()
			IncomingChallengeUI.rejectChallenge(challengerId)
		end)
	end
	
	-- Store the notification
	activeNotifications[challengerId] = notificationFrame
	
	-- Animate in (slide from right edge of the frame)
	local startPosition = UDim2.new(1, 0, yPosition, 0) -- Start from right edge
	local endPosition = UDim2.new(0, 0, yPosition, 0) -- End at template position
	
	-- Set initial position
	notificationFrame.Position = startPosition
	
	-- Animate to final position
	local tween = TweenService:Create(notificationFrame, 
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), 
		{Position = endPosition}
	)
	tween:Play()
	
	print("Created incoming challenge notification for:", challengerName)
end

-- Remove a notification
function IncomingChallengeUI.removeNotification(challengerId: number)
	local notificationFrame = activeNotifications[challengerId]
	if not notificationFrame then
		return
	end
	
	-- Animate out (slide to right edge of the frame)
	local tween = TweenService:Create(notificationFrame, 
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), 
		{Position = UDim2.new(1.75, 0, notificationPositions[challengerId], 0)}
	)
	tween:Play()
	
	tween.Completed:Connect(function()
		notificationFrame:Destroy()
		
		-- Remove from tracking
		activeNotifications[challengerId] = nil
		notificationPositions[challengerId] = nil
		
		-- Reposition remaining notifications
		IncomingChallengeUI.repositionNotifications()
	end)
	
	print("Removed incoming challenge notification for challenger:", challengerId)
end

-- Reposition remaining notifications after one is removed
function IncomingChallengeUI.repositionNotifications()
	local baseY = 0.75 
	local stackOffset = 0.25 
	local currentIndex = 0
	
	-- Sort notifications by their current Y position (lowest first)
	local sortedNotifications = {}
	for challengerId, frame in pairs(activeNotifications) do
		table.insert(sortedNotifications, {challengerId = challengerId, frame = frame})
	end
	
	table.sort(sortedNotifications, function(a, b)
		return notificationPositions[a.challengerId] < notificationPositions[b.challengerId]
	end)
	
	-- Reposition each notification
	for _, notification in ipairs(sortedNotifications) do
		local newY = baseY - (currentIndex * stackOffset)
		
		-- Update stored position
		notificationPositions[notification.challengerId] = newY
		
		-- Animate to new position (use template's X position)
		local tween = TweenService:Create(notification.frame, 
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), 
			{Position = UDim2.new(0, 0, newY, 0)}
		)
		tween:Play()
		
		currentIndex = currentIndex + 1
	end
end

-- Accept a challenge
function IncomingChallengeUI.acceptChallenge(challengerId: number)
	-- Send accept event to server
	local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
	local acceptChallengeEvent = remoteEventsFolder:WaitForChild(Constants.REMOTE_EVENT_NAMES.ACCEPT_CHALLENGE)
	acceptChallengeEvent:FireServer(challengerId)
	
	-- Remove the notification
	IncomingChallengeUI.removeNotification(challengerId)
	
	print("Accepted challenge from:", challengerId)
end

-- Reject a challenge
function IncomingChallengeUI.rejectChallenge(challengerId: number)
	-- Send reject event to server
	local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
	local rejectChallengeEvent = remoteEventsFolder:WaitForChild(Constants.REMOTE_EVENT_NAMES.REJECT_CHALLENGE)
	rejectChallengeEvent:FireServer(challengerId)
	
	-- Remove the notification
	IncomingChallengeUI.removeNotification(challengerId)
	
	print("Rejected challenge from:", challengerId)
end

-- Clear all notifications
function IncomingChallengeUI.clearAllNotifications()
	for challengerId, _ in pairs(activeNotifications) do
		IncomingChallengeUI.removeNotification(challengerId)
	end
end

-- Initialize the Incoming Challenge UI
function IncomingChallengeUI.init()
	print("IncomingChallengeUI.init() called")
	
	-- Set up RemoteEvent handlers
	local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
	print("RemoteEvents folder found")
	
	-- Handle incoming challenge requests
	local showChallengeRequestEvent = remoteEventsFolder:WaitForChild(Constants.REMOTE_EVENT_NAMES.SHOW_CHALLENGE_REQUEST)
	print("ShowChallengeRequest event found:", showChallengeRequestEvent.Name)
	
	showChallengeRequestEvent.OnClientEvent:Connect(function(challengerId, challengerName)
		print("Received ShowChallengeRequest event - Challenger ID:", challengerId, "Name:", challengerName)
		IncomingChallengeUI.createNotification(challengerId, challengerName)
	end)
	
	print("Incoming Challenge UI initialized successfully")
end

return IncomingChallengeUI
