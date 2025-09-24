--[[
	Constants.luau
	Game constants and configuration values
]]

local Constants = {}

-- Player constants
Constants.STARTING_GOLD = 10
Constants.STARTING_LEVEL = 1
Constants.MAX_LEVEL = 10
Constants.BASE_EXPERIENCE_PER_LEVEL = 100 -- Base experience for exponential calculation
Constants.LEVEL_UP_COST = 5
Constants.LEVEL_UP_EXPERIENCE = 10

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

-- Combat rewards constants
Constants.BASE_EXPERIENCE_REWARD = 10 -- Base experience per enemy level
Constants.BASE_GOLD_REWARD = 15 -- Base gold per enemy level
Constants.LOSER_EXPERIENCE_MULTIPLIER = 0.1 -- Loser gets 10% of base experience
Constants.LOSER_GOLD_MULTIPLIER = 0.1 -- Loser gets 10% of base gold

-- Unit tiering
Constants.UNITS_FOR_TIER_UP = 3

-- Battle constants
Constants.BATTLE_PREPARATION_TIME = 15 -- seconds
Constants.BATTLE_TIMEOUT = 300 -- seconds

-- Effects / VFX constants
-- Lifetime for impact effects spawned at projectile targets
Constants.PROJECTILE_IMPACT_EFFECT_DURATION = 0.3 -- seconds

-- Mapping of projectile name -> impact effect name under ReplicatedStorage.Effects
-- For now, only Bomb has an Explosion effect
Constants.PROJECTILE_IMPACT_EFFECTS = {
	Bomb = "Explosion",
}

-- Challenge constants
Constants.MIN_WAGER = 10
Constants.MAX_WAGER = 1000
Constants.CHALLENGE_TIMEOUT = 60 -- seconds

-- UI constants
Constants.UI_UPDATE_RATE = 0.1 -- seconds

-- Arena and Lobby constants
Constants.DEFAULT_ARENA_NAME = "Grass Arena" -- Players start with this arena; must exist in ReplicatedStorage.Arenas
Constants.GROUND_LEVEL = 3.16
Constants.ARENA_SPACING = 250
Constants.LOBBY_SPACING = 2000
Constants.MAX_PLAYERS_PER_LOBBY = 6
Constants.PLAYER_SPAWN_FORWARD_OFFSET = -70 

-- Board Detection constants
Constants.BOARD_DETECTION_ZONE_SIZE = Vector3.new(200, 10, 200) -- 100 unit radius detection zone
Constants.BOARD_DETECTION_ZONE_HEIGHT = 5 -- Height above ground
Constants.BOARD_DETECTION_ZONE_FORWARD_OFFSET = -25 -- Move back 25 units in Z direction
Constants.BOARD_DETECTION_ZONE_RADIUS = 105 -- Detection radius in units

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
	SHOW_PVP_FRAMES = "ShowPVPFrames",
	UPDATE_PVP_FRAMES = "UpdatePVPFrames",
	UPDATE_BOARD = "UpdateBoard",
	UPDATE_PLAYER_DATA = "UpdatePlayerData",
	UPDATE_SHOP = "UpdateShop",
	UPDATE_BENCH = "UpdateBench",
	UPDATE_TRAITS = "UpdateTraits", -- New: send active trait info to client
	SHOW_NOTIFICATION = "ShowNotification",
	RESET_PLAYER_DATA = "ResetPlayerData",
	SHOW_EDIT_ARENA_FRAME = "ShowEditArenaFrame",
	HIDE_EDIT_ARENA_FRAME = "HideEditArenaFrame",
	SWITCH_ARENA = "SwitchArena" -- Client requests switching arena theme
}

-- Trait definitions (shared for UI + server logic)
Constants.TRAITS = {
	Medieval = {
		id = "Medieval",
		requirement = 2,
		name = "Medieval",
		description = "Castle Wall: Adjacent allies to Medieval units gain a shield equal to 20% of their max health.",
		icon = "rbxassetid://0" -- placeholder icon id
	},
	Mystic = {
		id = "Mystic",
		requirement = 2,
		name = "Mystic",
		description = "Ethereal Strikes: Allies' attacks deal 3% of target max health as bonus magic damage.",
		icon = "rbxassetid://0"
	},
	Artillerist = {
		id = "Artillerist",
		requirement = 2,
		name = "Artillerist",
		description = "Bombs Away!: Artillerist projectiles deal 50% splash damage in 1 hex radius.",
		icon = "rbxassetid://0"
	},
	Juggernaut = {
		id = "Juggernaut",
		requirement = 2,
		name = "Juggernaut",
		description = "Durable: Juggernauts take 15% reduced damage.",
		icon = "rbxassetid://0"
	},
	Ranger = {
		id = "Ranger",
		requirement = 2,
		name = "Ranger",
		description = "Hail of Arrows: Attacks grant stacking 4% attack speed (max 40%).",
		icon = "rbxassetid://0"
	}
}

return Constants
