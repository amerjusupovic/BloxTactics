--[[
	UnitSpawner.luau
	Server-side unit model spawning and management
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UnitSpawner = {}

-- Cache for unit models
local unitModels = {}

-- Helper function to find player arena in any lobby
local function findPlayerArena(userId: number): (Folder?, Instance?)
	-- Search through all lobby folders in the main workspace to find the player's arena
	for _, child in pairs(workspace:GetChildren()) do
		if child.Name:find("Lobby_") then
			local spawnPoints = child:FindFirstChild("SpawnPoints")
			if spawnPoints then
				local playerFolder = spawnPoints:FindFirstChild(tostring(userId))
				if playerFolder then
					for _, arenaCandidate in pairs(playerFolder:GetChildren()) do
						if arenaCandidate.Name:match("%sArena$") then
							return playerFolder, arenaCandidate
						end
					end
				end
			end
		end
	end
	return nil, nil
end

-- Function to load unit models from ReplicatedStorage
function UnitSpawner.loadUnitModels()
	print("Loading unit models from ReplicatedStorage...")
	local unitModelsFolder = ReplicatedStorage:FindFirstChild("UnitModels")
	if not unitModelsFolder then
		warn("UnitModels folder not found in ReplicatedStorage!")
		return
	end
	
	print("Found UnitModels folder, loading models...")
	-- Load all unit models into cache
	for _, model in pairs(unitModelsFolder:GetChildren()) do
		if model:IsA("Model") then
			unitModels[model.Name] = model
			print("Loaded unit model: " .. model.Name)
		else
			print("Found non-Model item in UnitModels: " .. model.Name .. " (Type: " .. model.ClassName .. ")")
		end
	end
	
	print("Unit model loading complete. Loaded " .. #unitModels .. " models.")
end

-- Function to get unit model by unit name
function UnitSpawner.getUnitModel(unitName: string): Model?
	return unitModels[unitName]
end

-- Function to spawn unit on board
function UnitSpawner.spawnUnitOnBoard(userId: number, unit: any, position: Vector2)
	-- Find the player's arena in the current workspace
	
	print("=== UnitSpawner.spawnUnitOnBoard START ===")
	print("Parameters - UserId:", userId, "Unit:", unit.name, "Position:", position)
	
	-- Find the player's arena in the current workspace
	local playerFolder, arena = findPlayerArena(userId)
	if not playerFolder then
		warn("Player folder not found for: " .. userId)
		print("=== UnitSpawner.spawnUnitOnBoard FAILED - No player folder ===")
		return nil
	end
	print("Player folder found:", playerFolder.Name)
	
	if not arena then
		warn("Arena not found for player: " .. userId)
		print("=== UnitSpawner.spawnUnitOnBoard FAILED - No Arena ===")
		return nil
	end
	print("Arena found:", arena.Name)
	
	-- Find the board hex (convert position to hex name)
	-- Position (3, 3) should map to Hex_4_4 (client expectation)
	-- Convert from 0-indexed coordinates to 1-indexed hex names
	local hexRow = position.Y + 1
	local hexCol = position.X + 1
	local hexName = "Hex_" .. hexRow .. "_" .. hexCol
	
	local hex = arena:FindFirstChild(hexName)
	if not hex then
		warn("Board hex not found for position: " .. tostring(position) .. " (looking for " .. hexName .. ")")
		print("=== UnitSpawner.spawnUnitOnBoard FAILED - No board hex ===")
		return nil
	end
	
	-- Get unit model
	local unitModel = UnitSpawner.getUnitModel(unit.name)
	if not unitModel then
		warn("Unit model not found for: " .. unit.name)
		print("=== UnitSpawner.spawnUnitOnBoard FAILED - No unit model ===")
		return nil
	end
	
	-- Clone and position the unit model
	local spawnedUnit = unitModel:Clone()
	spawnedUnit.Name = unit.name .. "_" .. unit.id
	
	-- Scale unit based on tier
	local UnitDatabase = require(game.ReplicatedStorage.Shared.UnitDatabase)
	local sizeScale = UnitDatabase.calculateUnitSizeScale(unit.tier)
	
	-- Scale the entire model using the top-level Scale property
	spawnedUnit:ScaleTo(sizeScale)
	
	-- Position the unit at the hex location
	-- Adjust Y so the unit's feet sit on top of the hex (account for hex thickness)
	-- Resolve a BasePart representing the hex's collider/surface
	local hexPart: BasePart? = nil
	if hex:IsA("BasePart") then
		hexPart = hex
	elseif hex:IsA("Model") then
		hexPart = hex.PrimaryPart or hex:FindFirstChildWhichIsA("BasePart")
	end
	if not hexPart then
		-- Fallback: attempt to use CFrame position as-is
		hexPart = (hex :: any)
	end
	local unitSize = spawnedUnit:GetExtentsSize()
	local unitHalf = unitSize.Y / 2
	local hexTopY = hexPart.Position.Y + (hexPart.Size.Y / 2)
	local targetPos = Vector3.new(hexPart.Position.X, hexTopY + unitHalf, hexPart.Position.Z)

	-- Preserve current model orientation, only change position
	local pivotCFrame = spawnedUnit:GetPivot()
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = pivotCFrame:GetComponents()
	local adjustedCFrame = CFrame.new(targetPos.X, targetPos.Y, targetPos.Z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	spawnedUnit:PivotTo(adjustedCFrame)
	
	-- Store unit data in the model
	spawnedUnit:SetAttribute("UnitId", unit.id)
	spawnedUnit:SetAttribute("UnitName", unit.name)
	spawnedUnit:SetAttribute("UnitTier", unit.tier)
	spawnedUnit:SetAttribute("PositionX", position.X)
	spawnedUnit:SetAttribute("PositionY", position.Y)
	
	-- Parent to the hex
	spawnedUnit.Parent = hex
	
	print("Successfully spawned unit " .. unit.name .. " on board at position: " .. tostring(position))
	print("=== UnitSpawner.spawnUnitOnBoard SUCCESS ===")
	return spawnedUnit
end

-- Function to spawn unit on bench
function UnitSpawner.spawnUnitOnBench(userId: number, unit: any, benchSlot: number)
	-- Find the player's arena in the current workspace
	
	print("=== UnitSpawner.spawnUnitOnBench START ===")
	print("Parameters - UserId:", userId, "Unit:", unit.name, "BenchSlot:", benchSlot)
	print("Unit object:", unit)
	
	-- Find the player's arena in the current workspace
	local playerFolder, arena = findPlayerArena(userId)
	if not playerFolder then
		warn("Player folder not found for: " .. userId)
		print("=== UnitSpawner.spawnUnitOnBench FAILED - No player folder ===")
		return nil
	end
	
	if not arena then
		warn("Arena not found for player: " .. userId)
		print("=== UnitSpawner.spawnUnitOnBench FAILED - No Arena ===")
		return nil
	end
	
	-- Find the bench spot
	local bench = arena:FindFirstChild("Bench_" .. benchSlot)
	if not bench then
		warn("Bench slot not found: " .. benchSlot .. " for player: " .. userId)
		print("=== UnitSpawner.spawnUnitOnBench FAILED - No bench slot ===")
		return nil
	end
	
	-- Re-enable unit spawning temporarily
	print("Attempting to spawn unit on bench - UserId:", userId, "Unit:", unit.name, "Slot:", benchSlot)
	
	-- Get unit model
	local unitModel = UnitSpawner.getUnitModel(unit.name)
	if not unitModel then
		warn("Unit model not found for: " .. unit.name)
		print("=== UnitSpawner.spawnUnitOnBench FAILED - No unit model ===")
		return nil
	end
	
	-- Clone and position the unit model
	local spawnedUnit = unitModel:Clone()
	spawnedUnit.Name = unit.name .. "_" .. unit.id
	
	-- Scale unit based on tier
	local UnitDatabase = require(game.ReplicatedStorage.Shared.UnitDatabase)
	local sizeScale = UnitDatabase.calculateUnitSizeScale(unit.tier)
	
	-- Scale the entire model using the top-level Scale property
	spawnedUnit:ScaleTo(sizeScale)
	
	-- Position the unit at the bench location with feet on top (account for bench thickness)
	-- Resolve a BasePart representing the bench slot's surface
	local benchPart: BasePart? = nil
	if bench:IsA("BasePart") then
		benchPart = bench
	elseif bench:IsA("Model") then
		benchPart = bench.PrimaryPart or bench:FindFirstChildWhichIsA("BasePart")
	end
	if not benchPart then
		benchPart = (bench :: any)
	end
	local unitSize = spawnedUnit:GetExtentsSize()
	local unitHalf = unitSize.Y / 2
	local benchTopY = benchPart.Position.Y + (benchPart.Size.Y / 2)
	local targetPos = Vector3.new(benchPart.Position.X, benchTopY + unitHalf, benchPart.Position.Z)
	local pivotCFrame = spawnedUnit:GetPivot()
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = pivotCFrame:GetComponents()
	local adjustedCFrame = CFrame.new(targetPos.X, targetPos.Y, targetPos.Z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	spawnedUnit:PivotTo(adjustedCFrame)
	
	-- Store unit data in the model
	spawnedUnit:SetAttribute("UnitId", unit.id)
	spawnedUnit:SetAttribute("UnitName", unit.name)
	spawnedUnit:SetAttribute("UnitTier", unit.tier)
	spawnedUnit:SetAttribute("BenchSlot", benchSlot)
	
	-- Parent to the bench slot
	spawnedUnit.Parent = bench
	
	print("Successfully spawned unit " .. unit.name .. " on bench at slot: " .. benchSlot)
	print("=== UnitSpawner.spawnUnitOnBench SUCCESS ===")
	return spawnedUnit
end

-- Function to remove unit from board
function UnitSpawner.removeUnitFromBoard(userId: number, position: Vector2)
	-- Find the player's arena in the current workspace
	
	print("=== UnitSpawner.removeUnitFromBoard START ===")
	print("Parameters - UserId:", userId, "Position:", position)
	
	-- Find the player's arena in the current workspace
	local playerFolder, arena = findPlayerArena(userId)
	if not playerFolder then
		warn("Player folder not found for: " .. userId)
		print("=== UnitSpawner.removeUnitFromBoard FAILED - No player folder ===")
		return
	end
	
	if not arena then
		warn("Arena not found for player: " .. userId)
		print("=== UnitSpawner.removeUnitFromBoard FAILED - No Arena ===")
		return
	end
	
	-- Find the board hex (convert position to hex name)
	-- Convert from 0-indexed coordinates to 1-indexed hex names
	local hexRow = position.Y + 1
	local hexCol = position.X + 1
	local hexName = "Hex_" .. hexRow .. "_" .. hexCol
	
	local hex = arena:FindFirstChild(hexName)
	if not hex then
		warn("Board hex not found for position: " .. tostring(position) .. " (looking for " .. hexName .. ")")
		print("=== UnitSpawner.removeUnitFromBoard FAILED - No board hex ===")
		return
	end
	
	-- Remove all unit models from this hex
	local removedCount = 0
	for _, child in pairs(hex:GetChildren()) do
		if child:IsA("Model") then
			-- Identify a unit model either by underscore naming OR by presence of unit attributes
			local hasUnderscore = child.Name:find("_") ~= nil
			local hasUnitAttrs = child:GetAttribute("UnitId") ~= nil or child:GetAttribute("UnitName") ~= nil or child:GetAttribute("UnitTier") ~= nil
			if hasUnderscore or hasUnitAttrs then
				print("Removing unit model:", child.Name, " criteria:", hasUnderscore and "underscore" or "attrs")
				child:Destroy()
				removedCount = removedCount + 1
			end
		end
	end
	
	print("Removed " .. removedCount .. " unit models from board position " .. tostring(position))
	print("=== UnitSpawner.removeUnitFromBoard SUCCESS ===")
end

-- Function to remove unit from bench
function UnitSpawner.removeUnitFromBench(userId: number, benchSlot: number)
	-- Find the player's arena in the current workspace
	
	print("=== UnitSpawner.removeUnitFromBench START ===")
	print("Parameters - UserId:", userId, "BenchSlot:", benchSlot)
	
	-- Find the player's arena in the current workspace
	local playerFolder, arena = findPlayerArena(userId)
	if not playerFolder then
		warn("Player folder not found for: " .. userId)
		print("=== UnitSpawner.removeUnitFromBench FAILED - No player folder ===")
		return
	end
	
	if not arena then
		warn("Arena not found for player: " .. userId)
		print("=== UnitSpawner.removeUnitFromBench FAILED - No Arena ===")
		return
	end
	
	-- Find the bench spot
	local bench = arena:FindFirstChild("Bench_" .. benchSlot)
	if not bench then
		warn("Bench slot not found: " .. benchSlot .. " for player: " .. userId)
		print("=== UnitSpawner.removeUnitFromBench FAILED - No bench slot ===")
		return
	end
	
	-- Remove all unit models from this bench slot
	local removedCount = 0
	for _, child in pairs(bench:GetChildren()) do
		if child:IsA("Model") then
			local hasUnderscore = child.Name:find("_") ~= nil
			local hasUnitAttrs = child:GetAttribute("UnitId") ~= nil or child:GetAttribute("UnitName") ~= nil or child:GetAttribute("UnitTier") ~= nil
			if hasUnderscore or hasUnitAttrs then
				print("Removing unit model:", child.Name, " criteria:", hasUnderscore and "underscore" or "attrs")
				child:Destroy()
				removedCount = removedCount + 1
			end
		end
	end
	
	print("Removed " .. removedCount .. " unit models from bench slot " .. benchSlot)
	print("=== UnitSpawner.removeUnitFromBench SUCCESS ===")
end

-- Function to move unit between bench slots
function UnitSpawner.moveUnitBetweenBenchSlots(userId: number, fromSlot: number, toSlot: number)
	-- Find the player's arena in the current workspace
	
	print("=== UnitSpawner.moveUnitBetweenBenchSlots START ===")
	print("Parameters - UserId:", userId, "FromSlot:", fromSlot, "ToSlot:", toSlot)
	
	-- Find the player's arena in the current workspace
	local playerFolder, arena = findPlayerArena(userId)
	if not playerFolder then
		warn("Player folder not found for: " .. userId)
		print("=== UnitSpawner.moveUnitBetweenBenchSlots FAILED - No player folder ===")
		return
	end
	
	if not arena then
		warn("Arena not found for player: " .. userId)
		print("=== UnitSpawner.moveUnitBetweenBenchSlots FAILED - No Arena ===")
		return
	end
	print("Arena found:", arena.Name)
	
	-- Find the bench spots
	local fromBench = arena:FindFirstChild("Bench_" .. fromSlot)
	local toBench = arena:FindFirstChild("Bench_" .. toSlot)
	
	if not fromBench or not toBench then
		warn("Bench spots not found - From: " .. fromSlot .. ", To: " .. toSlot)
		print("=== UnitSpawner.moveUnitBetweenBenchSlots FAILED - No bench spots ===")
		return
	end
	
	-- Find the unit model in the source bench slot
	local unitModel = nil
	for _, child in pairs(fromBench:GetChildren()) do
		if child:IsA("Model") and child.Name:find("_") then
			unitModel = child
			break
		end
	end
	
	if unitModel then		
		-- Update the bench slot attribute
		unitModel:SetAttribute("BenchSlot", toSlot)
		
		-- Move the unit to the new bench slot
		unitModel.Parent = toBench
		
		-- Reposition the unit at the new bench location (feet on top)
		local benchPart: BasePart? = nil
		if toBench:IsA("BasePart") then
			benchPart = toBench
		elseif toBench:IsA("Model") then
			benchPart = toBench.PrimaryPart or toBench:FindFirstChildWhichIsA("BasePart")
		end
		if not benchPart then
			benchPart = (toBench :: any)
		end
		local unitSize = unitModel:GetExtentsSize()
		local unitHalf = unitSize.Y / 2
		local benchTopY = benchPart.Position.Y + (benchPart.Size.Y / 2)
		local targetPos = Vector3.new(benchPart.Position.X, benchTopY + unitHalf, benchPart.Position.Z)
		local pivotCFrame = unitModel:GetPivot()
		local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = pivotCFrame:GetComponents()
		local adjustedCFrame = CFrame.new(targetPos.X, targetPos.Y, targetPos.Z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
		unitModel:PivotTo(adjustedCFrame)
		
		print("Successfully moved unit from bench slot " .. fromSlot .. " to bench slot " .. toSlot)
		print("=== UnitSpawner.moveUnitBetweenBenchSlots SUCCESS ===")
	else
		print("No unit model found in source bench slot " .. fromSlot)
		print("=== UnitSpawner.moveUnitBetweenBenchSlots FAILED - No unit to move ===")
	end
end

-- Function to clear all units for a player
function UnitSpawner.clearPlayerUnits(userId: number)
	-- Find the player's arena in the current workspace
	
	print("=== UnitSpawner.clearPlayerUnits START ===")
	print("Parameters - UserId:", userId)
	
	-- Find the player's arena in the current workspace
	local playerFolder, arena = findPlayerArena(userId)
	if not playerFolder then
		warn("PlayerFolder not found for: " .. userId)
		print("=== UnitSpawner.clearPlayerUnits FAILED - No player folder ===")
		return
	end
	
	if not arena then
		warn("Arena not found for player: " .. userId)
		print("=== UnitSpawner.clearPlayerUnits FAILED - No Arena ===")
		return
	end
	
	local totalRemoved = 0
	
	-- Clear units from board hexes
	for _, child in pairs(arena:GetChildren()) do
		if child.Name:find("Hex_") then
			for _, unitModel in pairs(child:GetChildren()) do
				if unitModel:IsA("Model") then
					local hasUnderscore = unitModel.Name:find("_") ~= nil
					local hasUnitAttrs = unitModel:GetAttribute("UnitId") ~= nil or unitModel:GetAttribute("UnitName") ~= nil or unitModel:GetAttribute("UnitTier") ~= nil
					if hasUnderscore or hasUnitAttrs then
						print("Removing board unit:", unitModel.Name, "from", child.Name)
						unitModel:Destroy()
						totalRemoved = totalRemoved + 1
					end
				end
			end
		end
	end
	
	-- Clear units from bench spots
	for _, child in pairs(arena:GetChildren()) do
		if child.Name:find("Bench_") then
			for _, unitModel in pairs(child:GetChildren()) do
				if unitModel:IsA("Model") then
					local hasUnderscore = unitModel.Name:find("_") ~= nil
					local hasUnitAttrs = unitModel:GetAttribute("UnitId") ~= nil or unitModel:GetAttribute("UnitName") ~= nil or unitModel:GetAttribute("UnitTier") ~= nil
					if hasUnderscore or hasUnitAttrs then
						print("Removing bench unit:", unitModel.Name, "from", child.Name)
						unitModel:Destroy()
						totalRemoved = totalRemoved + 1
					end
				end
			end
		end
	end
	
	print("Cleared " .. totalRemoved .. " total units for player " .. userId)
	print("=== UnitSpawner.clearPlayerUnits SUCCESS ===")
end

-- Function to spawn all existing units for a player (used when player rejoins)
function UnitSpawner.spawnExistingUnits(userId: number, playerData: any)
	print("=== UnitSpawner.spawnExistingUnits START ===")
	print("Parameters - UserId:", userId)
	
	if not playerData then
		warn("No player data provided for spawning existing units")
		return
	end
	
	local spawnedCount = 0
	
	-- Spawn units from board state
	if playerData.boardState and playerData.boardState.grid then
		for position, unit in pairs(playerData.boardState.grid) do
			if position and unit then
				-- Skip ephemeral/summon-only units (e.g., Tank) because reinforcements are handled
				-- by ShopManager.ensureMilitaryReinforcement to avoid race conditions and duplicates.
				if unit.isSummonOnly then
					print("Skipping summon-only unit during existing spawn:", unit.name, position)
				else
					print("Spawning existing board unit:", unit.name, "at position:", position)
					local success = UnitSpawner.spawnUnitOnBoard(userId, unit, position)
					if success then
						spawnedCount = spawnedCount + 1
					end
				end
			end
		end
	end
	
	-- Spawn units from bench state
	if playerData.benchState and playerData.benchState.units then
		for unitId, unit in pairs(playerData.benchState.units) do
			if unit and unit.slot then
				print("Spawning existing bench unit:", unit.name, "at slot:", unit.slot)
				local success = UnitSpawner.spawnUnitOnBench(userId, unit, unit.slot)
				if success then
					spawnedCount = spawnedCount + 1
				end
			end
		end
	end
	
	print("Spawned " .. spawnedCount .. " existing units for player " .. userId)
	print("=== UnitSpawner.spawnExistingUnits SUCCESS ===")
end

-- Initialize unit models when the module loads
UnitSpawner.loadUnitModels()

return UnitSpawner
