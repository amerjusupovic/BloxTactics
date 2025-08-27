# Physical Units Setup Guide

## Overview
The shop system now supports spawning actual 3D unit models in the workspace! When you purchase units, they will appear both in the UI and as physical models in the game world.

## ✅ **What's Been Implemented:**

### **1. UnitSpawner Module**
- **Automatic Model Loading**: Loads unit models from `ReplicatedStorage/UnitModels`
- **Board Spawning**: Places units on physical board hexes
- **Bench Spawning**: Places units on physical bench slots
- **Cleanup System**: Removes units when players leave

### **2. Integration with Shop System**
- **Automatic Spawning**: Units spawn when purchased from shop
- **Position Tracking**: Units are placed at correct board/bench positions
- **Data Storage**: Unit information stored in model attributes

## 🏗️ **Required Setup:**

### **Step 1: Create Unit Models Folder**
1. **In ReplicatedStorage**, create a folder called `UnitModels`
2. **Add your unit models** to this folder
3. **Model names must match** the unit names in your database:
   - `Knight` (for Knight unit)
   - `Warrior` (for Warrior unit)
   - `Archer` (for Archer unit)
   - `Mage` (for Mage unit)
   - `Tank` (for Tank unit)

### **Step 2: Create Player Board/Bench Structure**
In **Workspace**, create the following structure for each player:

```
Workspace/
└── [Player User ID]/
    ├── Hex_1_1/     (Board position 1,1)
    ├── Hex_1_2/     (Board position 1,2)
    ├── Hex_1_3/     (Board position 1,3)
    ├── Hex_2_1/     (Board position 2,1)
    ├── Hex_2_2/     (Board position 2,2)
    ├── Hex_2_3/     (Board position 2,3)
    ├── Hex_3_1/     (Board position 3,1)
    ├── Hex_3_2/     (Board position 3,2)
    ├── Hex_3_3/     (Board position 3,3)
    ├── Hex_4_1/     (Board position 4,1)
    ├── Hex_4_2/     (Board position 4,2)
    ├── Hex_4_3/     (Board position 4,3)
    ├── Bench_1/     (Bench slot 1)
    ├── Bench_2/     (Bench slot 2)
    ├── Bench_3/     (Bench slot 3)
    ├── Bench_4/     (Bench slot 4)
    ├── Bench_5/     (Bench slot 5)
    └── Bench_6/     (Bench slot 6)
```

### **Step 3: Board/Bench Hex Setup**
Each hex should be a **Part** with:
- **Name**: `Hex_R_C` or `Bench_C` (where R=row, C=column)
- **Position**: Where you want units to spawn
- **Size**: Appropriate for your unit models
- **Anchored**: `true`

## 🎯 **How It Works:**

### **Unit Purchase Flow:**
1. **Player clicks unit** in shop
2. **Server validates** purchase (gold, space)
3. **Unit added** to board/bench state
4. **Physical model spawned** at correct position
5. **UI updated** to show unit
6. **Shop refreshed** with new unit

### **Model Positioning:**
- **Board Units**: Spawn at `Hex_R_C` positions
- **Bench Units**: Spawn at `Bench_C` positions
- **Automatic Positioning**: Models use `PivotTo(hex.CFrame)`
- **Unique Names**: `UnitName_UnitId` format

### **Data Storage:**
Each spawned unit model stores:
- `UnitId`: Unique unit identifier
- `UnitName`: Unit type name
- `UnitTier`: Unit tier (1, 2, 3)
- `PositionX/Y` or `BenchSlot`: Location data

## 🔧 **Testing the System:**

### **Step 1: Verify Setup**
1. **Check ReplicatedStorage/UnitModels** exists
2. **Verify unit model names** match database
3. **Create test player folder** in Workspace
4. **Add board/bench hexes** with correct names

### **Step 2: Test Unit Purchase**
1. **Start the game** in Roblox Studio
2. **Join as a player** (create player folder if needed)
3. **Press F** to open shop
4. **Purchase a unit** (should spawn both UI and 3D model)
5. **Check workspace** for physical unit model

### **Step 3: Test Multiple Units**
1. **Buy several units** to fill bench
2. **Buy one more** (should go to board)
3. **Verify models appear** in correct positions
4. **Check tier labels** on models

## 🚨 **Troubleshooting:**

### **Units Not Spawning:**
- **Check UnitModels folder** exists in ReplicatedStorage
- **Verify model names** match unit names exactly
- **Check player folder** exists in Workspace
- **Verify hex names** follow naming convention

### **Units in Wrong Positions:**
- **Check hex naming** (Hex_1_1, Bench_1, etc.)
- **Verify hex positions** are set correctly
- **Check CFrame** of hex parts

### **Models Not Loading:**
- **Check Output window** for loading messages
- **Verify models are Models** (not Groups)
- **Check model names** match database

## 🎨 **Customization Tips:**

### **Model Requirements:**
- **Must be Models** (not Groups)
- **Names must match** unit database exactly
- **Should be appropriately sized** for your board
- **Consider using Pivot** for proper positioning

### **Visual Enhancements:**
- **Add animations** to unit models
- **Use different models** for different tiers
- **Add particle effects** for unit placement
- **Create custom materials** for different units

### **Performance Optimization:**
- **Keep models lightweight** (low polygon count)
- **Use LOD (Level of Detail)** for distant units
- **Consider streaming** for large numbers of units
- **Optimize textures** and materials

## 🚀 **Next Steps:**

Once physical units are working:
1. **Add unit animations** (idle, attack, death)
2. **Implement unit movement** between positions
3. **Add unit abilities** and special effects
4. **Create unit tier-up** visual effects
5. **Add unit selling** (remove from workspace)

Your game will now have both UI and physical representations of units!
