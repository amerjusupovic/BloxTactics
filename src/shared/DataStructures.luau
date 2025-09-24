--[[
	DataStructures.luau
	Core data structures for BloxTactics
]]

local DataStructures = {}

-- Player data structure
export type PlayerData = {
	userId: number,
	username: string,
	gold: number,
	level: number,
	experience: number,
	units: {[string]: Unit},
	items: {[string]: Item},
	boardState: BoardState,
	benchState: BenchState,
	shopState: ShopState?,
	streak: number, -- win/loss streak
	lastUpdated: number,
	selectedArenaName: string? -- Name of currently selected arena (e.g., "Grass Arena")
}

-- Unit data structure
export type Unit = {
	id: string,
	name: string,
	cost: number,
	tier: number, -- 1, 2, or 3 stars
	stats: UnitStats,
	abilities: {[string]: Ability},
	position: Vector2?, -- position on board/bench
	items: {[string]: Item},
	imageAssetId: string,
	starIndicator: ("none" | "silver" | "gold")?, -- Star indicator for shop units
	soldOut: boolean?, -- Whether the unit is sold out in shop
	projectileName: string?, -- Name of projectile model in ReplicatedStorage.Projectiles (nil for melee)
	traits: {string}?, -- Trait tags for the unit (e.g., {"Medieval","Juggernaut"})
	-- Runtime (battle-only) ephemeral fields (not persisted):
	shield: number?, -- Remaining shield (from Medieval)
	rangerStacks: number?, -- Current Ranger attack speed stacks
	damageReduction: number? -- Percent reduction (0.15 for Juggernaut active)
}

-- Unit stats
export type UnitStats = {
	health: number,
	attack: number,
	attackSpeed: number,
	range: number,
	armor: number,
	magicResist: number
}

-- Ability data structure
export type Ability = {
	name: string,
	description: string,
	cooldown: number,
	currentCooldown: number,
	effect: (unit: Unit, target: Unit?) -> ()
}

-- Item data structure
export type Item = {
	id: string,
	name: string,
	description: string,
	cost: number,
	effects: {[string]: any},
	requirements: {[string]: any}?
}

-- Board state
export type BoardState = {
	grid: {[Vector2]: Unit?},
	maxUnits: number,
	currentUnits: number
}

-- Bench state
export type BenchState = {
	units: {[string]: Unit},
	maxCapacity: number,
	currentCapacity: number
}

-- Shop data
export type ShopData = {
	units: {Unit},
	refreshCost: number,
	lastRefresh: number
}

-- Shop state (for persistence)
export type ShopState = {
	units: {Unit},
	lastRefresh: number
}

-- Challenge data
export type Challenge = {
	id: string,
	challenger: number, -- userId
	challenged: number, -- userId
	wager: number,
	status: "pending" | "accepted" | "rejected" | "completed",
	createdAt: number
}

-- Battle data
export type Battle = {
	id: string,
	player1: number,
	player2: number,
	board1: BoardState,
	board2: BoardState,
	status: "preparing" | "in_progress" | "completed",
	winner: number?,
	wager: number,
	startTime: number?,
	endTime: number?
}

return DataStructures
