--[[
    ShieldVisuals.luau
    Client-side visual for unit shields using Highlight
]]

local ShieldVisuals = {}

local Workspace = game:GetService("Workspace")

-- Registry: model -> { conn: RBXScriptConnection? }
local tracked: {[Instance]: {shieldConn: RBXScriptConnection?, maxConn: RBXScriptConnection?}} = {}

local HIGHLIGHT_NAME = "BT_ShieldHighlight"
local BILLBOARD_NAME = "BT_ShieldBar"
local HEALTH_BILLBOARD_NAME = "BT_HealthBar"

local function findAdorneePart(model: Model): BasePart?
    if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
        return model.PrimaryPart
    end
    -- Prefer Head-like parts
    local head = model:FindFirstChild("Head")
    if head and head:IsA("BasePart") then return head end
    -- Fallback to any BasePart
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then return d end
    end
    return nil
end

local function ensureShieldBillboard(model: Model, shield: number, maxHealth: number)
    local adornee = findAdorneePart(model)
    if not adornee then return end

    local existing = model:FindFirstChild(BILLBOARD_NAME)
    if not existing or not existing:IsA("BillboardGui") then
        -- Create billboard
        local bb = Instance.new("BillboardGui")
        bb.Name = BILLBOARD_NAME
        bb.AlwaysOnTop = true
        bb.LightInfluence = 0
    bb.Size = UDim2.fromOffset(100, 10)
    -- Place shield bar slightly above health bar
    bb.StudsOffsetWorldSpace = Vector3.new(0, (model:GetExtentsSize().Y) + 10, 0)
        bb.Adornee = adornee
        bb.Parent = model

        -- Background frame (like Roblox health bar)
        local bg = Instance.new("Frame")
        bg.Name = "BG"
        bg.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        bg.BackgroundTransparency = 0.2
        bg.Size = UDim2.fromScale(1, 1)
        bg.BorderSizePixel = 0
        bg.Parent = bb

        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 1
        stroke.Color = Color3.fromRGB(0, 0, 0)
        stroke.Parent = bg

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 3)
        corner.Parent = bg

        local fill = Instance.new("Frame")
        fill.Name = "Fill"
        fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
        fill.Size = UDim2.fromScale(0, 1)
        fill.BorderSizePixel = 0
        fill.Parent = bg

        local fillCorner = corner:Clone()
        fillCorner.Parent = fill

        local label = Instance.new("TextLabel")
        label.Name = "PercentLabel"
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 1)
        label.TextScaled = true
        label.Font = Enum.Font.GothamSemibold
        label.TextColor3 = Color3.fromRGB(225, 245, 255)
        label.Parent = bg

        existing = bb
    end

    -- Update values
    local percent = 0
    if maxHealth and maxHealth > 0 then
        percent = math.clamp(shield / maxHealth, 0, 1)
    end

    local bg = existing:FindFirstChild("BG")
    if bg and bg:IsA("Frame") then
        local fill = bg:FindFirstChild("Fill")
        if fill and fill:IsA("Frame") then
            fill.Size = UDim2.fromScale(percent, 1)
        end
        local label = bg:FindFirstChild("PercentLabel")
        if label and label:IsA("TextLabel") then
            label.Text = string.format("%d%%", math.floor(percent * 100 + 0.5))
            label.Visible = percent > 0
        end
    end
end

local function ensureHealthBillboard(model: Model, health: number, maxHealth: number)
    local adornee = findAdorneePart(model)
    if not adornee then return end

    local existing = model:FindFirstChild(HEALTH_BILLBOARD_NAME)
    if not existing or not existing:IsA("BillboardGui") then
        local bb = Instance.new("BillboardGui")
        bb.Name = HEALTH_BILLBOARD_NAME
        bb.AlwaysOnTop = true
        bb.LightInfluence = 0
        bb.Size = UDim2.fromOffset(100, 10)
        -- Health bar just above head
        bb.StudsOffsetWorldSpace = Vector3.new(0, (model:GetExtentsSize().Y) + 1.0, 0)
        bb.Adornee = adornee
        bb.Parent = model

        local bg = Instance.new("Frame")
        bg.Name = "BG"
        bg.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        bg.BackgroundTransparency = 0.2
        bg.Size = UDim2.fromScale(1, 1)
        bg.BorderSizePixel = 0
        bg.Parent = bb

        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 1
        stroke.Color = Color3.fromRGB(0, 0, 0)
        stroke.Parent = bg

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 3)
        corner.Parent = bg

        local fill = Instance.new("Frame")
        fill.Name = "Fill"
        fill.BackgroundColor3 = Color3.fromRGB(55, 200, 70) -- green health
        fill.Size = UDim2.fromScale(0, 1)
        fill.BorderSizePixel = 0
        fill.Parent = bg

        local fillCorner = corner:Clone()
        fillCorner.Parent = fill

        local label = Instance.new("TextLabel")
        label.Name = "PercentLabel"
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 1)
        label.TextScaled = true
        label.Font = Enum.Font.GothamSemibold
        label.TextColor3 = Color3.fromRGB(235, 255, 235)
        label.Parent = bg

        existing = bb
    end

    local percent = 0
    if maxHealth and maxHealth > 0 then
        percent = math.clamp(health / maxHealth, 0, 1)
    end
    local bg = existing:FindFirstChild("BG")
    if bg and bg:IsA("Frame") then
        local fill = bg:FindFirstChild("Fill")
        if fill and fill:IsA("Frame") then
            fill.Size = UDim2.fromScale(percent, 1)
        end
        local label = bg:FindFirstChild("PercentLabel")
        if label and label:IsA("TextLabel") then
            label.Text = string.format("%d%%", math.floor(percent * 100 + 0.5))
        end
    end
