--[[
	Constants.luau
	Game constants and configuration values
]]

local Constants = {}

-- Player constants
Constants.STARTING_GOLD = 100
Constants.STARTING_LEVEL = 1
Constants.MAX_LEVEL = 10
Constants.BASE_EXPERIENCE_PER_LEVEL = 100 -- Base experience for exponential calculation
Constants.EXPERIENCE_PER_LEVEL = 100 -- Legacy support, will be calculated dynamically
Constants.LEVEL_UP_COST = 10
Constants.LEVEL_UP_EXPERIENCE = 20

-- Board constants
Constants.BOARD_WIDTH = 7
Constants.BOARD_HEIGHT = 4
Constants.MAX_BOARD_UNITS = 10

-- Bench constants
Constants.BENCH_CAPACITY = 6

-- Shop constants
Constants.SHOP_SIZE = 5
Constants.SHOP_REFRESH_COST = 2
Constants.SHOP_REFRESH_COOLDOWN = 1 -- seconds

-- Gold constants
Constants.INTEREST_RATE = 0.1 -- 10% interest per round
Constants.MAX_INTEREST = 5 -- maximum gold from interest
Constants.STREAK_BONUS = 1 -- extra gold per streak

-- Combat rewards constants
Constants.BASE_EXPERIENCE_REWARD = 10 -- Base experience per enemy level
Constants.BASE_GOLD_REWARD = 8 -- Base gold per enemy level
Constants.LOSER_EXPERIENCE_MULTIPLIER = 0.1 -- Loser gets 10% of base experience
Constants.LOSER_GOLD_MULTIPLIER = 0.1 -- Loser gets 10% of base gold

-- Unit tiering
Constants.UNITS_FOR_TIER_UP = 3

-- Battle constants
Constants.BATTLE_PREPARATION_TIME = 15 -- seconds
Constants.BATTLE_TIMEOUT = 300 -- seconds

-- Challenge constants
Constants.MIN_WAGER = 10
Constants.MAX_WAGER = 1000
Constants.CHALLENGE_TIMEOUT = 60 -- seconds

-- UI constants
Constants.UI_UPDATE_RATE = 0.1 -- seconds

-- Arena and Lobby constants
Constants.GROUND_LEVEL = 0
Constants.ARENA_SPACING = 300
Constants.LOBBY_SPACING = 2000
Constants.MAX_PLAYERS_PER_LOBBY = 6

-- Network constants
Constants.REMOTE_EVENT_NAMES = {
	PURCHASE_UNIT = "PurchaseUnit",
	PLACE_UNIT = "PlaceUnit",
	MOVE_UNIT = "MoveUnit",
	SELL_UNIT = "SellUnit",
	REFRESH_SHOP = "RefreshShop",
	LEVEL_UP = "LevelUp",
	CHALLENGE_PLAYER = "ChallengePlayer",
	ACCEPT_CHALLENGE = "AcceptChallenge",
	REJECT_CHALLENGE = "RejectChallenge",
	START_BATTLE = "StartBattle",
	START_BATTLE_PREPARATION = "StartBattlePreparation",
	SHOW_CHALLENGE_REQUEST = "ShowChallengeRequest",
	SHOW_CHALLENGE_PROMPT = "ShowChallengePrompt",
	HIDE_CHALLENGE_PROMPT = "HideChallengePrompt",
	UPDATE_BOARD = "UpdateBoard",
	UPDATE_PLAYER_DATA = "UpdatePlayerData",
	UPDATE_SHOP = "UpdateShop",
	UPDATE_BENCH = "UpdateBench",
	SHOW_NOTIFICATION = "ShowNotification",
	RESET_PLAYER_DATA = "ResetPlayerData"
}

return Constants
