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
local TraitSystem = require(ReplicatedStorage.Shared.TraitSystem)
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
	originalHexName = nil, -- Name of the original hex parent (easier re-parenting on reset)
	originalCFrame = nil -- Full original pivot CFrame for rotation restoration
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
	MOVEMENT_TWEEN_TIME = 2.0, -- Time for smooth movement between hexes
	PROJECTILE_TRAVEL_TIME = 0.5 -- Time it takes projectile to reach target (seconds)
}

-- Toggle to enable very verbose per-frame attack/range logs
local ENABLE_VERBOSE_ATTACK_DEBUG = false
local ENABLE_Y_CHECK_DEBUG = false

-- Centralized debug toggle for animation diagnostics
local ENABLE_ANIMATION_DEBUG = false
local ENABLE_RIG_AUDIT_DEBUG = false

-- Generate unique battle ID
local function generateBattleId(): string
	return "battle_" .. os.time() .. "_" .. math.random(1000, 9999)
end

-- Animator resolver: works with Humanoid or AnimationController
local function resolveAnimator(model: Model): (Animator?, string)
	if not model then return nil, "no-model" end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
			if ENABLE_ANIMATION_DEBUG then
				print(string.format("[ANIM] Created Animator under Humanoid for model %s", model.Name))
			end
		end
		return animator, "humanoid"
	end
	local animCtrl = model:FindFirstChildOfClass("AnimationController")
	if animCtrl then
		local animator = animCtrl:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = animCtrl
			if ENABLE_ANIMATION_DEBUG then
				print(string.format("[ANIM] Created Animator under AnimationController for model %s", model.Name))
			end
		end
		return animator, "controller"
	end
	if ENABLE_ANIMATION_DEBUG then
		warn(string.format("[ANIM] No Humanoid or AnimationController found on model %s", model.Name))
	end
	return nil, "none"
end

-- Create a battle unit from a model and unit data
local function createBattleUnit(model: Model?, unit: DataStructures.Unit, team: number): BattleUnit?
	if not model or (typeof(model) ~= "Instance") or not model:IsA("Model") then
		warn("[BattleManager] createBattleUnit called with invalid model; skipping unit creation")
		return nil
	end
	-- Get health from Humanoid if available, otherwise use unit stats
	local humanoid = model:FindFirstChild("Humanoid")
	if humanoid and ENABLE_ANIMATION_DEBUG then
		local rigType = tostring(humanoid.RigType)
		print(string.format("[ANIM] %s rig type for model %s", rigType, model.Name))
	end
	-- Hide default Roblox health bar (we render our own via client BillboardGui)
	if humanoid then
		pcall(function()
			humanoid.HealthDisplayDistance = 0
			-- Tolerate missing necks on imported rigs so animations can still run
			humanoid.RequiresNeck = false
		end)
	end

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
		originalCFrame = model:GetPivot(),
		battleUnitId = uniqueId
	}
	
	-- Store battle data in the model
	model:SetAttribute("BattleUnit", true)
	model:SetAttribute("Team", team)
	model:SetAttribute("Health", battleUnit.health)
	model:SetAttribute("MaxHealth", battleUnit.maxHealth)
	model:SetAttribute("IsAlive", true)
	model:SetAttribute("BattleUnitId", uniqueId)
	-- Animation diagnostics
	local animator, aKind = resolveAnimator(model)
	model:SetAttribute("HasAnimator", animator ~= nil)
	if ENABLE_ANIMATION_DEBUG then
		print(string.format("[ANIM] %s animator for model %s (kind=%s)", animator and "Found" or "Missing", model.Name, aKind))
	end
	-- Disable default Roblox Animate script if present to prevent conflicts
	local animateScript = model:FindFirstChild("Animate")
	if animateScript and (animateScript:IsA("LocalScript") or animateScript:IsA("Script")) then
		(animateScript :: any).Disabled = true
		if ENABLE_ANIMATION_DEBUG then
			print(string.format("[ANIM] Disabled default Animate script on %s to avoid conflicts", model.Name))
		end
	end
	
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
							if battleUnit then
								table.insert(battleUnits, battleUnit)
								print("DEBUG: Added battle unit to team", team)
							else
								warn("[BattleManager] Skipped adding unit due to invalid model in createBattleUnit")
							end
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

-- Planar (XZ) distance helper to avoid Y offsets affecting range checks
local function calculatePlanarDistance(pos1: Vector3, pos2: Vector3): number
	local a = Vector3.new(pos1.X, 0, pos1.Z)
	local b = Vector3.new(pos2.X, 0, pos2.Z)
	return (a - b).Magnitude
end

