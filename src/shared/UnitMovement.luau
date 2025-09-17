--[[
	UnitMovement.luau
	Shared unit movement logic for UI components
]]

local Constants = require(game.ReplicatedStorage.Shared.Constants)

local UnitMovement = {}

-- Unit selection state
local selectedUnit = nil
local selectedHex = nil

-- Function to select a unit
function UnitMovement.selectUnit(unitVisual: GuiObject, hex: GuiObject, context: string?)
	print("Selecting unit in", context or "unknown context:", unitVisual:GetAttribute("UnitName"))
	
	-- Clear previous selection
	UnitMovement.clearSelection()
	
	-- Set new selection
	selectedUnit = unitVisual
	selectedHex = hex
	
	-- Highlight the selected unit
	if unitVisual then
		unitVisual.BackgroundColor3 = Color3.fromRGB(255, 255, 0) -- Yellow highlight
		unitVisual.BorderSizePixel = 2
		unitVisual.BorderColor3 = Color3.fromRGB(255, 255, 0)
		print("Unit highlighted in yellow in", context or "unknown context")
	end
end

-- Function to clear unit selection
function UnitMovement.clearSelection()
	if selectedUnit then
		selectedUnit.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		selectedUnit.BorderSizePixel = 0
		selectedUnit = nil
	end
	selectedHex = nil
end

-- Function to handle hex click for unit selection/movement
function UnitMovement.handleHexClick(hex: GuiObject, position: Vector2, onMoveUnit: (unit: any, fromPosition: Vector2, toPosition: Vector2) -> (), context: string?)
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
		-- Move the unit (this handles swapping too)
		UnitMovement.moveUnit(selectedUnit, selectedHex, hex, position, onMoveUnit, context)
		UnitMovement.clearSelection()
		return
	end
	
	-- If we clicked on an empty hex, clear selection
	if not unitVisual then
		UnitMovement.clearSelection()
		return
	end
	
	-- If we clicked on a hex with a unit, select it
	-- This allows for unit swapping when clicking on different units
	if unitVisual then
		UnitMovement.selectUnit(unitVisual, hex, context)
	end
end

-- Function to move a unit
function UnitMovement.moveUnit(unitVisual: GuiObject, fromHex: GuiObject, toHex: GuiObject, toPosition: Vector2, onMoveUnit: (unit: any, fromPosition: Vector2, toPosition: Vector2) -> (), context: string?)
	if not unitVisual or not fromHex or not toHex then return end
	
	-- Get unit data from the visual
	local unitId = unitVisual:GetAttribute("UnitId")
	local unitName = unitVisual:GetAttribute("UnitName")
	local unitTier = unitVisual:GetAttribute("UnitTier")
	local unitImageAssetId = unitVisual:GetAttribute("UnitImageAssetId")
	
	-- Check if this is a bench unit or board unit
	local benchSlot = unitVisual:GetAttribute("BenchSlot")
	local fromX = unitVisual:GetAttribute("PositionX")
	local fromY = unitVisual:GetAttribute("PositionY")
	
	-- Determine from position
	local fromPosition
	if benchSlot then
		-- This is a bench unit, use negative bench slot as X coordinate
		fromPosition = Vector2.new(-benchSlot, 0)
		print("Moving bench unit from slot:", benchSlot, "to board position:", toPosition, "in", context or "unknown context")
	else
		-- This is a board unit
		fromPosition = Vector2.new(fromX, fromY)
		print("Moving board unit from:", fromPosition, "to:", toPosition, "in", context or "unknown context")
	end
	
	-- Create unit data for the move request
	local unit = {
		id = unitId,
		name = unitName,
		tier = unitTier,
		imageAssetId = unitImageAssetId
	}
	
	-- Call the provided move handler
	if onMoveUnit then
		onMoveUnit(unit, fromPosition, toPosition)
	end
end

-- Function to add unit data attributes to a unit visual
function UnitMovement.addUnitAttributes(unitVisual: GuiObject, unit: any, x: number?, y: number?, benchSlot: number?)
	-- Store unit data (only primitive types)
	unitVisual:SetAttribute("UnitId", unit.id)
	unitVisual:SetAttribute("UnitName", unit.name)
	unitVisual:SetAttribute("UnitTier", unit.tier)
	unitVisual:SetAttribute("UnitImageAssetId", unit.imageAssetId)
	
	if x and y then
		unitVisual:SetAttribute("PositionX", x)
		unitVisual:SetAttribute("PositionY", y)
	end
	
	if benchSlot then
		unitVisual:SetAttribute("BenchSlot", benchSlot)
	end
