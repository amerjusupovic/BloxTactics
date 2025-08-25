--[[
	Hello.luau
	Shared utility functions
]]

local Hello = {}

-- Function to get a greeting message
function Hello.getGreeting(playerName: string): string
	return "Hello, " .. playerName .. "! Welcome to BloxTactics!"
end

-- Function to format gold amount
function Hello.formatGold(amount: number): string
	return tostring(amount) .. " Gold"
end

-- Function to format unit stats
function Hello.formatUnitStats(stats: {health: number, attack: number, attackSpeed: number, range: number, armor: number, magicResist: number}): string
	return "HP: " .. stats.health .. " | ATK: " .. stats.attack .. " | SPD: " .. stats.attackSpeed .. " | RNG: " .. stats.range .. " | ARM: " .. stats.armor .. " | MR: " .. stats.magicResist
end

-- Function to validate Vector2 position
function Hello.isValidPosition(position: Vector2, maxX: number, maxY: number): boolean
	return position.X >= 0 and position.X < maxX and position.Y >= 0 and position.Y < maxY
end

return Hello