# UI Setup Guide for Studio Editing

## Method 1: Create UI Template in ReplicatedStorage (Recommended)

### Step 1: Create the Template in Studio

1. **Open Roblox Studio** and your BloxTactics project
2. **Navigate to ReplicatedStorage** in the Explorer
3. **Create a new ScreenGui**:
   - Right-click on ReplicatedStorage
   - Insert → ScreenGui
   - Name it `BloxTacticsUITemplate`
   - Set `ResetOnSpawn` to `false`

### Step 2: Build the UI Structure

Create the following hierarchy in the ScreenGui:

```
BloxTacticsUITemplate (ScreenGui)
└── MainFrame (Frame)
    ├── ShopFrame (Frame) - Initially hidden
    │   └── ShopTitle (TextLabel)
    ├── BoardFrame (Frame) - Initially hidden
    │   └── BoardTitle (TextLabel)
    ├── BenchFrame (Frame) - Initially hidden
    │   └── BenchTitle (TextLabel)
    ├── StatsFrame (Frame) - Always visible
    │   ├── StatsTitle (TextLabel)
    │   ├── GoldLabel (TextLabel)
    │   ├── LevelLabel (TextLabel)
    │   ├── ExpLabel (TextLabel)
    │   └── StreakLabel (TextLabel)
    └── KeybindContainer (Frame)
        ├── FKeyIndicator (Frame)
        │   ├── FKeyLabel (TextLabel)
        │   └── FKeyDesc (TextLabel)
        └── CKeyIndicator (Frame)
            ├── CKeyLabel (TextLabel)
            └── CKeyDesc (TextLabel)
```

### Step 3: Configure Each Element

#### MainFrame
- **Size**: 1, 0, 1, 0 (Full screen)
- **BackgroundTransparency**: 1
- **Position**: 0, 0, 0, 0

#### ShopFrame
- **Size**: 0.3, 0, 0.4, 0
- **Position**: 0.7, 0, 0.1, 0
- **BackgroundColor**: Dark gray (40, 40, 40)
- **Visible**: false (initially hidden)

#### BoardFrame
- **Size**: 0.6, 0, 0.6, 0
- **Position**: 0.05, 0, 0.2, 0
- **BackgroundColor**: Dark gray (30, 30, 30)
- **Visible**: false (initially hidden)

#### BenchFrame
- **Size**: 0.6, 0, 0.15, 0
- **Position**: 0.05, 0, 0.85, 0
- **BackgroundColor**: Dark gray (35, 35, 35)
- **Visible**: false (initially hidden)

#### StatsFrame
- **Size**: 0.25, 0, 0.3, 0
- **Position**: 0.05, 0, 0.05, 0
- **BackgroundColor**: Dark gray (40, 40, 40)
- **Visible**: true (always visible)

#### KeybindContainer
- **Size**: 0.2, 0, 0.15, 0
- **Position**: 0.8, 0, 0.85, 0
- **BackgroundTransparency**: 1

### Step 4: Update the Code

The code is already set up to use the template! The `UITemplate.luau` module will create the template programmatically, but you can also:

1. **Create the template manually** in Studio (as described above)
2. **Update the UI module** to load from the existing template instead of creating it

### Method 2: Load from Existing Template

If you want to create the template manually in Studio and load it, update the `UITemplate.luau`:

```lua
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
```

Then update the UI module to use `loadExistingTemplate()` instead of `createTemplate()`.

## Benefits of This Approach

1. **Visual Editing**: Edit UI positions, sizes, and properties directly in Studio
2. **Real-time Preview**: See changes immediately in Studio
3. **Version Control**: Template is part of your project structure
4. **Flexibility**: Easy to modify without touching code
5. **Consistency**: All players get the same UI layout

## Tips for Studio Editing

1. **Use the Properties panel** to adjust positions and sizes
2. **Use the Explorer** to organize the hierarchy
3. **Test different screen sizes** using the Viewport
4. **Use Anchors** for responsive design
5. **Keep element names consistent** with the code expectations

## Troubleshooting

- **"Template not found"**: Make sure the ScreenGui is in ReplicatedStorage
- **"Frames not found"**: Check that all required frames exist with correct names
- **UI not appearing**: Verify the template is properly cloned and parented

This approach gives you the best of both worlds - visual editing in Studio and programmatic control from your code!
