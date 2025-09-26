# PVP Challenge System Test Guide

## Overview
The PVP Challenge System has been implemented with the following components:

1. **PVPChallengeManager** - Server-side challenge management
2. **BoardDetection** - Detects when players enter board areas
3. **PVPChallengeUI** - Challenge request and battle preparation UI
4. **ChallengePromptUI** - Prompt when entering another player's board

## How It Works

### 1. Board Detection
- Each player has a "Grass Arena" model in `Spawn Points -> <player id>`
- The system creates invisible detection zones around each board
- When a player enters another player's board area, a challenge prompt appears

### 2. Challenge Flow
1. Player A enters Player B's board area
2. Challenge prompt appears for Player A
3. Player A clicks "Challenge to Battle"
4. Player B receives a challenge request UI
5. Player B can accept or reject the challenge
6. If accepted, both players get a 10-second battle preparation timer
7. After preparation time, battle begins (not implemented yet)

### 3. UI Components
- **Challenge Prompt**: Appears when entering another player's board
- **Challenge Request**: Shows when someone challenges you
- **Battle Preparation**: 10-second countdown timer for arranging units

## Testing Instructions

### Prerequisites
1. Ensure you have a workspace structure with:
   ```
   workspace/
   ├── Spawn Points/
   │   ├── <player1_id>/
   │   │   └── Grass Arena/
   │   └── <player2_id>/
   │       └── Grass Arena/
   ```

### Test Steps
1. **Start the game** with at least 2 players
2. **Player 1** should see their board area created
3. **Player 2** should see their board area created
4. **Player 1** walks to **Player 2's** board area
5. **Player 1** should see the challenge prompt
6. **Player 1** clicks "Challenge to Battle"
7. **Player 2** should see the challenge request UI
8. **Player 2** accepts the challenge
9. Both players should see the 10-second battle preparation timer
10. After 10 seconds, the battle preparation UI disappears

### Expected Behavior
- Challenge prompts appear smoothly with animations
- Challenge requests are clearly visible
- Battle preparation timer counts down from 10 seconds
- All UI elements are properly positioned and styled
- Server logs show challenge creation, acceptance, and battle start

## Troubleshooting

### Common Issues
1. **No challenge prompt appears**
   - Check if BoardDetection system is initialized
   - Verify workspace structure has correct folder names
   - Check server console for error messages

2. **Challenge request not received**
   - Verify RemoteEvents are properly set up
   - Check if PVPChallengeManager is initialized
   - Ensure both players are in the game

3. **UI elements not visible**
   - Check if client modules are properly loaded
   - Verify PlayerGui exists and is accessible
   - Check for any script errors in client console

### Debug Information
- Server console shows challenge creation and status changes
- Client console shows UI initialization and event handling
- Check RemoteEvents folder in ReplicatedStorage for proper setup

## Next Steps
Once the PVP challenge system is working:
1. Implement the actual battle system
2. Add unit transfer from preparation to battle
3. Implement battle resolution and rewards
4. Add spectator mode for battles
5. Implement challenge history and statistics
