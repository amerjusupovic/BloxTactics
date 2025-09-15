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
	originalPosition = Vector3.new(0, 0, 0),
	originalParent = nil, -- Original parent Instance (expected to be a Hex_ part)
	originalHexName = nil -- Name of the original hex parent (easier re-parenting on reset)
}

-- Active battles storage
local activeBattles = {} -- {battleId = BattleData}

-- Hex reservation system to prevent multiple units from moving to the same hex
local reservedHexes = {} -- {hexName = unitId}

-- Battle constants
local BATTLE_CONSTANTS = {
	UNIT_MOVEMENT_SPEED = 4, -- studs per second (slower movement)
	ATTACK_RANGE_BUFFER = 4, -- Extra range buffer for range tolerance
	BATTLE_TIMEOUT = 300, -- 5 minutes max battle time
	RESET_DELAY = 5, -- 5 seconds before resetting units
	HEX_SIZE = 20, -- Size of each hex in studs
	UNIT_HEIGHT_OFFSET = 2, -- Height offset for units above hexes
	ATTACK_SPEED_MULTIPLIER = 0.5, -- Slow down attack speed by 50%
	MOVEMENT_COOLDOWN = 1, -- Seconds between hex movements (faster to allow melee to close)
	HEX_OCCUPANCY_CHECK_DISTANCE = 3, -- Distance to check for hex occupancy
	MOVEMENT_TWEEN_TIME = 3.0 -- Time for smooth movement between hexes
}

-- Toggle to enable very verbose per-frame attack/range logs
local ENABLE_VERBOSE_ATTACK_DEBUG = false

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
	
	-- Generate a unique battle unit id to track reservations and identity during battle
	local uniqueId = (unit.id or "unit") .. "_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))

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
		originalPosition = model:GetPivot().Position,
		originalParent = model.Parent,
		originalHexName = (model.Parent and typeof(model.Parent.Name) == "string" and model.Parent.Name:find("Hex_") and model.Parent.Name) or nil,
		battleUnitId = uniqueId
	}
	
	-- Store battle data in the model
	model:SetAttribute("BattleUnit", true)
	model:SetAttribute("Team", team)
	model:SetAttribute("Health", battleUnit.health)
	model:SetAttribute("MaxHealth", battleUnit.maxHealth)
	model:SetAttribute("IsAlive", true)
	model:SetAttribute("BattleUnitId", uniqueId)
	
	return battleUnit
end

-- Get all units from a board (either player board or enemy board)
local function getUnitsFromBoard(board: Instance, team: number): {BattleUnit}
	local battleUnits = {}
	print("DEBUG: Searching for units in board:", board.Name, "Team:", team)

	for _, hex in pairs(board:GetChildren()) do
		if hex.Name:find("Hex_") then
			print("DEBUG: Checking hex:", hex.Name)
			for _, child in pairs(hex:GetChildren()) do
				if child:IsA("Model") then
					local unitId = child:GetAttribute("UnitId")
					local unitName = child:GetAttribute("UnitName")
					local unitTier = child:GetAttribute("UnitTier")

					local isTeam1Unit = team == 1 and (not child.Name:find("EnemyUnit_") and unitId and unitName and unitTier)
					local isTeam2Unit = team == 2 and (child.Name:find("EnemyUnit_") and unitId and unitName and unitTier)

					if isTeam1Unit or isTeam2Unit then
						print("DEBUG: Found unit model:", child.Name)
						print("DEBUG: Unit attributes - ID:", unitId, "Name:", unitName, "Tier:", unitTier)
						local unitData = UnitDatabase.createUnit(unitId, unitTier)
						if unitData then
							print("DEBUG: Created unit data for:", unitName)
							local battleUnit = createBattleUnit(child, unitData, team)
							table.insert(battleUnits, battleUnit)
							print("DEBUG: Added battle unit to team", team)
						else
							warn("DEBUG: Failed to create unit data for:", unitName)
						end
					end
				end
			end
		end
	end

	if #battleUnits == 0 then
		warn("No valid units found for team " .. tostring(team) .. " in board " .. board.Name)
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
	local epsilon = 0.75
	return distance <= (attackRange + epsilon)
end

-- Check if a hex is occupied by any unit
local function isHexOccupied(hex: Instance, excludeUnit: Model?): boolean
	for _, child in pairs(hex:GetChildren()) do
		if child:IsA("Model") and child ~= excludeUnit then
			-- Check if this is a battle unit (has underscore in name and is not a bench unit)
			if child.Name:find("_") and not child.Name:find("Bench_") then
				return true
			end
		end
	end
	return false
