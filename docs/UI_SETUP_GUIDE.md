# UI Setup Guide

## Current UI System

The BloxTactics UI system now uses existing UI elements from ReplicatedStorage. The UITemplate system has been removed, and the code directly references UI elements that should already exist in ReplicatedStorage.

## Required UI Structure in ReplicatedStorage

You need to create a ScreenGui named `BloxTacticsUITemplate` in ReplicatedStorage with the following structure:

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
    ├── ChallengeFrame (Frame) - For challenge prompts
    │   ├── ChallengeLabel (TextLabel)
    │   ├── YesButton (TextButton)
    │   └── NoButton (TextButton)
    ├── IncomingChallengeFrame (Frame) - For incoming challenges
    │   └── IncomingChallengePrompt (Frame)
    │       ├── IncomingChallengeLabel (TextLabel)
    │       ├── YesButton (TextButton)
    │       └── NoButton (TextButton)
    ├── SellUnitFrame (Frame) - For selling units
    │   └── SellLabel (TextLabel)
    └── KeybindContainer (Frame)
        ├── FKeyIndicator (Frame)
        │   ├── FKeyLabel (TextLabel)
        │   └── FKeyDesc (TextLabel)
        └── CKeyIndicator (Frame)
            ├── CKeyLabel (TextLabel)
            └── CKeyDesc (TextLabel)
```

## How to Set Up UI

### Step 1: Create the UI in Studio
1. **Open Roblox Studio** and your BloxTactics project
2. **Navigate to ReplicatedStorage** in the Explorer
3. **Create a new ScreenGui**:
   - Right-click on ReplicatedStorage
   - Insert → ScreenGui
   - Name it `BloxTacticsUITemplate`
   - Set `ResetOnSpawn` to `false`

### Step 2: Build the UI Structure
Create the hierarchy shown above with all the required frames and labels.

### Step 3: Configure Properties
Set appropriate sizes, positions, colors, and other properties for each element.

## How the Code Works

- **UI.luau**: Looks for `BloxTacticsUITemplate` in ReplicatedStorage and clones it to the player's PlayerGui
- **ChallengePromptUI.luau**: Uses the `ChallengeFrame` from the cloned UI
- **IncomingChallengeUI.luau**: Uses the `IncomingChallengeFrame` and `IncomingChallengePrompt` from the cloned UI

## Key UI Functions

- `UI.createMainUI()`: Clones the UI from ReplicatedStorage to PlayerGui
- `UI.toggleShop()`: Shows/hides the shop (F key)
- `UI.toggleBoard()`: Shows/hides board and bench (C key)
- `UI.updatePlayerStats()`: Updates player statistics display

## Benefits of This Approach

1. **Visual Editing**: Edit UI directly in Studio
2. **No Code Dependencies**: UI structure is separate from code logic
3. **Easy Modifications**: Change UI without touching code
4. **Consistent Behavior**: All players get the same UI from ReplicatedStorage

## Troubleshooting

- **"BloxTacticsUITemplate not found"**: Make sure the ScreenGui exists in ReplicatedStorage
- **"MainFrame not found"**: Check that MainFrame exists as a child of BloxTacticsUITemplate
- **"Frames not found"**: Verify all required frames exist with correct names
- **UI not appearing**: Check that the UI is properly cloned and parented

The system now uses existing UI elements from ReplicatedStorage without any template system!
