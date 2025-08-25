# BloxTactics Setup Instructions

## Fixing Module Loading Issues

If you're seeing errors like:
- `PlayerData is not a valid member of ServerScriptService`
- `UI is not a valid member of PlayerScripts`

Follow these steps to resolve the issues:

## Step 1: Restart Rojo

1. **Stop Rojo** if it's running
2. **Restart Rojo** with the command: `rojo serve`
3. **Reconnect** in Roblox Studio

## Step 2: Verify File Structure

Make sure your file structure looks like this:
```
src/
├── client/
│   ├── init.client.luau
│   └── UI.luau
├── server/
│   ├── init.server.luau
│   ├── PlayerData.luau
│   ├── Shop.luau
│   ├── Board.luau
│   ├── Bench.luau
│   └── RemoteEvents.luau
└── shared/
    ├── DataStructures.luau
    ├── Constants.luau
    ├── UnitDatabase.luau
    ├── UnitTiering.luau
    └── Hello.luau
```

## Step 3: Check Project Configuration

The `default.project.json` should map files like this:
- `src/server/` → `ServerScriptService`
- `src/client/` → `StarterPlayerScripts`
- `src/shared/` → `ReplicatedStorage.Shared`

## Step 4: Module Paths

All modules now use absolute paths:
- Server modules: `game.ReplicatedStorage.Shared.ModuleName`
- Client modules: `game.ReplicatedStorage.Shared.ModuleName`
- Shared modules: `script.Parent.ModuleName`

## Step 5: Test the Setup

1. **Start the game** in Roblox Studio
2. **Check the Output** for any error messages
3. **Look for** "BloxTactics Server initialized successfully!" and "BloxTactics Client initialized for [PlayerName]"

## Common Issues and Solutions

### Issue: "Module not found"
**Solution**: Make sure Rojo is running and connected to Studio

### Issue: "Invalid member" errors
**Solution**: Restart Rojo and reconnect to Studio

### Issue: Scripts not appearing in Studio
**Solution**: Check that the `default.project.json` file is correct and Rojo is syncing

## What Should Happen

When everything is working correctly:

1. **Server scripts** appear in `ServerScriptService`
2. **Client scripts** appear in `StarterPlayerScripts`
3. **Shared modules** appear in `ReplicatedStorage.Shared`
4. **No error messages** in the Output window
5. **UI appears** when a player joins the game

## Next Steps

Once the module loading issues are resolved, you can:
1. Test the basic UI functionality
2. Implement Phase 2 (Shop system)
3. Add more units to the database
4. Implement the battle system

## Getting Help

If you're still having issues:
1. Check the Roblox Studio Output for specific error messages
2. Verify all files exist in the correct locations
3. Make sure Rojo is properly configured and running
4. Try restarting both Rojo and Roblox Studio
