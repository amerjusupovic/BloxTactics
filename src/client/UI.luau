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
local sellUnitFrame = nil

-- UI state variables
local shopVisible = false
local boardVisible = false

-- Unit selection state
local selectedUnit = nil
local selectedHex = nil


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
	sellUnitFrame = mainFrame:FindFirstChild("SellUnitFrame")
	
	-- Verify all frames exist
	if not shopFrame or not boardFrame or not benchFrame or not statsFrame or not sellUnitFrame then
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
	
	-- Create board hexes
	UI.createBoardHexes()
	
	-- Add click handler for sell area
	if sellUnitFrame then
		sellUnitFrame.MouseButton1Click:Connect(function()
			UI.sellSelectedUnit()
		end)
	end

	sellUnitTitle = sellUnitFrame:FindFirstChild("SellUnitTitle")
	sellUnitTitle.Font = Enum.Font.GothamBold
	
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
	local purchaseUnitEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("PurchaseUnit")
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
	if not position then
		warn("Position is nil in placeUnitOnBoard")
		return
	end
	
	-- Handle both Vector2 and table formats
	local x, y
	if typeof(position) == "Vector2" then
		x = position.X
		y = position.Y
	elseif typeof(position) == "table" then
		x = position.X or position.x
		y = position.Y or position.y
	else
		warn("Invalid position type in placeUnitOnBoard:", typeof(position), position)
		return
	end
	
	if not x or not y then
		warn("Invalid position coordinates in placeUnitOnBoard:", position)
		return
	end
	
	-- Position validation successful
	
	local hexName = string.format("Hex_%d_%d", y + 1, x + 1)
	local hex = boardFrame:FindFirstChild(hexName)
	-- Hex lookup completed
	
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
		unitVisual:SetAttribute("PositionX", x)
		unitVisual:SetAttribute("PositionY", y)
		
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
	
	-- Board update started
	
	-- Clear selection when board is updated
	UI.clearSelection()
	
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
	
	-- Show/hide sell area based on board visibility and selection
	if sellUnitFrame then
		sellUnitFrame.Visible = boardVisible and selectedUnit ~= nil
	end
	
	-- Clear selection when hiding board
	if not boardVisible then
		UI.clearSelection()
	end
	
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

-- Function to select a unit on the board
function UI.selectUnit(unitVisual: GuiObject, hex: GuiObject)
	-- Clear previous selection
	UI.clearSelection()
	
	-- Set new selection
	selectedUnit = unitVisual
	selectedHex = hex
	
	-- Highlight the selected unit
	if unitVisual then
		unitVisual.BackgroundColor3 = Color3.fromRGB(255, 255, 0) -- Yellow highlight
		unitVisual.BorderSizePixel = 2
		unitVisual.BorderColor3 = Color3.fromRGB(255, 255, 0)
	end
	
	-- Show sell area when board is visible
	if boardVisible and sellUnitFrame then
		sellUnitFrame.Visible = true
	end
end

-- Function to clear unit selection
function UI.clearSelection()
	if selectedUnit then
		selectedUnit.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		selectedUnit.BorderSizePixel = 0
		selectedUnit = nil
	end
	selectedHex = nil
	
	-- Hide sell area
	if sellUnitFrame then
		sellUnitFrame.Visible = false
	end
end

-- Function to handle hex click for unit selection/movement
function UI.handleHexClick(hex: GuiObject, position: Vector2)
	if not hex then return end
	
	-- Check if there's a unit in this hex
	local unitVisual = nil
	for _, child in pairs(hex:GetChildren()) do
		if child:IsA("ImageButton") and child ~= hex then
			unitVisual = child
			break
		end
	end
	
	-- If we have a selected unit and clicked on a different hex
	if selectedUnit and selectedHex and selectedHex ~= hex then
		-- Move the unit
		UI.moveUnit(selectedUnit, selectedHex, hex, position)
		UI.clearSelection()
		return
	end
	
	-- If we clicked on a hex with a unit and no unit is selected
	if unitVisual and not selectedUnit then
		UI.selectUnit(unitVisual, hex)
		return
	end
	
	-- If we clicked on the same hex or an empty hex, clear selection
	UI.clearSelection()
end

-- Function to move a unit
function UI.moveUnit(unitVisual: GuiObject, fromHex: GuiObject, toHex: GuiObject, toPosition: Vector2)
	if not unitVisual or not fromHex or not toHex then return end
	
	-- Get unit data from the visual
	local unitId = unitVisual:GetAttribute("UnitId")
	local unitName = unitVisual:GetAttribute("UnitName")
	local unitTier = unitVisual:GetAttribute("UnitTier")
	local unitImageAssetId = unitVisual:GetAttribute("UnitImageAssetId")
	local fromX = unitVisual:GetAttribute("PositionX")
	local fromY = unitVisual:GetAttribute("PositionY")
	
	-- Check if there's a unit in the destination hex
	local targetUnitVisual = nil
	for _, child in pairs(toHex:GetChildren()) do
		if child:IsA("ImageButton") and child ~= toHex then
			targetUnitVisual = child
			break
		end
	end
	
	-- Create unit data for the move request
	local unit = {
		id = unitId,
		name = unitName,
		tier = unitTier,
		imageAssetId = unitImageAssetId
	}
	
	-- Send move request to server
	local fromPosition = Vector2.new(fromX, fromY)
	UI.requestUnitMove(unit, fromPosition, toPosition)
