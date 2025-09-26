--[[
	UnitMovement.luau
	Shared unit movement logic for UI components
]]

local Constants = require(game.ReplicatedStorage.Shared.Constants)

-- Optional: access unit base data for tooltip fallbacks
local UnitDatabase
do
	local ok, mod = pcall(function()
		return require(game.ReplicatedStorage.Shared.UnitDatabase)
	end)
	if ok then
		UnitDatabase = mod
	end
end

local UnitMovement = {}

-- Unit selection state
local selectedUnit = nil
local selectedHex = nil
local selectionChangedEvent = Instance.new("BindableEvent")

-- Public signal accessor
function UnitMovement.selectionChanged()
	return selectionChangedEvent.Event
end

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

	selectionChangedEvent:Fire(true, unitVisual)
end

-- Function to clear unit selection
function UnitMovement.clearSelection()
	if selectedUnit then
		selectedUnit.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		selectedUnit.BorderSizePixel = 0
		selectedUnit = nil
	end
	selectedHex = nil
    selectionChangedEvent:Fire(false, nil)
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
function UnitMovement.addUnitClickHandler(unitVisual: ImageButton, hex: GuiObject, context: string?, onMoveUnit: ((unit: any, fromPosition: Vector2, toPosition: Vector2) -> ())?)
	-- Add click handler that supports selecting or swapping when another unit is already selected
	unitVisual.MouseButton1Click:Connect(function()
		local state = UnitMovement.getSelectionState()

		-- If a different unit is selected already and a move handler is available, perform a move/swap
	if state.selectedUnit and state.selectedHex and state.selectedHex ~= hex and onMoveUnit then
			-- Determine destination position from the clicked unit's attributes
			local benchSlot = unitVisual:GetAttribute("BenchSlot")
			local posX = unitVisual:GetAttribute("PositionX")
			local posY = unitVisual:GetAttribute("PositionY")

			local toPosition: Vector2?
			if benchSlot ~= nil then
				toPosition = Vector2.new(-benchSlot, 0)
			elseif posX ~= nil and posY ~= nil then
				toPosition = Vector2.new(posX, posY)
			end

			-- Fallback: derive position from hex/bench names if attributes are missing
			if not toPosition and hex and typeof(hex.Name) == "string" then
				local name = hex.Name
				-- Board hexes: Hex_row_col where row/col are 1-based bottom-up
				local rowStr, colStr = string.match(name, "^Hex_(%d+)_(%d+)$")
				if rowStr and colStr then
					local rows = Constants.BOARD_HEIGHT
					local hexRow = tonumber(rowStr)
					local hexCol = tonumber(colStr)
					if hexRow and hexCol then
						toPosition = Vector2.new(hexCol - 1, hexRow - 1)
					end
				else
					-- Bench hexes: BenchHex_slot
					local slotStr = string.match(name, "^BenchHex_(%d+)$")
					if slotStr then
						local slot = tonumber(slotStr)
						if slot then
							toPosition = Vector2.new(-slot, 0)
						end
					end
				end
			end

			if toPosition then
				-- Reuse moveUnit helper to compute fromPosition and invoke the callback
				UnitMovement.moveUnit(state.selectedUnit, state.selectedHex, hex, toPosition, onMoveUnit, context)
				UnitMovement.clearSelection()
				return
			end
			-- If destination position couldn't be determined, fall back to selection
		end

		-- Default behavior: select this unit
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
function UnitMovement.createUnitVisual(hex: GuiObject, unit: any, x: number?, y: number?, benchSlot: number?, context: string?, onMoveUnit: ((unit: any, fromPosition: Vector2, toPosition: Vector2) -> ())?): ImageButton
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
	
	-- Add click handler (supports swap when another unit is selected)
	UnitMovement.addUnitClickHandler(unitVisual, hex, context, onMoveUnit)

	-- Attach hover tooltip (similar formatting to trait tooltip)
	if not unitVisual:GetAttribute("TooltipBound") then
		unitVisual:SetAttribute("TooltipBound", true)

		-- Create tooltip label once (parent to container to avoid being occluded/clipped)
		local tooltip = Instance.new("TextLabel")
		tooltip.Name = "Tooltip"
		tooltip.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
		tooltip.BackgroundTransparency = 0.15
		tooltip.TextColor3 = Color3.fromRGB(255, 255, 255)
		tooltip.BorderSizePixel = 0
		tooltip.Visible = false
		tooltip.TextWrapped = true
		tooltip.ZIndex = 1000
		tooltip.Active = false
		tooltip.ClipsDescendants = false
		tooltip.Size = UDim2.new(0, 260, 0, 110)
		tooltip.Position = UDim2.new(0, 0, 0, 0)
		tooltip.TextScaled = true
		tooltip.Font = Enum.Font.Gotham
		tooltip.TextXAlignment = Enum.TextXAlignment.Left
		tooltip.TextYAlignment = Enum.TextYAlignment.Top
		-- Parent to the board/bench container (hex's parent) to avoid sibling occlusion
		local container = hex and hex.Parent
		if container and container:IsA("GuiObject") then
			tooltip.Parent = container
		else
			-- Fallback: keep under the unitVisual (may be occluded in some setups)
			tooltip.Parent = unitVisual
		end

		-- Helper to build tooltip text safely
		local function buildTooltipText(): string
			local name = unit.name or (typeof(unitVisual:GetAttribute("UnitName")) == "string" and unitVisual:GetAttribute("UnitName")) or "Unit"
			local cost = unit.cost or 0
			local tier = unit.tier or (typeof(unitVisual:GetAttribute("UnitTier")) == "number" and unitVisual:GetAttribute("UnitTier")) or 1

			-- Resolve stats with fallbacks
			local stats = unit.stats
			local traits = unit.traits
			if (not stats or not traits) and UnitDatabase and unit.id then
				local base = UnitDatabase.getUnitById(unit.id)
				if base then
					traits = traits or base.traits
					if not stats and base.baseStats then
						local ok2, calc = pcall(function()
							return UnitDatabase.calculateUnitStats(base.baseStats, tier)
						end)
						if ok2 then stats = calc end
					end
				end
			end

			local health = stats and stats.health or 0
			local attack = stats and stats.attack or 0
			local atkSpd = stats and stats.attackSpeed or 0
			local armor = stats and stats.armor or 0
			local traitText = "None"
			if traits and typeof(traits) == "table" then
				local parts = {}
				for i, t in ipairs(traits) do parts[i] = tostring(t) end
				traitText = table.concat(parts, ", ")
			end

			return string.format(
				"%s  (Cost: %d)\nTraits: %s\nHealth: %d    Atk Spd: %.2f\nDamage: %d    Armor: %d",
				name, cost, traitText, health, atkSpd, attack, armor
			)
		end

		-- Bind hover events
		unitVisual.MouseEnter:Connect(function()
			tooltip.Text = buildTooltipText()
			-- Position tooltip near the unit using absolute coordinates
			local parentObj: GuiObject = tooltip.Parent :: any
			if parentObj and parentObj.AbsoluteSize then
				local unitAbsPos = unitVisual.AbsolutePosition
				local unitAbsSize = unitVisual.AbsoluteSize
				local parentAbsPos = parentObj.AbsolutePosition
				local parentAbsSize = parentObj.AbsoluteSize

				local offsetX = 8
				local offsetY = 0
				local desiredX = (unitAbsPos.X - parentAbsPos.X) + unitAbsSize.X + offsetX
				local desiredY = (unitAbsPos.Y - parentAbsPos.Y) + offsetY

				-- Clamp within container bounds; if overflowing right, place to the left of the unit
				local width = tooltip.Size.X.Offset
				local height = tooltip.Size.Y.Offset
				if desiredX + width > parentAbsSize.X then
					desiredX = math.max(0, (unitAbsPos.X - parentAbsPos.X) - width - offsetX)
				end
				desiredY = math.clamp(desiredY, 0, math.max(0, parentAbsSize.Y - height))

				tooltip.Position = UDim2.fromOffset(desiredX, desiredY)
			end
			tooltip.Visible = true
		end)
		unitVisual.MouseLeave:Connect(function()
			tooltip.Visible = false
		end)

		-- Clean up tooltip if the unit visual is destroyed
		unitVisual.Destroying:Connect(function()
			if tooltip then
				tooltip:Destroy()
			end
		end)
	end
	
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
