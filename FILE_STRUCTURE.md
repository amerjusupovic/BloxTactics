# BloxTactics File Structure

This document explains the file structure of the BloxTactics project and how to navigate the codebase.

## Overview

The project follows a modular architecture with clear separation between client, server, and shared code. This structure makes it easy to:
- Find specific functionality quickly
- Modify code without affecting other systems
- Add new features in a organized way
- Understand the relationships between different components

## Directory Structure

```
src/
├── client/          # Client-side code (runs on player's device)
├── server/          # Server-side code (runs on Roblox servers)
└── shared/          # Shared code (used by both client and server)
```

## Shared Modules (`src/shared/`)

### Core Data Structures
- **`DataStructures.luau`** - Defines all the main data types used throughout the game
  - `PlayerData` - Player state including gold, level, units, etc.
  - `Unit` - Unit data with stats, abilities, position
  - `BoardState` - Board grid and unit positions
  - `BenchState` - Bench storage for unused units
  - `Item` - Item definitions and effects
  - `Challenge` - PvP challenge data
  - `Battle` - Battle state and results

### Configuration
- **`Constants.luau`** - All game constants and configuration values
  - Starting values (gold, level, etc.)
  - Board dimensions and capacities
  - Shop settings and odds
  - RemoteEvent names for networking

### Game Data
- **`UnitDatabase.luau`** - Unit definitions and base stats
  - Base unit stats for each tier
  - Unit creation and stat calculation
  - Tier multipliers for unit progression

### Utilities
- **`UnitTiering.luau`** - Unit combination and tiering system
  - Logic for combining 3 units into higher tiers
  - Auto-combination detection
  - Unit grouping by type and tier

- **`Hello.luau`** - General utility functions
  - Formatting functions for UI display
  - Validation helpers
  - Common utility functions

## Server Modules (`src/server/`)

### Data Management
- **`PlayerData.luau`** - Player data persistence and management
  - DataStore integration for saving/loading
  - Player joining/leaving handlers
  - Auto-save functionality
  - Gold and experience management

### Game Systems
- **`Shop.luau`** - Unit shop system
  - Level-based unit odds calculation
  - Shop generation and refresh
  - Unit purchase validation

- **`Board.luau`** - Board state management
  - Unit placement and movement
  - Position validation
  - Board state queries and updates

- **`Bench.luau`** - Bench storage system
  - Unit storage and retrieval
  - Capacity management
  - Unit organization

### Networking
- **`RemoteEvents.luau`** - Client-server communication setup
  - Creates all RemoteEvents used in the game
  - Provides access functions for event management

### Main Server
- **`init.server.luau`** - Main server initialization
  - Loads all server modules
  - Sets up RemoteEvent handlers
  - Initializes game systems

## Client Modules (`src/client/`)

### User Interface
- **`UI.luau`** - Client-side UI management
  - Creates and manages all GUI elements
  - Updates player stats display
  - Shop and board visualization
  - Notification system

### Main Client
- **`init.client.luau`** - Main client initialization
  - Loads client modules
  - Sets up RemoteEvent listeners
  - Initializes UI and requests initial data

## How to Navigate the Codebase

### Adding New Units
1. **Define the unit** in `src/shared/UnitDatabase.luau`
2. **Add base stats** in the `BASE_UNITS` table
3. **Update shop odds** in `src/shared/Constants.luau` if needed

### Adding New Features
1. **Define data structures** in `src/shared/DataStructures.luau`
2. **Add constants** in `src/shared/Constants.luau`
3. **Implement server logic** in appropriate `src/server/` module
4. **Add UI elements** in `src/client/UI.luau`
5. **Set up networking** in `src/server/RemoteEvents.luau` and handlers

### Modifying Existing Systems
- **Player data**: Look in `src/server/PlayerData.luau`
- **Shop system**: Look in `src/server/Shop.luau`
- **Board management**: Look in `src/server/Board.luau`
- **UI updates**: Look in `src/client/UI.luau`

### Finding Specific Functionality
- **Unit-related**: Check `UnitDatabase.luau` and `UnitTiering.luau`
- **Data structures**: Check `DataStructures.luau`
- **Constants**: Check `Constants.luau`
- **Server logic**: Check appropriate module in `src/server/`
- **Client UI**: Check `src/client/UI.luau`

## Development Workflow

1. **Start with data structures** - Define what data you need in `DataStructures.luau`
2. **Add constants** - Put configuration values in `Constants.luau`
3. **Implement server logic** - Add functionality in appropriate server module
4. **Add client UI** - Create UI elements in `UI.luau`
5. **Set up networking** - Add RemoteEvents and handlers
6. **Test and iterate** - Use the modular structure to easily test and modify

## Benefits of This Structure

- **Modularity**: Each system is self-contained and can be modified independently
- **Scalability**: Easy to add new features without affecting existing code
- **Maintainability**: Clear organization makes it easy to find and fix issues
- **Reusability**: Shared modules can be used across different parts of the game
- **Testing**: Individual modules can be tested in isolation

This structure follows Roblox best practices and makes the codebase easy to understand and modify as the project grows.
