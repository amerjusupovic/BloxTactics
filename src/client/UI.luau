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
	local benchTitle = nil
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
-- function UI.createUnitButton(unit: DataStructures.Unit, parent: GuiObject, onClick: () -> ())
	-- local button = Instance.new("TextButton")
	-- button.Size = UDim2.new(0.18, 0, 0.8, 0)
	-- button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	-- button.BorderSizePixel = 0
	-- button.Text = unit.name .. "\nCost: " .. unit.cost .. "\nTier: " .. unit.tier
	-- button.TextColor3 = Color3.fromRGB(255, 255, 255)
	-- button.TextScaled = true
	-- button.Font = Enum.Font.Gotham
	-- button.Parent = parent
	
	-- -- Add click handler
	-- button.MouseButton1Click:Connect(onClick)
	
	-- return button
-- end

-- Function to create shop unit button
function UI.createShopUnitButton(unit: DataStructures.Unit, parent: GuiObject, onClick: () -> ())
	local button = Instance.new("ImageButton")
	button.Size = UDim2.new(0.18, 0, 0.6, 0)
	button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	button.BorderSizePixel = 0
	button.Image = unit.imageAssetId -- Use unit's image asset ID
	button.Parent = parent
	
	-- Create unit info label
	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, 0, 0.3, 0)
	infoLabel.Position = UDim2.new(0, 0, 0.75, 0)
	infoLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	infoLabel.BackgroundTransparency = 0.5
	infoLabel.Text = unit.name .. "\nCost: " .. unit.cost .. "\nTier: " .. unit.tier
	infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	infoLabel.TextScaled = true
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.Parent = button
	
	-- Add click handler
	button.MouseButton1Click:Connect(onClick)
	
	-- Store unit data in button (only primitive types)
	button:SetAttribute("UnitId", unit.id)
	button:SetAttribute("UnitName", unit.name)
	button:SetAttribute("UnitCost", unit.cost)
	button:SetAttribute("UnitTier", unit.tier)
	button:SetAttribute("UnitImageAssetId", unit.imageAssetId)
	
	return button
end

-- Function to update shop display
function UI.updateShopDisplay(shopUnits: {DataStructures.Unit})
	if not shopFrame then return end
	
	-- Clear existing shop buttons
	for _, child in pairs(shopFrame:GetChildren()) do
		if child:IsA("ImageButton") and child.Name:find("ShopUnit_") then
			child:Destroy()
		end
	end
	
	-- Create new shop buttons
	for i, unit in ipairs(shopUnits) do
		local button = UI.createShopUnitButton(unit, shopFrame, function()
			-- Handle unit purchase
			UI.handleUnitPurchase(unit, i)
		end)
		
		button.Name = "ShopUnit_" .. i
		button.Position = UDim2.new(0.05 + (i-1) * 0.19, 0, 0.15, 0)
	end
end

-- Function to handle unit purchase
function UI.handleUnitPurchase(unit: DataStructures.Unit, shopIndex: number)
	-- Fire RemoteEvent to server
	local purchaseUnitEvent = game.ReplicatedStorage.RemoteEvents:FindFirstChild("PurchaseUnit")
	if purchaseUnitEvent then
		purchaseUnitEvent:FireServer(shopIndex)
	else
		warn("PurchaseUnit RemoteEvent not found!")
	end
end

-- Function to gray out shop button
function UI.grayOutShopButton(shopIndex: number)
	if not shopFrame then return end
	
	local button = shopFrame:FindFirstChild("ShopUnit_" .. shopIndex)
	if button then
		button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		button.ImageTransparency = 0.7
		button:SetAttribute("SoldOut", true)
	end
end

-- Function to place unit on board
function UI.placeUnitOnBoard(unit: DataStructures.Unit, position: Vector2)
	if not boardFrame then return end
	
	-- Validate position
	if not position or not position.X or not position.Y then
		warn("Invalid position in placeUnitOnBoard:", position)
		return
	end
	
	local hexName = string.format("Hex_%d_%d", position.Y + 1, position.X + 1)
	local hex = boardFrame:FindFirstChild(hexName)
	
	if hex then
		-- Create unit visual
		local unitVisual = Instance.new("ImageButton")
		unitVisual.Size = UDim2.new(0.8, 0, 0.8, 0)
		unitVisual.Position = UDim2.new(0.1, 0, 0, 0) -- Position at top of hex
		unitVisual.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		unitVisual.BorderSizePixel = 0
		unitVisual.Image = unit.imageAssetId -- Use unit's image
		unitVisual.Parent = hex
		
		-- Create tier label overlay
		local tierLabel = Instance.new("TextLabel")
		tierLabel.Size = UDim2.new(0.3, 0, 0.3, 0)
		tierLabel.Position = UDim2.new(0.7, 0, 0.7, 0)
		tierLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		tierLabel.BackgroundTransparency = 0.3
		tierLabel.Text = "T" .. unit.tier
		tierLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		tierLabel.TextScaled = true
		tierLabel.Font = Enum.Font.GothamBold
		tierLabel.Parent = unitVisual
		
		-- Store unit data (only primitive types)
		unitVisual:SetAttribute("UnitId", unit.id)
		unitVisual:SetAttribute("UnitName", unit.name)
		unitVisual:SetAttribute("UnitTier", unit.tier)
		unitVisual:SetAttribute("UnitImageAssetId", unit.imageAssetId)
		unitVisual:SetAttribute("PositionX", position.X)
		unitVisual:SetAttribute("PositionY", position.Y)
		
		print("Unit placed on board at position:", position)
	end
