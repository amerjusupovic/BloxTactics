--[[
	UITemplate.luau
	UI template management for Studio editing
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITemplate = {}

-- Function to load existing template from ReplicatedStorage
function UITemplate.loadExistingTemplate()
    local existingTemplate = ReplicatedStorage:FindFirstChild("BloxTacticsUITemplate")
    if existingTemplate then
        return existingTemplate:Clone()
    else
        warn("UI Template not found in ReplicatedStorage! Creating from code...")
        return UITemplate.createTemplate()
    end
end

-- Function to create the UI template structure
function UITemplate.createTemplate()
	local templateGui = Instance.new("ScreenGui")
	templateGui.Name = "BloxTacticsUITemplate"
	templateGui.ResetOnSpawn = false
	
	-- Create main frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(1, 0, 1, 0)
	mainFrame.BackgroundTransparency = 1
	mainFrame.Parent = templateGui
	
	-- Create shop frame
	local shopFrame = Instance.new("Frame")
	shopFrame.Name = "ShopFrame"
	shopFrame.Size = UDim2.new(0.3, 0, 0.4, 0)
	shopFrame.Position = UDim2.new(0.7, 0, 0.1, 0)
	shopFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	shopFrame.BorderSizePixel = 0
	shopFrame.Visible = false
	shopFrame.Parent = mainFrame
	
	-- Create shop title
	local shopTitle = Instance.new("TextLabel")
	shopTitle.Name = "ShopTitle"
	shopTitle.Size = UDim2.new(1, 0, 0.1, 0)
	shopTitle.Position = UDim2.new(0, 0, 0, 0)
	shopTitle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	shopTitle.Text = "Unit Shop"
	shopTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	shopTitle.TextScaled = true
	shopTitle.Font = Enum.Font.GothamBold
	shopTitle.Parent = shopFrame
	
	-- Create board frame
	local boardFrame = Instance.new("Frame")
	boardFrame.Name = "BoardFrame"
	boardFrame.Size = UDim2.new(0.6, 0, 0.6, 0)
	boardFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
	boardFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	boardFrame.BorderSizePixel = 0
	boardFrame.Visible = false
	boardFrame.Parent = mainFrame
	
	-- Create board title
	local boardTitle = Instance.new("TextLabel")
	boardTitle.Name = "BoardTitle"
	boardTitle.Size = UDim2.new(1, 0, 0.1, 0)
	boardTitle.Position = UDim2.new(0, 0, 0, 0)
	boardTitle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	boardTitle.Text = "Battle Board"
	boardTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	boardTitle.TextScaled = true
	boardTitle.Font = Enum.Font.GothamBold
	boardTitle.Parent = boardFrame
	
	-- Create bench frame
	local benchFrame = Instance.new("Frame")
	benchFrame.Name = "BenchFrame"
	benchFrame.Size = UDim2.new(0.6, 0, 0.15, 0)
	benchFrame.Position = UDim2.new(0.05, 0, 0.85, 0)
	benchFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	benchFrame.BorderSizePixel = 0
	benchFrame.Visible = false
	benchFrame.Parent = mainFrame
	
	-- Create bench title
	local benchTitle = Instance.new("TextLabel")
	benchTitle.Name = "BenchTitle"
	benchTitle.Size = UDim2.new(1, 0, 0.3, 0)
	benchTitle.Position = UDim2.new(0, 0, 0, 0)
	benchTitle.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
	benchTitle.Text = "Bench"
	benchTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	benchTitle.TextScaled = true
	benchTitle.Font = Enum.Font.GothamBold
	benchTitle.Parent = benchFrame
	
	-- Create stats frame
	local statsFrame = Instance.new("Frame")
	statsFrame.Name = "StatsFrame"
	statsFrame.Size = UDim2.new(0.25, 0, 0.3, 0)
	statsFrame.Position = UDim2.new(0.05, 0, 0.05, 0)
	statsFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	statsFrame.BorderSizePixel = 0
	statsFrame.Parent = mainFrame
	
	-- Create stats title
	local statsTitle = Instance.new("TextLabel")
	statsTitle.Name = "StatsTitle"
	statsTitle.Size = UDim2.new(1, 0, 0.2, 0)
	statsTitle.Position = UDim2.new(0, 0, 0, 0)
	statsTitle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	statsTitle.Text = "Player Stats"
	statsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	statsTitle.TextScaled = true
	statsTitle.Font = Enum.Font.GothamBold
	statsTitle.Parent = statsFrame
	
	-- Create stats labels
	local goldLabel = Instance.new("TextLabel")
	goldLabel.Name = "GoldLabel"
	goldLabel.Size = UDim2.new(1, 0, 0.2, 0)
	goldLabel.Position = UDim2.new(0, 0, 0.6, 0)
	goldLabel.BackgroundTransparency = 1
	goldLabel.Text = "Gold: 100"
	goldLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	goldLabel.TextScaled = true
	goldLabel.Font = Enum.Font.Gotham
	goldLabel.Parent = statsFrame
	
	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.new(1, 0, 0.2, 0)
	levelLabel.Position = UDim2.new(0, 0, 0.2, 0)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "Level: 1"
	levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	levelLabel.TextScaled = true
	levelLabel.Font = Enum.Font.Gotham
	levelLabel.Parent = statsFrame
	
	local expLabel = Instance.new("TextLabel")
	expLabel.Name = "ExpLabel"
	expLabel.Size = UDim2.new(1, 0, 0.2, 0)
	expLabel.Position = UDim2.new(0, 0, 0.4, 0)
	expLabel.BackgroundTransparency = 1
	expLabel.Text = "Exp: 0/100"
	expLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	expLabel.TextScaled = true
	expLabel.Font = Enum.Font.Gotham
	expLabel.Parent = statsFrame
	
	local streakLabel = Instance.new("TextLabel")
	streakLabel.Name = "StreakLabel"
	streakLabel.Size = UDim2.new(1, 0, 0.2, 0)
	streakLabel.Position = UDim2.new(0, 0, 0.8, 0)
	streakLabel.BackgroundTransparency = 1
	streakLabel.Text = "Streak: 0"
	streakLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	streakLabel.TextScaled = true
	streakLabel.Font = Enum.Font.Gotham
	streakLabel.Parent = statsFrame
	
	-- Create keybind container
	local keybindContainer = Instance.new("Frame")
	keybindContainer.Name = "KeybindContainer"
	keybindContainer.Size = UDim2.new(0.2, 0, 0.15, 0)
	keybindContainer.Position = UDim2.new(0.8, 0, 0.85, 0)
	keybindContainer.BackgroundTransparency = 1
	keybindContainer.Parent = mainFrame
	
	-- Create F key indicator
	local fKeyIndicator = Instance.new("Frame")
	fKeyIndicator.Name = "FKeyIndicator"
	fKeyIndicator.Size = UDim2.new(0.45, 0, 0.4, 0)
	fKeyIndicator.Position = UDim2.new(0, 0, 0, 0)
	fKeyIndicator.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	fKeyIndicator.BorderSizePixel = 0
	fKeyIndicator.Parent = keybindContainer
	
	local fKeyLabel = Instance.new("TextLabel")
	fKeyLabel.Name = "FKeyLabel"
	fKeyLabel.Size = UDim2.new(1, 0, 0.6, 0)
	fKeyLabel.Position = UDim2.new(0, 0, 0, 0)
	fKeyLabel.BackgroundTransparency = 1
	fKeyLabel.Text = "F"
	fKeyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	fKeyLabel.TextScaled = true
	fKeyLabel.Font = Enum.Font.GothamBold
	fKeyLabel.Parent = fKeyIndicator
	
	local fKeyDesc = Instance.new("TextLabel")
	fKeyDesc.Name = "FKeyDesc"
	fKeyDesc.Size = UDim2.new(1, 0, 0.4, 0)
	fKeyDesc.Position = UDim2.new(0, 0, 0.6, 0)
	fKeyDesc.BackgroundTransparency = 1
	fKeyDesc.Text = "Shop"
	fKeyDesc.TextColor3 = Color3.fromRGB(200, 200, 200)
	fKeyDesc.TextScaled = true
	fKeyDesc.Font = Enum.Font.Gotham
	fKeyDesc.Parent = fKeyIndicator
	
	-- Create C key indicator
	local cKeyIndicator = Instance.new("Frame")
	cKeyIndicator.Name = "CKeyIndicator"
	cKeyIndicator.Size = UDim2.new(0.45, 0, 0.4, 0)
	cKeyIndicator.Position = UDim2.new(0.55, 0, 0, 0)
	cKeyIndicator.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	cKeyIndicator.BorderSizePixel = 0
	cKeyIndicator.Parent = keybindContainer
	
	local cKeyLabel = Instance.new("TextLabel")
	cKeyLabel.Name = "CKeyLabel"
	cKeyLabel.Size = UDim2.new(1, 0, 0.6, 0)
	cKeyLabel.Position = UDim2.new(0, 0, 0, 0)
	cKeyLabel.BackgroundTransparency = 1
	cKeyLabel.Text = "C"
	cKeyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	cKeyLabel.TextScaled = true
	cKeyLabel.Font = Enum.Font.GothamBold
	cKeyLabel.Parent = cKeyIndicator
	
	local cKeyDesc = Instance.new("TextLabel")
	cKeyDesc.Name = "CKeyDesc"
	cKeyDesc.Size = UDim2.new(1, 0, 0.4, 0)
	cKeyDesc.Position = UDim2.new(0, 0, 0.6, 0)
	cKeyDesc.BackgroundTransparency = 1
	cKeyDesc.Text = "Board"
	cKeyDesc.TextColor3 = Color3.fromRGB(200, 200, 200)
	cKeyDesc.TextScaled = true
	cKeyDesc.Font = Enum.Font.Gotham
	cKeyDesc.Parent = cKeyIndicator
	
	return templateGui
end

-- Function to clone the template
function UITemplate.cloneTemplate()
	local template = UITemplate.loadExistingTemplate()
	return template
end

return UITemplate
