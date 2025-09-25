--[[
	CombatRewards.luau
	Combat rewards calculation system for experience and gold gains
]]

local Constants = require(script.Parent.Constants)

local CombatRewards = {}

-- Base rewards for winning a battle (per enemy level)
local BASE_EXPERIENCE_REWARD = Constants.BASE_EXPERIENCE_REWARD
local BASE_GOLD_REWARD = Constants.BASE_GOLD_REWARD

-- Level difference multipliers
local LEVEL_DIFFERENCE_MULTIPLIERS = {
	-- If opponent is higher level, you get bonus rewards
	[1] = 1.2,  -- 1 level higher = 20% bonus
	[2] = 1.4,  -- 2 levels higher = 40% bonus
	[3] = 1.6,  -- 3 levels higher = 60% bonus
	[4] = 1.8,  -- 4 levels higher = 80% bonus
	[5] = 2.0,  -- 5+ levels higher = 100% bonus
}

-- Streak bonus multipliers
local STREAK_BONUS_MULTIPLIERS = {
	[0] = 1.0,  -- No streak
	[1] = 1.1,  -- 1 win streak = 10% bonus
	[2] = 1.2,  -- 2 win streak = 20% bonus
	[3] = 1.3,  -- 3 win streak = 30% bonus
	[4] = 1.4,  -- 4 win streak = 40% bonus
	[5] = 1.5,  -- 5+ win streak = 50% bonus
}

-- Function to calculate experience reward for winning a battle
function CombatRewards.calculateExperienceReward(winnerLevel: number, loserLevel: number, winnerStreak: number): number
	-- Start with base experience per enemy level
	local experienceReward = BASE_EXPERIENCE_REWARD * loserLevel
	
	-- Apply level difference multiplier
	local levelDifference = loserLevel - winnerLevel
	if levelDifference > 0 then
		-- Opponent was higher level, apply bonus
		local multiplier = LEVEL_DIFFERENCE_MULTIPLIERS[math.min(levelDifference, 5)] or 2.0
		experienceReward = experienceReward * multiplier
	elseif levelDifference < 0 then
		-- Opponent was lower level, apply penalty
		local penalty = math.max(0.5, 1.0 + (levelDifference * 0.1)) -- Minimum 50% of base reward
		experienceReward = experienceReward * penalty
	end
	
	-- Apply streak bonus
	local streakMultiplier = STREAK_BONUS_MULTIPLIERS[math.min(winnerStreak, 5)] or 1.5
	experienceReward = experienceReward * streakMultiplier
	
	-- Round to nearest integer
	return math.floor(experienceReward + 0.5)
end

-- Function to calculate gold reward for winning a battle
function CombatRewards.calculateGoldReward(winnerLevel: number, loserLevel: number, winnerStreak: number): number
	-- Start with base gold per enemy level
	local goldReward = BASE_GOLD_REWARD * loserLevel
	
	-- Apply level difference multiplier
	local levelDifference = loserLevel - winnerLevel
	if levelDifference > 0 then
		-- Opponent was higher level, apply bonus
		local multiplier = LEVEL_DIFFERENCE_MULTIPLIERS[math.min(levelDifference, 5)] or 2.0
		goldReward = goldReward * multiplier
	elseif levelDifference < 0 then
		-- Opponent was lower level, apply penalty
		local penalty = math.max(0.5, 1.0 + (levelDifference * 0.1)) -- Minimum 50% of base reward
		goldReward = goldReward * penalty
	end
	
	-- Apply streak bonus
	local streakMultiplier = STREAK_BONUS_MULTIPLIERS[math.min(winnerStreak, 5)] or 1.5
	goldReward = goldReward * streakMultiplier
	
	-- Round to nearest integer
	return math.floor(goldReward + 0.5)
end

-- Function to calculate rewards for both winner and loser
function CombatRewards.calculateBattleRewards(winnerLevel: number, loserLevel: number, winnerStreak: number): {
	winner: {experience: number, gold: number},
	loser: {experience: number, gold: number}
}
	local winnerExperience = CombatRewards.calculateExperienceReward(winnerLevel, loserLevel, winnerStreak)
	local winnerGold = CombatRewards.calculateGoldReward(winnerLevel, loserLevel, winnerStreak)
	
	-- Loser gets minimal rewards (consolation prize)
	local loserExperience = math.floor(BASE_EXPERIENCE_REWARD * loserLevel * Constants.LOSER_EXPERIENCE_MULTIPLIER)
	local loserGold = math.floor(BASE_GOLD_REWARD * loserLevel * Constants.LOSER_GOLD_MULTIPLIER)
	
	return {
		winner = {
			experience = winnerExperience,
			gold = winnerGold
		},
		loser = {
			experience = loserExperience,
			gold = loserGold
		}
	}
end

-- Function to get reward breakdown for UI display
function CombatRewards.getRewardBreakdown(winnerLevel: number, loserLevel: number, winnerStreak: number): {
	baseExperience: number,
	baseGold: number,
	levelDifference: number,
	levelMultiplier: number,
	streakMultiplier: number,
	finalExperience: number,
	finalGold: number
}
	local levelDifference = loserLevel - winnerLevel
	local levelMultiplier = 1.0
	local streakMultiplier = STREAK_BONUS_MULTIPLIERS[math.min(winnerStreak, 5)] or 1.5
	
	if levelDifference > 0 then
		levelMultiplier = LEVEL_DIFFERENCE_MULTIPLIERS[math.min(levelDifference, 5)] or 2.0
	elseif levelDifference < 0 then
		levelMultiplier = math.max(0.5, 1.0 + (levelDifference * 0.2))
	end
	
	local finalExperience = CombatRewards.calculateExperienceReward(winnerLevel, loserLevel, winnerStreak)
	local finalGold = CombatRewards.calculateGoldReward(winnerLevel, loserLevel, winnerStreak)
	
	return {
		baseExperience = BASE_EXPERIENCE_REWARD * loserLevel,
		baseGold = BASE_GOLD_REWARD * loserLevel,
		levelDifference = levelDifference,
		levelMultiplier = levelMultiplier,
		streakMultiplier = streakMultiplier,
		finalExperience = finalExperience,
		finalGold = finalGold
	}
end

-- Function to apply rewards to players (for use in battle resolution)
function CombatRewards.applyBattleRewards(winnerUserId: number, loserUserId: number, winnerLevel: number, loserLevel: number, winnerStreak: number, playerDataManager: any): {
	winner: {experience: number, gold: number},
	loser: {experience: number, gold: number}
}
	local rewards = CombatRewards.calculateBattleRewards(winnerLevel, loserLevel, winnerStreak)
	
	-- Apply rewards to winner
	playerDataManager.addExperience(winnerUserId, rewards.winner.experience)
	playerDataManager.addGold(winnerUserId, rewards.winner.gold)
	
	-- Apply rewards to loser
	playerDataManager.addExperience(loserUserId, rewards.loser.experience)
	playerDataManager.addGold(loserUserId, rewards.loser.gold)
	
	return rewards
end

return CombatRewards