-- Utility to play an animation by id; returns track or nil
local function playAnimation(model: Model, animationId: string, opts: { looped: boolean?, priority: Enum.AnimationPriority? }?): AnimationTrack?
	if not model or not animationId or animationId == "" then return nil end
	local animator, kind = resolveAnimator(model)
	if not animator then return nil end
	local anim = Instance.new("Animation")
	anim.AnimationId = animationId
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if not ok then
		warn(string.format("[ANIM] Failed to load animation %s for %s (%s): %s", tostring(animationId), model.Name, kind, tostring(track)))
		return nil
	end
	if opts and opts.looped ~= nil then
		track.Looped = opts.looped
	end
	if opts and opts.priority then
		track.Priority = opts.priority
	end
	-- Play with explicit fade, weight, and speed to ensure visibility
	pcall(function()
		track:Play(0.1, 1.0, 1.0)
		track:AdjustSpeed(1.0)
	end)
	if ENABLE_ANIMATION_DEBUG then
		local lenStr = "?"
		pcall(function() lenStr = string.format("%.2f", track.Length) end)
		print(string.format("[ANIM] Playing %s animation on %s (id=%s looped=%s len=%s)", (opts and opts.looped) and "looped" or "one-shot", model.Name, tostring(animationId), tostring(opts and opts.looped), lenStr))
	end
	return track
end

-- Utility to stop any playing track on a model that matches a given animationId
local function stopAnimationById(model: Model, animationId: string)
	if not model or not animationId or animationId == "" then return end
	local animator = select(1, resolveAnimator(model))
	if not animator then return end
	for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
		if t.Animation and t.Animation.AnimationId == animationId then
			pcall(function() t:Stop() end)
		end
	end
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
	-- Use planar distance to avoid vertical offsets influencing decision
	local distance = calculatePlanarDistance(unit.position, target.position)
	local attackRange = unit.unit.stats.range * BATTLE_CONSTANTS.HEX_SIZE + BATTLE_CONSTANTS.ATTACK_RANGE_BUFFER
	local epsilon = 0.75

	if distance <= (attackRange + epsilon) then
		return true
	end

	-- Extra tolerance for melee when standing on adjacent hexes that might be spaced slightly wider
	if unit.unit.stats.range <= 1 then
		if distance <= (BATTLE_CONSTANTS.HEX_SIZE * 1.25) then
			if ENABLE_VERBOSE_ATTACK_DEBUG then
				print(string.format("[RANGE] Melee adjacency tolerance applied (dist=%.2f, hex=%.2f)", distance, BATTLE_CONSTANTS.HEX_SIZE))
			end
			return true
		end
	end

	return false
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
	for _, child in pairs(arena:GetDescendants()) do
		if child.Name:find("Hex_") and isHexOccupied(child, excludeUnit) then
			local base: BasePart? = nil
			if child:IsA("BasePart") then base = child elseif child:IsA("Model") then base = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart") end
			local pos: Vector3
			if base then
				pos = base.Position
			elseif child:IsA("Model") then
				pos = (child :: Model):GetPivot().Position
			else
				-- Skip if no usable position
				continue
			end
			local distance = (pos - position).Magnitude
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
    
	for _, child in pairs(arena:GetDescendants()) do
		if child.Name:find("Hex_") and not isHexOccupied(child, excludeUnit) and not isHexReserved(child, excludeUnitId) then
			local base: BasePart? = nil
			if child:IsA("BasePart") then base = child elseif child:IsA("Model") then base = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart") end
			local pos: Vector3
			if base then
				pos = base.Position
			elseif child:IsA("Model") then
				pos = (child :: Model):GetPivot().Position
			else
				-- No reliable position, skip
				continue
			end
			local distance = (pos - targetPosition).Magnitude
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
    
	for _, child in pairs(arena:GetDescendants()) do
		if child.Name:find("Hex_") then
			local base: BasePart? = nil
			if child:IsA("BasePart") then base = child elseif child:IsA("Model") then base = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart") end
			local pos: Vector3
			if base then
				pos = base.Position
			elseif child:IsA("Model") then
				pos = (child :: Model):GetPivot().Position
			else
				continue
			end
			local distance = (pos - targetPosition).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestHex = child
			end
		end
	end
	
	return closestHex
end

