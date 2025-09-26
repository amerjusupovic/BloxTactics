# Lobby System Test Guide

## Overview
The new Lobby System automatically creates multiple game instances (lobbies) when needed, each with their own complete workspace environment. This allows for better scalability and player management.

## How It Works

### **Automatic Lobby Creation**
- **Initial Lobby**: Created when the server starts
- **New Lobbies**: Automatically created when existing lobbies reach capacity
- **Player Distribution**: Players are automatically assigned to available lobbies
- **Lobby Cleanup**: Empty lobbies are automatically destroyed to save resources

### **Lobby Configuration**
- **Max Players per Lobby**: 8 players
- **Lobby Spacing**: 1000 studs apart horizontally
- **Auto-scaling**: Unlimited lobbies can be created as needed

## File Structure

### **Before (Single Instance)**
```
workspace/
├── Baseplate
├── SpawnPoints/
│   ├── <player1_id>/
│   │   └── Grass Arena/
│   └── <player2_id>/
│       └── Grass Arena/
├── Lighting
├── Terrain
└── Other objects...
```

### **After (Multiple Lobbies)**
```
workspace/
├── Baseplate
├── Lighting
├── Terrain
├── Other objects...
└── Lobby_1/ (Workspace)
    ├── Baseplate (cloned)
    ├── SpawnPoints/
    │   ├── <player1_id>/
    │   │   └── Grass Arena/
    │   └── <player2_id>/
    │       └── Grass Arena/
    ├── Lighting (cloned)
    ├── Terrain (cloned)
    └── Other objects (cloned)
└── Lobby_2/ (Workspace)
    ├── Baseplate (cloned)
    ├── SpawnPoints/
    │   ├── <player3_id>/
    │   │   └── Grass Arena/
    │   └── <player4_id>/
    │       └── Grass Arena/
    ├── Lighting (cloned)
    ├── Terrain (cloned)
    └── Other objects (cloned)
```

## What Gets Cloned

### **Complete Workspace Environment**
- ✅ **Baseplate** - The main ground surface
- ✅ **Lighting** - All lighting settings and effects
- ✅ **Terrain** - Terrain settings and appearance
- ✅ **Other Objects** - Any additional workspace objects (decorations, buildings, etc.)
- ✅ **SpawnPoints** - Fresh folder for each lobby

### **Lobby-Specific Managers**
Each lobby gets its own instances of:
- **ArenaSpawner** - Manages arena creation for that lobby
- **BoardDetection** - Handles PVP challenge detection
- **ShopManager** - Manages shops and units
- **PlayerDataManager** - Handles player data
- **UnitSpawner** - Manages unit spawning
- **PVPChallengeManager** - Handles PVP challenges

## Testing Instructions

### **Prerequisites**
1. Ensure the LobbyManager module is properly loaded
2. Have at least 1 player join the game
3. **Important**: Make sure you have a Grass Arena model in `ReplicatedStorage -> Arenas -> Grass Arena`

### **Test Steps**

#### **1. Basic Lobby Creation**
1. **Start the game** with 1 player
2. **Check the workspace** for the new structure:
   - Look for `Lobby_1` folder
   - Verify it contains cloned Baseplate, Lighting, Terrain
   - Check that SpawnPoints folder exists
   - Verify player's arena is created inside Lobby_1

#### **2. Multiple Lobby Creation**
1. **Add more players** (up to 8 in first lobby)
2. **Add 9th player** - should automatically create Lobby_2
3. **Verify Lobby_2** contains:
   - Cloned workspace environment
   - New SpawnPoints folder
   - 9th player's arena

#### **3. Lobby Scaling**
1. **Continue adding players** (9th through 16th)
2. **Verify Lobby_2** fills up to 8 players
3. **Add 17th player** - should create Lobby_3
4. **Check positioning** - lobbies should be 1000 studs apart

#### **4. Player Movement Between Lobbies**
1. **Have players leave** from different lobbies
2. **Verify lobby cleanup** - empty lobbies should be destroyed
3. **Check new player assignment** - should fill existing lobbies before creating new ones

### **Expected Behavior**

#### **Player Joining**
- **1st-8th players**: Join Lobby_1
- **9th-16th players**: Join Lobby_2
- **17th-24th players**: Join Lobby_3
- **And so on...**

