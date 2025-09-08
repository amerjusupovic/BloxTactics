--[[
	PVPChallengeUI.luau
	Client-side PVP challenge UI management
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _TweenService = game:GetService("TweenService")
local _UserInputService = game:GetService("UserInputService")

-- Load shared modules
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local DataStructures = require(game.ReplicatedStorage.Shared.DataStructures)
local UnitMovement = require(game.ReplicatedStorage.Shared.UnitMovement)

local PVPChallengeUI = {}

-- UI elements
local pvpBoardFrame = nil
local pvpBenchFrame = nil
local pvpCountdownLabel = nil
local currentChallengeId = nil
local countdownTimer = nil
local battleCountdownVisual = nil
local originalCountdownVisualPosition = nil

-- PVP state storage
local currentPVPBoardState = nil
local currentPVPBenchState = nil

-- Unit selection state is now handled by UnitMovement module

-- ScreenGui containers
local pvpFramesScreenGui = nil


-- Create PVP board and bench frames
function PVPChallengeUI.createPVPFrames()
	if pvpBoardFrame then
		pvpBoardFrame:Destroy()
	end
	if pvpBenchFrame then
		pvpBenchFrame:Destroy()
	end
	if pvpFramesScreenGui then
		pvpFramesScreenGui:Destroy()
	end
	
	print("DEBUG: Creating PVP frames...")
	
	-- Get the existing UI from ReplicatedStorage
	local existingUI = ReplicatedStorage:FindFirstChild("BloxTacticsUITemplate")
	if not existingUI then
		warn("DEBUG: BloxTacticsUITemplate not found in ReplicatedStorage!")
		return
	end
	
	local mainFrame = existingUI:FindFirstChild("MainFrame")
	if not mainFrame then
		warn("DEBUG: MainFrame not found in UI!")
		return
	end
	
	-- Clone PVPBoardFrame and PVPBenchFrame
	local templatePVPBoardFrame = mainFrame:FindFirstChild("PVPBoardFrame")
	local templatePVPBenchFrame = mainFrame:FindFirstChild("PVPBenchFrame")
	
	if not templatePVPBoardFrame or not templatePVPBenchFrame then
		warn("DEBUG: PVPBoardFrame or PVPBenchFrame not found in MainFrame!")
		print("DEBUG: Available frames in MainFrame:")
		for _, child in pairs(mainFrame:GetChildren()) do
			print("  - " .. child.Name)
		end
		return
	end
	
	-- Create ScreenGui container
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	pvpFramesScreenGui = Instance.new("ScreenGui")
	pvpFramesScreenGui.Name = "PVPFramesScreenGui"
	pvpFramesScreenGui.Parent = playerGui
	
	-- Clone the frames
	pvpBoardFrame = templatePVPBoardFrame:Clone()
	pvpBenchFrame = templatePVPBenchFrame:Clone()
	
	-- Find and store the BattleCountdownVisual frame
	battleCountdownVisual = pvpBenchFrame:FindFirstChild("BattleCountdownVisual")
	if battleCountdownVisual then
		originalCountdownVisualPosition = battleCountdownVisual.Position
		print("DEBUG: Found BattleCountdownVisual and stored original position")
	else
		warn("DEBUG: BattleCountdownVisual not found in PVPBenchFrame!")
		-- List available children for debugging
		print("Available children in PVPBenchFrame:")
		for _, child in pairs(pvpBenchFrame:GetChildren()) do
			print("  - " .. child.Name .. " (" .. child.ClassName .. ")")
		end
	end
	
	-- Parent frames to ScreenGui
	pvpBoardFrame.Parent = pvpFramesScreenGui
	pvpBenchFrame.Parent = pvpFramesScreenGui
	
	-- Get the countdown label
	pvpCountdownLabel = pvpBoardFrame:FindFirstChild("PVPCountdownLabel")
	if pvpCountdownLabel then
		print("DEBUG: Found PVPCountdownLabel")
	else
		warn("DEBUG: PVPCountdownLabel not found in PVPBoardFrame!")
	end
	
	-- Hide initially
	pvpBoardFrame.Visible = false
	pvpBenchFrame.Visible = false
	
	-- Create board hexes for PVP frames using shared module
	UnitMovement.createBoardHexes(pvpBoardFrame, function(hex, position)
		UnitMovement.handleHexClick(hex, position, PVPChallengeUI.requestUnitMove, "PVP board")
	end, "PVP board")
	
	-- Create bench hexes for PVP frames using shared module
	UnitMovement.createBenchHexes(pvpBenchFrame, function(hex, position)
		UnitMovement.handleHexClick(hex, position, PVPChallengeUI.requestUnitMove, "PVP bench")
	end, "PVP bench")
	
	print("DEBUG: PVP frames created successfully with ScreenGui")
	return pvpBoardFrame, pvpBenchFrame
end

-- PVP board and bench hexes are now created using the shared UnitMovement module

-- Show PVP frames with board and bench data
function PVPChallengeUI.showPVPFrames(boardState: DataStructures.BoardState, benchState: DataStructures.BenchState)
	print("DEBUG: Showing PVP frames with board and bench data")
	
	if not pvpBoardFrame or not pvpBenchFrame then
		print("DEBUG: Creating PVP frames...")
		PVPChallengeUI.createPVPFrames()
	end
	
	-- Store the PVP states for later use
	currentPVPBoardState = boardState
	currentPVPBenchState = benchState
	print("DEBUG: Stored PVP board and bench states")
	
	-- Populate the frames with current board and bench data
	PVPChallengeUI.updatePVPBoardDisplay(boardState)
	PVPChallengeUI.updatePVPBenchDisplay(benchState)
	print("DEBUG: Updated PVP board and bench displays")
	
	-- Reset BattleCountdownVisual position to original before showing
	if battleCountdownVisual and originalCountdownVisualPosition then
		battleCountdownVisual.Position = originalCountdownVisualPosition
		print("DEBUG: Reset BattleCountdownVisual to original position")
	end
	
	-- Show the frames
	pvpBoardFrame.Visible = true
	pvpBenchFrame.Visible = true
	print("DEBUG: Made PVP frames visible")
	
	-- Show countdown label
	if pvpCountdownLabel then
		pvpCountdownLabel.Visible = true
		print("DEBUG: Made countdown label visible")
	else
		warn("DEBUG: Countdown label not found!")
	end
end

-- Hide PVP frames
function PVPChallengeUI.hidePVPFrames()
	if pvpBoardFrame then
		pvpBoardFrame.Visible = false
	end
	if pvpBenchFrame then
		pvpBenchFrame.Visible = false
		-- Reset position when hiding frames
		-- This will be restored when frames are shown again
	end
	if pvpCountdownLabel then
		pvpCountdownLabel.Visible = false
	end
	
	-- Clear selection when hiding frames
	UnitMovement.clearSelection()
end

-- Update PVP board display
function PVPChallengeUI.updatePVPBoardDisplay(boardState: DataStructures.BoardState)
	if not pvpBoardFrame or not boardState or not boardState.grid then
		return
	end
	
	-- Clear selection when board is updated
	UnitMovement.clearSelection()
	
	-- Clear existing units
	for _, child in pairs(pvpBoardFrame:GetChildren()) do
		if child:IsA("ImageButton") and child.Name:find("Hex_") then
			-- Clear any unit visuals in this hex
			for _, unitVisual in pairs(child:GetChildren()) do
				if unitVisual:IsA("ImageButton") and unitVisual ~= child then
					unitVisual:Destroy()
				end
			end
		end
	end
	
	-- Place units from board state
	for position, unit in pairs(boardState.grid) do
		if position and unit then
			PVPChallengeUI.placeUnitOnPVPBoard(unit, position)
		end
	end
end

-- Update PVP bench display
function PVPChallengeUI.updatePVPBenchDisplay(benchState: DataStructures.BenchState)
	if not pvpBenchFrame or not benchState or not benchState.units then
		return
	end
	
	-- Clear existing units
	for _, child in pairs(pvpBenchFrame:GetChildren()) do
		if child:IsA("ImageButton") and child.Name:find("BenchHex_") then
			-- Clear any unit visuals in this hex
			for _, unitVisual in pairs(child:GetChildren()) do
				if unitVisual:IsA("ImageButton") and unitVisual ~= child then
					unitVisual:Destroy()
				end
			end
		end
	end
	
	-- Place units from bench state
	local units = {}
	for unitId, unit in pairs(benchState.units) do
		if unit then
			table.insert(units, unit)
		end
	end
	
	-- Sort units by their slot to maintain correct order
	table.sort(units, function(a, b)
		return (a.slot or 0) < (b.slot or 0)
	end)
	
	-- Place units in their correct slots
	for _, unit in ipairs(units) do
		local slot = unit.slot or 1
		if slot <= benchState.maxCapacity then
			PVPChallengeUI.placeUnitOnPVPBench(unit, slot)
		end
	end
end

-- Place unit on PVP board
function PVPChallengeUI.placeUnitOnPVPBoard(unit: DataStructures.Unit, position: Vector2)
	if not pvpBoardFrame or not position then
		return
	end
	
	-- Handle position parsing (same logic as regular UI)
	local x, y
	if typeof(position) == "Vector2" then
		x = position.X
		y = position.Y
	elseif typeof(position) == "table" then
		x = position.X or position.x
		y = position.Y or position.y
	elseif typeof(position) == "string" then
		local match = string.match(position, "%(([^%)]+)%)")
		if match then
			local parts = {}
			for part in string.gmatch(match, "[^,]+") do
				table.insert(parts, part:match("^%s*(%-?%d+)%s*$"))
			end
			if #parts >= 2 and parts[1] and parts[2] then
				x = tonumber(parts[1])
				y = tonumber(parts[2])
			else
				return
			end
		else
			return
		end
	else
		return
	end
	
	if not x or not y then
		return
	end
	
	-- Convert to hex naming
	local _rows = Constants.BOARD_HEIGHT
	local hexRow = y + 1
	local hexCol = x + 1
	local hexName = string.format("Hex_%d_%d", hexRow, hexCol)
	local hex = pvpBoardFrame:FindFirstChild(hexName)
	
	if hex then
		-- Create unit visual using shared module
		local _unitVisual = UnitMovement.createUnitVisual(hex, unit, x, y, nil, "PVP board")
	end
end

-- Place unit on PVP bench
function PVPChallengeUI.placeUnitOnPVPBench(unit: DataStructures.Unit, benchSlot: number)
	if not pvpBenchFrame or not benchSlot or benchSlot <= 0 then
		return
	end
	
	local hexName = string.format("BenchHex_%d", benchSlot)
	local hex = pvpBenchFrame:FindFirstChild(hexName)
	
	if hex then
		-- Create unit visual using shared module
		local _unitVisual = UnitMovement.createUnitVisual(hex, unit, nil, nil, benchSlot, "PVP bench")
	end
end


-- Start PVP countdown timer
function PVPChallengeUI.startPVPCountdown(duration: number)
	print("DEBUG: Starting PVP countdown with duration: " .. duration .. " seconds")
	
	if countdownTimer then
		countdownTimer:Disconnect()
	end
	
	local timeRemaining = duration
	local lastUpdateTime = tick()
	local startTime = tick()
	
	-- Use stored original position for animation
	local initialPosition = originalCountdownVisualPosition
	if initialPosition then
		print("DEBUG: Using original BattleCountdownVisual position for animation: " .. tostring(initialPosition))
	else
		warn("DEBUG: No original position stored for BattleCountdownVisual animation!")
	end
	
	-- Update the countdown label immediately
	if pvpCountdownLabel then
		pvpCountdownLabel.Text = "Battle starting in: " .. timeRemaining .. "s"
	end
	
	countdownTimer = game:GetService("RunService").Heartbeat:Connect(function()
		local currentTime = tick()
		local elapsedTime = currentTime - startTime
		
		-- Animate BattleCountdownVisual moving left over the duration
		if battleCountdownVisual and initialPosition then
			local progress = math.min(elapsedTime / duration, 1) -- Progress from 0 to 1
			
			-- Calculate target position (completely off-screen to the left)
			-- Move the frame completely off-screen by setting X scale to -1 (or more negative)
			local targetX = -2.05 -- Move completely off-screen to the left
			
			-- Smooth animation using easing
			local easedProgress = 1 - math.pow(1 - progress, 3) -- Ease-out cubic
			local currentX = initialPosition.X.Scale + (targetX - initialPosition.X.Scale) * easedProgress
			
			battleCountdownVisual.Position = UDim2.new(currentX, initialPosition.X.Offset, initialPosition.Y.Scale, initialPosition.Y.Offset)
		end
		
		-- Only update every second
		if currentTime - lastUpdateTime >= 1 then
			lastUpdateTime = currentTime
			timeRemaining = timeRemaining - 1
			
			if timeRemaining <= 0 then
				print("DEBUG: Countdown finished, starting battle")
				-- Disconnect the timer to prevent further calls
				if countdownTimer then
					countdownTimer:Disconnect()
					countdownTimer = nil
				end
				-- Countdown finished, hide PVP frames and start battle
				PVPChallengeUI.hidePVPFrames()
				PVPChallengeUI.startBattle()
				return
			end
		
			if pvpCountdownLabel then
				pvpCountdownLabel.Text = "Battle starting in: " .. timeRemaining .. "s"
			else
				warn("DEBUG: Countdown label not found during countdown!")
			end
		end
	end)
end

-- Start battle (teleport players and populate boards)
function PVPChallengeUI.startBattle()
	-- Send battle start request to server
	local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
	local startBattleEvent = remoteEventsFolder:WaitForChild(Constants.REMOTE_EVENT_NAMES.START_BATTLE)
	startBattleEvent:FireServer(currentChallengeId)
end

-- Update player's board with their PVP board state
function PVPChallengeUI.updatePlayerBoardFromPVP()
	-- Get the current PVP board and bench states
	local pvpBoardState = PVPChallengeUI.getCurrentPVPBoardState()
	local pvpBenchState = PVPChallengeUI.getCurrentPVPBenchState()
	
	if pvpBoardState and pvpBenchState then
		-- Update the main UI with the PVP states
		local UI = require(script.Parent.UI)
		UI.updateBoardDisplay(pvpBoardState)
		UI.updateBenchDisplay(pvpBenchState)
		
		print("Updated player board from PVP state")
	end
end

-- Get current PVP board state (stored from when PVP frames were shown)
function PVPChallengeUI.getCurrentPVPBoardState()
	return currentPVPBoardState
end

-- Get current PVP bench state (stored from when PVP frames were shown)
function PVPChallengeUI.getCurrentPVPBenchState()
	return currentPVPBenchState
end

-- Function to request unit move from server (used by shared UnitMovement module)
function PVPChallengeUI.requestUnitMove(unit: any, fromPosition: Vector2, toPosition: Vector2)
	local moveUnitEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("MoveUnit")
	if moveUnitEvent then
		moveUnitEvent:FireServer(fromPosition, toPosition)
	else
		warn("MoveUnit RemoteEvent not found!")
	end
end


-- Challenge another player
function PVPChallengeUI.challengePlayer(targetPlayerId: number)
	local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
	local challengePlayerEvent = remoteEventsFolder:WaitForChild(Constants.REMOTE_EVENT_NAMES.CHALLENGE_PLAYER)
	challengePlayerEvent:FireServer(targetPlayerId)
end

-- Initialize PVP Challenge UI
function PVPChallengeUI.init()
	print("DEBUG: Initializing PVP Challenge UI...")
	
	-- Create UI elements
	PVPChallengeUI.createPVPFrames()
	
	-- Set up RemoteEvent handlers
	local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
	
	-- Handle PVP frames show (new event for showing PVP board/bench)
	local showPVPFramesEvent = remoteEventsFolder:WaitForChild(Constants.REMOTE_EVENT_NAMES.SHOW_PVP_FRAMES)
	showPVPFramesEvent.OnClientEvent:Connect(function(challengeId, boardState, benchState, countdownTime)
		print("DEBUG: Received show PVP frames event")
		currentChallengeId = challengeId
		PVPChallengeUI.showPVPFrames(boardState, benchState)
		PVPChallengeUI.startPVPCountdown(countdownTime)
	end)
	
	-- Handle PVP frames update
	local updatePVPFramesEvent = remoteEventsFolder:WaitForChild(Constants.REMOTE_EVENT_NAMES.UPDATE_PVP_FRAMES)
	updatePVPFramesEvent.OnClientEvent:Connect(function(boardState, benchState)
		print("DEBUG: Received PVP frames update event")
		-- Update the PVP frames with the new board and bench state
		PVPChallengeUI.updatePVPBoardDisplay(boardState)
		PVPChallengeUI.updatePVPBenchDisplay(benchState)
		print("DEBUG: Updated PVP frames with new state")
	end)
	
	-- Handle battle start
	local startBattleEvent = remoteEventsFolder:WaitForChild(Constants.REMOTE_EVENT_NAMES.START_BATTLE)
	startBattleEvent.OnClientEvent:Connect(function(challengeId)
		print("DEBUG: Received battle start event for challenge: " .. challengeId)
		PVPChallengeUI.hidePVPFrames()
		
		-- Update the player's board with their PVP board state
		PVPChallengeUI.updatePlayerBoardFromPVP()
		
		-- Battle system will be implemented later
		print("Battle starting for challenge: " .. challengeId)
	end)
	
	print("DEBUG: PVP Challenge UI initialized successfully")
end

return PVPChallengeUI