end

-- Function to request unit move from server
function UI.requestUnitMove(unit: any, fromPosition: Vector2, toPosition: Vector2)
	local moveUnitEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("MoveUnit")
	if moveUnitEvent then
		moveUnitEvent:FireServer(fromPosition, toPosition)
	else
		warn("MoveUnit RemoteEvent not found!")
	end
end

-- Function to sell selected unit
function UI.sellSelectedUnit()
	if not selectedUnit then return end
	
	local unitId = selectedUnit:GetAttribute("UnitId")
	local positionX = selectedUnit:GetAttribute("PositionX")
	local positionY = selectedUnit:GetAttribute("PositionY")
	
	if unitId and positionX and positionY then
		local position = Vector2.new(positionX, positionY)
		UI.requestUnitSell(unitId, position)
		UI.clearSelection()
	end
end

-- Function to request unit sell from server
function UI.requestUnitSell(unitId: string, position: Vector2)
	local sellUnitEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("SellUnit")
	if sellUnitEvent then
		sellUnitEvent:FireServer(unitId, position)
	else
		warn("SellUnit RemoteEvent not found!")
	end
end

-- Function to reset player data (for testing)
function UI.resetPlayerData()
	local resetEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("ResetPlayerData")
	if resetEvent then
		resetEvent:FireServer()
		UI.showNotification("Player data reset!", 3)
	else
		warn("ResetPlayerData RemoteEvent not found!")
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

-- Function to create board hexes
function UI.createBoardHexes()
	if not boardFrame then return end
	
	-- Grid size
	local rows = Constants.BOARD_HEIGHT
	local cols = Constants.BOARD_WIDTH
	
	-- Hex size (as scale of parent container)
	local hexWidth = 0.13
	local hexHeight = 0.22
	local aspectRatio = 0.92 -- depends on your hex image
	
	-- Offset (half a hex width)
	local offsetX = hexWidth / 2
	local titleHeightOffset = 0.09 -- TODO calculate
	
	-- Compute total board width/height in scale
	local boardWidth = (cols - 1) * hexWidth + hexWidth + offsetX
	local boardHeight = hexHeight + (rows - 1) * (hexHeight * 0.85)
	
	-- Compute margins to center
	local marginX = (1 - (boardWidth - 0.04)) / 2
	local marginY = (1 - (boardHeight - titleHeightOffset)) / 2
	
	for row = 1, rows do
		for col = 1, cols do
			local hex = Instance.new("ImageButton")
			hex.Size = UDim2.new(hexWidth, 0, hexHeight, 0)
			hex.BackgroundTransparency = 1
			hex.Image = "rbxassetid://135628423497794"
			hex.Name = string.format("Hex_%d_%d", row, col)
			
			-- Aspect ratio lock
			local constraint = Instance.new("UIAspectRatioConstraint")
			constraint.AspectRatio = aspectRatio
			constraint.Parent = hex
			
			-- Base pos
			local posX = (col - 1) * hexWidth
			local posY = (row - 1) * (hexHeight * 0.88)
			
			-- Row offset
			if row % 2 == 0 then
				posX = posX + offsetX
			end
			
			-- Apply centering margin
			posX = posX + marginX
			posY = posY + marginY
			
			hex.Position = UDim2.new(posX, 0, posY, 0)
			hex.Parent = boardFrame
			
			-- Add click handler for unit selection/movement
			local position = Vector2.new(col - 1, row - 1)
			hex.MouseButton1Click:Connect(function()
				UI.handleHexClick(hex, position)
			end)
		end
	end
	
	-- Create bench hexes
	if not benchFrame then return end
	
	-- Grid size (bench is 1 row, 6 columns)
	local benchRows = 1
	local benchCols = Constants.BENCH_CAPACITY -- e.g. 6
	
	-- Hex size (as scale of parent container)
	local benchHexWidth = 0.13
	local benchHexHeight = 0.55
	local benchAspectRatio = 0.92 -- depends on your hex image
	
	-- Compute total bench width/height in scale
	local benchWidth = benchCols * benchHexWidth
	local benchHeight = benchHexHeight
	
	local benchTitleHeightOffset = 0.2 -- TODO calculate
	
	-- Compute margins to center in BenchFrame
	local benchMarginX = (1 - (benchWidth - 0.04)) / 2
	local benchMarginY = (1 - (benchHeight - benchTitleHeightOffset)) / 2
	
	for col = 1, benchCols do
		local hex = Instance.new("ImageButton")
		hex.Size = UDim2.new(benchHexWidth, 0, benchHexHeight, 0)
		hex.BackgroundTransparency = 1
		hex.Image = "rbxassetid://135628423497794"
		hex.Name = string.format("BenchHex_%d", col)
		
		-- Aspect ratio lock
		local constraint = Instance.new("UIAspectRatioConstraint")
		constraint.AspectRatio = benchAspectRatio
		constraint.Parent = hex
		
		-- Position (no staggering needed)
		local posX = (col - 1) * benchHexWidth
		local posY = 0
		
		-- Apply centering margin
		posX = posX + benchMarginX
		posY = posY + benchMarginY
		
		hex.Position = UDim2.new(posX, 0, posY, 0)
		hex.Parent = benchFrame
	end
	
	print("Board and bench hexes created successfully!")
end

return UI
