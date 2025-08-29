# BloxTactics - Roblox TFT-Style Game Project Plan

## Overview
BloxTactics is a Teamfight Tactics (TFT) inspired game for Roblox where players build teams, challenge each other, and compete for gold rewards. Players manage their own board, units, and items while engaging in strategic battles.

## Core Features
- Individual player boards and benches
- Unit shop with level-based odds
- Unit tiering system (1-star to 3-star)
- PvP challenges with gold wagering
- GUI-based unit placement system
- Automated battle simulation
- Gold economy system

---

## Phase 1: Foundation & Core Systems

### Step 1: Project Structure & Basic Setup
- [x] Set up proper folder structure for client, server, and shared modules
- [x] Create basic player data structure (gold, level, experience, units, items)
- [x] Implement basic player spawning and board creation
- [x] Set up RemoteEvents for client-server communication

### Step 2: Player Data Management
- [x] Create PlayerData module to handle player state
- [x] Implement data persistence (save/load player data)
- [x] Set up player joining/leaving handlers
- [x] Create basic UI for displaying player stats (gold, level, etc.)

### Step 3: Unit System Foundation
- [x] Design unit data structure (name, cost, tier, stats, abilities)
- [x] Create Unit module for unit management
- [x] Implement unit creation and basic properties
- [x] Set up unit tiering system (1-star to 3-star)

---

## Phase 2: Shop & Economy System

### Step 4: Shop System
- [x] Create shop interface with unit display
- [x] Implement level-based unit odds calculation
- [x] Add shop refresh functionality
- [x] Create unit purchase system with gold validation

### Step 5: Leveling System
- [ ] Implement experience gain from battles
- [ ] Create level-up system with experience requirements
- [ ] Update shop odds based on player level
- [ ] Add level-up UI and effects

### Step 6: Gold Economy
- [ ] Implement gold earning from battles
- [ ] Add gold loss from unit purchases
- [ ] Create interest system (gold earned per round)
- [ ] Add streak bonuses (win/loss streaks)

---

## Phase 3: Board & Unit Management

### Step 7: Board System
- [x] Create visual board representation
- [x] Implement board grid system (hexagonal or square)
- [x] Add unit placement validation
- [x] Create board state management

### Step 8: Bench System
- [x] Implement bench for storing unused units
- [x] Create unit movement between board and bench
- [x] Add bench capacity management
- [x] Implement unit selling from bench

### Step 9: Unit Tiering
- [x] Create unit combination system (3 same units = 1 higher tier)
- [ ] Implement automatic tiering when conditions are met
- [ ] Add tier-up effects and animations
- [ ] Update unit stats based on tier

---

## Phase 4: PvP Challenge System

### Step 10: Challenge Framework
- [ ] Create player-to-player challenge system
- [ ] Implement challenge acceptance/rejection
- [ ] Add gold wagering system
- [ ] Create challenge queue and matchmaking

### Step 11: Pre-Battle GUI
- [ ] Design unit placement interface
- [ ] Implement drag-and-drop unit movement
- [ ] Add board preview functionality
- [ ] Create unit positioning validation

### Step 12: Battle Preparation
- [ ] Implement unit transfer from GUI to battle board
- [ ] Create battle board initialization
- [ ] Add unit positioning verification
- [ ] Implement battle start sequence

---

## Phase 5: Battle System

### Step 13: Battle Simulation Foundation
- [ ] Create battle arena and unit spawning
- [ ] Implement basic unit movement and targeting
- [ ] Add unit health and damage systems
- [ ] Create battle state management

### Step 14: Combat Mechanics
- [ ] Implement unit attack patterns and ranges
- [ ] Add unit abilities and special effects
- [ ] Create damage calculation system
- [ ] Implement unit death and removal

### Step 15: Battle Resolution
- [ ] Create win condition detection
- [ ] Implement battle end sequence
- [ ] Add gold distribution to winner
- [ ] Create battle replay/spectator system

---

## Phase 6: Items & Enhancements