-- Choose the next step hex toward a target (one-hex greedy move)
local function findNextStepHex(
	arena: Instance,
	currentPos: Vector3,
	targetPos: Vector3,
	excludeUnit: Model?,
	excludeUnitId: string?
): Instance?
	-- Compute a desired step point one hex-length toward the target on XZ plane
	local dir = targetPos - currentPos
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 1e-3 then
		return nil
	end
	dir = dir.Unit
	local desiredStepPos = currentPos + dir * BATTLE_CONSTANTS.HEX_SIZE

	local bestHex: Instance? = nil
	local bestCost = math.huge
	local currentToTarget = (currentPos - targetPos).Magnitude

	for _, child in pairs(arena:GetDescendants()) do
		if child.Name:find("Hex_") then
			-- Skip occupied/reserved hexes (except our own model when checking occupancy)
			if not isHexOccupied(child, excludeUnit) and not isHexReserved(child, excludeUnitId) then
				-- Resolve hex world position robustly (BasePart or Model)
				local base: BasePart? = nil
				if child:IsA("BasePart") then
					base = child
				elseif child:IsA("Model") then
					base = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
				end
				local pos: Vector3
				if base then
					pos = base.Position
				elseif child:IsA("Model") then
					pos = (child :: Model):GetPivot().Position
				else
					continue
				end

				-- Require progress toward the target
				local stepToTarget = (pos - targetPos).Magnitude
				if stepToTarget + 0.01 < currentToTarget then
					-- Cost = distance to desired step point (prefer closer to ideal) with small tie-breaker by target distance
					local cost = (pos - desiredStepPos).Magnitude + stepToTarget * 0.01
					if cost < bestCost then
						bestCost = cost
						bestHex = child
					end
				end
			end
		end
	end

	return bestHex
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
	-- Don't start a new tween if we're already tweening a move
	if unit.isMoving then
		return
	end
	
	-- Identify current and next step hexes
	local unitId = unit.battleUnitId or unit.model:GetAttribute("BattleUnitId") or unit.model.Name
	local currentHex = findClosestHex(arena, unit.position)
	if not currentHex then return end

	-- Prefer a one-hex step toward the target to guarantee progress for melee
	local nextHex = findNextStepHex(arena, unit.position, target.position, unit.model, unitId)
	local pickedVia = "step"

	if not nextHex then
		-- Fallback: closest unoccupied to target (may still be suboptimal but better than nothing)
		nextHex = findClosestUnoccupiedHex(arena, target.position, unit.model, unitId)
		pickedVia = "closest-to-target"
	end

	if not nextHex then
		-- Last fallback: any closest hex to target (ignores occupancy)
		nextHex = findClosestHex(arena, target.position)
		pickedVia = "closest-any"
	end

	if not nextHex then
		if ENABLE_VERBOSE_ATTACK_DEBUG then
			print(string.format("[MOVE] %s had no nextHex toward %s (pos=%s target=%s)", unit.unit.name, target.unit.name, tostring(unit.position), tostring(target.position)))
		end
		return
	end

	-- If we somehow selected the same hex we already occupy, do nothing
	if currentHex == nextHex then
		return
	end
	
	-- Check if the target hex is already occupied or reserved
	if isHexOccupied(nextHex, unit.model) or isHexReserved(nextHex, unitId) then
		if ENABLE_VERBOSE_ATTACK_DEBUG then
			print(string.format("[MOVE] Next hex %s blocked (occupied=%s reserved=%s)", nextHex.Name, tostring(isHexOccupied(nextHex, unit.model)), tostring(isHexReserved(nextHex, unitId))))
		end
		-- Find a safer hex that's not occupied or reserved
		local saferHex = nil
		local closestDistance = math.huge
		
		for _, child in pairs(arena:GetDescendants()) do
			if child.Name:find("Hex_") and not isHexOccupied(child, unit.model) and not isHexReserved(child, unitId) then
				-- Resolve child position robustly
				local base: BasePart? = nil
				if child:IsA("BasePart") then base = child elseif child:IsA("Model") then base = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart") end
				local cpos: Vector3
				if base then
					cpos = base.Position
				elseif child:IsA("Model") then
					cpos = (child :: Model):GetPivot().Position
				else
					continue
				end
				local distance = (cpos - target.position).Magnitude
				if distance < closestDistance then
					closestDistance = distance
					saferHex = child
				end
			end
		end
		
		if saferHex then
			nextHex = saferHex
		else
			-- If no safe hex found, don't move
			if ENABLE_VERBOSE_ATTACK_DEBUG then
				print(string.format("[MOVE] %s found no safer hex; skipping move", unit.unit.name))
			end
			return
		end
	end
	
	-- Reserve the target hex
	reserveHex(nextHex, unitId)
	
	-- Release reservation on current hex if we have one
	if currentHex then
		releaseHex(currentHex)
	end
	
	-- Move to the target hex (compute final Y so feet sit on hex top)
	local targetPart: BasePart? = nil
	if nextHex:IsA("BasePart") then
		targetPart = nextHex
	elseif nextHex:IsA("Model") then
		targetPart = nextHex.PrimaryPart or nextHex:FindFirstChildWhichIsA("BasePart")
	end
	local targetPosRaw: Vector3
	if targetPart then
		targetPosRaw = targetPart.Position
	elseif nextHex:IsA("Model") then
		targetPosRaw = (nextHex :: Model):GetPivot().Position
	else
		-- As a last fallback, avoid moving if we cannot determine a target position
		return
	end
	local unitSizeNow = unit.model:GetExtentsSize()
	local unitHalf = unitSizeNow.Y / 2
	local hexTopY = (targetPart and (targetPart.Position.Y + (targetPart.Size.Y / 2))) or targetPosRaw.Y
	local newPosition = Vector3.new(targetPosRaw.X, hexTopY + unitHalf, targetPosRaw.Z)
	unit.position = newPosition
	unit.lastMoveTime = tick() -- Update movement cooldown
	unit.isMoving = true
	
	-- Play move animation for unit (looped) using Animator API
	local moveTrack = nil
	if unit.unit.moveAnimationId then
		-- Stop any stale move track first
		stopAnimationById(unit.model, unit.unit.moveAnimationId)
		moveTrack = playAnimation(unit.model, unit.unit.moveAnimationId, { looped = true, priority = Enum.AnimationPriority.Movement })
		unit._moveTrack = moveTrack
		if not moveTrack and ENABLE_ANIMATION_DEBUG then
			warn(string.format("[ANIM] Move animation failed to play for %s (id=%s)", unit.unit.name, tostring(unit.unit.moveAnimationId)))
		end
	end

	-- Compute yaw-only facing and tween the model's pivot using a CFrameValue
	local startPos = unit.model:GetPivot().Position
	-- Face along the horizontal direction towards the destination while keeping current yaw as baseline
	local flatTargetStart = Vector3.new(newPosition.X, startPos.Y, newPosition.Z)
	local startLook = CFrame.new(startPos, flatTargetStart)
	local _, startYaw = startLook:ToOrientation()
	local endLook = CFrame.new(newPosition) * CFrame.Angles(0, startYaw, 0)

	-- Apply initial facing/pivot
	unit.model:PivotTo(startLook)

	-- Tween pivot to endLook to keep facing with correct final Y
	local TweenService = game:GetService("TweenService")
	local cfValue = Instance.new("CFrameValue")
	cfValue.Value = startLook
	local tweenInfo = TweenInfo.new(
		BATTLE_CONSTANTS.MOVEMENT_TWEEN_TIME,
		Enum.EasingStyle.Linear,
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
		unit.model.Parent = nextHex
		-- Safety clamp: ensure final Y sits exactly on hex top + unit half
		local base: BasePart? = nil
		if nextHex:IsA("BasePart") then base = nextHex elseif nextHex:IsA("Model") then base = nextHex.PrimaryPart or nextHex:FindFirstChildWhichIsA("BasePart") end
		if base then
			local curPos = unit.model:GetPivot().Position
			local unitSizeFinal = unit.model:GetExtentsSize()
			local expectedY = base.Position.Y + (base.Size.Y / 2) + (unitSizeFinal.Y / 2)
			if math.abs(curPos.Y - expectedY) > 0.02 then
				local corrected = CFrame.new(Vector3.new(base.Position.X, expectedY, base.Position.Z)) * CFrame.Angles(0, select(2, startLook:ToOrientation()), 0)
				unit.model:PivotTo(corrected)
				print("[BattleManager] Corrected unit Y after tween to prevent sinking: " .. unit.unit.name)
				unit.position = corrected.Position
			end
		end
		releaseHex(nextHex)
		if unit._moveTrack then
			-- Ensure we stop the looped move track when we arrive
			pcall(function()
				unit._moveTrack:Stop()
			end)
			unit._moveTrack = nil
		elseif moveTrack then
			pcall(function()
				moveTrack:Stop()
			end)
		end
		unit.isMoving = false
	end)
	tween:Play()
	local curDist = (unit.position - target.position).Magnitude
	local nextDist = (newPosition - target.position).Magnitude
	print("Unit " .. unit.unit.name .. " moving to hex " .. nextHex.Name .. " via " .. pickedVia .. " (dist " .. string.format("%.1f", curDist) .. " -> " .. string.format("%.1f", nextDist) .. ")")