end
local function ensureHighlight(model: Model, hasShield: boolean)
    -- Remove if no shield
    local existing = model:FindFirstChild(HIGHLIGHT_NAME)
    if not hasShield then
        if existing and existing:IsA("Highlight") then existing:Destroy() end
        return
    end

    if not existing or not existing:IsA("Highlight") then
        local hl = Instance.new("Highlight")
        hl.Name = HIGHLIGHT_NAME
        hl.Adornee = model
        hl.FillColor = Color3.fromRGB(0, 200, 255)
        hl.FillTransparency = 0.75
        hl.OutlineColor = Color3.fromRGB(0, 255, 255)
        hl.OutlineTransparency = 0.2
        hl.DepthMode = Enum.HighlightDepthMode.Occluded
        hl.Parent = model
        existing = hl
    end
end

local function updateForModel(model: Model)
    local shieldVal = model:GetAttribute("Shield")
    local maxHealth = model:GetAttribute("MaxHealth")
    local healthVal = model:GetAttribute("Health")
    local hasShield = (typeof(shieldVal) == "number" and shieldVal > 0)
    ensureHighlight(model, hasShield)
    -- Billboard bar
    local existingBB = model:FindFirstChild(BILLBOARD_NAME)
    if hasShield and typeof(maxHealth) == "number" and maxHealth > 0 then
        ensureShieldBillboard(model, shieldVal, maxHealth)
    else
        if existingBB and existingBB:IsA("BillboardGui") then
            existingBB:Destroy()
        end
    end
    -- Health bar (always when health/max present)
    local healthBB = model:FindFirstChild(HEALTH_BILLBOARD_NAME)
    if typeof(healthVal) == "number" and typeof(maxHealth) == "number" and maxHealth > 0 then
        ensureHealthBillboard(model, healthVal, maxHealth)
    else
        if healthBB and healthBB:IsA("BillboardGui") then
            healthBB:Destroy()
        end
    end
end

local function attach(model: Model)
    if tracked[model] then return end
    -- Only track unit models (identified by UnitId attribute)
    if not model:GetAttribute("UnitId") then return end
    -- Initial update
    updateForModel(model)
    -- Subscribe to Shield, Health and MaxHealth changes
    local sConn = model:GetAttributeChangedSignal("Shield"):Connect(function()
        updateForModel(model)
    end)
    local hConn = model:GetAttributeChangedSignal("Health"):Connect(function()
        updateForModel(model)
    end)
    local mConn = model:GetAttributeChangedSignal("MaxHealth"):Connect(function()
        updateForModel(model)
    end)
    tracked[model] = { shieldConn = sConn, maxConn = mConn, healthConn = hConn }
end

local function detach(model: Model)
    local entry = tracked[model]
    if entry then
        if entry.shieldConn then entry.shieldConn:Disconnect() end
        if entry.maxConn then entry.maxConn:Disconnect() end
        if entry.healthConn then entry.healthConn:Disconnect() end
        tracked[model] = nil
    end
    local existing = model:FindFirstChild(HIGHLIGHT_NAME)
    if existing and existing:IsA("Highlight") then
        existing:Destroy()
    end
    local bb = model:FindFirstChild(BILLBOARD_NAME)
    if bb and bb:IsA("BillboardGui") then
        bb:Destroy()
    end
    local hbb = model:FindFirstChild(HEALTH_BILLBOARD_NAME)
    if hbb and hbb:IsA("BillboardGui") then
        hbb:Destroy()
    end
end

function ShieldVisuals.init()
    -- Attach to existing unit models
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("Model") then
            attach(inst)
        end
    end
    -- Watch for future models
    Workspace.DescendantAdded:Connect(function(inst)
        if inst:IsA("Model") then
            attach(inst)
        end
    end)
    Workspace.DescendantRemoving:Connect(function(inst)
        if inst:IsA("Model") then
            detach(inst)
        end
    end)
end

return ShieldVisuals
