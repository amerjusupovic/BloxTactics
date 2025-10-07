--[[
	UI.luau
	Client-side user interface management
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

local _Constants = require(game.ReplicatedStorage.Shared.Constants)
local DataStructures = require(game.ReplicatedStorage.Shared.DataStructures)
local GameUtils = require(game.ReplicatedStorage.Shared.GameUtils)
local UnitMovement = require(game.ReplicatedStorage.Shared.UnitMovement)

local UI = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI references
local mainGui = nil
local shopFrame = nil
local boardFrame = nil
local benchFrame = nil
local statsFrame = nil
local sellUnitFrame = nil
local editArenaFrame = nil
local arenaSelectionFrames = {}
local currentArenaCheckmark = nil
local traitBarFrame = nil -- container for trait icons
local arenaOwnership = nil -- table of owned arenas from player data

-- UI state variables
local shopVisible = false
local boardVisible = false
local currentPlayerData = nil -- Store current player data to access level and other stats

-- Unit selection state is now handled by UnitMovement module

-- Helper function to keep SellUnitFrame visibility consistent
local function updateSellUnitFrameVisibility()
	if sellUnitFrame then
		sellUnitFrame.Visible = boardVisible and UnitMovement.hasSelection()
	end
end

-- Function to create the main UI
function UI.createMainUI()
	print("UI.createMainUI() called")
	
	-- Get existing UI from ReplicatedStorage
	print("Looking for existing UI in ReplicatedStorage...")
	local existingUI = game.ReplicatedStorage:FindFirstChild("BloxTacticsUITemplate")
	if not existingUI then
		warn("BloxTacticsUITemplate not found in ReplicatedStorage!")
		return
	end
	
	-- Clone the existing UI
	print("Cloning existing UI...")
	mainGui = existingUI:Clone()
	mainGui.Name = "BloxTacticsUITemplate"
	mainGui.Parent = playerGui
	print("Main GUI cloned and parented to PlayerGui")
	
	-- Get references to UI elements
	print("Looking for MainFrame...")
	local mainFrame = mainGui:FindFirstChild("MainFrame")
	if not mainFrame then
		warn("MainFrame not found in UI!")
		return
	end
	print("MainFrame found successfully")
	
	print("Looking for UI frames...")
	shopFrame = mainFrame:FindFirstChild("ShopFrame")
	boardFrame = mainFrame:FindFirstChild("BoardFrame")
	benchFrame = mainFrame:FindFirstChild("BenchFrame")
	statsFrame = mainFrame:FindFirstChild("StatsFrame")
	sellUnitFrame = mainFrame:FindFirstChild("SellUnitFrame")
	editArenaFrame = mainFrame:FindFirstChild("EditArenaFrame")
	traitBarFrame = mainFrame:FindFirstChild("TraitBarFrame") -- Expected container (assumed existing per instructions)

	-- KeybindContainer buttons (Board planner, return to arena, open shop)
	local keybindContainer = mainFrame:FindFirstChild("KeybindContainer")
	if keybindContainer then
		local function connectButton(frameName: string, handler: () -> ())
			local frame = keybindContainer:FindFirstChild(frameName)
			if frame then
				local btn = frame:FindFirstChild("Button")
				if btn and (btn:IsA("TextButton") or btn:IsA("ImageButton")) then
					btn.MouseButton1Click:Connect(function()
						handler()
					end)
				end
			else
				warn("KeybindContainer missing frame " .. frameName)
			end
		end

		-- 1) BoardPlannerButton -> toggleBoard (Key C)
		connectButton("BoardPlannerButton", function()
			UI.toggleBoard()
		end)
		-- 2) ArenaReturnButton -> fire ReturnToArena remote
		connectButton("ArenaReturnButton", function()
			local ev = game.ReplicatedStorage:FindFirstChild("RemoteEvents")
			if ev then
				local r = ev:FindFirstChild(_Constants.REMOTE_EVENT_NAMES.RETURN_TO_ARENA)
				if r then
					(r :: any):FireServer()
				else
					warn("ReturnToArena RemoteEvent not found")
				end
			end
		end)
		-- 3) OpenUnitShop -> toggleShop (Key F)
		connectButton("OpenUnitShop", function()
			UI.toggleShop()
		end)
	else
		warn("KeybindContainer not found under MainFrame; keybind buttons won't be clickable")
	end
	
	print("UI frames found:")
	print("  shopFrame:", shopFrame and "YES" or "NO")
	print("  boardFrame:", boardFrame and "YES" or "NO")
	print("  benchFrame:", benchFrame and "YES" or "NO")
	print("  statsFrame:", statsFrame and "YES" or "NO")
	print("  sellUnitFrame:", sellUnitFrame and "YES" or "NO")
	print("  editArenaFrame:", editArenaFrame and "YES" or "NO")
	print("  traitBarFrame:", traitBarFrame and "YES" or "NO")
	
	-- Verify all frames exist
	if not shopFrame or not boardFrame or not benchFrame or not statsFrame or not sellUnitFrame or not traitBarFrame then
		warn("One or more UI frames not found in UI!")
		return
	end
	-- EditArenaFrame is optional for now; if missing we log but continue
	if not editArenaFrame then
		warn("EditArenaFrame not found (will only matter when triggering edit arena)")
	else
		-- Gather arena option frames (children that end with ArenaFrame)
		for _, child in ipairs(editArenaFrame:GetChildren()) do
			if child.Name:match("ArenaFrame$") or child.Name:match("ArenaFrame") then
				arenaSelectionFrames[child.Name] = child
				local button = child:FindFirstChild("SwitchArenaButton")
				if button and (button:IsA("TextButton") or button:IsA("ImageButton")) then
					button.MouseButton1Click:Connect(function()
						local arenaName = child:GetAttribute("ArenaName") or child.Name:gsub("Frame$","")
						-- Check ownership locally before firing server request
						if UI.isArenaOwned(arenaName) then
							UI.requestArenaSwitch(arenaName)
						else
							UI.showNotification("Purchase this arena first!", 2)
						end
					end)
				end
				-- Bind buy button if present
				local buyBtn = child:FindFirstChild("BuyButton")
				if buyBtn and (buyBtn:IsA("TextButton") or buyBtn:IsA("ImageButton")) then
					buyBtn.MouseButton1Click:Connect(function()
						local arenaName = child:GetAttribute("ArenaName") or child.Name:gsub("Frame$","")
						UI.promptArenaPurchase(arenaName)
					end)
				end
		end
	end
	end
	print("All UI frames found successfully!")
	
	-- Create board & bench hexes using shared module (no wrapper needed now that we have selectionChanged signal)
	UnitMovement.createBoardHexes(boardFrame, function(hex, position)
		UnitMovement.handleHexClick(hex, position, UI.requestUnitMove, "regular board")
	end, "regular board")
	UnitMovement.createBenchHexes(benchFrame, function(hex, position)
		UnitMovement.handleHexClick(hex, position, UI.requestUnitMove, "regular bench")
	end, "regular bench")

	-- Listen for selection changes to keep SellUnitFrame in sync
	local ok, event = pcall(function()
		return UnitMovement.selectionChanged()
	end)
	if ok and event then
		event:Connect(function(hasSelection)
			updateSellUnitFrameVisibility()
		end)
	else
		warn("UnitMovement.selectionChanged() not available; SellUnitFrame visibility may desync")
	end
	
	-- Add click handler for sell area (only if it's a button type)
	if sellUnitFrame then
		if sellUnitFrame:IsA("GuiButton") then
			sellUnitFrame.MouseButton1Click:Connect(function()
				UI.sellSelectedUnit()
			end)
		else
			warn("SellUnitFrame is not a clickable GuiButton. Add a TextButton/ImageButton for selling or change the instance type.")
		end
	end
	
	-- Add click handler for refresh button
	local refreshButton = shopFrame:FindFirstChild("RefreshButton")
	if refreshButton then
		refreshButton.MouseButton1Click:Connect(function()
			UI.handleShopRefresh()
		end)
	end
	
	-- Add click handlers for level up buttons (small & big)
	local levelUpButtonSmall = shopFrame:FindFirstChild("LevelUpButtonSmall")
	local levelUpButtonBig = shopFrame:FindFirstChild("LevelUpButtonBig")

	-- Backward-compat: support old name "LevelUpButton" as small
	local legacyLevelUpButton = shopFrame:FindFirstChild("LevelUpButton")

	if levelUpButtonSmall and levelUpButtonSmall:IsA("GuiButton") then
		levelUpButtonSmall.MouseButton1Click:Connect(function()
			UI.handleLevelUp("small")
		end)
	end

	if levelUpButtonBig and levelUpButtonBig:IsA("GuiButton") then
		levelUpButtonBig.MouseButton1Click:Connect(function()
			UI.handleLevelUp("big")
		end)
	end

	if (not levelUpButtonSmall) and legacyLevelUpButton and legacyLevelUpButton:IsA("GuiButton") then
		legacyLevelUpButton.MouseButton1Click:Connect(function()
			UI.handleLevelUp("small")
		end)
	end
	
	-- Ensure correct initial visibility (hidden until a selection while board is open)
	updateSellUnitFrameVisibility()
	print("UI created successfully from existing ReplicatedStorage elements!")

	-- Initial ownership visuals (may update once player data arrives)
	UI.refreshArenaOwnershipVisuals()
end

--[[
	Update trait bar display.
	traitData shape (server): { TraitId = { count = number, active = boolean, units = {Unit,...} }, ... }
	Assumptions about UI:
	- There is a Frame named TraitBarFrame under MainFrame (assigned to traitBarFrame).
	- Inside it, there may be pre-created Frames for each trait with Name == traitId (e.g., Medieval, Mystic...)
	  Each trait frame can optionally contain:
	    * A TextLabel named Count (we'll show progress like "1/2" or "2/2")
	    * A TextLabel named Name (shown when active or always)
	If a trait frame doesn't exist, we'll create a simple placeholder Frame so UI doesn't break.
]]
function UI.updateTraitsDisplay(traitData)
	if not traitData then
		warn("[Traits:UI] updateTraitsDisplay called with nil traitData")
	else
		local keys = {}
		for k,_ in pairs(traitData) do table.insert(keys, k) end
		table.sort(keys)
		print("[Traits:UI] Updating display for traits:", table.concat(keys, ", "))
	end
	if not mainGui then return end
	if not traitBarFrame then
		-- Attempt to find (maybe created after UI init)
		local mainFrame = mainGui:FindFirstChild("MainFrame")
		if mainFrame then
			traitBarFrame = mainFrame:FindFirstChild("TraitBarFrame")
		end
	end
	if not traitBarFrame then
		warn("TraitBarFrame not found; cannot update trait UI")
		return
	end

	local constants = _Constants
	local traitDefs = constants.TRAITS or {}

	-- Ensure frames exist for each defined trait
	for traitId, def in pairs(traitDefs) do
		local frame = traitBarFrame:FindFirstChild(traitId)
		if not frame then
			warn("Trait frame for", traitId, "not found.")
		end
	end

	for traitId, def in pairs(traitDefs) do
		local frame = traitBarFrame:FindFirstChild(traitId)
		if frame then
			local countLabel = frame:FindFirstChild("Count")
			local info = traitData and traitData[traitId]
			local count = info and info.count or 0
			local active = info and info.active or false
			-- Progress text
			if countLabel and countLabel:IsA("TextLabel") then
				countLabel.Text = string.format("%d/%d", count, def.requirement)
			end
			print(string.format("[Traits:UI] %s -> count=%d active=%s", traitId, count, tostring(active)))
			-- Visual state: active = bright color, inactive = dim
			local activeColor = Color3.fromRGB(255, 215, 0)
			local inactiveColor = Color3.fromRGB(70,70,70)
			frame.BackgroundColor3 = active and activeColor or Color3.fromRGB(30,30,30)
			-- Tooltip via Hover (simple: set attribute; advanced system could be added later)
			frame:SetAttribute("Description", def.description)

			-- Attach a simple tooltip on first run
			local tooltip = frame:FindFirstChild("Tooltip")
			if not tooltip then
				tooltip = Instance.new("TextLabel")
				tooltip.Name = "Tooltip"
				tooltip.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
				tooltip.BackgroundTransparency = 0.2
				tooltip.TextColor3 = Color3.fromRGB(255,255,255)
				tooltip.BorderSizePixel = 0
				tooltip.Visible = false
				tooltip.TextWrapped = true
				tooltip.ZIndex = 10
				tooltip.Size = UDim2.new(0, 220, 0, 60)
				tooltip.Position = UDim2.new(1, 8, 0, -8)
				tooltip.TextScaled = true
				tooltip.Font = Enum.Font.Gotham
				tooltip.Parent = frame

				-- Avoid duplicate connections
				if not frame:GetAttribute("HoverBound") then
					frame:SetAttribute("HoverBound", true)
					frame.MouseEnter:Connect(function()
						local desc = frame:GetAttribute("Description") or (def and def.description) or ""
						tooltip.Text = desc
						tooltip.Visible = true
					end)
					frame.MouseLeave:Connect(function()
						tooltip.Visible = false
					end)
				end
			end
			-- Always ensure tooltip text matches latest description
			if tooltip and tooltip:IsA("TextLabel") then
				tooltip.Text = def.description or ""
			end
		end
	end
end

-- Convenience: recompute traits from a boardState and update the trait bar
function UI.refreshTraitsFromBoardState(boardState: DataStructures.BoardState)
	if not boardState then return end
	if not boardState.grid then
		warn("[Traits:UI] refreshTraitsFromBoardState: boardState.grid is nil")
	end
	local ok, TraitSystem = pcall(function()
		return require(game.ReplicatedStorage.Shared.TraitSystem)
	end)
	if ok and TraitSystem then
		local traitData = TraitSystem.computeBoardTraits(boardState)
		print("[Traits:UI] Computed traitData from boardState")
		UI.updateTraitsDisplay(traitData)
	else
		warn("TraitSystem unavailable; cannot compute trait data from boardState")
	end
end

-- Request arena switch
function UI.requestArenaSwitch(arenaName: string)
	local switchEvent = game.ReplicatedStorage.RemoteEvents:FindFirstChild(_Constants.REMOTE_EVENT_NAMES.SWITCH_ARENA)
	if switchEvent then
		switchEvent:FireServer(arenaName)
	else
		warn("SwitchArena RemoteEvent not found")
	end
end

-- Update arena selection checkmarks
function UI.updateArenaSelection(selectedArenaName: string)
	if not editArenaFrame then return end
	-- Remove previous checkmark
	if currentArenaCheckmark then
		currentArenaCheckmark:Destroy()
		currentArenaCheckmark = nil
	end
	-- Find frame whose ArenaName attribute or derived name matches selectedArenaName
	for _, frame in pairs(arenaSelectionFrames) do
		local arenaName = frame:GetAttribute("ArenaName") or frame.Name:gsub("Frame$","")
		if arenaName == selectedArenaName then
			local mark = Instance.new("TextLabel")
			mark.Name = "SelectedArenaMark"
			mark.Size = UDim2.new(0, 24, 0, 24)
			mark.Position = UDim2.new(1, -28, 0, 4)
			mark.BackgroundTransparency = 1
			mark.Text = "✓"
			mark.TextScaled = true
			mark.TextColor3 = Color3.fromRGB(0,255,0)
			mark.Font = Enum.Font.GothamBold
			mark.Parent = frame
			currentArenaCheckmark = mark
			break
		end
	end
end

-- Show Edit Arena Frame
function UI.showEditArenaFrame()
	print("UI.showEditArenaFrame() called")
	if not editArenaFrame then
		warn("EditArenaFrame not available in UI")
		return
	end
	-- Fade in animation
	editArenaFrame.Visible = true
	editArenaFrame.Active = true
	editArenaFrame.Selectable = true

	-- Store original transparency values once
	if not editArenaFrame:GetAttribute("OrigBgTransparency") then
		editArenaFrame:SetAttribute("OrigBgTransparency", editArenaFrame.BackgroundTransparency)
		-- Capture descendant text/image transparency so we can restore gracefully
		for _, desc in ipairs(editArenaFrame:GetDescendants()) do
			if desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("ImageLabel") or desc:IsA("ImageButton") then
				if desc.BackgroundTransparency ~= nil then
					desc:SetAttribute("OrigBgTransparency", desc.BackgroundTransparency)
				end
				if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.TextTransparency ~= nil then
					desc:SetAttribute("OrigTextTransparency", desc.TextTransparency)
				end
				if (desc:IsA("ImageLabel") or desc:IsA("ImageButton")) and desc.ImageTransparency ~= nil then
					desc:SetAttribute("OrigImageTransparency", desc.ImageTransparency)
				end
			end
		end
	end

	-- Cancel any running hide tween by clearing attribute
	editArenaFrame:SetAttribute("FadeState", "showing")

	local TweenService = game:GetService("TweenService")
	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	-- Initialize to fully transparent before fade if first show after hide
	editArenaFrame.BackgroundTransparency = 1
	for _, desc in ipairs(editArenaFrame:GetDescendants()) do
		if desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("ImageLabel") or desc:IsA("ImageButton") then
			if desc:GetAttribute("OrigBgTransparency") then desc.BackgroundTransparency = 1 end
			if desc:GetAttribute("OrigTextTransparency") then desc.TextTransparency = 1 end
			if desc:GetAttribute("OrigImageTransparency") then desc.ImageTransparency = 1 end
		end
	end

	-- Tween frame itself
	TweenService:Create(editArenaFrame, tweenInfo, {
		BackgroundTransparency = editArenaFrame:GetAttribute("OrigBgTransparency") or 0
	}):Play()

	-- Tween descendants
	for _, desc in ipairs(editArenaFrame:GetDescendants()) do
		if desc:IsA("TextLabel") or desc:IsA("TextButton") then
			local targetBg = desc:GetAttribute("OrigBgTransparency") or desc.BackgroundTransparency
			local targetText = desc:GetAttribute("OrigTextTransparency") or 0
			TweenService:Create(desc, tweenInfo, {
				BackgroundTransparency = targetBg,
				TextTransparency = targetText
			}):Play()
		elseif desc:IsA("ImageLabel") or desc:IsA("ImageButton") then
			local targetBg = desc:GetAttribute("OrigBgTransparency") or desc.BackgroundTransparency
			local targetImg = desc:GetAttribute("OrigImageTransparency") or 0
			TweenService:Create(desc, tweenInfo, {
				BackgroundTransparency = targetBg,
				ImageTransparency = targetImg
			}):Play()
		end
	end

	print("EditArenaFrame fade-in started")
end

-- Hide Edit Arena Frame (can be bound to ESC or a close button)
function UI.hideEditArenaFrame()
	if editArenaFrame then
		local TweenService = game:GetService("TweenService")
		editArenaFrame:SetAttribute("FadeState", "hiding")
		local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

		-- Make it non-interactive immediately during fade
		editArenaFrame.Active = false
		editArenaFrame.Selectable = false

		local totalTweens = 0
		local completed = 0

		local function registerTween(tween)
			totalTweens += 1
			tween.Completed:Connect(function()
				completed += 1
				if completed == totalTweens then
					-- Only hide if we are still in hiding state (wasn't re-shown mid-fade)
					if editArenaFrame and editArenaFrame:GetAttribute("FadeState") == "hiding" then
						editArenaFrame.Visible = false
					end
				end
			end)
			tween:Play()
		end

		-- Frame tween
		registerTween(TweenService:Create(editArenaFrame, tweenInfo, {BackgroundTransparency = 1}))

		-- Descendant tweens
		for _, desc in ipairs(editArenaFrame:GetDescendants()) do
			if desc:IsA("TextLabel") or desc:IsA("TextButton") then
				registerTween(TweenService:Create(desc, tweenInfo, {BackgroundTransparency = 1, TextTransparency = 1}))
			elseif desc:IsA("ImageLabel") or desc:IsA("ImageButton") then
				registerTween(TweenService:Create(desc, tweenInfo, {BackgroundTransparency = 1, ImageTransparency = 1}))
			end
		end
	end
end

-- Helper function to update TotalUnits label in a frame
local function updateTotalUnitsLabel(frame, currentUnits: number, playerLevel: number)
	if not frame then return end
	
	local totalUnitsLabel = frame:FindFirstChild("TotalUnits")
	if totalUnitsLabel and totalUnitsLabel:IsA("TextLabel") then
		-- Calculate max units using the same formula as Board.calculateMaxBoardUnits
		local maxUnits = math.min(playerLevel + 2, 10)
		totalUnitsLabel.Text = string.format("%d/%d", currentUnits, maxUnits)
		print("Updated TotalUnits label:", totalUnitsLabel.Text)
	end
end

-- Function to update player stats display
function UI.updatePlayerStats(playerData: DataStructures.PlayerData)
	print("=== UI.updatePlayerStats START ===")
	print("Player data received:", playerData)
	
	-- Store current player data for later use
	currentPlayerData = playerData
	
	if not statsFrame then 
		warn("Stats frame not found!")
		return 
	end
	
	local goldLabel = statsFrame:FindFirstChild("GoldLabel")
	local levelLabel = statsFrame:FindFirstChild("LevelLabel")
	local expLabel = statsFrame:FindFirstChild("ExpLabel")
	local streakLabel = statsFrame:FindFirstChild("StreakLabel")
	
	print("Found UI elements - Gold:", goldLabel and "YES" or "NO", "Level:", levelLabel and "YES" or "NO", "Exp:", expLabel and "YES" or "NO", "Streak:", streakLabel and "YES" or "NO")
	
	if goldLabel then
		goldLabel.Text = "Gold: " .. playerData.gold
		print("Updated gold label to:", goldLabel.Text)
	end
	
	if levelLabel then
		levelLabel.Text = "Level: " .. playerData.level
		print("Updated level label to:", levelLabel.Text)
	end
	
	if expLabel then
		local expRequired = GameUtils.getExperienceRequiredForLevel(playerData.level)
		expLabel.Text = "Exp: " .. playerData.experience .. "/" .. expRequired
		print("Updated exp label to:", expLabel.Text)
	end
	
	if streakLabel then
		streakLabel.Text = "Streak: " .. playerData.streak
		print("Updated streak label to:", streakLabel.Text)
	end

	-- Update refresh & level up button text
	if shopFrame then
		local refreshButton = shopFrame:FindFirstChild("RefreshButton")
		if refreshButton and refreshButton:IsA("TextButton") then
			-- Mirror server formula: base refresh cost + (level - 1)
			local baseCost = _Constants.SHOP_REFRESH_COST
			local refreshCost = baseCost + math.max(0, (playerData.level - 1))
			refreshButton.Text = string.format("Refresh: %dg", refreshCost)
		end

		-- Update text for both small and big level-up buttons if present
		local levelUpButtonSmall = shopFrame:FindFirstChild("LevelUpButtonSmall")
		if levelUpButtonSmall and levelUpButtonSmall:IsA("TextButton") then
			levelUpButtonSmall.Text = "Level Up (+10xp): 5g"
		end

		local levelUpButtonBig = shopFrame:FindFirstChild("LevelUpButtonBig")
		if levelUpButtonBig and levelUpButtonBig:IsA("TextButton") then
			levelUpButtonBig.Text = "Level Up (+100xp): 50g"
		end

		-- Backward-compat: legacy LevelUpButton behaves as small
		local legacyLevelUpButton = shopFrame:FindFirstChild("LevelUpButton")
		if legacyLevelUpButton and legacyLevelUpButton:IsA("TextButton") then
			legacyLevelUpButton.Text = "Level Up (+10xp): 5g"
		end
	end
	
	print("=== UI.updatePlayerStats SUCCESS ===")

	-- Update arena selection UI (if any) using selectedArenaName
	if playerData.selectedArenaName then
		UI.updateArenaSelection(playerData.selectedArenaName)
	end

	-- Update ownership reference & visuals
	arenaOwnership = playerData.arenaOwnership
	UI.refreshArenaOwnershipVisuals()
end

-- Determine if an arena is owned locally (default arena always owned)
function UI.isArenaOwned(arenaName: string): boolean
	if not arenaName then return false end
	local constants = _Constants
	if arenaName == constants.DEFAULT_ARENA_NAME then return true end
	if arenaOwnership then
		-- Insert a space before 'Arena' if missing to compare to canonical template names
		local spaced = arenaName
		if not spaced:match("%sArena") and spaced:sub(-5):lower() == "arena" then
			spaced = spaced:gsub("Arena$", " Arena")
		end
		local frameVariant = spaced:gsub("Arena", " Frame")
		local variants = {
			arenaName, -- original
			arenaName:gsub("%s+", ""), -- no spaces
			spaced, -- with space before Arena
			spaced:gsub("%s+", ""), -- spaced but compact
			frameVariant,
			frameVariant:gsub("%s+", ""),
		}
		for _, key in ipairs(variants) do
			if arenaOwnership[key] then return true end
		end
	end
	return false
end

-- Refresh UI state (darken unowned, show buy button, etc.)
function UI.refreshArenaOwnershipVisuals()
	if not editArenaFrame then return end
	for name, frame in pairs(arenaSelectionFrames) do
		local arenaName = frame:GetAttribute("ArenaName") or name:gsub("Frame$","")
		local owned = UI.isArenaOwned(arenaName)
		local buyBtn = frame:FindFirstChild("BuyButton")
		local switchBtn = frame:FindFirstChild("SwitchArenaButton")
		if owned then
			-- restore brightness & hide buy
			frame.BackgroundColor3 = Color3.fromRGB(60,60,60)
			if buyBtn then buyBtn.Visible = false end
			if switchBtn then switchBtn.AutoButtonColor = true end
		else
			-- dark overlay for locked
			frame.BackgroundColor3 = Color3.fromRGB(25,25,25)
			if buyBtn then buyBtn.Visible = true end
			if switchBtn then switchBtn.AutoButtonColor = false end
		end
	end
end

-- Prompt purchase for an arena skin (maps arena name to product id)
function UI.promptArenaPurchase(arenaName: string)
	if UI.isArenaOwned(arenaName) then
		UI.showNotification("Already owned!", 2)
		return
	end
	-- Map arenaName to product id via Constants.ARENA_PRODUCTS keys (normalize by removing spaces)
	local normalized = arenaName:lower():gsub("%s+", "")
	local productId = nil
	for key, id in pairs(_Constants.ARENA_PRODUCTS) do
		local keyNorm = key:lower():gsub("%s+", "")
		if keyNorm == normalized or normalized:find(keyNorm, 1, true) or keyNorm:find(normalized, 1, true) then
			productId = id; break
		end
	end
	if not productId then
		UI.showNotification("Cannot purchase: unknown arena", 3)
		return
	end
	local plr = Players.LocalPlayer
	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(plr, productId)
	end)
	if not ok then
		warn("Failed to prompt purchase: " .. tostring(err))
		UI.showNotification("Purchase failed to start", 3)
	else
		UI.showNotification("Purchasing...", 2)
	end
end

-- Function to create shop unit button
function UI.createShopUnitButton(unit: DataStructures.Unit, parent: GuiObject, onClick: () -> ())
	print("Creating shop button for unit:", unit.name, "Cost:", unit.cost)
	
	local button = Instance.new("ImageButton")
	button.Size = UDim2.new(0.18, 0, 0.5, 0)
	button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	button.BorderSizePixel = 0
	button.Image = unit.imageAssetId -- Use unit's image asset ID
	button.Parent = parent

	-- Add border stroke for visual clarity
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(180, 180, 180)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	
	-- Create star indicators if applicable
	if unit.starIndicator and unit.starIndicator ~= "none" then
		local starCount = (unit.starIndicator == "silver") and 2 or 3
		local starColor = (unit.starIndicator == "silver") and Color3.fromRGB(192, 192, 192) or Color3.fromRGB(255, 215, 0)
		local starBorderColor = (unit.starIndicator == "silver") and Color3.fromRGB(152, 152, 152) or Color3.fromRGB(215, 175, 0)
		
		for i = 1, starCount do
			local star = Instance.new("TextLabel")
			star.Size = UDim2.new(0.15, 0, 0.15, 0)
			star.Position = UDim2.new(0.1 + (i-1) * 0.2, 0, 0.05, 0)
			star.BackgroundTransparency = 1
			star.Text = "★"
			star.TextColor3 = starColor
			star.TextScaled = true
			star.Font = Enum.Font.GothamBold
			star.TextStrokeColor3 = starBorderColor
            star.TextStrokeTransparency = 0
			star.Parent = button
		end
	end
	
	-- Create unit info label
	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, 0, 0.3, 0)
	infoLabel.Position = UDim2.new(0, 0, 0.7, 0)
	infoLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	infoLabel.BackgroundTransparency = 0.5
	infoLabel.Text = unit.name .. "\nCost: " .. unit.cost .. "\nTier: " .. unit.tier
	infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	infoLabel.TextScaled = true
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.Parent = button
	
	-- Check if unit is sold out
	if unit.soldOut then
		-- Gray out the button and make it unclickable
		button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		button.ImageTransparency = 0.7
		button:SetAttribute("SoldOut", true)
		
		-- Update info label to show "SOLD OUT"
		infoLabel.Text = unit.name .. "\nSOLD OUT\nTier: " .. unit.tier
		infoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	else
		-- Add click handler only if not sold out
		print("Adding click handler for unit:", unit.name)
		button.MouseButton1Click:Connect(function()
			print("Shop button clicked for unit:", unit.name)
			onClick()
		end)
	end
	
	-- Store unit data in button (only primitive types)
	button:SetAttribute("UnitId", unit.id)
	button:SetAttribute("UnitName", unit.name)
	button:SetAttribute("UnitCost", unit.cost)
	button:SetAttribute("UnitTier", unit.tier)
	button:SetAttribute("UnitImageAssetId", unit.imageAssetId)
	button:SetAttribute("SoldOut", unit.soldOut or false)
	
	return button
end

-- Function to update shop display
function UI.updateShopDisplay(shopUnits: {DataStructures.Unit})
	if not shopFrame then return end
	
	-- Clear existing shop buttons
	for _, child in pairs(shopFrame:GetChildren()) do
		if child:IsA("ImageButton") and child.Name:find("ShopUnit_") then
			child:Destroy()
		end
	end
	
	-- Create new shop buttons
	for i, unit in ipairs(shopUnits) do
		local button = UI.createShopUnitButton(unit, shopFrame, function()
			-- Handle unit purchase
			UI.handleUnitPurchase(unit, i)
		end)
		
		button.Name = "ShopUnit_" .. i
		button.Position = UDim2.new(0.03 + (i-1) * 0.19, 0, 0.2, 0)
	end
end

-- Function to handle unit purchase
function UI.handleUnitPurchase(unit: DataStructures.Unit, shopIndex: number)
	print("handleUnitPurchase called for unit:", unit.name, "shopIndex:", shopIndex)
	
	-- Fire RemoteEvent to server
	local purchaseUnitEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("PurchaseUnit")
	if purchaseUnitEvent then
		print("PurchaseUnit RemoteEvent found, firing server event...")
		purchaseUnitEvent:FireServer(shopIndex)
	else
		warn("PurchaseUnit RemoteEvent not found!")
	end
end

-- Function to handle shop refresh
function UI.handleShopRefresh()
	-- Fire RemoteEvent to server
	local refreshShopEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("RefreshShop")
	if refreshShopEvent then
		refreshShopEvent:FireServer()
	else
		warn("RefreshShop RemoteEvent not found!")
	end
end

-- Function to handle level up (buy experience)
function UI.handleLevelUp(size: string?)
	-- size: "small" or "big" (defaults to "small")
	local chosenSize = (size == "big") and "big" or "small"
	-- Fire RemoteEvent to server with size parameter
	local levelUpEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("LevelUp")
	if levelUpEvent then
		levelUpEvent:FireServer(chosenSize)
	else
		warn("LevelUp RemoteEvent not found!")
	end
end

-- Function to gray out shop button
function UI.grayOutShopButton(shopIndex: number)
	if not shopFrame then return end
	
	local button = shopFrame:FindFirstChild("ShopUnit_" .. shopIndex)
	if button then
		button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		button.ImageTransparency = 0.7
		button:SetAttribute("SoldOut", true)
	end
end

-- Function to place unit on board
function UI.placeUnitOnBoard(unit: DataStructures.Unit, position: Vector2)
	if not boardFrame then return end
	
	-- Validate position
	if not position then
		warn("Position is nil in placeUnitOnBoard")
		return
	end
	
	-- Handle both Vector2 and table formats
	local x, y
	if typeof(position) == "Vector2" then
		x = position.X
		y = position.Y
	elseif typeof(position) == "table" then
		x = position.X or position.x
		y = position.Y or position.y
	elseif typeof(position) == "string" then
		-- Handle string representation of Vector2 (e.g., "<Vector2> (0, 2)")
		print("Parsing string position:", position)
		
		-- Extract numbers from parentheses only: (x, y)
		local match = string.match(position, "%(([^%)]+)%)")
		if match then
			print("Extracted content from parentheses:", match)
			-- Split by comma and extract numbers
			local parts = {}
			for part in string.gmatch(match, "[^,]+") do
				table.insert(parts, part:match("^%s*(%-?%d+)%s*$"))
			end
			print("Parts after splitting:", table.concat(parts, ", "))
			if #parts >= 2 and parts[1] and parts[2] then
				x = tonumber(parts[1])
				y = tonumber(parts[2])
				print("Parsed coordinates:", x, y)
			else
				warn("Failed to parse Vector2 string:", position)
				return
			end
		else
			warn("Failed to find parentheses in Vector2 string:", position)
			return
		end
	else
		warn("Invalid position type in placeUnitOnBoard:", typeof(position), position)
		return
	end
	
	if not x or not y then
		warn("Invalid position coordinates in placeUnitOnBoard:", position)
		return
	end
	
	-- Position validation successful
	
	-- Convert from bottom-up coordinates to hex naming
	-- Hex names are in bottom-up format: (bottomUpRow, col)
	-- where bottomUpRow = rows - row + 1
	-- For position (0,0) bottom-left: hexRow = 1, hexCol = 1 -> Hex_1_1
	-- For position (0,1) second row: hexRow = 2, hexCol = 1 -> Hex_2_1
	-- For position (0,3) top-left: hexRow = 4, hexCol = 1 -> Hex_4_1
	local hexRow = y + 1
	local hexCol = x + 1
	
	local hexName = string.format("Hex_%d_%d", hexRow, hexCol)
	local hex = boardFrame:FindFirstChild(hexName)
	-- Hex lookup completed
	
	print("Looking for hex:", hexName, "Found:", hex ~= nil)
	print("  Position:", x, y, "-> hexRow:", hexRow, "hexCol:", hexCol)
	
	-- Debug: List all hexes in boardFrame
	if not hex then
		print("Available hexes in boardFrame:")
		for _, child in pairs(boardFrame:GetChildren()) do
			if child.Name:find("Hex_") then
				print("  ", child.Name)
			end
		end
	end
	
	if hex then
		-- Create unit visual using shared module
	local _unitVisual = UnitMovement.createUnitVisual(hex, unit, x, y, nil, "regular board", UI.requestUnitMove)
		
		print("Unit placed on board at position:", position)
	end
end

-- Function to place unit on bench
function UI.placeUnitOnBench(unit: DataStructures.Unit, benchSlot: number)
	if not benchFrame then return end
	
	-- Validate bench slot
	if not benchSlot or benchSlot <= 0 then
		warn("Invalid bench slot in placeUnitOnBench:", benchSlot)
		return
	end
	
	local hexName = string.format("BenchHex_%d", benchSlot)
	local hex = benchFrame:FindFirstChild(hexName)
	
	if hex then
		-- Create unit visual using shared module
	local _unitVisual = UnitMovement.createUnitVisual(hex, unit, nil, nil, benchSlot, "regular bench", UI.requestUnitMove)
		
		print("Unit placed on bench at slot:", benchSlot)
	end
end

-- Function to update board display
function UI.updateBoardDisplay(boardState: DataStructures.BoardState)
	if not boardFrame then return end
	
	-- Validate board state
	if not boardState or not boardState.grid then
		warn("Invalid board state in updateBoardDisplay")
		return
	end
	
	-- Count units in board state
	local unitCount = 0
	for _ in pairs(boardState.grid) do
		unitCount = unitCount + 1
	end
	print("Updating board display with", unitCount, "units")
	
	-- Board update started
	
	-- Clear selection when board is updated
	UnitMovement.clearSelection()
	
	-- Clear existing units
	for _, child in pairs(boardFrame:GetChildren()) do
		if child:IsA("ImageButton") and child.Name:find("Hex_") then
			-- Clear any unit visuals in this hex
			for _, unitVisual in pairs(child:GetChildren()) do
				if unitVisual:IsA("ImageButton") and unitVisual ~= child then
					unitVisual:Destroy()
				end
			end
		end
	end
	
	-- Place units from board state (robust position resolution for reinforcement units)
	for rawKey, unit in pairs(boardState.grid) do
		if unit then
			local posVec: Vector2? = nil
			-- Preferred: key is a Vector2
			if typeof(rawKey) == "Vector2" then
				posVec = rawKey
			end
			-- Fallback: unit.position field
			if not posVec and unit.position and typeof(unit.position) == "Vector2" then
				posVec = unit.position
			end
			-- Fallback: string key like "3,2" or "Vector2(3, 2)" or "<Vector2> (3, 2)"
			if not posVec and type(rawKey) == "string" then
				local xStr,yStr = string.match(rawKey, "^(%-?%d+),%s*(%-?%d+)$")
				if not xStr then
					-- Try to extract numbers inside parentheses
					local inside = string.match(rawKey, "%(%-?%d+,%s*%-?%d+%)")
					if inside then
						xStr,yStr = string.match(inside, "(%-?%d+),%s*(%-?%d+)")
					end
				end
				if xStr and yStr then
					local x = tonumber(xStr)
					local y = tonumber(yStr)
					if x and y then
						posVec = Vector2.new(x,y)
					end
				end
			end

			if posVec then
				print("Placing unit", unit.name, "at resolved position", posVec)
				UI.placeUnitOnBoard(unit, posVec)
			else
				print("[BoardDisplay] Could not resolve position for unit", unit.name, "rawKey=", rawKey, "unit.position=", unit.position)
			end
		else
			print("Skipping nil unit at key:", rawKey)
		end
	end

	-- Bind swap-capable click handlers for any unit visuals just placed
	if UnitMovement and UnitMovement.addUnitClickHandler then
		for _, hex in pairs(boardFrame:GetChildren()) do
			if hex:IsA("ImageButton") and hex.Name:find("Hex_") then
				for _, unitVisual in pairs(hex:GetChildren()) do
					if unitVisual:IsA("ImageButton") and unitVisual ~= hex then
						if not unitVisual:GetAttribute("ClickBound") then
							unitVisual:SetAttribute("ClickBound", true)
							UnitMovement.addUnitClickHandler(unitVisual, hex, "regular board", UI.requestUnitMove)
						end
					end
				end
			end
		end
	end
	
	updateSellUnitFrameVisibility()

	-- Also refresh trait display from the latest board state (extra safety)
	UI.refreshTraitsFromBoardState(boardState)
	
	-- Update TotalUnits label if player data is available
	if currentPlayerData and currentPlayerData.level then
		updateTotalUnitsLabel(boardFrame, boardState.currentUnits or unitCount, currentPlayerData.level)
	end
end

-- Function to update bench display
function UI.updateBenchDisplay(benchState: DataStructures.BenchState)
	if not benchFrame then return end
	
	-- Validate bench state
	if not benchState or not benchState.units or not benchState.maxCapacity then
		warn("Invalid bench state in updateBenchDisplay")
		return
	end
	
	print("Updating bench display with", benchState.currentCapacity, "units")
	
	-- Clear existing units
	for _, child in pairs(benchFrame:GetChildren()) do
		if child:IsA("ImageButton") and child.Name:find("BenchHex_") then
			-- Clear any unit visuals in this hex
			for _, unitVisual in pairs(child:GetChildren()) do
				if unitVisual:IsA("ImageButton") and unitVisual ~= child then
					unitVisual:Destroy()
				end
			end
		end
	end
	
	-- Place units from bench state using their slot information
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
			print("Placing bench unit", unit.name, "at slot", slot)
			UI.placeUnitOnBench(unit, slot)
		end
	end

	-- Bind swap-capable click handlers for any bench unit visuals just placed
	if UnitMovement and UnitMovement.addUnitClickHandler then
		for _, hex in pairs(benchFrame:GetChildren()) do
			if hex:IsA("ImageButton") and hex.Name:find("BenchHex_") then
				for _, unitVisual in pairs(hex:GetChildren()) do
					if unitVisual:IsA("ImageButton") and unitVisual ~= hex then
						if not unitVisual:GetAttribute("ClickBound") then
							unitVisual:SetAttribute("ClickBound", true)
							UnitMovement.addUnitClickHandler(unitVisual, hex, "regular bench", UI.requestUnitMove)
						end
					end
				end
			end
		end
	end
end

-- Function to toggle shop visibility
function UI.toggleShop()
	print("UI.toggleShop() called")
	if not shopFrame then 
		warn("shopFrame is nil in toggleShop!")
		return 
	end
	
	print("shopFrame found, toggling visibility...")
	shopVisible = not shopVisible
	shopFrame.Visible = shopVisible
	print("Shop visibility set to:", shopVisible)
	
	-- Show notification
	-- local message = shopVisible and "Shop opened" or "Shop closed"
	-- UI.showNotification(message, 1)
end

-- Function to toggle board visibility
function UI.toggleBoard()
	print("UI.toggleBoard() called")
	if not boardFrame or not benchFrame then 
		warn("boardFrame or benchFrame is nil in toggleBoard!")
		return 
	end
	
	print("boardFrame and benchFrame found, toggling visibility...")
	boardVisible = not boardVisible
	boardFrame.Visible = boardVisible
	benchFrame.Visible = boardVisible
	traitBarFrame.Visible = boardVisible
	updateSellUnitFrameVisibility()
	-- Ensure existing unit visuals have swap-capable click handlers when showing the board
	if boardVisible then
		if UnitMovement and UnitMovement.addUnitClickHandler then
			local function bindForContainer(container: Instance, context: string)
				for _, hex in pairs(container:GetChildren()) do
					if hex:IsA("ImageButton") and hex.Name:find("Hex_") then
						for _, unitVisual in pairs(hex:GetChildren()) do
							if unitVisual:IsA("ImageButton") and unitVisual ~= hex then
								if not unitVisual:GetAttribute("ClickBound") then
									unitVisual:SetAttribute("ClickBound", true)
									UnitMovement.addUnitClickHandler(unitVisual, hex, context, UI.requestUnitMove)
								end
							end
						end
					end
				end
			end
			if boardFrame then bindForContainer(boardFrame, "regular board") end
			if benchFrame then bindForContainer(benchFrame, "regular bench") end
		end
	end
	if not boardVisible then
		UnitMovement.clearSelection()
	end
end

-- Function to show/hide UI
function UI.setUIVisibility(visible: boolean)
	if mainGui then
		mainGui.Enabled = visible
	end
end

-- Function to handle unit selection with sell area visibility
function UI.handleUnitSelection(unitVisual: GuiObject, hex: GuiObject)
	UnitMovement.selectUnit(unitVisual, hex, "regular board")
	updateSellUnitFrameVisibility()
end

-- Function to clear unit selection with sell area visibility
function UI.clearSelection()
	UnitMovement.clearSelection()
	updateSellUnitFrameVisibility()
end

-- Function to request unit move from server
function UI.requestUnitMove(unit: any, fromPosition: Vector2, toPosition: Vector2)
	local moveUnitEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("MoveUnit")
	if moveUnitEvent then
		moveUnitEvent:FireServer(fromPosition, toPosition)
	else
		warn("MoveUnit RemoteEvent not found!")
	end
end

-- Function to sell selected unit
function UI.sellSelectedUnit()
	local selectionState = UnitMovement.getSelectionState()
	if not selectionState.selectedUnit then return end
	
	local unitId = selectionState.selectedUnit:GetAttribute("UnitId")
	local benchSlot = selectionState.selectedUnit:GetAttribute("BenchSlot")
	local positionX = selectionState.selectedUnit:GetAttribute("PositionX")
	local positionY = selectionState.selectedUnit:GetAttribute("PositionY")
	
	if unitId then
		local position
		if benchSlot then
			-- This is a bench unit, use negative bench slot as position
			position = Vector2.new(-benchSlot, 0)
		elseif positionX and positionY then
			-- This is a board unit
			position = Vector2.new(positionX, positionY)
		else
			warn("Invalid unit position for selling")
			return
		end
		
		UI.requestUnitSell(unitId, position)
		UI.clearSelection()
	end
end

-- Function to request unit sell from server
function UI.requestUnitSell(unitId: string, position: Vector2)
	local sellUnitEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("SellUnit")
	if sellUnitEvent then
		sellUnitEvent:FireServer(unitId, position)
	else
		warn("SellUnit RemoteEvent not found!")
	end
end

-- Function to reset player data (for testing)
function UI.resetPlayerData()
	print("=== UI.resetPlayerData START ===")
	local resetEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("ResetPlayerData")
	if resetEvent then
		print("Firing ResetPlayerData RemoteEvent...")
		resetEvent:FireServer()
		print("ResetPlayerData RemoteEvent fired successfully")
		UI.showNotification("Player data reset!", 3)
	else
		warn("ResetPlayerData RemoteEvent not found!")
	end
	print("=== UI.resetPlayerData END ===")
end

-- Function to show notification
function UI.showNotification(message: string, duration: number)
	local notification = Instance.new("TextLabel")
	notification.Size = UDim2.new(0.3, 0, 0.1, 0)
	notification.Position = UDim2.new(0.35, 0, 0.45, 0)
	notification.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	notification.BackgroundTransparency = 0.3
	notification.Text = message
	notification.TextColor3 = Color3.fromRGB(255, 255, 255)
	notification.TextScaled = true
	notification.Font = Enum.Font.GothamBold
	notification.Parent = mainGui
	
	-- Animate out
	local tween = TweenService:Create(notification, TweenInfo.new(duration), {
		BackgroundTransparency = 1,
		TextTransparency = 1
	})
	
	tween:Play()
	tween.Completed:Connect(function()
		notification:Destroy()
	end)
end

-- Function to get current player data
function UI.getCurrentPlayerData()
	return currentPlayerData
end

-- Board and bench hexes are now created using the shared UnitMovement module

return UI