end

-- Attack target unit
-- Spawns a projectile (if any) and returns whether damage application should be delayed until projectile impact
local function spawnProjectileIfNeeded(unit: BattleUnit, target: BattleUnit): boolean
	if not unit.unit or not unit.unit.projectileName then
		return false
	end

	local projectileFolder = ReplicatedStorage:FindFirstChild("Projectiles")
	if not projectileFolder then
		warn("[BattleManager] Projectiles folder missing in ReplicatedStorage")
		return false
	end

	local projectileTemplate = projectileFolder:FindFirstChild(unit.unit.projectileName)
	if not projectileTemplate then
		warn("[BattleManager] Projectile template not found: " .. tostring(unit.unit.projectileName))
		return false
	end

	if not unit.model or not target.model then
		return false
	end

	local cloned = projectileTemplate:Clone()
	cloned.Name = unit.unit.projectileName .. "_Proj"
	-- Determine start (attacker) and end (target) positions
	local startPos = unit.model:GetPivot().Position + Vector3.new(0, BATTLE_CONSTANTS.UNIT_HEIGHT_OFFSET, 0)
	local endPos = target.model:GetPivot().Position + Vector3.new(0, BATTLE_CONSTANTS.UNIT_HEIGHT_OFFSET, 0)

	-- Resolve impact effect (optional)
	local impactEffectName: string? = nil
	if Constants and Constants.PROJECTILE_IMPACT_EFFECTS then
		impactEffectName = Constants.PROJECTILE_IMPACT_EFFECTS[unit.unit.projectileName]
	end

	local function spawnImpactEffect()
		if not impactEffectName then return end
		local effectsFolder = ReplicatedStorage:FindFirstChild("Effects")
		if not effectsFolder then return end
		local effectTemplate = effectsFolder:FindFirstChild(impactEffectName)
		if not effectTemplate then return end
		local effectClone = effectTemplate:Clone()
		effectClone.Name = tostring(impactEffectName) .. "_Impact"
		-- Position effect at endPos
		if effectClone:IsA("Model") then
			local size = effectClone:GetExtentsSize()
			local yOff = size.Y/2
			effectClone:PivotTo(CFrame.new(endPos + Vector3.new(0, yOff, 0)))
		elseif effectClone:IsA("BasePart") then
			effectClone.CFrame = CFrame.new(endPos)
		end
		effectClone.Parent = workspace
		-- Cleanup after configured duration
		task.delay(Constants.PROJECTILE_IMPACT_EFFECT_DURATION or 0.3, function()
			if effectClone and effectClone.Parent then
				effectClone:Destroy()
			end
		end)
	end

	-- If projectile is a Model, set its pivot; if it's a BasePart just position it
	if cloned:IsA("Model") then
		local pivot = cloned:GetPivot()
		local size = cloned:GetExtentsSize()
		local heightOffset = size.Y/2
		cloned:PivotTo(CFrame.new(startPos + Vector3.new(0, heightOffset, 0), endPos))
	else
		if cloned:IsA("BasePart") then
			cloned.CFrame = CFrame.new(startPos, endPos)
		end
	end

	cloned.Parent = workspace

	-- Tween instantly (fast travel) from start to end using TweenService
	local tweenInfo = TweenInfo.new(BATTLE_CONSTANTS.PROJECTILE_TRAVEL_TIME, Enum.EasingStyle.Linear)
	local goalCFrame = CFrame.new(endPos, startPos) -- face backwards for simple effect

	-- Support Part vs Model tweening
	if cloned:IsA("BasePart") then
		local tween = TweenService:Create(cloned, tweenInfo, {CFrame = goalCFrame})
		tween.Completed:Connect(function()
			spawnImpactEffect()
			cloned:Destroy()
		end)
		tween:Play()
	else
		-- For models, move via a CFrameValue and PivotTo updates
		local cfVal = Instance.new("CFrameValue")
		cfVal.Value = cloned:GetPivot()
		local tween = TweenService:Create(cfVal, tweenInfo, {Value = goalCFrame})
		local conn
		conn = cfVal:GetPropertyChangedSignal("Value"):Connect(function()
			if cloned.Parent then
				cloned:PivotTo(cfVal.Value)
			end
		end)
		tween.Completed:Connect(function()
			if conn then conn:Disconnect() end
			spawnImpactEffect()
			cloned:Destroy()
			cfVal:Destroy()
		end)
		tween:Play()
	end

	-- Delay damage application until projectile completes
	return true
