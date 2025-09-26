# Arena Structure Test Guide

## Overview
The Arena Spawner system has been implemented to automatically clone existing arena models from ReplicatedStorage for each player when they join. This creates the proper file structure for the PVP challenge system using your pre-built arena models.

## New File Structure

### Before (Old Structure)
```
workspace/
├── SpawnPoints/
│   ├── <player1_id>/
│   │   ├── Hex_1_1
│   │   ├── Hex_1_2
│   │   ├── ...
│   │   ├── Bench_1
│   │   ├── Bench_2
│   │   └── ...
│   └── <player2_id>/
│       ├── Hex_1_1
│       ├── Hex_1_2
│       ├── ...
│       ├── Bench_1
│       ├── Bench_2
│       └── ...
```

### After (New Structure)
```
workspace/
├── SpawnPoints/
│   ├── <player1_id>/
│   │   └── Grass Arena/
│   │       ├── Hex_1_1
│   │       ├── Hex_1_2
│   │       ├── ...
│   │       ├── Bench_1
│   │       ├── Bench_2
│   │       ├── ...
│   │       └── Enemy Unit Board/
│   │           ├── Hex_1_1
│   │           ├── Hex_1_2
│   │           ├── ...
│   └── <player2_id>/
│       └── Grass Arena/
│           ├── Hex_1_1
│           ├── Hex_1_2
│           ├── ...
│           ├── Bench_1
│           ├── Bench_2
│           ├── ...
│           └── Enemy Unit Board/
│               ├── Hex_1_1
│               ├── Hex_1_2
│               ├── ...
```

## What Gets Created

The system clones your existing Grass Arena model from `ReplicatedStorage -> Arenas -> Grass Arena` and positions it for each player.

### Expected Structure in Your Arena Model
Your Grass Arena model should contain:
- **Board hexes**: Hex_1_1 to Hex_4_7 (28 total hexes in a 7x4 grid)
- **Bench spots**: Bench_1 to Bench_6 (6 bench spots)
- **Enemy Unit Board**: A folder containing Hex_1_1 to Hex_4_7 for enemy units

### Arena Positioning
- Each player's arena is positioned at a unique location
- Horizontal spacing: 100 studs between players
- Vertical spacing: 100 studs between rows of players
- Formula: `(playerId % 10) * 100` horizontally, `math.floor(playerId / 10) * 100` vertically

## Testing Instructions

### Prerequisites
1. Ensure the ArenaSpawner module is properly loaded
2. Have at least one player join the game
3. **Important**: Make sure you have a Grass Arena model in `ReplicatedStorage -> Arenas -> Grass Arena`

### Test Steps
1. **Start the game** with at least 1 player
2. **Check the workspace** for the new structure:
   - Look for `SpawnPoints` folder
   - Look for `<player_id>` folder inside SpawnPoints
   - Look for `Grass Arena` folder inside the player folder
   - Verify all hexes and bench spots are created

### Expected Behavior
- **Player joins**: Arena model is automatically cloned and positioned
- **Arena structure**: Exact copy of your Grass Arena model from ReplicatedStorage
- **Positioning**: Each player gets a unique arena position (100 studs apart)
- **Player leaves**: Arena structure is automatically removed

### Console Output
You should see messages like:
```
Arena Spawner initialized - will clone existing arena models from ReplicatedStorage
Player [Name] joined, initializing arena and shop...
Cloning Grass Arena for player [Name]
Successfully cloned Grass Arena for player [Name] at position Vector3(x, 0, z)
Board Detection system initialized
Player [Name] entered [OtherPlayer]'s board area
```

## Integration with PVP System

### Board Detection
- The BoardDetection system now works with the new structure
- Challenge prompts appear when entering another player's arena
- Detection zones are created around each Grass Arena

### Unit Spawning
- Units are spawned on the appropriate hexes within Grass Arena
- Bench units are spawned on bench spots within Grass Arena
- Enemy units will be spawned on the Enemy Unit Board during battles

### Battle Preparation
- Players can arrange units on their board during the 10-second preparation
- Enemy units will be copied to the Enemy Unit Board for battle simulation

## Troubleshooting

### Common Issues
1. **No arena created**
   - Check if ArenaSpawner is initialized
   - Verify player joining/leaving handlers are set up
   - Check server console for error messages
   - **Most important**: Ensure Grass Arena model exists in `ReplicatedStorage -> Arenas -> Grass Arena`

2. **Missing hexes or bench spots**
   - Verify your Grass Arena model contains the expected hex and bench names
   - Check that Hex_1_1 to Hex_4_7 and Bench_1 to Bench_6 exist in your model
   - Ensure the Enemy Unit Board folder exists with its own hexes

3. **Units not spawning**
   - Ensure UnitSpawner is using ArenaSpawner functions
   - Check if hex/bench names in your model match the expected format
   - Verify unit models exist in ReplicatedStorage

### Debug Information
- Server console shows arena creation progress
- Check workspace structure in Studio
- Verify all required modules are loaded
- Look for any script errors or warnings

## Next Steps
Once the arena structure is working:
1. Test PVP challenge system with the new structure
2. Implement battle system using Enemy Unit Board
3. Add unit transfer from preparation to battle
4. Implement battle resolution and rewards