#### **Lobby Management**
- **Automatic creation**: New lobbies created when needed
- **Player distribution**: Even distribution across available lobbies
- **Resource cleanup**: Empty lobbies automatically destroyed
- **Isolation**: Players in different lobbies cannot interact

#### **Arena Creation**
- **Per-lobby arenas**: Each lobby has its own arena system
- **Positioning**: Arenas positioned within their lobby workspace
- **PVP system**: Challenge system works within each lobby

## Console Output

### **Server Start**
```
BloxTactics Server initialized successfully!
Initializing BloxTactics game systems...
Lobby Manager initialized - Max players per lobby: 8
Created lobby workspace 1 at position Vector3(1000, 0, 0)
Created new lobby 1 with 8 player capacity
Initialized managers for lobby 1
Lobby Manager setup complete
Game systems initialized!
```

### **Player Joining**
```
Added player [Name] to lobby 1 (Total: 1/8)
Cloning Grass Arena for player [Name]
Successfully cloned Grass Arena for player [Name] at position Vector3(x, 0, z)
Initialized player [Name] in lobby 1
```

### **New Lobby Creation**
```
Added player [Name] to lobby 2 (Total: 1/8)
Created lobby workspace 2 at position Vector3(2000, 0, 0)
Created new lobby 2 with 8 player capacity
Initialized managers for lobby 2
```

### **Lobby Cleanup**
```
Removed player [ID] from lobby 1 (Remaining: 0)
Cleaned up empty lobby 1
```

## Integration with Existing Systems

### **PVP Challenge System**
- **Lobby isolation**: Players can only challenge others in the same lobby
- **Board detection**: Works within each lobby's workspace
- **Challenge management**: Each lobby has its own PVP manager

### **Shop and Units**
- **Per-lobby shops**: Each lobby has independent shop instances
- **Unit management**: Units are managed within their respective lobbies
- **Player data**: Each lobby maintains its own player data

### **Arena System**
- **Cloned arenas**: Uses existing Grass Arena model from ReplicatedStorage
- **Positioning**: Arenas positioned within lobby workspace
- **Enemy boards**: Each arena has its own enemy unit board

## Troubleshooting

### **Common Issues**

#### **1. No lobbies created**
- Check if LobbyManager is initialized
- Verify player joining/leaving handlers are set up
- Check server console for error messages

#### **2. Lobbies not scaling**
- Verify MAX_PLAYERS_PER_LOBBY is set correctly (default: 8)
- Check if new lobbies are being created when needed
- Look for any script errors in the server console

#### **3. Players not distributed correctly**
- Check lobby assignment logic
- Verify lobby capacity calculations
- Ensure player counting is accurate

#### **4. Workspace cloning issues**
- Verify Baseplate exists in main workspace
- Check if Lighting and Terrain services are accessible
- Look for any cloning errors in console

### **Debug Information**
- Server console shows lobby creation and management
- Check workspace structure in Studio
- Verify all required modules are loaded
- Look for any script errors or warnings

## Performance Considerations

### **Resource Management**
- **Lobby cleanup**: Empty lobbies are automatically destroyed
- **Memory efficiency**: Only active lobbies consume resources
- **Scaling limits**: Monitor performance with many concurrent lobbies

### **Recommended Limits**
- **Maximum lobbies**: Test with 10+ lobbies to ensure stability
- **Player density**: 8 players per lobby provides good balance
- **Lobby spacing**: 1000 studs prevents overlap and performance issues

## Next Steps

Once the lobby system is working:
1. **Test PVP system** within individual lobbies
2. **Implement cross-lobby features** (if needed)
3. **Add lobby management commands** for admins
4. **Optimize performance** for high player counts
5. **Add lobby-specific settings** (different arena types, rules, etc.)

## Configuration Options

### **Customizable Settings**
```lua
-- In LobbyManager.luau
local MAX_PLAYERS_PER_LOBBY = 8        -- Players per lobby
local LOBBY_SPACING = 1000             -- Distance between lobbies
local AUTO_CLEANUP_EMPTY = true        -- Auto-destroy empty lobbies
local MAX_LOBBIES = 50                 -- Maximum lobbies allowed
```

### **Future Enhancements**
- **Lobby types**: Different arena themes (Grass, Desert, Ice, etc.)
- **Lobby rules**: Custom game rules per lobby
- **Lobby persistence**: Save lobby state between sessions
- **Admin controls**: Manual lobby management tools