end

-- Check if a hex is reserved by another unit
local function isHexReserved(hex: Instance, excludeUnitId: string?): boolean
	if not excludeUnitId then return false end
	local reservedBy = reservedHexes[hex.Name]
	return reservedBy and reservedBy ~= excludeUnitId
end

-- Reserve a hex for a unit
local function reserveHex(hex: Instance, unitId: string)
	reservedHexes[hex.Name] = unitId
end

-- Release a hex reservation
local function releaseHex(hex: Instance)
	reservedHexes[hex.Name] = nil
end

-- Check if a position is too close to any occupied hex
local function isPositionTooCloseToOccupiedHex(arena: Instance, position: Vector3, excludeUnit: Model?): boolean
	for _, child in pairs(arena:GetChildren()) do
		if child.Name:find("Hex_") and isHexOccupied(child, excludeUnit) then
			local distance = (child.Position - position).Magnitude
			if distance < BATTLE_CONSTANTS.HEX_OCCUPANCY_CHECK_DISTANCE then
				return true
			end
		end
	end
	return false
end

-- Find the closest unoccupied hex to a target position
local function findClosestUnoccupiedHex(arena: Instance, targetPosition: Vector3, excludeUnit: Model?, excludeUnitId: string?): Instance?
	local closestHex = nil
	local closestDistance = math.huge
	
	for _, child in pairs(arena:GetChildren()) do
		if child.Name:find("Hex_") and not isHexOccupied(child, excludeUnit) and not isHexReserved(child, excludeUnitId) then
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
	
	-- Check movement cooldown
	local timeSinceLastMove = tick() - (unit.lastMoveTime or 0)
	if timeSinceLastMove < BATTLE_CONSTANTS.MOVEMENT_COOLDOWN then
		return -- Still in cooldown
	end
	
	-- Find the closest unoccupied hex to the target
	local unitId = unit.battleUnitId or unit.model:GetAttribute("BattleUnitId") or unit.model.Name
	local targetHex = findClosestUnoccupiedHex(arena, target.position, unit.model, unitId)
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
	
	-- Check if the target hex is already occupied or reserved
	if isHexOccupied(targetHex, unit.model) or isHexReserved(targetHex, unitId) then
		-- Find a safer hex that's not occupied or reserved
		local saferHex = nil
		local closestDistance = math.huge
		
		for _, child in pairs(arena:GetChildren()) do
			if child.Name:find("Hex_") and not isHexOccupied(child, unit.model) and not isHexReserved(child, unitId) then
				local distance = (child.Position - target.position).Magnitude
				if distance < closestDistance then
					closestDistance = distance
					saferHex = child
				end
			end
		end
		
		if saferHex then
			targetHex = saferHex
		else
			-- If no safe hex found, don't move
			return
		end
	end
	
	-- Reserve the target hex
	reserveHex(targetHex, unitId)
	
	-- Release reservation on current hex if we have one
	if currentHex then
		releaseHex(currentHex)
	end
	
	-- Move to the target hex
	local newPosition = targetHex.Position
	unit.position = newPosition
	unit.lastMoveTime = tick() -- Update movement cooldown
	
	-- Play move animation for unit
	local humanoid = unit.model:FindFirstChild("Humanoid")
	local moveTrack = nil
	if humanoid and unit.unit.moveAnimationId then
		local anim = Instance.new("Animation")
		anim.AnimationId = unit.unit.moveAnimationId
		moveTrack = humanoid:LoadAnimation(anim)
		moveTrack:Play()
	end

	-- Compute yaw-only facing and tween the model's pivot using a CFrameValue
	local startPos = unit.model:GetPivot().Position
	local endPos = newPosition + Vector3.new(0, BATTLE_CONSTANTS.UNIT_HEIGHT_OFFSET, 0)
	local flatTargetStart = Vector3.new(endPos.X, startPos.Y, endPos.Z)
	local startLook = CFrame.new(startPos, flatTargetStart)
	local _, startYaw = startLook:ToOrientation()
	local endLook = CFrame.new(endPos) * CFrame.Angles(0, startYaw, 0)

	-- Set initial facing
	unit.model:PivotTo(startLook)

	-- Tween pivot to endLook to keep facing
	local TweenService = game:GetService("TweenService")
	local cfValue = Instance.new("CFrameValue")
	cfValue.Value = startLook
	local tweenInfo = TweenInfo.new(
		BATTLE_CONSTANTS.MOVEMENT_TWEEN_TIME,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out,
		0,
		false,
		0
	)
	local tween = TweenService:Create(cfValue, tweenInfo, { Value = endLook })
	local conn
	conn = cfValue:GetPropertyChangedSignal("Value"):Connect(function()
		unit.model:PivotTo(cfValue.Value)
	end)
	tween.Completed:Connect(function()
		if conn then conn:Disconnect() end
		cfValue:Destroy()
		unit.model:PivotTo(endLook)
		unit.model.Parent = targetHex
		releaseHex(targetHex)
		if moveTrack then
			moveTrack:Stop()
		end
	end)
	tween:Play()
	print("Unit " .. unit.unit.name .. " moving to hex " .. targetHex.Name)
