# Arena Baseplate Cloning System Test Guide

## Overview
The arena spawning system has been updated to:
1. Set max lobby size to 6 players (reduced from 8)
2. Clone the existing baseplate from Workspace -> Baseplate for new lobbies
3. Use the original baseplate at (0, 0, 0) for Lobby 1
4. Position arenas on top of the baseplates
5. Properly cleanup cloned baseplates when lobbies are empty

## Expected Behavior

### Lobby 1 (First 6 Players)
- **No baseplate creation** - uses existing baseplate at (0, 0, 0)
- Arenas are positioned on top of the existing baseplate
- Y position: GROUND_LEVEL (0) + 1 = 1

### Lobby 2+ (7+ Players)
- **Clones existing baseplate** from Workspace -> Baseplate
- Baseplates positioned at different X coordinates (2000, 4000, etc.)
- Arenas positioned on top of cloned baseplates
- Y position: GROUND_LEVEL (0) + 1 = 1

### Arena Positioning
- Arenas within a lobby are arranged in a **2x3 grid layout**

```
Grid Layout (Top View):
Z-axis (depth)
    ↑
    |  [P1]  [P2]  [P3]  ← Z = ARENA_SPACING/2 (Front Row)
    |  [P4]  [P5]  [P6]  ← Z = -ARENA_SPACING/2 (Back Row)
    +----------------→ X-axis (lobby spacing)
    -ARENA_SPACING    0    ARENA_SPACING
```

- **Z = ARENA_SPACING/2 (Front Row)**: Players 1, 2, 3
- **Z = -ARENA_SPACING/2 (Back Row)**: Players 4, 5, 6
- **X = -ARENA_SPACING (Left)**: Players 1, 4
- **X = 0 (Center)**: Players 2, 5
- **X = ARENA_SPACING (Right)**: Players 3, 6

**Detailed Positioning (Lobby 1):**
- **Player 1**: X = -ARENA_SPACING, Z = ARENA_SPACING/2 (Front Left)
- **Player 2**: X = 0, Z = ARENA_SPACING/2 (Front Center)
- **Player 3**: X = ARENA_SPACING, Z = ARENA_SPACING/2 (Front Right)
- **Player 4**: X = -ARENA_SPACING, Z = -ARENA_SPACING/2 (Back Left)
- **Player 5**: X = 0, Z = -ARENA_SPACING/2 (Back Center)
- **Player 6**: X = ARENA_SPACING, Z = -ARENA_SPACING/2 (Back Right)

**Formula:**
- X position: (lobbyId - 1) * LOBBY_SPACING + (column - 1) * ARENA_SPACING
- Y position: 1 (above baseplate)
- Z position: ARENA_SPACING/2 (front row) or -ARENA_SPACING/2 (back row)

### Player Limits
- Maximum 6 players per lobby
- New lobbies are automatically created when existing ones are full
- Players are positioned at the same X coordinate as their lobby but with individual Z offsets

### Cleanup
- **Lobby 1**: Never cleans up baseplate (it's the original)
- **Lobby 2+**: Cloned baseplates are automatically removed when the last arena is removed
- Empty lobbies are cleaned up completely

## Testing Scenarios

### Test 1: Single Lobby (1-6 Players)
1. Join with 1-6 players
2. Verify **NO** new baseplate is created
3. Verify arenas are positioned on existing baseplate at (0, 0, 0)
4. Verify character positions match arena positions

### Test 2: Multiple Lobbies (7+ Players)
1. Join with 7+ players
2. Verify second lobby is created at X=2000
3. Verify **cloned baseplate** is created from existing baseplate
4. Verify arenas in second lobby are positioned correctly on cloned baseplate

### Test 3: Lobby Cleanup
1. Have players in multiple lobbies
2. Remove all players from Lobby 2 (not Lobby 1)
3. Verify cloned baseplate is cleaned up
4. Verify lobby folder is destroyed
5. Verify Lobby 1 baseplate remains untouched

### Test 4: Arena Grid Layout
1. Join with 6 players in one lobby
2. Verify arenas are arranged in a 2x3 grid pattern
3. Verify front row (Z = 100) has players 1, 2, 3
4. Verify back row (Z = -100) has players 4, 5, 6
5. Verify left column (X = -200) has players 1, 4
6. Verify center column (X = 0) has players 2, 5
7. Verify right column (X = 200) has players 3, 6
8. Verify no overlap between arenas

## Key Changes Made

### Baseplate Handling
- **Lobby 1**: No baseplate creation, uses existing Workspace -> Baseplate
- **Lobby 2+**: Clones existing baseplate and positions at (lobbyId - 1) * 2000

### Positioning Logic
- Baseplates positioned at Y=0 (same as original)
- Arenas positioned at Y=1 (above baseplate)
- **Grid positioning**: 
  - Row = floor((playerIndex - 1) / 3) (0 = front row, 1 = back row)
  - Column = (playerIndex - 1) % 3 (0 = left, 1 = center, 2 = right)
  - X = (lobbyId - 1) * LOBBY_SPACING + (column - 1) * ARENA_SPACING
  - Z = ARENA_SPACING/2 (front row) or -ARENA_SPACING/2 (back row)
- This creates a proper 2x3 grid with 2 rows (Z) and 3 columns (X)

### Cleanup Logic
- Lobby 1 baseplate is never touched
- Only cloned baseplates (Lobby 2+) are cleaned up
- Prevents accidental deletion of the original baseplate

## Constants Used
- `MAX_PLAYERS_PER_LOBBY = 6`
- `LOBBY_SPACING = 2000`
- `ARENA_SPACING = 200`
- `GROUND_LEVEL = 0`

## File Changes Made
1. **ArenaSpawner.luau**: 
   - Modified to clone existing baseplate instead of creating custom ones
   - Added logic to skip baseplate creation for Lobby 1
   - Updated cleanup logic to preserve original baseplate
2. **Constants.luau**: GROUND_LEVEL set to 0 (already done)
3. **LobbyManager.luau**: Max lobby size set to 6 (already done)

## Benefits of This Approach
1. **Consistency**: All baseplates look identical (cloned from same source)
2. **Efficiency**: No need to recreate baseplate properties
3. **Safety**: Original baseplate is never modified or deleted
4. **Maintainability**: Changes to baseplate design automatically apply to all lobbies
