local board = script.Parent:WaitForChild("BoardFrame")
local Constants = require(game.ReplicatedStorage.Shared.Constants)

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
		hex.Parent = board
	end
end

local bench = script.Parent:WaitForChild("BenchFrame")

-- Grid size (bench is 1 row, 6 columns)
local rows = 1
local cols = Constants.BENCH_CAPACITY -- e.g. 6

-- Hex size (as scale of parent container)
local hexWidth = 0.13
local hexHeight = 0.55
local aspectRatio = 0.92 -- depends on your hex image

-- Compute total bench width/height in scale
local benchWidth = cols * hexWidth
local benchHeight = hexHeight

local benchTitleHeightOffset = 0.2 -- TODO calculate

-- Compute margins to center in BenchFrame
local marginX = (1 - (benchWidth - 0.04)) / 2
local marginY = (1 - (benchHeight - benchTitleHeightOffset)) / 2

for col = 1, cols do
	local hex = Instance.new("ImageButton")
	hex.Size = UDim2.new(hexWidth, 0, hexHeight, 0)
	hex.BackgroundTransparency = 1
	hex.Image = "rbxassetid://135628423497794"
	hex.Name = string.format("BenchHex_%d", col)

	-- Aspect ratio lock
	local constraint = Instance.new("UIAspectRatioConstraint")
	constraint.AspectRatio = aspectRatio
	constraint.Parent = hex

	-- Position (no staggering needed)
	local posX = (col - 1) * hexWidth
	local posY = 0

	-- Apply centering margin
	posX = posX + marginX
	posY = posY + marginY

	hex.Position = UDim2.new(posX, 0, posY, 0)
	hex.Parent = bench
end
