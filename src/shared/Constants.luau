--[[
	Constants.luau
	Game constants and configuration values
]]

local Constants = {}

-- Player constants
Constants.STARTING_GOLD = 100
Constants.STARTING_LEVEL = 1
Constants.MAX_LEVEL = 10
Constants.EXPERIENCE_PER_LEVEL = 100
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

-- Unit tiering
Constants.UNITS_FOR_TIER_UP = 3

-- Battle constants
Constants.BATTLE_PREPARATION_TIME = 30 -- seconds
Constants.BATTLE_TIMEOUT = 300 -- seconds

-- Challenge constants
Constants.MIN_WAGER = 10
Constants.MAX_WAGER = 1000
Constants.CHALLENGE_TIMEOUT = 60 -- seconds

-- UI constants
Constants.UI_UPDATE_RATE = 0.1 -- seconds

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
	UPDATE_BOARD = "UpdateBoard",
	UPDATE_PLAYER_DATA = "UpdatePlayerData",
	UPDATE_SHOP = "UpdateShop",
	UPDATE_BENCH = "UpdateBench",
	SHOW_NOTIFICATION = "ShowNotification",
	RESET_PLAYER_DATA = "ResetPlayerData"
}

return Constants
