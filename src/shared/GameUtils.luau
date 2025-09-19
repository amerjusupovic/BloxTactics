--[[
	GameUtils.luau
	Shared utility functions for common game calculations
]]

local Constants = require(script.Parent.Constants)

local GameUtils = {}

-- Function to calculate experience required for a specific level
function GameUtils.getExperienceRequiredForLevel(level: number): number
	return Constants.BASE_EXPERIENCE_PER_LEVEL * (level ^ 2)
end

-- Function to calculate unit sell value (half the cost)
function GameUtils.calculateSellValue(unitCost: number): number
	return math.ceil(unitCost / 2)
end

-- Function to check if a player can level up
function GameUtils.canLevelUp(currentLevel: number, currentExperience: number): boolean
	if currentLevel >= Constants.MAX_LEVEL then
		return false
	end
	
	local experienceRequired = GameUtils.getExperienceRequiredForLevel(currentLevel)
	return currentExperience >= experienceRequired
end

-- Function to get experience progress percentage
function GameUtils.getExperienceProgress(currentLevel: number, currentExperience: number): number
	local experienceRequired = GameUtils.getExperienceRequiredForLevel(currentLevel)
	return math.min(1.0, currentExperience / experienceRequired)
end

-- Function to format gold amount with commas
function GameUtils.formatGold(amount: number): string
	local formatted = tostring(amount)
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
		if k == 0 then break end
	end
	return formatted
end

-- Function to validate level range
function GameUtils.isValidLevel(level: number): boolean
	return level >= Constants.STARTING_LEVEL and level <= Constants.MAX_LEVEL
end

-- Function to validate gold amount
function GameUtils.isValidGoldAmount(amount: number): boolean
	return amount >= 0
end

-- Function to clamp a value between min and max
function GameUtils.clamp(value: number, min: number, max: number): number
	return math.max(min, math.min(max, value))
end

return GameUtils