end

-- Helper to compute current attack speed (includes Ranger stacks)
local function getEffectiveAttackSpeed(bu)
	local base = bu.unit.stats.attackSpeed or 1
	if bu.rangerStacks and bu.rangerStacks > 0 then
		local bonus = math.min(bu.rangerStacks, 10) * 0.04 -- 4% per stack, cap 10
		return base * (1 + bonus)
	end
	return base
end

local function attackTarget(battleData: BattleData, unit: BattleUnit, target: BattleUnit)
	if not unit.model or not target.model then
		print("DEBUG: attackTarget failed - missing models")
		return
	end

	-- Calculate damage data upfront
	local damage = unit.unit.stats.attack
	local armor = target.unit.stats.armor
	-- Calculate armor damage reduction (will use magic resist in future for abilities/ magic damage) TODO
	local actualDamage = math.max(1, damage - (damage * (armor / (100 + armor))))
	print("DEBUG: Unit " .. unit.unit.name .. " initiating attack on " .. target.unit.name .. " (baseDamage=" .. damage .. ", armor=" .. armor .. ", postMitigation=" .. actualDamage .. ")")
	
	-- Face the target and play attack animation for attacker
	-- Rotate attacker to face target (yaw-only)
	local attackerPos = unit.model:GetPivot().Position
	local targetPos = target.model:GetPivot().Position
	local faceCFrame = CFrame.new(attackerPos, Vector3.new(targetPos.X, attackerPos.Y, targetPos.Z))
	unit.model:PivotTo(faceCFrame)
	-- Stop any looped move track we own
	if unit._moveTrack then
		pcall(function()
			unit._moveTrack:Stop()
		end)
		unit._moveTrack = nil
	end
	-- Also stop residual move animation by id in case it was started elsewhere
	if unit.unit.moveAnimationId then
		stopAnimationById(unit.model, unit.unit.moveAnimationId)
	end
	if unit.unit.attackAnimationId then
		local track = playAnimation(unit.model, unit.unit.attackAnimationId, { looped = false, priority = Enum.AnimationPriority.Action })
		if not track and ENABLE_ANIMATION_DEBUG then
			warn(string.format("[ANIM] Attack animation failed to play for %s (id=%s)", unit.unit.name, tostring(unit.unit.attackAnimationId)))
		end
	end
    
	local delayDamage = spawnProjectileIfNeeded(unit, target)

	local function applyDamage()
		-- Find the Humanoid in the target model (it could have died already)
		if not target.model then return end
		local humanoid = target.model:FindFirstChild("Humanoid")
		if humanoid and humanoid.Health > 0 then
			-- Juggernaut damage reduction
			local dr = target.damageReduction or 0
			local mitigated = math.max(1, math.floor(actualDamage * (1 - dr)))

			-- Shield application (from Medieval)
			local remainingDamage = mitigated
			if target.shield and target.shield > 0 then
				local absorbed = math.min(target.shield, remainingDamage)
				target.shield -= absorbed
				remainingDamage -= absorbed
				if target.model then target.model:SetAttribute("Shield", target.shield) end
			end

			-- Mystic bonus damage (3% target max health true magic damage) if active for attacker team
			local function teamHasActive(trait)
				return unit._teamActiveTraits and unit._teamActiveTraits[trait] == true
			end
			local bonusMagic = 0
			if teamHasActive("Mystic") then
				bonusMagic = math.max(1, math.floor(0.03 * (target.maxHealth or humanoid.MaxHealth)))
			end

			print("DEBUG: Applying damage " .. remainingDamage .. " (+magic " .. bonusMagic .. ") to target " .. target.unit.name)
			if remainingDamage > 0 then
				humanoid:TakeDamage(remainingDamage)
			end
			if bonusMagic > 0 and humanoid.Health > 0 then
				humanoid:TakeDamage(bonusMagic)
			end
			target.health = humanoid.Health
			-- Sync model attribute so client health bar updates
			if target.model then
				target.model:SetAttribute("Health", target.health)
			end
			print("DEBUG: Target health after damage: " .. target.health)
			if humanoid.Health <= 0 then
				target.isAlive = false
				target.model:SetAttribute("IsAlive", false)
				for _, part in pairs(target.model:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Transparency = 0.7
					end
				end
				print("Unit " .. target.unit.name .. " died!")
			end
		else
			if not humanoid then
				warn("No Humanoid found in target unit: " .. target.unit.name)
			end
		end
	end

	if delayDamage then
		task.delay(BATTLE_CONSTANTS.PROJECTILE_TRAVEL_TIME, applyDamage)
	else
		applyDamage()
	end
	
	-- Visual damage feedback - make the model flash red briefly
	-- Temporary hit highlight (non-color-changing) to show damage feedback
	if target.model and target.model.Parent then
		local existing = target.model:FindFirstChild("BT_DamageHighlight")
		local hl: Instance
		if existing and existing:IsA("Highlight") then
			hl = existing
		else
			if existing then existing:Destroy() end
			hl = Instance.new("Highlight")
			hl.Name = "BT_DamageHighlight"
			hl.Adornee = target.model
			-- Subtle, readable colors; avoid red per request
			hl.FillColor = Color3.fromRGB(255, 0, 0) -- red
			hl.OutlineColor = Color3.fromRGB(255, 255, 255)
			hl.FillTransparency = 0.7
			hl.OutlineTransparency = 0
			hl.Parent = target.model
		end
		-- Ensure it goes away quickly
		task.delay(0.15, function()
			if hl and hl.Parent then
				pcall(function()
					if hl.Parent then hl:Destroy() end
				end)
			end
		end)
	end
	
	-- Update last attack time
	unit.lastAttackTime = tick()
	
	-- Ranger stacking (after successful attack application)
	if unit.unit.traits and table.find(unit.unit.traits, "Ranger") and unit._teamActiveTraits and unit._teamActiveTraits["Ranger"] then
		unit.rangerStacks = (unit.rangerStacks or 0) + 1
		if unit.rangerStacks > 10 then unit.rangerStacks = 10 end
		if unit.model then unit.model:SetAttribute("RangerStacks", unit.rangerStacks) end
	end

	-- Artillerist splash (50% splash in 1 hex radius) if projectile unit and trait active
	if unit.unit.projectileName and unit.unit.traits and table.find(unit.unit.traits, "Artillerist") and unit._teamActiveTraits and unit._teamActiveTraits["Artillerist"] then
		-- Determine enemy team list
		local enemyTeam = (unit.team == 1) and battleData.team2 or battleData.team1
		local splashRadius = BATTLE_CONSTANTS.HEX_SIZE -- 1 hex
		local splashDamage = math.max(1, math.floor(actualDamage * 0.5))
		for _, e in ipairs(enemyTeam) do
			if e.isAlive and e ~= target then
				local dist = (e.position - target.position).Magnitude
				if dist <= splashRadius then
					local eh = e.model and e.model:FindFirstChild("Humanoid")
					if eh and eh.Health > 0 then
						-- Apply juggernaut DR + shield to splash recipients too
						local dr2 = e.damageReduction or 0
						local dmg2 = math.max(1, math.floor(splashDamage * (1 - dr2)))
						local remain2 = dmg2
						if e.shield and e.shield > 0 then
							local absorbed2 = math.min(e.shield, remain2)
							e.shield -= absorbed2
							remain2 -= absorbed2
							if e.model then e.model:SetAttribute("Shield", e.shield) end
						end
						if remain2 > 0 then eh:TakeDamage(remain2) end
						-- Sync splash recipient health to attribute for client UI
						if e.model then e.model:SetAttribute("Health", eh.Health) end
						if eh.Health <= 0 then
							e.isAlive = false
							e.model:SetAttribute("IsAlive", false)
						end
					end
				end
			end
		end
	end

	print("Unit " .. unit.unit.name .. " completed attack on " .. target.unit.name .. " for " .. actualDamage .. " damage (pre-mitigation)")
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

			-- Completely reset all visual changes and physics
			for _, part in pairs(unit.model:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = 0
					-- Clear any leftover velocities from battle movement
					part.AssemblyLinearVelocity = Vector3.zero
					part.AssemblyAngularVelocity = Vector3.zero
				end
			end
			-- Remove any temporary damage highlight if still present
			local dmgHl = unit.model:FindFirstChild("BT_DamageHighlight")
			if dmgHl and dmgHl:IsA("Highlight") then
				pcall(function() dmgHl:Destroy() end)
			end

			-- Clear transient battle attributes so client UI resets
			unit.shield = 0
			unit.model:SetAttribute("Shield", 0)
			unit.model:SetAttribute("RangerStacks", nil)

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
				-- Position feet on hex surface using part thickness
				local hexPart = targetHex :: BasePart
				local unitSizeR = unit.model:GetExtentsSize()
				local unitHalf = unitSizeR.Y / 2
				local hexTopY = hexPart.Position.Y + (hexPart.Size.Y / 2)
				local targetPos = Vector3.new(hexPart.Position.X, hexTopY + unitHalf, hexPart.Position.Z)
				-- Restore original rotation if we captured it; otherwise align to hex
				local adjustedCFrame
				if unit.originalCFrame then
					local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = unit.originalCFrame:GetComponents()
					adjustedCFrame = CFrame.new(targetPos.X, targetPos.Y, targetPos.Z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
				else
					adjustedCFrame = CFrame.lookAt(targetPos, targetPos + hexPart.CFrame.LookVector, Vector3.yAxis)
				end
				unit.model:PivotTo(adjustedCFrame)
				unit.position = targetPos
			else
				-- As a last resort, move back to original world position with a small offset
				local pos = Vector3.new(unit.originalPosition.X, Constants.GROUND_LEVEL, unit.originalPosition.Z) + Vector3.new(0, BATTLE_CONSTANTS.UNIT_HEIGHT_OFFSET, 0)
				local targetCFrame
				if unit.originalCFrame then
					local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = unit.originalCFrame:GetComponents()
					targetCFrame = CFrame.new(pos.X, pos.Y, pos.Z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
				else
					targetCFrame = CFrame.lookAt(pos, pos + Vector3.zAxis, Vector3.yAxis)
				end
				unit.model:PivotTo(targetCFrame)
				unit.position = targetCFrame.Position
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
	local function stopForTeam(team)
		for _, unit in ipairs(team) do
			if unit and unit.model and unit.unit and unit.unit.moveAnimationId then
				-- Try to stop via stored track first
				if unit._moveTrack then
					pcall(function() unit._moveTrack:Stop() end)
					unit._moveTrack = nil
				end
				-- Also stop any matching tracks on the animator
				stopAnimationById(unit.model, unit.unit.moveAnimationId)
			end
		end
	end
	stopForTeam(battleData.team1)
	stopForTeam(battleData.team2)
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
				-- Keep runtime position in sync with model
				if unit.model then
					unit.position = unit.model:GetPivot().Position
				end
				if ENABLE_Y_CHECK_DEBUG and unit.model and unit.model.Parent and typeof(unit.model.Parent) == "Instance" then
					local parentHex = unit.model.Parent
					if parentHex and typeof(parentHex.Name) == "string" and parentHex.Name:find("Hex_") then
						local base: BasePart? = nil
						if parentHex:IsA("BasePart") then base = parentHex elseif parentHex:IsA("Model") then base = parentHex.PrimaryPart or parentHex:FindFirstChildWhichIsA("BasePart") end
						if base then
							local size = unit.model:GetExtentsSize()
							local expectedY = base.Position.Y + (base.Size.Y/2) + (size.Y/2)
							local curY = unit.model:GetPivot().Position.Y
							if math.abs(curY - expectedY) > 0.05 then
								print(string.format("[Y-DEBUG] %s off-surface by %.3f studs", unit.unit.name, curY - expectedY))
							end
						end
					end
				end
				--print("[DEBUG] Team 1 Unit " .. unit.unit.name .. " Position: " .. tostring(unit.position))
				if not unit.target or not unit.target.isAlive then
					unit.target = findClosestEnemy(unit, battleData.team2)
					if unit.target then
						--print("DEBUG: Unit " .. unit.unit.name .. " found new target: " .. unit.target.unit.name .. " at position " .. tostring(unit.target.position))
					end
				end
				if unit.target then
					local distance = calculateDistance(unit.position, unit.target.position)
					local attackRange = unit.unit.stats.range * BATTLE_CONSTANTS.HEX_SIZE + BATTLE_CONSTANTS.ATTACK_RANGE_BUFFER
					--print("[DEBUG] Team 1 Unit " .. unit.unit.name .. " distance to target " .. unit.target.unit.name .. ": " .. distance .. ", attack range: " .. attackRange)
					if isInAttackRange(unit, unit.target) then
						local timeSinceLastAttack = tick() - unit.lastAttackTime
						local attackCooldown = (1 / getEffectiveAttackSpeed(unit)) / BATTLE_CONSTANTS.ATTACK_SPEED_MULTIPLIER
						--print("[DEBUG] Team 1 Unit " .. unit.unit.name .. " in range! Time since last attack: " .. timeSinceLastAttack .. ", cooldown: " .. attackCooldown)
						if timeSinceLastAttack >= attackCooldown then
							--print("[DEBUG] Team 1 Unit " .. unit.unit.name .. " attacking!")
							attackTarget(battleData, unit, unit.target)
							unit.lastAttackTime = tick() -- Update attack time
						end
					else
						--print("[DEBUG] Team 1 Unit " .. unit.unit.name .. " not in attack range of " .. unit.target.unit.name)
						moveUnitTowardsTarget(unit, unit.target, battleData.arena)
					end
				else
					--print("DEBUG: Unit " .. unit.unit.name .. " has no target")
				end
			end
		end
		
		-- Update team 2 units
		for _, unit in ipairs(battleData.team2) do
			if unit.isAlive then
				-- Keep runtime position in sync with model
				if unit.model then
					unit.position = unit.model:GetPivot().Position
				end
				--print("[DEBUG] Team 2 Unit " .. unit.unit.name .. " Position: " .. tostring(unit.position))
				if not unit.target or not unit.target.isAlive then
					unit.target = findClosestEnemy(unit, battleData.team1)
					if unit.target then
						--print("DEBUG: Enemy unit " .. unit.unit.name .. " found new target: " .. unit.target.unit.name .. " at position " .. tostring(unit.target.position))
					end
				end
				if unit.target then
					local distance = calculateDistance(unit.position, unit.target.position)
					local attackRange = unit.unit.stats.range * BATTLE_CONSTANTS.HEX_SIZE + BATTLE_CONSTANTS.ATTACK_RANGE_BUFFER
					--print("[DEBUG] Team 2 Unit " .. unit.unit.name .. " distance to target " .. unit.target.unit.name .. ": " .. distance .. ", attack range: " .. attackRange)
					if isInAttackRange(unit, unit.target) then
						local timeSinceLastAttack = tick() - unit.lastAttackTime
						local attackCooldown = (1 / getEffectiveAttackSpeed(unit)) / BATTLE_CONSTANTS.ATTACK_SPEED_MULTIPLIER
						--print("[DEBUG] Team 2 Unit " .. unit.unit.name .. " in range! Time since last attack: " .. timeSinceLastAttack .. ", cooldown: " .. attackCooldown)
						if timeSinceLastAttack >= attackCooldown then
							--print("[DEBUG] Team 2 Unit " .. unit.unit.name .. " attacking!")
							attackTarget(battleData, unit, unit.target)
							unit.lastAttackTime = tick() -- Update attack time
						end
					else
						--print("[DEBUG] Team 2 Unit " .. unit.unit.name .. " not in attack range of " .. unit.target.unit.name)
						moveUnitTowardsTarget(unit, unit.target, battleData.arena)
					end
				else
					--print("DEBUG: Enemy unit " .. unit.unit.name .. " has no target")
				end
			end
		end
		
		-- Check for battle end conditions
		local team1Defeated = isTeamDefeated(battleData.team1)
		local team2Defeated = isTeamDefeated(battleData.team2)
		
		if team1Defeated or team2Defeated then
			--print(string.format("[DEBUG] Battle end condition reached (team1Defeated=%s, team2Defeated=%s) p1=%s p2=%s", tostring(team1Defeated), tostring(team2Defeated), tostring(battleData.player1Id), tostring(battleData.player2Id)))
			local winner: number? = nil
			if team1Defeated and not team2Defeated then
				winner = battleData.player2Id
				--print("[DEBUG] Team 1 defeated; declaring Player2 winner: " .. tostring(winner))
			elseif team2Defeated and not team1Defeated then
				winner = battleData.player1Id
				--print("[DEBUG] Team 2 defeated; declaring Player1 winner: " .. tostring(winner))
			else
				--print("[DEBUG] Both teams defeated simultaneously -> draw")
			end

			-- Sanity check: ensure winner is one of the two players else treat as draw
			if winner and winner ~= battleData.player1Id and winner ~= battleData.player2Id then
				warn("[BattleManager] Computed winner (" .. tostring(winner) .. ") not in battle participants; forcing draw")
				winner = nil
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
	
	-- Compute and apply trait bonuses for both teams before battle begins
	local team1TraitContext = TraitSystem.applyPreBattleBonuses(battleData.team1)
	local team2TraitContext = TraitSystem.applyPreBattleBonuses(battleData.team2)
	-- Store active trait flags on each battle unit for fast lookup during attacks
	local t1Active = {}
	for trait, def in pairs(Constants.TRAITS) do
		local c = 0
		for _, bu in ipairs(battleData.team1) do
			if bu.unit.traits and table.find(bu.unit.traits, trait) then c += 1 end
		end
		if c >= def.requirement then t1Active[trait] = true end
	end
	for _, bu in ipairs(battleData.team1) do bu._teamActiveTraits = t1Active end

	local t2Active = {}
	for trait, def in pairs(Constants.TRAITS) do
		local c = 0
		for _, bu in ipairs(battleData.team2) do
			if bu.unit.traits and table.find(bu.unit.traits, trait) then c += 1 end
		end
		if c >= def.requirement then t2Active[trait] = true end
	end
	for _, bu in ipairs(battleData.team2) do bu._teamActiveTraits = t2Active end

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