### Step 16: Item System
- [ ] Design item data structure (name, effects, cost)
- [ ] Create item shop interface
- [ ] Implement item application to units
- [ ] Add item effects in battle

### Step 17: Unit Abilities
- [ ] Design unit-specific abilities
- [ ] Implement ability activation conditions
- [ ] Create ability effects and animations
- [ ] Add ability cooldown system

---

## Phase 7: UI/UX & Polish

### Step 18: Main Game Interface
- [ ] Create comprehensive game UI
- [ ] Add shop, board, and bench displays
- [ ] Implement player stats and information panels
- [ ] Create settings and options menu

### Step 19: Visual Effects & Animations
- [ ] Add unit movement animations
- [ ] Implement battle effects and particles
- [ ] Create tier-up animations
- [ ] Add victory/defeat effects

### Step 20: Sound & Audio
- [ ] Implement background music
- [ ] Add sound effects for actions
- [ ] Create battle audio
- [ ] Add UI feedback sounds

---

## Phase 8: Advanced Features

### Step 21: Leaderboards & Statistics
- [ ] Create player ranking system
- [ ] Implement match history
- [ ] Add statistics tracking
- [ ] Create leaderboard display

### Step 22: Social Features
- [ ] Add friend system
- [ ] Implement chat functionality
- [ ] Create party/team system
- [ ] Add spectating capabilities

### Step 23: Tournaments & Events
- [ ] Design tournament system
- [ ] Implement special events
- [ ] Add seasonal content
- [ ] Create reward systems

---

## Phase 9: Testing & Optimization

### Step 24: Testing & Bug Fixes
- [ ] Comprehensive testing of all systems
- [ ] Performance optimization
- [ ] Bug identification and fixes
- [ ] Balance adjustments

### Step 25: Final Polish
- [ ] UI/UX refinements
- [ ] Code cleanup and documentation
- [ ] Performance optimization
- [ ] Final testing and deployment

---

## Technical Considerations

### Data Structures
- **PlayerData**: gold, level, experience, units, items, board state
- **Unit**: name, cost, tier, stats, abilities, position
- **Item**: name, effects, cost, requirements
- **Board**: grid system, unit positions, validation rules

### Key Modules
- `PlayerData` - Player state management
- `Unit` - Unit creation and management
- `Shop` - Shop system and odds calculation
- `Board` - Board state and unit placement
- `Battle` - Battle simulation and resolution
- `Challenge` - PvP challenge system
- `UI` - User interface management

### RemoteEvents Needed
- `PurchaseUnit` - Buy unit from shop
- `PlaceUnit` - Move unit on board
- `ChallengePlayer` - Send challenge request
- `AcceptChallenge` - Accept/reject challenge
- `StartBattle` - Begin battle simulation
- `UpdateBoard` - Sync board state

---

## Development Guidelines

1. **Modular Design**: Keep systems separate and loosely coupled
2. **Data-Driven**: Use configuration files for unit stats, shop odds, etc.
3. **Error Handling**: Implement proper error handling and validation
4. **Performance**: Optimize for smooth gameplay with multiple players
5. **Scalability**: Design systems to handle future expansions
6. **Testing**: Test each step thoroughly before moving to the next

---

## Estimated Timeline
- **Phase 1-3**: Core systems (2-3 weeks)
- **Phase 4-5**: PvP and battle systems (2-3 weeks)
- **Phase 6-7**: Items and UI (1-2 weeks)
- **Phase 8-9**: Advanced features and polish (2-3 weeks)

**Total Estimated Time**: 7-11 weeks

---

## Success Metrics
- [ ] Players can successfully purchase and place units
- [ ] PvP challenges work without issues
- [ ] Battle simulation runs smoothly
- [ ] Gold economy is balanced
- [ ] UI is intuitive and responsive
- [ ] Game is stable with multiple concurrent players

This plan provides a structured approach to building your TFT-style Roblox game. Each step builds upon the previous ones, making it easy to test and modify as you progress through development.