end

-- Attack target unit
local function attackTarget(unit: BattleUnit, target: BattleUnit)
	if not unit.model or not target.model then
		print("DEBUG: attackTarget failed - missing models")
		return
	end
	
	-- Calculate damage
	local damage = unit.unit.stats.attack
	local armor = target.unit.stats.armor
	local actualDamage = math.max(1, damage - armor)
	
	print("DEBUG: Unit " .. unit.unit.name .. " attacking " .. target.unit.name .. " for " .. actualDamage .. " damage")
	print("DEBUG: Attacker stats - damage: " .. damage .. ", target armor: " .. armor)
	
	-- Face the target and play attack animation for attacker
	local attackerHumanoid = unit.model:FindFirstChild("Humanoid")
	-- Rotate attacker to face target (yaw-only)
	local attackerPos = unit.model:GetPivot().Position
	local targetPos = target.model:GetPivot().Position
	local faceCFrame = CFrame.new(attackerPos, Vector3.new(targetPos.X, attackerPos.Y, targetPos.Z))
	unit.model:PivotTo(faceCFrame)
	if attackerHumanoid and unit.unit.attackAnimationId then
		-- Stop move animation if running
		for _, track in ipairs(attackerHumanoid:GetPlayingAnimationTracks()) do
			if track.Animation and track.Animation.AnimationId == unit.unit.moveAnimationId then
				track:Stop()
			end
		end
		local anim = Instance.new("Animation")
		anim.AnimationId = unit.unit.attackAnimationId
		local track = attackerHumanoid:LoadAnimation(anim)
		track:Play()
	end
    
	-- Find the Humanoid in the target model
	local humanoid = target.model:FindFirstChild("Humanoid")
	if humanoid then
		print("DEBUG: Found Humanoid in target, applying damage via Humanoid")
		-- Use Roblox's built-in damage system
		humanoid:TakeDamage(actualDamage)
		
		-- Update our internal health tracking
		target.health = humanoid.Health
		print("DEBUG: Target health after damage: " .. target.health)
		
		-- Check if target died
		if humanoid.Health <= 0 then
			target.isAlive = false
			target.model:SetAttribute("IsAlive", false)
			-- Make the model semi-transparent
			for _, part in pairs(target.model:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = 0.7
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
	
	-- Clear all hex reservations
	reservedHexes = {}
	
	-- Team 1 units (challenged player's original units) - reset to original positions
	for _, unit in ipairs(battleData.team1) do
		if unit.model then
			-- Always ensure core unit identity attributes exist for discovery in the next battle
			local coreUnitId = unit.unit and unit.unit.id or unit.model:GetAttribute("UnitId")
			local coreUnitName = unit.unit and unit.unit.name or unit.model:GetAttribute("UnitName")
			local coreUnitTier = unit.unit and unit.unit.tier or unit.model:GetAttribute("UnitTier")

			-- Restore health and visibility
			unit.health = unit.maxHealth
			unit.isAlive = true
			unit.model:SetAttribute("Health", unit.health)
			unit.model:SetAttribute("IsAlive", true)

			-- Reset Humanoid health if available
			local humanoid = unit.model:FindFirstChild("Humanoid")
			if humanoid then
				if humanoid.Health <= 0 then
					print("[DEBUG] Unit " .. unit.unit.name .. " is dead, replacing entire model from template...")
					local ReplicatedStorage = game:GetService("ReplicatedStorage")
					local unitModels = ReplicatedStorage:FindFirstChild("UnitModels")
					if unitModels then
						local template = unitModels:FindFirstChild(unit.unit.name)
						if template then
							local newModel = template:Clone()
							-- Name consistently so UnitSpawner removal logic can find it later (looks for underscore)
							local unitIdForName = coreUnitId or unit.unit.id or tostring(math.random(100000,999999))
							newModel.Name = (unit.unit.name or coreUnitName or "Unit") .. "_" .. tostring(unitIdForName)

							-- Apply tier scaling using the same approach as UnitSpawner
							local UnitDatabase = require(game:GetService("ReplicatedStorage").Shared.UnitDatabase)
							if unit.unit.tier then
								local sizeScale = UnitDatabase.calculateUnitSizeScale(unit.unit.tier)
								newModel:ScaleTo(sizeScale)
							end

							-- Replace old model
							local oldParent = unit.model.Parent
							local oldPivot = unit.model:GetPivot()
							unit.model:Destroy()
							newModel.Parent = oldParent
							newModel:PivotTo(oldPivot)

							-- Restore essential identification attributes so future battles can discover this unit
							if coreUnitId then newModel:SetAttribute("UnitId", coreUnitId) end
							if coreUnitName then newModel:SetAttribute("UnitName", coreUnitName) end
							if coreUnitTier then newModel:SetAttribute("UnitTier", coreUnitTier) end
							unit.model = newModel
							humanoid = newModel:FindFirstChild("Humanoid")
						else
							warn("[BattleManager] Could not find template model for unit: " .. unit.unit.name)
						end
					else
						warn("[BattleManager] UnitModels folder not found in ReplicatedStorage")
					end
				end
				humanoid.Health = humanoid.MaxHealth
				unit.health = humanoid.Health
				unit.model:SetAttribute("Health", humanoid.Health)
				unit.model:SetAttribute("IsAlive", true)
			end

			-- Ensure essential discovery attributes exist even if we didn't replace the model
			if coreUnitId and unit.model:GetAttribute("UnitId") == nil then
				unit.model:SetAttribute("UnitId", coreUnitId)
			end
			if coreUnitName and unit.model:GetAttribute("UnitName") == nil then
				unit.model:SetAttribute("UnitName", coreUnitName)
			end
			if coreUnitTier and unit.model:GetAttribute("UnitTier") == nil then
				unit.model:SetAttribute("UnitTier", coreUnitTier)
			end

			-- Completely reset all visual changes
			for _, part in pairs(unit.model:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = 0
				end
			end

			-- Clear temporary battle attributes on the model
			unit.model:SetAttribute("BattleUnit", nil)
			unit.model:SetAttribute("Team", nil)
			unit.model:SetAttribute("BattleUnitId", nil)

			-- Reparent back to the original hex if possible (so removal and future moves work reliably)
			local targetHex: Instance? = nil
			if unit.originalHexName then
				targetHex = battleData.arena:FindFirstChild(unit.originalHexName)
			end
			if not targetHex then
				-- Fallback to closest hex to the original position
				targetHex = findClosestHex(battleData.arena, unit.originalPosition)
			end
			if targetHex then
				unit.model.Parent = targetHex
				-- Position feet on hex surface similar to UnitSpawner
				local hexCFrame = (targetHex :: any).CFrame
				local unitSize = unit.model:GetExtentsSize()
				local heightOffset = unitSize.Y / 2
				local adjustedCFrame = CFrame.new(hexCFrame.Position + Vector3.new(0, heightOffset, 0))
				unit.model:PivotTo(adjustedCFrame)
				unit.position = unit.originalPosition
			else
				-- As a last resort, move back to original world position with a small offset
				local targetCFrame = CFrame.new(unit.originalPosition + Vector3.new(0, BATTLE_CONSTANTS.UNIT_HEIGHT_OFFSET, 0))
				unit.model:PivotTo(targetCFrame)
				unit.position = unit.originalPosition
			end

			print("Reset unit " .. unit.unit.name .. " to original state")
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

-- Stop all move animations for all units (call before reset)
local function stopAllMoveAnimations(battleData)
    for _, unit in ipairs(battleData.team1) do
        if unit.model then
            local humanoid = unit.model:FindFirstChild("Humanoid")
            if humanoid and unit.unit and unit.unit.moveAnimationId then
                for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
                    if track.Animation and track.Animation.AnimationId == unit.unit.moveAnimationId then
                        track:Stop()
                    end
                end
            end
        end
    end
    for _, unit in ipairs(battleData.team2) do
        if unit.model then
            local humanoid = unit.model:FindFirstChild("Humanoid")
            if humanoid and unit.unit and unit.unit.moveAnimationId then
                for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
                    if track.Animation and track.Animation.AnimationId == unit.unit.moveAnimationId then
                        track:Stop()
                    end
                end
            end
        end
    end
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
				print("[DEBUG] Team 1 Unit " .. unit.unit.name .. " Position: " .. tostring(unit.position))
				if not unit.target or not unit.target.isAlive then
					unit.target = findClosestEnemy(unit, battleData.team2)
					if unit.target then
						print("DEBUG: Unit " .. unit.unit.name .. " found new target: " .. unit.target.unit.name .. " at position " .. tostring(unit.target.position))
					end
				end
				if unit.target then
					local distance = calculateDistance(unit.position, unit.target.position)
					local attackRange = unit.unit.stats.range * BATTLE_CONSTANTS.HEX_SIZE + BATTLE_CONSTANTS.ATTACK_RANGE_BUFFER
					print("[DEBUG] Team 1 Unit " .. unit.unit.name .. " distance to target " .. unit.target.unit.name .. ": " .. distance .. ", attack range: " .. attackRange)
					if isInAttackRange(unit, unit.target) then
						local timeSinceLastAttack = tick() - unit.lastAttackTime
						local attackCooldown = (1 / unit.unit.stats.attackSpeed) / BATTLE_CONSTANTS.ATTACK_SPEED_MULTIPLIER
						print("[DEBUG] Team 1 Unit " .. unit.unit.name .. " in range! Time since last attack: " .. timeSinceLastAttack .. ", cooldown: " .. attackCooldown)
						if timeSinceLastAttack >= attackCooldown then
							print("[DEBUG] Team 1 Unit " .. unit.unit.name .. " attacking!")
							attackTarget(unit, unit.target)
							unit.lastAttackTime = tick() -- Update attack time
						end
					else
						print("[DEBUG] Team 1 Unit " .. unit.unit.name .. " not in attack range of " .. unit.target.unit.name)
						moveUnitTowardsTarget(unit, unit.target, battleData.arena)
					end
				else
					print("DEBUG: Unit " .. unit.unit.name .. " has no target")
				end
			end
		end
		
		-- Update team 2 units
		for _, unit in ipairs(battleData.team2) do
			if unit.isAlive then
				print("[DEBUG] Team 2 Unit " .. unit.unit.name .. " Position: " .. tostring(unit.position))
				if not unit.target or not unit.target.isAlive then
					unit.target = findClosestEnemy(unit, battleData.team1)
					if unit.target then
						print("DEBUG: Enemy unit " .. unit.unit.name .. " found new target: " .. unit.target.unit.name .. " at position " .. tostring(unit.target.position))
					end
				end
				if unit.target then
					local distance = calculateDistance(unit.position, unit.target.position)
					local attackRange = unit.unit.stats.range * BATTLE_CONSTANTS.HEX_SIZE + BATTLE_CONSTANTS.ATTACK_RANGE_BUFFER
					print("[DEBUG] Team 2 Unit " .. unit.unit.name .. " distance to target " .. unit.target.unit.name .. ": " .. distance .. ", attack range: " .. attackRange)
					if isInAttackRange(unit, unit.target) then
						local timeSinceLastAttack = tick() - unit.lastAttackTime
						local attackCooldown = (1 / unit.unit.stats.attackSpeed) / BATTLE_CONSTANTS.ATTACK_SPEED_MULTIPLIER
						print("[DEBUG] Team 2 Unit " .. unit.unit.name .. " in range! Time since last attack: " .. timeSinceLastAttack .. ", cooldown: " .. attackCooldown)
						if timeSinceLastAttack >= attackCooldown then
							print("[DEBUG] Team 2 Unit " .. unit.unit.name .. " attacking!")
							attackTarget(unit, unit.target)
							unit.lastAttackTime = tick() -- Update attack time
						end
					else
						print("[DEBUG] Team 2 Unit " .. unit.unit.name .. " not in attack range of " .. unit.target.unit.name)
						moveUnitTowardsTarget(unit, unit.target, battleData.arena)
					end
				else
					print("DEBUG: Enemy unit " .. unit.unit.name .. " has no target")
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
	-- Debug: Print initial positions of all units
	for i, unit in ipairs(battleData.team1) do
		print("[DEBUG] Team 1 Unit " .. tostring(i) .. ": " .. unit.unit.name .. " Position: " .. tostring(unit.position))
	end
	for i, unit in ipairs(battleData.team2) do
		print("[DEBUG] Team 2 Unit " .. tostring(i) .. ": " .. unit.unit.name .. " Position: " .. tostring(unit.position))
		-- Turn enemy units around 180 degrees on Y axis to face the other side
		if unit.model then
			local pivot = unit.model:GetPivot()
			local rotated = pivot * CFrame.Angles(0, math.pi, 0)
			unit.model:PivotTo(rotated)
		end
	end
	
	-- Start the battle with a short delay to allow teleports to settle
	wait(2)
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
	stopAllMoveAnimations(battleData)
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