end

-- Function to add click handler to a unit visual
function UnitMovement.addUnitClickHandler(unitVisual: ImageButton, hex: GuiObject, context: string?)
	-- Add click handler for unit selection
	unitVisual.MouseButton1Click:Connect(function()
		UnitMovement.selectUnit(unitVisual, hex, context)
	end)
end

-- Function to create a tier label overlay
function UnitMovement.createTierLabel(unitVisual: GuiObject, tier: number)
	local tierLabel = Instance.new("TextLabel")
	tierLabel.Size = UDim2.new(0.3, 0, 0.3, 0)
	tierLabel.Position = UDim2.new(0.7, 0, 0.7, 0)
	tierLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	tierLabel.BackgroundTransparency = 0.3
	tierLabel.Text = "T" .. tier
	tierLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	tierLabel.TextScaled = true
	tierLabel.Font = Enum.Font.GothamBold
	tierLabel.Parent = unitVisual
end

-- Function to create a unit visual
function UnitMovement.createUnitVisual(hex: GuiObject, unit: any, x: number?, y: number?, benchSlot: number?, context: string?): ImageButton
	-- Create unit visual
	local unitVisual = Instance.new("ImageButton")
	unitVisual.Size = UDim2.new(0.8, 0, 0.8, 0)
	unitVisual.Position = UDim2.new(0.1, 0, 0.1, 0)
	unitVisual.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	unitVisual.BorderSizePixel = 0
	unitVisual.Image = unit.imageAssetId
	unitVisual.Parent = hex
	
	-- Create tier label overlay
	UnitMovement.createTierLabel(unitVisual, unit.tier)
	
	-- Add unit attributes
	UnitMovement.addUnitAttributes(unitVisual, unit, x, y, benchSlot)
	
	-- Add click handler
	UnitMovement.addUnitClickHandler(unitVisual, hex, context)
	
	return unitVisual
end

-- Function to get current selection state
function UnitMovement.getSelectionState()
	return {
		selectedUnit = selectedUnit,
		selectedHex = selectedHex
	}
end

-- Function to check if a unit is selected
function UnitMovement.hasSelection()
	return selectedUnit ~= nil
end

-- Function to create board hexes
function UnitMovement.createBoardHexes(boardFrame: GuiObject, onHexClick: (hex: GuiObject, position: Vector2) -> (), context: string?)
	if not boardFrame then return end
	
	-- Grid size
	local rows = Constants.BOARD_HEIGHT
	local cols = Constants.BOARD_WIDTH
	
	-- Hex size (as scale of parent container)
	local hexWidth = 0.13
	local hexHeight = 0.22
	local aspectRatio = 0.92
	
	-- Offset (half a hex width)
	local offsetX = hexWidth / 2
	local titleHeightOffset = 0.05
	
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
			
			-- Convert to bottom-up coordinate system for hex naming
			local bottomUpRow = rows - row + 1
			hex.Name = string.format("Hex_%d_%d", bottomUpRow, col)
			
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
			-- Convert to bottom-up coordinate system: (col-1, rows-row)
			local position = Vector2.new(col - 1, rows - row)
			hex.MouseButton1Click:Connect(function()
				if onHexClick then
					onHexClick(hex, position)
				end
			end)
		end
	end
end

-- Function to create bench hexes
function UnitMovement.createBenchHexes(benchFrame: GuiObject, onHexClick: (hex: GuiObject, position: Vector2) -> (), context: string?)
	if not benchFrame then return end
	
	-- Grid size (bench is 1 row, 6 columns)
	local benchCols = Constants.BENCH_CAPACITY
	
	-- Hex size (as scale of parent container)
	local benchHexWidth = 0.13
	local benchHexHeight = 0.55
	local benchAspectRatio = 0.92
	
	-- Compute total bench width/height in scale
	local benchWidth = benchCols * benchHexWidth
	local benchHeight = benchHexHeight
	
	-- Calculate bench title height offset
	local benchTitleHeightOffset = 0.1
	
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
		
		-- Add click handler for bench hex selection/movement
		-- Use negative bench slot as position (e.g., -1 for slot 1)
		local benchPosition = Vector2.new(-col, 0)
		hex.MouseButton1Click:Connect(function()
			if onHexClick then
				onHexClick(hex, benchPosition)
			end
		end)
	end
end

return UnitMovement
