--[[
	UI.luau
	Client-side user interface management
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(game.ReplicatedStorage.Shared.Constants)
local DataStructures = require(game.ReplicatedStorage.Shared.DataStructures)
local UITemplate = require(game.ReplicatedStorage.Shared.UITemplate)
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


-- Function to create the main UI
function UI.createMainUI()
	-- Create main GUI from template
	mainGui = UITemplate.cloneTemplate()
	mainGui.Name = "BloxTacticsUI"
	mainGui.Parent = playerGui
	
	-- Get references to UI elements
	local mainFrame = mainGui:FindFirstChild("MainFrame")
	if not mainFrame then
		warn("MainFrame not found in UI template!")
		return
	end
	
	shopFrame = mainFrame:FindFirstChild("ShopFrame")
	boardFrame = mainFrame:FindFirstChild("BoardFrame")
	benchFrame = mainFrame:FindFirstChild("BenchFrame")
	statsFrame = mainFrame:FindFirstChild("StatsFrame")
	
	-- Verify all frames exist
	if not shopFrame or not boardFrame or not benchFrame or not statsFrame then
		warn("One or more UI frames not found in template!")
		return
	end

	local shopTitle = nil
	local boardTitle = nil
	local statsTitle = nil
	local statsLevelLabel = nil
	local statsExpLabel = nil
	local statsGoldLabel = nil
	local statsStreakLabel = nil

	shopTitle = shopFrame:FindFirstChild("ShopTitle")
	shopTitle.Font = Enum.Font.GothamBold

	boardTitle = boardFrame:FindFirstChild("BoardTitle")
	boardTitle.Font = Enum.Font.GothamBold

	benchTitle = benchFrame:FindFirstChild("BenchTitle")
	benchTitle.Font = Enum.Font.GothamBold

	statsTitle = statsFrame:FindFirstChild("StatsTitle")
	statsTitle.Font = Enum.Font.GothamBold

	statsLevelLabel = statsFrame:FindFirstChild("LevelLabel")
	statsLevelLabel.Font = Enum.Font.Gotham

	statsExpLabel = statsFrame:FindFirstChild("ExpLabel")
	statsExpLabel.Font = Enum.Font.Gotham

	statsGoldLabel = statsFrame:FindFirstChild("GoldLabel")
	statsGoldLabel.Font = Enum.Font.Gotham

	statsStreakLabel = statsFrame:FindFirstChild("StreakLabel")
	statsStreakLabel.Font = Enum.Font.Gotham
	
	print("UI created successfully from template!")
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
	-- local message = shopVisible and "Shop opened" or "Shop closed"
	-- UI.showNotification(message, 1)
end

-- Function to toggle board visibility
function UI.toggleBoard()
	if not boardFrame or not benchFrame then return end
	
	boardVisible = not boardVisible
	boardFrame.Visible = boardVisible
	benchFrame.Visible = boardVisible
	
	-- Show notification
	-- local message = boardVisible and "Board manager opened" or "Board manager closed"
	-- UI.showNotification(message, 1)
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
