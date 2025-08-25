--[[
	UI.luau
	Client-side user interface management
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(game.ReplicatedStorage.Shared.Constants)
local DataStructures = require(game.ReplicatedStorage.Shared.DataStructures)
local PlayerData = DataStructures.PlayerData

local UI = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI references
local mainGui = nil
local shopFrame = nil
local boardFrame = nil
local benchFrame = nil
local statsFrame = nil

-- UI state variables
local shopVisible = false
local boardVisible = false

-- Function to create keybind indicators
local function createKeybindIndicators(parent: GuiObject)
	-- Create container for keybind indicators
	local keybindContainer = Instance.new("Frame")
	keybindContainer.Name = "KeybindContainer"
	keybindContainer.Size = UDim2.new(0.2, 0, 0.15, 0)
	keybindContainer.Position = UDim2.new(0.8, 0, 0.85, 0)
	keybindContainer.BackgroundTransparency = 1
	keybindContainer.Parent = parent

	-- Create F key indicator (Shop)
	local fKeyIndicator = Instance.new("Frame")
	fKeyIndicator.Name = "FKeyIndicator"
	fKeyIndicator.Size = UDim2.new(0.45, 0, 0.4, 0)
	fKeyIndicator.Position = UDim2.new(0, 0, 0, 0)
	fKeyIndicator.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	fKeyIndicator.BorderSizePixel = 0
	fKeyIndicator.Parent = keybindContainer

	-- Create F key label
	local fKeyLabel = Instance.new("TextLabel")
	fKeyLabel.Name = "FKeyLabel"
	fKeyLabel.Size = UDim2.new(1, 0, 0.6, 0)
	fKeyLabel.Position = UDim2.new(0, 0, 0, 0)
	fKeyLabel.BackgroundTransparency = 1
	fKeyLabel.Text = "F"
	fKeyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	fKeyLabel.TextScaled = true
	fKeyLabel.Font = Enum.Font.GothamBold
	fKeyLabel.Parent = fKeyIndicator

	-- Create F key description
	local fKeyDesc = Instance.new("TextLabel")
	fKeyDesc.Name = "FKeyDesc"
	fKeyDesc.Size = UDim2.new(1, 0, 0.4, 0)
	fKeyDesc.Position = UDim2.new(0, 0, 0.6, 0)
	fKeyDesc.BackgroundTransparency = 1
	fKeyDesc.Text = "Shop"
	fKeyDesc.TextColor3 = Color3.fromRGB(200, 200, 200)
	fKeyDesc.TextScaled = true
	fKeyDesc.Font = Enum.Font.Gotham
	fKeyDesc.Parent = fKeyIndicator

	-- Create C key indicator (Board)
	local cKeyIndicator = Instance.new("Frame")
	cKeyIndicator.Name = "CKeyIndicator"
	cKeyIndicator.Size = UDim2.new(0.45, 0, 0.4, 0)
	cKeyIndicator.Position = UDim2.new(0.55, 0, 0, 0)
	cKeyIndicator.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	cKeyIndicator.BorderSizePixel = 0
	cKeyIndicator.Parent = keybindContainer

	-- Create C key label
	local cKeyLabel = Instance.new("TextLabel")
	cKeyLabel.Name = "CKeyLabel"
	cKeyLabel.Size = UDim2.new(1, 0, 0.6, 0)
	cKeyLabel.Position = UDim2.new(0, 0, 0, 0)
	cKeyLabel.BackgroundTransparency = 1
	cKeyLabel.Text = "C"
	cKeyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	cKeyLabel.TextScaled = true
	cKeyLabel.Font = Enum.Font.GothamBold
	cKeyLabel.Parent = cKeyIndicator

	-- Create C key description
	local cKeyDesc = Instance.new("TextLabel")
	cKeyDesc.Name = "CKeyDesc"
	cKeyDesc.Size = UDim2.new(1, 0, 0.4, 0)
	cKeyDesc.Position = UDim2.new(0, 0, 0.6, 0)
	cKeyDesc.BackgroundTransparency = 1
	cKeyDesc.Text = "Board"
	cKeyDesc.TextColor3 = Color3.fromRGB(200, 200, 200)
	cKeyDesc.TextScaled = true
	cKeyDesc.Font = Enum.Font.Gotham
	cKeyDesc.Parent = cKeyIndicator
end


-- Function to create the main UI
function UI.createMainUI()
	-- Create main GUI
	mainGui = Instance.new("ScreenGui")
	mainGui.Name = "BloxTacticsUI"
	mainGui.Parent = playerGui
	
	-- Create main frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(1, 0, 1, 0)
	mainFrame.BackgroundTransparency = 1
	mainFrame.Parent = mainGui
	
	-- Create shop frame (initially hidden)
	shopFrame = Instance.new("Frame")
	shopFrame.Name = "ShopFrame"
	shopFrame.Size = UDim2.new(0.3, 0, 0.4, 0)
	shopFrame.Position = UDim2.new(0.7, 0, 0.1, 0)
	shopFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	shopFrame.BorderSizePixel = 0
	shopFrame.Visible = false
	shopFrame.Parent = mainFrame
	
	-- Create shop title
	local shopTitle = Instance.new("TextLabel")
	shopTitle.Name = "ShopTitle"
	shopTitle.Size = UDim2.new(1, 0, 0.1, 0)
	shopTitle.Position = UDim2.new(0, 0, 0, 0)
	shopTitle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	shopTitle.Text = "Unit Shop"
	shopTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	shopTitle.TextScaled = true
	shopTitle.Font = Enum.Font.GothamBold
	shopTitle.Parent = shopFrame
	
	-- Create board frame (initially hidden)
	boardFrame = Instance.new("Frame")
	boardFrame.Name = "BoardFrame"
	boardFrame.Size = UDim2.new(0.6, 0, 0.6, 0)
	boardFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
	boardFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	boardFrame.BorderSizePixel = 0
	boardFrame.Visible = false
	boardFrame.Parent = mainFrame
	
	-- Create board title
	local boardTitle = Instance.new("TextLabel")
	boardTitle.Name = "BoardTitle"
	boardTitle.Size = UDim2.new(1, 0, 0.1, 0)
	boardTitle.Position = UDim2.new(0, 0, 0, 0)
	boardTitle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	boardTitle.Text = "Battle Board"
	boardTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	boardTitle.TextScaled = true
	boardTitle.Font = Enum.Font.GothamBold
	boardTitle.Parent = boardFrame
	
	-- Create bench frame (initially hidden)
	benchFrame = Instance.new("Frame")
	benchFrame.Name = "BenchFrame"
	benchFrame.Size = UDim2.new(0.6, 0, 0.15, 0)
	benchFrame.Position = UDim2.new(0.05, 0, 0.85, 0)
	benchFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	benchFrame.BorderSizePixel = 0
	benchFrame.Visible = false
	benchFrame.Parent = mainFrame
	
	-- Create bench title
	local benchTitle = Instance.new("TextLabel")
	benchTitle.Name = "BenchTitle"
	benchTitle.Size = UDim2.new(1, 0, 0.3, 0)
	benchTitle.Position = UDim2.new(0, 0, 0, 0)
	benchTitle.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
	benchTitle.Text = "Bench"
	benchTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	benchTitle.TextScaled = true
	benchTitle.Font = Enum.Font.GothamBold
	benchTitle.Parent = benchFrame
	
	-- Create stats frame (always visible)
	statsFrame = Instance.new("Frame")
	statsFrame.Name = "StatsFrame"
	statsFrame.Size = UDim2.new(0.25, 0, 0.3, 0)
	statsFrame.Position = UDim2.new(0.05, 0, 0.05, 0)
	statsFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	statsFrame.BorderSizePixel = 0
	statsFrame.Parent = mainFrame
	
	-- Create stats title
	local statsTitle = Instance.new("TextLabel")
	statsTitle.Name = "StatsTitle"
	statsTitle.Size = UDim2.new(1, 0, 0.2, 0)
	statsTitle.Position = UDim2.new(0, 0, 0, 0)
	statsTitle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	statsTitle.Text = "Player Stats"
	statsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	statsTitle.TextScaled = true
	statsTitle.Font = Enum.Font.GothamBold
	statsTitle.Parent = statsFrame
	
	-- Create stats labels
	local goldLabel = Instance.new("TextLabel")
	goldLabel.Name = "GoldLabel"
	goldLabel.Size = UDim2.new(1, 0, 0.2, 0)
	goldLabel.Position = UDim2.new(0, 0, 0.2, 0)
	goldLabel.BackgroundTransparency = 1
	goldLabel.Text = "Gold: 100"
	goldLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	goldLabel.TextScaled = true
	goldLabel.Font = Enum.Font.Gotham
	goldLabel.Parent = statsFrame
	
	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.new(1, 0, 0.2, 0)
	levelLabel.Position = UDim2.new(0, 0, 0.4, 0)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "Level: 1"
	levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	levelLabel.TextScaled = true
	levelLabel.Font = Enum.Font.Gotham
	levelLabel.Parent = statsFrame
	
	local expLabel = Instance.new("TextLabel")
	expLabel.Name = "ExpLabel"
	expLabel.Size = UDim2.new(1, 0, 0.2, 0)
	expLabel.Position = UDim2.new(0, 0, 0.6, 0)
	expLabel.BackgroundTransparency = 1
	expLabel.Text = "Exp: 0/100"
	expLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	expLabel.TextScaled = true
	expLabel.Font = Enum.Font.Gotham
	expLabel.Parent = statsFrame
	
	local streakLabel = Instance.new("TextLabel")
	streakLabel.Name = "StreakLabel"
	streakLabel.Size = UDim2.new(1, 0, 0.2, 0)
	streakLabel.Position = UDim2.new(0, 0, 0.8, 0)
	streakLabel.BackgroundTransparency = 1
	streakLabel.Text = "Streak: 0"
	streakLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	streakLabel.TextScaled = true
	streakLabel.Font = Enum.Font.Gotham
	streakLabel.Parent = statsFrame
	
	-- Create keybind indicators
	createKeybindIndicators(mainFrame)
end

-- Function to update player stats display
function UI.updatePlayerStats(playerData: PlayerData)
	if not statsFrame then return end
	
	local goldLabel = statsFrame:FindFirstChild("GoldLabel")
	local levelLabel = statsFrame:FindFirstChild("LevelLabel")
	local expLabel = statsFrame:FindFirstChild("ExpLabel")
	local streakLabel = statsFrame:FindFirstChild("StreakLabel")
	
	if goldLabel then
		goldLabel.Text = "Gold: " .. playerData.gold
	end
	
	if levelLabel then
		levelLabel.Text = "Level: " .. playerData.level
	end
	
	if expLabel then
		expLabel.Text = "Exp: " .. playerData.experience .. "/" .. Constants.EXPERIENCE_PER_LEVEL
	end
	
	if streakLabel then
		streakLabel.Text = "Streak: " .. playerData.streak
	end
end

-- Function to create unit button
function UI.createUnitButton(unit: DataStructures.Unit, parent: GuiObject, onClick: () -> ())
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0.18, 0, 0.8, 0)
	button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	button.BorderSizePixel = 0
	button.Text = unit.name .. "\nCost: " .. unit.cost .. "\nTier: " .. unit.tier
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = true
	button.Font = Enum.Font.Gotham
	button.Parent = parent
	
	-- Add click handler
	button.MouseButton1Click:Connect(onClick)
	
	return button
end

-- Function to update shop display
function UI.updateShopDisplay(shopUnits: {DataStructures.Unit})
	if not shopFrame then return end
	
	-- Clear existing shop buttons
	for _, child in pairs(shopFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	
	-- Create new shop buttons
	for i, unit in ipairs(shopUnits) do
		local button = UI.createUnitButton(unit, shopFrame, function()
			-- Handle unit purchase
			-- This will be connected to RemoteEvents later
		end)
		
		button.Position = UDim2.new(0.05 + (i-1) * 0.19, 0, 0.15, 0)
	end
end

-- Function to toggle shop visibility
function UI.toggleShop()
	if not shopFrame then return end
	
	shopVisible = not shopVisible
	shopFrame.Visible = shopVisible
	
	-- Show notification
	local message = shopVisible and "Shop opened" or "Shop closed"
	UI.showNotification(message, 1)
end

-- Function to toggle board visibility
function UI.toggleBoard()
	if not boardFrame or not benchFrame then return end
	
	boardVisible = not boardVisible
	boardFrame.Visible = boardVisible
	benchFrame.Visible = boardVisible
	
	-- Show notification
	local message = boardVisible and "Board manager opened" or "Board manager closed"
	UI.showNotification(message, 1)
end

-- Function to show/hide UI
function UI.setUIVisibility(visible: boolean)
	if mainGui then
		mainGui.Enabled = visible
	end
end

-- Function to show notification
function UI.showNotification(message: string, duration: number)
	local notification = Instance.new("TextLabel")
	notification.Size = UDim2.new(0.3, 0, 0.1, 0)
	notification.Position = UDim2.new(0.35, 0, 0.45, 0)
	notification.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	notification.BackgroundTransparency = 0.3
	notification.Text = message
	notification.TextColor3 = Color3.fromRGB(255, 255, 255)
	notification.TextScaled = true
	notification.Font = Enum.Font.GothamBold
	notification.Parent = mainGui
	
	-- Animate out
	local tween = TweenService:Create(notification, TweenInfo.new(duration), {
		BackgroundTransparency = 1,
		TextTransparency = 1
	})
	
	tween:Play()
	tween.Completed:Connect(function()
		notification:Destroy()
	end)
end

return UI
