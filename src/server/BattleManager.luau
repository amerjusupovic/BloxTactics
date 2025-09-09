--[[
	BattleManager.luau
	Manages TFT-style battles between two teams of units
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local DataStructures = require(ReplicatedStorage.Shared.DataStructures)
local UnitDatabase = require(ReplicatedStorage.Shared.UnitDatabase)
local RemoteEvents = require(script.Parent.RemoteEvents)

local BattleManager = {}

-- Battle data structure
local BattleData = {
	id = "",
	player1Id = 0,
	player2Id = 0,
	arena = nil,
	team1 = {}, -- Array of BattleUnit objects
	team2 = {}, -- Array of BattleUnit objects
	status = "preparing", -- "preparing", "in_progress", "completed"
	winner = nil,
	startTime = 0,
	endTime = 0,
	battleLoop = nil,
	onBattleEnd = nil -- Callback function for when battle ends
}

-- Battle unit data structure (extends Unit with battle-specific data)
local BattleUnit = {
	unit = nil, -- Original unit data
	model = nil, -- The actual model in the world
	health = 0,
	maxHealth = 0,
	position = Vector3.new(0, 0, 0),
	target = nil, -- Current target BattleUnit
	lastAttackTime = 0,
	team = 1, -- 1 or 2
	isAlive = true,
	originalPosition = Vector3.new(0, 0, 0)
}

-- Active battles storage
local activeBattles = {} -- {battleId = BattleData}

-- Battle constants
local BATTLE_CONSTANTS = {
	UNIT_MOVEMENT_SPEED = 8, -- studs per second (slower movement)
	ATTACK_RANGE_BUFFER = 2, -- Extra range buffer for melee units
	BATTLE_TIMEOUT = 300, -- 5 minutes max battle time
	RESET_DELAY = 5, -- 5 seconds before resetting units
	HEX_SIZE = 4, -- Size of each hex in studs
	UNIT_HEIGHT_OFFSET = 2, -- Height offset for units above hexes
	ATTACK_SPEED_MULTIPLIER = 0.5 -- Slow down attack speed by 50%
}

-- Generate unique battle ID
local function generateBattleId(): string
	return "battle_" .. os.time() .. "_" .. math.random(1000, 9999)
end


-- Create a battle unit from a model and unit data
local function createBattleUnit(model: Model, unit: DataStructures.Unit, team: number): BattleUnit
	-- Get health from Humanoid if available, otherwise use unit stats
	local humanoid = model:FindFirstChild("Humanoid")
	local currentHealth = humanoid and humanoid.Health or unit.stats.health
	local maxHealth = humanoid and humanoid.MaxHealth or unit.stats.health
	
	local battleUnit = {
		unit = unit,
		model = model,
		health = currentHealth,
		maxHealth = maxHealth,
		position = model:GetPivot().Position,
		target = nil,
		lastAttackTime = 0,
		team = team,
		isAlive = true,
		originalPosition = model:GetPivot().Position
	}
	
	-- Store battle data in the model
	model:SetAttribute("BattleUnit", true)
	model:SetAttribute("Team", team)
	model:SetAttribute("Health", battleUnit.health)
	model:SetAttribute("MaxHealth", battleUnit.maxHealth)
	model:SetAttribute("IsAlive", true)
	
	return battleUnit
end

-- Get all units from a board (either player board or enemy board)
local function getUnitsFromBoard(board: Instance, team: number): {BattleUnit}
	local battleUnits = {}
	
	print("DEBUG: Searching for units in board:", board.Name, "Team:", team)
	
	-- Search through all hexes in the board
	for _, hex in pairs(board:GetChildren()) do
		if hex.Name:find("Hex_") then
			print("DEBUG: Checking hex:", hex.Name)
			for _, child in pairs(hex:GetChildren()) do
				-- For team 1 (player), look for regular units (not enemy units)
				-- For team 2 (enemy), look for enemy units
				local isCorrectUnitType = false
				if team == 1 then
					-- Player units: look for units that are NOT enemy units
					isCorrectUnitType = child:IsA("Model") and child.Name:find("_") and not child.Name:find("EnemyUnit_")
				elseif team == 2 then
					-- Enemy units: look for enemy units specifically
					isCorrectUnitType = child:IsA("Model") and child.Name:find("EnemyUnit_")
				end
				
				if isCorrectUnitType then
					print("DEBUG: Found unit model:", child.Name)
					-- Get unit data from attributes
					local unitId = child:GetAttribute("UnitId")
					local unitName = child:GetAttribute("UnitName")
					local unitTier = child:GetAttribute("UnitTier")
					
					print("DEBUG: Unit attributes - ID:", unitId, "Name:", unitName, "Tier:", unitTier)
					
					if unitId and unitName and unitTier then
						-- Create unit data structure
						local unitData = UnitDatabase.createUnit(unitId, unitTier)
						if unitData then
							print("DEBUG: Created unit data for:", unitName)
							local battleUnit = createBattleUnit(child, unitData, team)
							table.insert(battleUnits, battleUnit)
							print("DEBUG: Added battle unit to team", team)
						else
							warn("DEBUG: Failed to create unit data for:", unitName)
						end
					else
						warn("DEBUG: Missing unit attributes for:", child.Name)
					end
				end
			end
		end
	end
	
	print("DEBUG: Found", #battleUnits, "units for team", team)
	return battleUnits
end

-- Calculate distance between two positions
local function calculateDistance(pos1: Vector3, pos2: Vector3): number
	return (pos1 - pos2).Magnitude
end

-- Find the closest enemy unit to a given unit
local function findClosestEnemy(unit: BattleUnit, enemyTeam: {BattleUnit}): BattleUnit?
	local closestEnemy = nil
	local closestDistance = math.huge
	
	for _, enemy in ipairs(enemyTeam) do
		if enemy.isAlive then
			local distance = calculateDistance(unit.position, enemy.position)
			if distance < closestDistance then
				closestDistance = distance
				closestEnemy = enemy
			end
		end
	end
	
	return closestEnemy
end

-- Check if a unit is in attack range of its target
local function isInAttackRange(unit: BattleUnit, target: BattleUnit): boolean
	local distance = calculateDistance(unit.position, target.position)
	local attackRange = unit.unit.stats.range * BATTLE_CONSTANTS.HEX_SIZE + BATTLE_CONSTANTS.ATTACK_RANGE_BUFFER
	return distance <= attackRange
end

-- Check if a hex is occupied by any unit
local function isHexOccupied(hex: Instance, excludeUnit: Model?): boolean
	for _, child in pairs(hex:GetChildren()) do
		if child:IsA("Model") and child.Name:find("_") and child ~= excludeUnit then
			return true
		end
	end
	return false
end

-- Find the closest unoccupied hex to a target position
local function findClosestUnoccupiedHex(arena: Instance, targetPosition: Vector3, excludeUnit: Model?): Instance?
	local closestHex = nil
	local closestDistance = math.huge
	
	for _, child in pairs(arena:GetChildren()) do
		if child.Name:find("Hex_") and not isHexOccupied(child, excludeUnit) then
			local distance = (child.Position - targetPosition).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestHex = child
			end
		end
	end
	
	return closestHex
end

-- Find the closest hex to a target position (for fallback)
local function findClosestHex(arena: Instance, targetPosition: Vector3): Instance?
	local closestHex = nil
	local closestDistance = math.huge
	
	for _, child in pairs(arena:GetChildren()) do
		if child.Name:find("Hex_") then
			local distance = (child.Position - targetPosition).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestHex = child
			end
		end
	end
	
	return closestHex
end

-- Move unit towards target by moving to the next hex
local function moveUnitTowardsTarget(unit: BattleUnit, target: BattleUnit, arena: Instance)
	if not unit.model or not target.model then
		return
	end
	
	-- Find the closest unoccupied hex to the target
	local targetHex = findClosestUnoccupiedHex(arena, target.position, unit.model)
	if not targetHex then
		-- Fallback: find any closest hex if no unoccupied ones
		targetHex = findClosestHex(arena, target.position)
		if not targetHex then
			return
		end
	end
	
	-- Find the closest hex to the current unit position
	local currentHex = findClosestHex(arena, unit.position)
	if not currentHex then
		return
	end
	
	-- If we're already at the target hex, don't move
	if currentHex == targetHex then
		return
	end
	
	-- Move to the target hex
	local newPosition = targetHex.Position
	unit.position = newPosition
	
	-- Move the model to the new position
	local targetCFrame = CFrame.new(newPosition + Vector3.new(0, BATTLE_CONSTANTS.UNIT_HEIGHT_OFFSET, 0))
	unit.model:PivotTo(targetCFrame)
	
	print("Unit " .. unit.unit.name .. " moved to hex " .. targetHex.Name)
end

-- Attack target unit
local function attackTarget(unit: BattleUnit, target: BattleUnit)
	if not unit.model or not target.model then
		return
	end
	
	-- Calculate damage
	local damage = unit.unit.stats.attack
	local armor = target.unit.stats.armor
	local actualDamage = math.max(1, damage - armor)
	
	-- Find the Humanoid in the target model
	local humanoid = target.model:FindFirstChild("Humanoid")
	if humanoid then
		-- Use Roblox's built-in damage system
		humanoid:TakeDamage(actualDamage)
		
		-- Update our internal health tracking
		target.health = humanoid.Health
		
		-- Check if target died
		if humanoid.Health <= 0 then
			target.isAlive = false
			target.model:SetAttribute("IsAlive", false)
			
			-- Make the model semi-transparent and gray
			for _, part in pairs(target.model:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = 0.7
					part.Color = Color3.new(0.5, 0.5, 0.5) -- Gray
				end
			end
			
			print("Unit " .. target.unit.name .. " died!")
		end
	else
		warn("No Humanoid found in target unit: " .. target.unit.name)
	end
	
	-- Visual damage feedback - make the model flash red briefly
	for _, part in pairs(target.model:GetDescendants()) do
		if part:IsA("BasePart") then
			-- Store original color
			local originalColor = part.Color
			-- Flash red
			part.Color = Color3.new(1, 0, 0) -- Red
			-- Reset color after a brief delay
			spawn(function()
				wait(0.2)
				part.Color = originalColor
			end)
		end
	end
	
	-- Update last attack time
	unit.lastAttackTime = tick()
	
	print("Unit " .. unit.unit.name .. " attacked " .. target.unit.name .. " for " .. actualDamage .. " damage")
end

-- Check if a team is defeated (all units dead)
local function isTeamDefeated(team: {BattleUnit}): boolean
	for _, unit in ipairs(team) do
		if unit.isAlive then
			return false
		end
	end
	return true
end

-- Reset units after battle - remove enemy units and reset original units
local function resetUnitsAfterBattle(battleData: BattleData)
	print("Resetting units after battle...")
	
	-- Team 1 units (challenged player's original units) - reset to original positions
	for _, unit in ipairs(battleData.team1) do
		if unit.model then
			-- Restore health and visibility
			unit.health = unit.maxHealth
			unit.isAlive = true
			unit.model:SetAttribute("Health", unit.health)
			unit.model:SetAttribute("IsAlive", true)
			
			-- Reset Humanoid health if available
			local humanoid = unit.model:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.Health = humanoid.MaxHealth
			end
			
			-- Reset transparency
			for _, part in pairs(unit.model:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = 0
				end
			end
			
			-- Move back to original position
			local targetCFrame = CFrame.new(unit.originalPosition + Vector3.new(0, BATTLE_CONSTANTS.UNIT_HEIGHT_OFFSET, 0))
			unit.model:SetPrimaryPartCFrame(targetCFrame)
			unit.position = unit.originalPosition
		end
	end
	
	-- Team 2 units (challenger's enemy units) - completely remove from board
	for _, unit in ipairs(battleData.team2) do
		if unit.model then
			print("Removing enemy unit: " .. unit.unit.name)
			unit.model:Destroy()
		end
	end
	
	print("Battle reset complete - enemy units removed, original units restored")
end

-- Main battle loop
local function runBattleLoop(battleData: BattleData)
	local connection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		-- Check if battle should end
		if battleData.status ~= "in_progress" then
			connection:Disconnect()
			return
		end
		
		-- Check for timeout
		if tick() - battleData.startTime > BATTLE_CONSTANTS.BATTLE_TIMEOUT then
			print("Battle timed out!")
			BattleManager.endBattle(battleData.id, nil) -- Draw
			connection:Disconnect()
			return
		end
		
		-- Update each unit
		for _, unit in ipairs(battleData.team1) do
			if unit.isAlive then
				-- Find target if we don't have one
				if not unit.target or not unit.target.isAlive then
					unit.target = findClosestEnemy(unit, battleData.team2)
				end
				
				if unit.target then
					-- Check if we're in attack range
					if isInAttackRange(unit, unit.target) then
						-- Check if we can attack (based on attack speed with multiplier)
						local timeSinceLastAttack = tick() - unit.lastAttackTime
						local attackCooldown = (1 / unit.unit.stats.attackSpeed) / BATTLE_CONSTANTS.ATTACK_SPEED_MULTIPLIER
						
						if timeSinceLastAttack >= attackCooldown then
							attackTarget(unit, unit.target)
						end
					else
						-- Move towards target (only move once per second, not continuously)
						if tick() - unit.lastAttackTime > 1 then -- Only move every second
							moveUnitTowardsTarget(unit, unit.target, battleData.arena)
							unit.lastAttackTime = tick() -- Use this to track movement timing
						end
					end
				end
			end
		end
		
		-- Update team 2 units
		for _, unit in ipairs(battleData.team2) do
			if unit.isAlive then
				-- Find target if we don't have one
				if not unit.target or not unit.target.isAlive then
					unit.target = findClosestEnemy(unit, battleData.team1)
				end
				
				if unit.target then
					-- Check if we're in attack range
					if isInAttackRange(unit, unit.target) then
						-- Check if we can attack (based on attack speed with multiplier)
						local timeSinceLastAttack = tick() - unit.lastAttackTime
						local attackCooldown = (1 / unit.unit.stats.attackSpeed) / BATTLE_CONSTANTS.ATTACK_SPEED_MULTIPLIER
						
						if timeSinceLastAttack >= attackCooldown then
							attackTarget(unit, unit.target)
						end
					else
						-- Move towards target (only move once per second, not continuously)
						if tick() - unit.lastAttackTime > 1 then -- Only move every second
							moveUnitTowardsTarget(unit, unit.target, battleData.arena)
							unit.lastAttackTime = tick() -- Use this to track movement timing
						end
					end
				end
			end
		end
		
		-- Check for battle end conditions
		local team1Defeated = isTeamDefeated(battleData.team1)
		local team2Defeated = isTeamDefeated(battleData.team2)
		
		if team1Defeated or team2Defeated then
			local winner = nil
			if team1Defeated and not team2Defeated then
				winner = battleData.player2Id
			elseif team2Defeated and not team1Defeated then
				winner = battleData.player1Id
			end
			
			BattleManager.endBattle(battleData.id, winner)
			connection:Disconnect()
		end
	end)
	
	battleData.battleLoop = connection
end

-- Start a battle between two players
function BattleManager.startBattle(challengeId: string, player1Id: number, player2Id: number, arena: Instance, onBattleEndCallback: ((winnerId: number?) -> ())?): string?
	print("Starting battle for challenge: " .. challengeId)
	
	-- Find the arena boards
	local playerBoard = nil
	local enemyBoard = arena:FindFirstChild("Enemy Unit Board")
	
	print("DEBUG: Arena name:", arena.Name)
	print("DEBUG: Enemy board found:", enemyBoard and enemyBoard.Name or "nil")
	
	-- For the player board, we need to search the arena itself since player units are placed directly in hexes
	-- The "BoardArea" is just a container, but the actual units are in the hexes within the arena
	playerBoard = arena -- Use the arena itself as the player board since units are in hexes directly
	
	print("DEBUG: Using arena as player board:", arena.Name)
	
	if not playerBoard or not enemyBoard then
		warn("Could not find both boards in arena for battle")
		warn("Player board:", playerBoard and playerBoard.Name or "nil")
		warn("Enemy board:", enemyBoard and enemyBoard.Name or "nil")
		return nil
	end
	
	-- Create battle data
	local battleId = generateBattleId()
	local battleData = {
		id = battleId,
		player1Id = player1Id,
		player2Id = player2Id,
		arena = arena,
		team1 = getUnitsFromBoard(playerBoard, 1),
		team2 = getUnitsFromBoard(enemyBoard, 2),
		status = "preparing",
		winner = nil,
		startTime = 0,
		endTime = 0,
		battleLoop = nil,
		onBattleEnd = onBattleEndCallback
	}
	
	-- Store battle
	activeBattles[battleId] = battleData
	
	print("Battle created with " .. #battleData.team1 .. " units on team 1 and " .. #battleData.team2 .. " units on team 2")
	
	-- Start the battle
	battleData.status = "in_progress"
	battleData.startTime = tick()
	
	-- Start the battle loop
	runBattleLoop(battleData)
	
	print("Battle started: " .. battleId)
	return battleId
end

-- End a battle
function BattleManager.endBattle(battleId: string, winnerId: number?)
	local battleData = activeBattles[battleId]
	if not battleData then
		warn("Battle not found: " .. battleId)
		return false
	end
	
	-- Stop the battle loop
	if battleData.battleLoop then
		battleData.battleLoop:Disconnect()
		battleData.battleLoop = nil
	end
	
	-- Update battle status
	battleData.status = "completed"
	battleData.winner = winnerId
	battleData.endTime = tick()
	
	-- Call the battle end callback if provided
	if battleData.onBattleEnd then
		battleData.onBattleEnd(winnerId)
	end
	
	-- Wait before resetting units
	wait(BATTLE_CONSTANTS.RESET_DELAY)
	resetUnitsAfterBattle(battleData)
	
	-- Clean up battle
	activeBattles[battleId] = nil
	
	print("Battle ended: " .. battleId .. " - Winner: " .. (winnerId or "Draw"))
	return true
end

-- Get battle data
function BattleManager.getBattle(battleId: string): BattleData?
	return activeBattles[battleId]
end

-- Check if a player is in a battle
function BattleManager.isPlayerInBattle(playerId: number): boolean
	for _, battleData in pairs(activeBattles) do
		if battleData.player1Id == playerId or battleData.player2Id == playerId then
			return true
		end
	end
	return false
end

return BattleManager
