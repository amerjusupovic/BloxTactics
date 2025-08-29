--[[
	UnitSpawner.luau
	Server-side unit model spawning and management
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local UnitSpawner = {}

-- Cache for unit models
local unitModels = {}

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
	local spawnPointsFolder = Workspace:FindFirstChild("SpawnPoints")
	if not spawnPointsFolder then
		warn("SpawnPoints folder not found in Workspace!")
		return nil
	end
	
	local playerFolder = spawnPointsFolder:FindFirstChild(tostring(userId))
	if not playerFolder then
		warn("Player folder not found for userId: " .. userId)
		return nil
	end
	
	-- Find the board hex
	local hexName = string.format("Hex_%d_%d", position.Y + 1, position.X + 1)
	local hex = playerFolder:FindFirstChild(hexName)
	if not hex then
		warn("Board hex not found: " .. hexName)
		return nil
	end
	
	-- Get unit model
	local unitModel = UnitSpawner.getUnitModel(unit.name)
	if not unitModel then
		warn("Unit model not found for: " .. unit.name)
		return nil
	end
	
	-- Clone and position the unit model
	local spawnedUnit = unitModel:Clone()
	spawnedUnit.Name = unit.name .. "_" .. unit.id
	
	-- Scale unit based on tier
	local UnitDatabase = require(game.ReplicatedStorage.Shared.UnitDatabase)
	local sizeScale = UnitDatabase.calculateUnitSizeScale(unit.tier)
	
	-- Scale the entire model uniformly
	-- Get the model's current pivot point
	local originalPivot = spawnedUnit:GetPivot()
	
	-- Scale all parts in the model uniformly
	for _, part in pairs(spawnedUnit:GetDescendants()) do
		if part:IsA("BasePart") then
			-- Scale the part size
			part.Size = part.Size * sizeScale
			
			-- Scale the part's position relative to the model's pivot
			local relativePosition = part.Position - originalPivot.Position
			part.Position = originalPivot.Position + (relativePosition * sizeScale)
		end
	end
	
	-- Position the unit at the hex location
	-- Adjust Y position to be on top of the hex
	local hexCFrame = hex.CFrame
	
	-- Calculate unit height and position so feet touch the hex surface
	local unitSize = spawnedUnit:GetExtentsSize()
	local unitHeight = unitSize.Y
	-- Position the unit so its bottom (feet) touches the hex surface
	-- The model's center should be positioned at half the unit height above the hex
	local heightOffset = unitHeight / 2
	
	-- Create CFrame with position and rotation to face forward
	local adjustedCFrame = CFrame.new(hexCFrame.Position + Vector3.new(0, heightOffset, 0)) * CFrame.Angles(0, math.rad(180), 0)
	spawnedUnit:PivotTo(adjustedCFrame)
	
	-- Store unit data in the model
	spawnedUnit:SetAttribute("UnitId", unit.id)
	spawnedUnit:SetAttribute("UnitName", unit.name)
	spawnedUnit:SetAttribute("UnitTier", unit.tier)
	spawnedUnit:SetAttribute("PositionX", position.X)
	spawnedUnit:SetAttribute("PositionY", position.Y)
	
	-- Parent to the hex
	spawnedUnit.Parent = hex
	
	print("Spawned unit " .. unit.name .. " on board at position: " .. tostring(position))
	return spawnedUnit
end

-- Function to spawn unit on bench
function UnitSpawner.spawnUnitOnBench(userId: number, unit: any, benchSlot: number)
	print("Attempting to spawn unit on bench - UserId:", userId, "Unit:", unit.name, "Slot:", benchSlot)
	
	local spawnPointsFolder = Workspace:FindFirstChild("SpawnPoints")
	if not spawnPointsFolder then
		warn("SpawnPoints folder not found in Workspace!")
		return nil
	end
	
	local playerFolder = spawnPointsFolder:FindFirstChild(tostring(userId))
    if not playerFolder then
		warn("Player folder not found for userId: " .. userId)
		return nil
	end
	
	-- Find the bench slot
	local benchName = string.format("Bench_%d", benchSlot)
	local bench = playerFolder:FindFirstChild(benchName)
	if not bench then
		warn("Bench slot not found: " .. benchName .. " in player folder: " .. tostring(userId))
		return nil
	end
	
	-- Get unit model
	local unitModel = UnitSpawner.getUnitModel(unit.name)
	if not unitModel then
		warn("Unit model not found for: " .. unit.name)
		return nil
	end
	
	-- Clone and position the unit model
	local spawnedUnit = unitModel:Clone()
	spawnedUnit.Name = unit.name .. "_" .. unit.id
	
	-- Scale unit based on tier
	local UnitDatabase = require(game.ReplicatedStorage.Shared.UnitDatabase)
	local sizeScale = UnitDatabase.calculateUnitSizeScale(unit.tier)
	
	-- Scale the entire model uniformly
	-- Get the model's current pivot point
	local originalPivot = spawnedUnit:GetPivot()
	
	-- Scale all parts in the model uniformly
	for _, part in pairs(spawnedUnit:GetDescendants()) do
		if part:IsA("BasePart") then
			-- Scale the part size
			part.Size = part.Size * sizeScale
			
			-- Scale the part's position relative to the model's pivot
			local relativePosition = part.Position - originalPivot.Position
			part.Position = originalPivot.Position + (relativePosition * sizeScale)
		end
	end
	
	-- Position the unit at the bench location
	-- Adjust Y position to be on top of the bench
	local benchCFrame = bench.CFrame
	
	-- Calculate unit height and position so feet touch the bench surface
	local unitSize = spawnedUnit:GetExtentsSize()
	local unitHeight = unitSize.Y
	-- Position the unit so its bottom (feet) touches the bench surface
	-- The model's center should be positioned at half the unit height above the bench
	local heightOffset = unitHeight / 2
	
	-- Create CFrame with position and rotation to face forward
	local adjustedCFrame = CFrame.new(benchCFrame.Position + Vector3.new(0, heightOffset, 0)) * CFrame.Angles(0, math.rad(180), 0)
	spawnedUnit:PivotTo(adjustedCFrame)
	
	-- Store unit data in the model
	spawnedUnit:SetAttribute("UnitId", unit.id)
	spawnedUnit:SetAttribute("UnitName", unit.name)
	spawnedUnit:SetAttribute("UnitTier", unit.tier)
	spawnedUnit:SetAttribute("BenchSlot", benchSlot)
	
	-- Parent to the bench slot
	spawnedUnit.Parent = bench
	
	print("Successfully spawned unit " .. unit.name .. " on bench at slot: " .. benchSlot)
	return spawnedUnit
end

-- Function to remove unit from board
function UnitSpawner.removeUnitFromBoard(userId: number, position: Vector2)
	local spawnPointsFolder = Workspace:FindFirstChild("SpawnPoints")
	local playerFolder = spawnPointsFolder:FindFirstChild(tostring(userId))
    if not playerFolder then return end
	
	local hexName = string.format("Hex_%d_%d", position.Y + 1, position.X + 1)
	local hex = playerFolder:FindFirstChild(hexName)
	if not hex then return end
	
	-- Remove all unit models from this hex
	for _, child in pairs(hex:GetChildren()) do
		if child:IsA("Model") and child.Name:find("_") then
			child:Destroy()
		end
	end
end

-- Function to remove unit from bench
function UnitSpawner.removeUnitFromBench(userId: number, benchSlot: number)
	local spawnPointsFolder = Workspace:FindFirstChild("SpawnPoints")
	local playerFolder = spawnPointsFolder and spawnPointsFolder:FindFirstChild(tostring(userId))
    if not playerFolder then return end
	
	local benchName = string.format("Bench_%d", benchSlot)
	local bench = playerFolder:FindFirstChild(benchName)
	if not bench then return end
	
	-- Remove all unit models from this bench slot
	for _, child in pairs(bench:GetChildren()) do
		if child:IsA("Model") and child.Name:find("_") then
			child:Destroy()
		end
	end
end

-- Function to move unit between bench slots
function UnitSpawner.moveUnitBetweenBenchSlots(userId: number, fromSlot: number, toSlot: number)
	local spawnPointsFolder = Workspace:FindFirstChild("SpawnPoints")
	local playerFolder = spawnPointsFolder and spawnPointsFolder:FindFirstChild(tostring(userId))
    if not playerFolder then return end
	
	local fromBenchName = string.format("Bench_%d", fromSlot)
	local toBenchName = string.format("Bench_%d", toSlot)
	local fromBench = playerFolder:FindFirstChild(fromBenchName)
	local toBench = playerFolder:FindFirstChild(toBenchName)
	
	if not fromBench or not toBench then return end
	
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
		
		-- Reposition the unit at the new bench location
		local benchCFrame = toBench.CFrame
		local unitSize = unitModel:GetExtentsSize()
		local unitHeight = unitSize.Y
		local heightOffset = unitHeight / 2
		-- Create CFrame with position and rotation to face forward
		local adjustedCFrame = CFrame.new(benchCFrame.Position + Vector3.new(0, heightOffset, 0)) * CFrame.Angles(0, math.rad(180), 0)
		unitModel:PivotTo(adjustedCFrame)
		
		print("Moved unit from bench slot", fromSlot, "to bench slot", toSlot)
	end
end

-- Function to clear all units for a player
function UnitSpawner.clearPlayerUnits(userId: number)
	-- Check both possible folder structures
	local spawnPointsFolder = Workspace:FindFirstChild("SpawnPoints")
	local spawnPointsFolder = Workspace:FindFirstChild("SpawnPoints")
	
	-- Clear units from SpawnPoints folder (board)
	if spawnPointsFolder then
		local playerFolder = spawnPointsFolder:FindFirstChild(tostring(userId))
		if playerFolder then
			for _, child in pairs(playerFolder:GetChildren()) do
				if child.Name:find("Hex_") then
					for _, unitModel in pairs(child:GetChildren()) do
						if unitModel:IsA("Model") and unitModel.Name:find("_") then
							unitModel:Destroy()
						end
					end
				end
			end
		end
	end
	
	-- Clear units from SpawnPoints folder (bench)
	if spawnPointsFolder then
		local playerFolder = spawnPointsFolder:FindFirstChild(tostring(userId))
		if playerFolder then
			for _, child in pairs(playerFolder:GetChildren()) do
				if child.Name:find("Bench_") then
					for _, unitModel in pairs(child:GetChildren()) do
						if unitModel:IsA("Model") and unitModel.Name:find("_") then
							unitModel:Destroy()
						end
					end
				end
			end
		end
	end
end

-- Initialize unit models when the module loads
UnitSpawner.loadUnitModels()

return UnitSpawner