end

-- Function to place unit on bench
function UI.placeUnitOnBench(unit: DataStructures.Unit, benchSlot: number)
	if not benchFrame then return end
	
	-- Validate bench slot
	if not benchSlot or benchSlot <= 0 then
		warn("Invalid bench slot in placeUnitOnBench:", benchSlot)
		return
	end
	
	local hexName = string.format("BenchHex_%d", benchSlot)
	local hex = benchFrame:FindFirstChild(hexName)
	
	if hex then
		-- Create unit visual
		local unitVisual = Instance.new("ImageButton")
		unitVisual.Size = UDim2.new(0.8, 0, 0.8, 0)
		unitVisual.Position = UDim2.new(0.1, 0, 0, 0) -- Position at top of hex
		unitVisual.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		unitVisual.BorderSizePixel = 0
		unitVisual.Image = unit.imageAssetId -- Use unit's image
		unitVisual.Parent = hex
		
		-- Create tier label overlay
		local tierLabel = Instance.new("TextLabel")
		tierLabel.Size = UDim2.new(0.3, 0, 0.3, 0)
		tierLabel.Position = UDim2.new(0.7, 0, 0.7, 0)
		tierLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		tierLabel.BackgroundTransparency = 0.3
		tierLabel.Text = "T" .. unit.tier
		tierLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		tierLabel.TextScaled = true
		tierLabel.Font = Enum.Font.GothamBold
		tierLabel.Parent = unitVisual
		
		-- Store unit data (only primitive types)
		unitVisual:SetAttribute("UnitId", unit.id)
		unitVisual:SetAttribute("UnitName", unit.name)
		unitVisual:SetAttribute("UnitTier", unit.tier)
		unitVisual:SetAttribute("UnitImageAssetId", unit.imageAssetId)
		unitVisual:SetAttribute("BenchSlot", benchSlot)
		
		print("Unit placed on bench at slot:", benchSlot)
	end
end

-- Function to update board display
function UI.updateBoardDisplay(boardState: DataStructures.BoardState)
	if not boardFrame then return end
	
	-- Validate board state
	if not boardState or not boardState.grid then
		warn("Invalid board state in updateBoardDisplay")
		return
	end
	
	-- Clear existing units
	for _, child in pairs(boardFrame:GetChildren()) do
		if child:IsA("ImageButton") and child.Name:find("Hex_") then
			-- Clear any unit visuals in this hex
			for _, unitVisual in pairs(child:GetChildren()) do
				if unitVisual:IsA("ImageButton") and unitVisual ~= child then
					unitVisual:Destroy()
				end
			end
		end
	end
	
	-- Place units from board state
	for position, unit in pairs(boardState.grid) do
		if position and unit then
			UI.placeUnitOnBoard(unit, position)
		end
	end
end

-- Function to update bench display
function UI.updateBenchDisplay(benchState: DataStructures.BenchState)
	if not benchFrame then return end
	
	-- Validate bench state
	if not benchState or not benchState.units or not benchState.maxCapacity then
		warn("Invalid bench state in updateBenchDisplay")
		return
	end
	
	-- Clear existing units
	for _, child in pairs(benchFrame:GetChildren()) do
		if child:IsA("ImageButton") and child.Name:find("BenchHex_") then
			-- Clear any unit visuals in this hex
			for _, unitVisual in pairs(child:GetChildren()) do
				if unitVisual:IsA("ImageButton") and unitVisual ~= child then
					unitVisual:Destroy()
				end
			end
		end
	end
	
	-- Place units from bench state in sequential order
	local units = {}
	for unitId, unit in pairs(benchState.units) do
		if unit then
			table.insert(units, unit)
		end
	end
	
	-- Sort units by their unique ID to maintain consistent order
	table.sort(units, function(a, b)
		return a.id < b.id
	end)
	
	-- Place units in sequential slots
	for i, unit in ipairs(units) do
		if i <= benchState.maxCapacity then
			UI.placeUnitOnBench(unit, i)
		end
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
