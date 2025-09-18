--[[
	ArenaSpawner.luau
	Handles spawning and managing arenas for players
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local PlayerData = require(script.Parent.PlayerData)

local ArenaSpawner = {}

-- Helper: move a Model to a world position while preserving its existing orientation.
-- If the model has a PrimaryPart, we use it; otherwise we compute pivot from GetPivot.
local function moveModelPreserveOrientation(model: Instance, targetPosition: Vector3)
	if not model or not model:IsA("Model") then return end
	-- Ensure model has a pivot reference
	local pivotCFrame = model:GetPivot()
	-- Keep rotation (orientation) and only change position
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = pivotCFrame:GetComponents()
	-- Rebuild CFrame with same rotation matrix but new position
	local newCFrame = CFrame.new(targetPosition.X, targetPosition.Y, targetPosition.Z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	model:PivotTo(newCFrame)
end

-- Track baseplates for each lobby
local lobbyBaseplates = {} -- {lobbyId = baseplate}

-- Constructor
function ArenaSpawner.new(workspace, spawnPoints)
	local self = setmetatable({}, {__index = ArenaSpawner})
	self.workspace = workspace
	self.spawnPoints = spawnPoints
	return self
end

-- Function to create a baseplate for a lobby if it doesn't exist
function ArenaSpawner:createLobbyBaseplate(lobbyId: number): BasePart?
	-- Check if baseplate already exists for this lobby
	if lobbyBaseplates[lobbyId] then
		return lobbyBaseplates[lobbyId]
	end
	
	-- Don't create baseplate for lobby 1 since it already exists at (0, 0, 0)
	if lobbyId == 1 then
		return nil
	end
	
	-- Find the existing baseplate in the workspace
	local existingBaseplate = workspace:FindFirstChild("Baseplate")
	if not existingBaseplate then
		warn("No existing baseplate found in workspace")
		return nil
	end
	
	-- Clone the existing baseplate
	local baseplate = existingBaseplate:Clone()
	baseplate.Name = "LobbyBaseplate_" .. lobbyId
	
	-- Position the cloned baseplate for this lobby
	local baseplatePosition = Vector3.new(
		(lobbyId - 1) * Constants.LOBBY_SPACING, -- Start second lobby at 2000, third at 4000, etc.
		0, -- Same Y level as original baseplate
		0 -- Center of the lobby area
	)
	baseplate.Position = baseplatePosition
	
	-- Parent the baseplate to the workspace
	baseplate.Parent = workspace
	
	-- Store the baseplate reference
	lobbyBaseplates[lobbyId] = baseplate
	
	print("Cloned baseplate for lobby " .. lobbyId .. " at position " .. tostring(baseplatePosition))
	return baseplate
end

-- Function to create an arena for a player (generalized)
-- Will use player's selectedArenaName if present, else default
function ArenaSpawner:createPlayerArena(playerId: number, playerName: string, playerIndex: number): Model?
	local spawnPoints = self.spawnPoints
	if not spawnPoints then
		warn("No spawn points folder found for arena creation")
		return nil
	end
	
	-- Create player folder if it doesn't exist
	local playerFolder = spawnPoints:FindFirstChild(tostring(playerId))
	if not playerFolder then
		playerFolder = Instance.new("Folder")
		playerFolder.Name = tostring(playerId)
		playerFolder.Parent = spawnPoints
		print("Created player folder for " .. playerName .. " (ID: " .. playerId .. ")")
	end
	
	-- Determine which arena to spawn (ensure data loaded)
	local playerData = PlayerData.getPlayerData(playerId)
	if not playerData then
		-- Attempt to load (may happen if arena spawn precedes PlayerAdded data load for some reason)
		local ok, loaded = pcall(function()
			return PlayerData.loadPlayerData(playerId, playerName)
		end)
		if ok and loaded then
			playerData = loaded
			print("[ArenaSpawner] Loaded player data on-demand for " .. playerName)
		else
			warn("[ArenaSpawner] Failed to load player data on-demand for " .. playerName .. ": " .. tostring(loaded))
		end
	end
	local arenaName = (playerData and playerData.selectedArenaName) or Constants.DEFAULT_ARENA_NAME
	print("[ArenaSpawner] Spawning arena '" .. arenaName .. "' for player " .. playerName .. " (playerData present: " .. tostring(playerData ~= nil) .. ")")

	-- Fetch arena model folder
	local arenasFolder = ReplicatedStorage:FindFirstChild("Arenas")
	if not arenasFolder then
		warn("Arenas folder not found in ReplicatedStorage")
		return nil
	end

	local arenaTemplate = arenasFolder:FindFirstChild(arenaName)
	if not arenaTemplate then
		warn("Arena template '" .. arenaName .. "' not found. Falling back to default arena.")
		arenaName = Constants.DEFAULT_ARENA_NAME
		arenaTemplate = arenasFolder:FindFirstChild(arenaName)
		if not arenaTemplate then
			warn("Default arena template '" .. arenaName .. "' also not found.")
			return nil
		end
	end

	print("Cloning arena '" .. arenaName .. "' for player " .. playerName)
	local clonedArena = arenaTemplate:Clone()
	clonedArena.Name = arenaName
	
	-- Position the arena for this player based on lobby ID
	-- Each lobby gets a different position to avoid overlap
	-- Use the lobby ID from the spawnPoints parent folder name
	local lobbyFolder = self.spawnPoints.Parent
	local lobbyId = 1 -- Default to lobby 1
	if lobbyFolder and lobbyFolder.Name:find("Lobby_") then
		lobbyId = tonumber(lobbyFolder.Name:match("Lobby_(%d+)")) or 1
	end
	
	-- Ensure baseplate exists for this lobby (except lobby 1 which uses existing baseplate)
	if lobbyId > 1 then
		self:createLobbyBaseplate(lobbyId)
	end
	
	-- Use the playerIndex passed from the lobby manager for positioning
	-- This ensures arena positioning is synchronized with lobby player counts
	
	-- Calculate arena position in a 2x3 grid layout
	-- Grid layout: 2 rows (Z), 3 columns (X)
	-- Z = ARENA_SPACING/2: Players 1, 2, 3 (front row)
	-- Z = -ARENA_SPACING/2: Players 4, 5, 6 (back row)
	-- X positions: -ARENA_SPACING, 0, ARENA_SPACING (left, center, right)
	local row = math.floor((playerIndex - 1) / 3)  -- 0 or 1 (which Z level)
	local column = (playerIndex - 1) % 3  -- 0, 1, or 2 (which X position)
	
	-- Calculate arena position relative to the lobby baseplate
	local arenaPosition = Vector3.new(
		(lobbyId - 1) * Constants.LOBBY_SPACING + (column - 1) * Constants.ARENA_SPACING, -- X: lobby offset + grid X position
		Constants.GROUND_LEVEL, -- Slightly above the baseplate
		(row == 0) and Constants.ARENA_SPACING/2 or -Constants.ARENA_SPACING/2 -- Z: ARENA_SPACING/2 for front row, -ARENA_SPACING/2 for back row
	)
	
	-- Set the arena position
	if clonedArena:IsA("Model") then
		-- For Models, move while preserving original orientation from the template
		moveModelPreserveOrientation(clonedArena, arenaPosition)
		
		-- Also ensure the PrimaryPart is set if it exists
		if not clonedArena.PrimaryPart then
			-- Try to find a suitable primary part
			for _, child in pairs(clonedArena:GetChildren()) do
				if child:IsA("BasePart") then
					clonedArena.PrimaryPart = child
					break
				end
			end
		end
	else
		-- If it's a folder, try to position its children
		for _, child in pairs(clonedArena:GetChildren()) do
			if child:IsA("BasePart") then
				child.Position = child.Position + arenaPosition
			end
		end
	end
	
	-- Parent the cloned arena to the player folder
	clonedArena.Parent = playerFolder
	
	
	-- Check if Enemy Unit Board exists in the cloned arena
	local enemyUnitBoard = clonedArena:FindFirstChild("Enemy Unit Board")
	if not enemyUnitBoard then
		warn("Enemy Unit Board not found in cloned arena for player: " .. playerName)
		warn("Arena name: " .. clonedArena.Name .. ", Arena type: " .. clonedArena.ClassName)
		warn("Available children in cloned arena:")
		for _, child in pairs(clonedArena:GetChildren()) do
			warn("  - " .. child.Name .. " (" .. child.ClassName .. ")")
		end
		warn("This suggests the 'Enemy Unit Board' folder is missing from the original arena model in ReplicatedStorage")
	else
		print("Enemy Unit Board found in cloned arena for player: " .. playerName)
	end
	
	-- Debug: Print the actual position after cloning
	local actualPosition
	if clonedArena:IsA("Model") then
		actualPosition = clonedArena:GetPivot().Position
	else
		actualPosition = arenaPosition
	end
	
	print("Successfully cloned arena '" .. arenaName .. "' for player " .. playerName .. " at position " .. tostring(arenaPosition))
	print("Actual arena position: " .. tostring(actualPosition))

	-- Set up Edit Arena interaction supporting either a single BasePart or a Model named 'Edit Arena'
	local editContainer = clonedArena:FindFirstChild("Edit Arena")
	if editContainer then
		local RemoteEvents = require(script.Parent.RemoteEvents)
		local showEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_EDIT_ARENA_FRAME)
		local hideEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.HIDE_EDIT_ARENA_FRAME)
		local active = false
		local monitoring = false
		local DEBOUNCE_TIME = 1
		local lastTouch = 0

		-- Collect all base parts that should trigger interaction
		local triggerParts = {}
		if editContainer:IsA("BasePart") then
			triggerParts = {editContainer}
		elseif editContainer:IsA("Model") or editContainer:IsA("Folder") then
			for _, desc in ipairs(editContainer:GetDescendants()) do
				if desc:IsA("BasePart") then
					table.insert(triggerParts, desc)
				end
			end
		end

		if #triggerParts == 0 then
			warn("'Edit Arena' found but contains no BaseParts to trigger interaction for player " .. playerName)
		else
			print("Setting up Edit Arena interaction with " .. #triggerParts .. " trigger part(s) for player " .. playerName)
		end

		-- Helper to get representative position of container (primary part / average)
		local function getEditPosition(): Vector3
			if editContainer:IsA("BasePart") then
				return editContainer.Position
			end
			if editContainer:IsA("Model") then
				if editContainer.PrimaryPart then
					return editContainer.PrimaryPart.Position
				end
				-- compute average of all parts
				local sum = Vector3.new(0,0,0)
				local count = 0
				for _, p in ipairs(triggerParts) do
					sum += p.Position
					count += 1
				end
				if count > 0 then
					return sum / count
				end
			end
			-- fallback
			if triggerParts[1] then return triggerParts[1].Position end
			return clonedArena.PrimaryPart and clonedArena.PrimaryPart.Position or actualPosition
		end

		local function startMonitoring(player: Player, humanoidRootPart: BasePart)
			if monitoring then return end
			monitoring = true
			spawn(function()
				while active and humanoidRootPart.Parent and humanoidRootPart.Parent.Parent do
					local distance = (humanoidRootPart.Position - getEditPosition()).Magnitude
					if distance > 20 then
						if hideEvent then hideEvent:FireClient(player) end
						active = false
						break
					end
					wait(0.5)
				end
				monitoring = false
			end)
		end

		local function onTouched(hit: BasePart)
			local now = os.clock()
			if now - lastTouch < DEBOUNCE_TIME then return end
			local character = hit.Parent
			if not character then return end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid then return end
			local player = game.Players:GetPlayerFromCharacter(character)
			if not player or player.UserId ~= playerId then return end
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if not hrp then return end
			lastTouch = now
			if not active then
				active = true
				if showEvent then showEvent:FireClient(player) end
				startMonitoring(player, hrp)
			else
				startMonitoring(player, hrp)
			end
		end

		for _, part in ipairs(triggerParts) do
			part.Touched:Connect(onTouched)
		end
	else
		print("No 'Edit Arena' part/model found in arena '" .. arenaName .. "' for player " .. playerName)
	end
	return clonedArena
end

-- Function to remove arena for a player
function ArenaSpawner:removeArena(playerId: number)
	local spawnPoints = self.spawnPoints
	if not spawnPoints then
		return
	end
	
	local playerFolder = spawnPoints:FindFirstChild(tostring(playerId))
	if playerFolder then
		playerFolder:Destroy()
		print("Removed arena for player ID: " .. playerId)
	end
	
	-- Check if this was the last arena in the lobby and cleanup baseplate if needed
	local lobbyFolder = self.spawnPoints.Parent
	if lobbyFolder and lobbyFolder.Name:find("Lobby_") then
		local lobbyId = tonumber(lobbyFolder.Name:match("Lobby_(%d+)")) or 1
		local remainingArenas = 0
		
		-- Count remaining arenas in this lobby
		for _, child in pairs(spawnPoints:GetChildren()) do
			-- Count if any child contains an arena (child with name ending in ' Arena')
			for _, arenaChild in pairs(child:GetChildren()) do
				if arenaChild.Name:match("%sArena$") then
				remainingArenas = remainingArenas + 1
				break
			end
			end
		end
		
		-- If no arenas left and this lobby has a custom baseplate (not lobby 1), cleanup the baseplate
		if remainingArenas == 0 and lobbyId > 1 and lobbyBaseplates[lobbyId] then
			lobbyBaseplates[lobbyId]:Destroy()
			lobbyBaseplates[lobbyId] = nil
			print("Cleaned up baseplate for lobby " .. lobbyId .. " - no more arenas")
		end
	end
end

-- Function to get arena for a player
function ArenaSpawner:getArena(playerId: number): Folder?
	local spawnPoints = self.spawnPoints
	if not spawnPoints then
		return nil
	end
	
	local playerFolder = spawnPoints:FindFirstChild(tostring(playerId))
	if not playerFolder then
		return nil
	end
	-- Return first child whose name ends with ' Arena'
	for _, child in pairs(playerFolder:GetChildren()) do
		if child.Name:match("%sArena$") then
			return child
		end
	end
	return nil
end

-- Internal helper: copy units from old arena to new arena (board + bench spots)
local function transferUnits(oldArena: Instance?, newArena: Instance?)
	if not oldArena or not newArena then return end

	-- Build lookup for destination parts (Hex_*_* and Bench_*)
	local destHexes = {}
	local destBenches = {}
	for _, child in ipairs(newArena:GetChildren()) do
		if child:IsA("BasePart") then
			local name = child.Name
			if name:match("^Hex_%d+_%d+$") then
				destHexes[name] = child
			elseif name:match("^Bench_%d+$") then
				destBenches[name] = child
			end
		end
	end

	-- Move unit models
	for _, child in ipairs(oldArena:GetChildren()) do
		if child:IsA("BasePart") then
			-- skip plain parts
		elseif child:IsA("Folder") or child:IsA("Model") then
			-- Skip enemy board container etc., only move actual unit models parented to hex or bench parts
		end
	end

	-- Units are parented under the hex/bench parts. We iterate those parts in old arena.
	for _, part in ipairs(oldArena:GetChildren()) do
		if part:IsA("BasePart") then
			local pname = part.Name
			if pname:match("^Hex_%d+_%d+$") or pname:match("^Bench_%d+$") then
				local destPart = destHexes[pname] or destBenches[pname]
				if destPart then
					for _, unitModel in ipairs(part:GetChildren()) do
						if unitModel:IsA("Model") then
							unitModel.Parent = destPart
						end
					end
				end
			end
		end
	end
end

-- Switch the player's arena to a new template name, preserving units (if possible)
function ArenaSpawner:switchArenaForPlayer(playerId: number, newArenaName: string): boolean
	local spawnPoints = self.spawnPoints
	if not spawnPoints then return false end
	local playerFolder = spawnPoints:FindFirstChild(tostring(playerId))
	if not playerFolder then return false end

	-- Find current arena (first child with name ending in ' Arena')
	local currentArena
	for _, child in ipairs(playerFolder:GetChildren()) do
		if child.Name:match("%sArena$") then
			currentArena = child
			break
		end
	end

	-- If already that arena, nothing to do
	if currentArena and currentArena.Name == newArenaName then
		return true
	end

	-- Get template
	local arenasFolder = ReplicatedStorage:FindFirstChild("Arenas")
	if not arenasFolder then
		warn("Arenas folder missing when switching arena")
		return false
	end
	local template = arenasFolder:FindFirstChild(newArenaName)
	if not template then
		warn("Arena template '" .. newArenaName .. "' not found")
		return false
	end

	-- Clone new arena
	local newArena = template:Clone()
	newArena.Name = newArenaName

	-- Preserve only the POSITION from current arena; keep the new template's original orientation
	local targetPosition: Vector3? = nil
	if currentArena and currentArena:IsA("Model") then
		targetPosition = currentArena:GetPivot().Position
	elseif currentArena and currentArena:IsA("Folder") then
		-- fallback: average parts
		local sum = Vector3.new(0,0,0); local count = 0
		for _, d in ipairs(currentArena:GetDescendants()) do
			if d:IsA("BasePart") then sum += d.Position; count += 1 end
		end
		if count > 0 then targetPosition = sum / count end
	end

	if not targetPosition and currentArena then
		for _, d in ipairs(currentArena:GetChildren()) do
			if d:IsA("BasePart") then targetPosition = d.Position; break end
		end
	end

	-- Place new arena before deleting old, then move while preserving its own template orientation
	newArena.Parent = playerFolder
	if newArena:IsA("Model") and targetPosition then
		moveModelPreserveOrientation(newArena, targetPosition)
	end

	-- Transfer units
	if currentArena then
		transferUnits(currentArena, newArena)
		currentArena:Destroy()
	end

	-- Re-establish Edit Arena interactions on new arena (reuse logic by calling portion of createPlayerArena logic)
	local editContainer = newArena:FindFirstChild("Edit Arena")
	if editContainer then
		local RemoteEvents = require(script.Parent.RemoteEvents)
		local showEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.SHOW_EDIT_ARENA_FRAME)
		local hideEvent = RemoteEvents.getEvent(Constants.REMOTE_EVENT_NAMES.HIDE_EDIT_ARENA_FRAME)
		local active = false
		local monitoring = false
		local DEBOUNCE_TIME = 1
		local lastTouch = 0
		local triggerParts = {}
		if editContainer:IsA("BasePart") then
			triggerParts = {editContainer}
		else
			for _, desc in ipairs(editContainer:GetDescendants()) do
				if desc:IsA("BasePart") then table.insert(triggerParts, desc) end
			end
		end
		local function getEditPosition(): Vector3
			if editContainer:IsA("BasePart") then return editContainer.Position end
			if editContainer:IsA("Model") and editContainer.PrimaryPart then return editContainer.PrimaryPart.Position end
			if triggerParts[1] then return triggerParts[1].Position end
			return newArena:IsA("Model") and newArena:GetPivot().Position or Vector3.new()
		end
		local function startMonitoring(player: Player, humanoidRootPart: BasePart)
			if monitoring then return end
			monitoring = true
			spawn(function()
				while active and humanoidRootPart.Parent and humanoidRootPart.Parent.Parent do
					local distance = (humanoidRootPart.Position - getEditPosition()).Magnitude
					if distance > 20 then
						if hideEvent then hideEvent:FireClient(player) end
						active = false
						break
					end
					wait(0.5)
				end
				monitoring = false
			end)
		end
		local function onTouched(hit: BasePart)
			local now = os.clock()
			if now - lastTouch < DEBOUNCE_TIME then return end
			local character = hit.Parent
			if not character then return end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid then return end
			local player = game.Players:GetPlayerFromCharacter(character)
			if not player or player.UserId ~= playerId then return end
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if not hrp then return end
			lastTouch = now
			if not active then
				active = true
				if showEvent then showEvent:FireClient(player) end
				startMonitoring(player, hrp)
			else
				startMonitoring(player, hrp)
			end
		end
		for _, part in ipairs(triggerParts) do
			part.Touched:Connect(onTouched)
		end
	end

	return true
end

-- Function to get enemy board for a player
function ArenaSpawner:getEnemyBoard(playerId: number): Folder?
	local grassArena = self:getArena(playerId)
	if not grassArena then
		return nil
	end
	
	-- Look for Enemy Unit Board folder in the cloned arena
	return grassArena:FindFirstChild("Enemy Unit Board")
end

-- Function to get a specific hex on the player's board
function ArenaSpawner:getBoardHex(playerId: number, row: number, col: number): Part?
	local grassArena = self:getArena(playerId)
	if not grassArena then
		return nil
	end
	
	local hexName = string.format("Hex_%d_%d", row, col)
	return grassArena:FindFirstChild(hexName)
end

-- Function to get a specific hex on the enemy board
function ArenaSpawner:getEnemyHex(playerId: number, row: number, col: number): Part?
	local enemyBoard = self:getEnemyBoard(playerId)
	if not enemyBoard then
		return nil
	end
	
	local hexName = string.format("Hex_%d_%d", row, col)
	return enemyBoard:FindFirstChild(hexName)
end

-- Function to get a specific bench spot
function ArenaSpawner:getBenchSpot(userId: number, benchIndex: number): Part?
	local grassArena = self:getArena(userId)
	if not grassArena then
		return nil
	end
	
	local benchName = string.format("Bench_%d", benchIndex)
	return grassArena:FindFirstChild(benchName)
end

-- Function to cleanup baseplate for a specific lobby
function ArenaSpawner:cleanupLobbyBaseplate(lobbyId: number)
	-- Don't cleanup baseplate for lobby 1 since it's the original baseplate
	if lobbyId == 1 then
		return
	end
	
	if lobbyBaseplates[lobbyId] then
		lobbyBaseplates[lobbyId]:Destroy()
		lobbyBaseplates[lobbyId] = nil
		print("Cleaned up baseplate for lobby " .. lobbyId)
	end
end

-- Initialize arena spawning for all existing players
function ArenaSpawner.init()
	print("Arena Spawner initialized - will clone existing arena models from ReplicatedStorage")
end

return ArenaSpawner
