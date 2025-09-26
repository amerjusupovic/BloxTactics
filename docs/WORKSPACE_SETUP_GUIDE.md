# Workspace Setup Guide

## Overview
To enable physical unit spawning, you need to create the proper folder structure in Workspace. This guide explains the required setup.

## 🏗️ **Required Workspace Structure:**

### **Option 1: Separate Folders (Recommended)**
```
Workspace/
├── SpawnPoints/          (For bench units)
│   └── [Player User ID]/
│       ├── Bench_1/
│       ├── Bench_2/
│       ├── Bench_3/
│       ├── Bench_4/
│       ├── Bench_5/
│       └── Bench_6/
└── SpawnUnits/           (For board units)
    └── [Player User ID]/
        ├── Hex_1_1/
        ├── Hex_1_2/
        ├── Hex_1_3/
        ├── Hex_2_1/
        ├── Hex_2_2/
        ├── Hex_2_3/
        ├── Hex_3_1/
        ├── Hex_3_2/
        ├── Hex_3_3/
        ├── Hex_4_1/
        ├── Hex_4_2/
        └── Hex_4_3/
```

### **Option 2: Single Folder (Alternative)**
```
Workspace/
└── [Player User ID]/
    ├── Bench_1/          (Bench slots)
    ├── Bench_2/
    ├── Bench_3/
    ├── Bench_4/
    ├── Bench_5/
    ├── Bench_6/
    ├── Hex_1_1/          (Board positions)
    ├── Hex_1_2/
    ├── Hex_1_3/
    ├── Hex_2_1/
    ├── Hex_2_2/
    ├── Hex_2_3/
    ├── Hex_3_1/
    ├── Hex_3_2/
    ├── Hex_3_3/
    ├── Hex_4_1/
    ├── Hex_4_2/
    └── Hex_4_3/
```

## 🔧 **Setup Instructions:**

### **Step 1: Create Main Folders**
1. **In Workspace**, create a folder called `SpawnPoints`
2. **In Workspace**, create a folder called `SpawnUnits`

### **Step 2: Create Player Folders**
1. **In SpawnPoints**, create a folder with your User ID (e.g., `2951571439`)
2. **In SpawnUnits**, create a folder with your User ID (e.g., `2951571439`)

### **Step 3: Create Bench Slots**
In `SpawnPoints/[Your User ID]/`, create 6 folders:
- `Bench_1`
- `Bench_2`
- `Bench_3`
- `Bench_4`
- `Bench_5`
- `Bench_6`

### **Step 4: Create Board Positions**
In `SpawnUnits/[Your User ID]/`, create 12 folders:
- `Hex_1_1`, `Hex_1_2`, `Hex_1_3`
- `Hex_2_1`, `Hex_2_2`, `Hex_2_3`
- `Hex_3_1`, `Hex_3_2`, `Hex_3_3`
- `Hex_4_1`, `Hex_4_2`, `Hex_4_3`

### **Step 5: Add Spawn Points (Optional)**
Each folder can contain a Part that serves as the spawn point:
- **Position**: Where you want units to appear
- **Size**: Appropriate for your unit models
- **Anchored**: `true`
- **Name**: Can be anything (the folder name is what matters)

## 🎯 **How It Works:**

### **Bench Units**
- **Folder**: `Workspace/SpawnPoints/[User ID]/Bench_X`
- **Units spawn** when purchased and bench has space
- **Position**: Units use `PivotTo(bench.CFrame)`

### **Board Units**
- **Folder**: `Workspace/SpawnUnits/[User ID]/Hex_R_C`
- **Units spawn** when bench is full and board has space
- **Position**: Units use `PivotTo(hex.CFrame)`

## 🚨 **Troubleshooting:**

### **"SpawnPoints folder not found"**
- **Solution**: Create `Workspace/SpawnPoints` folder
- **Check**: Folder name is exactly `SpawnPoints` (case-sensitive)

### **"SpawnUnits folder not found"**
- **Solution**: Create `Workspace/SpawnUnits` folder
- **Check**: Folder name is exactly `SpawnUnits` (case-sensitive)

### **"Player folder not found"**
- **Solution**: Create folder with your User ID in both SpawnPoints and SpawnUnits
- **Check**: User ID is correct (check Output window for your ID)

### **"Bench slot not found"**
- **Solution**: Create `Bench_1`, `Bench_2`, etc. folders
- **Check**: Folder names follow exact pattern `Bench_X`

### **"Board hex not found"**
- **Solution**: Create `Hex_R_C` folders
- **Check**: Folder names follow exact pattern `Hex_R_C`

## 🔍 **Finding Your User ID:**

1. **Start the game** in Roblox Studio
2. **Check the Output window** for messages like:
   - `"Player folder not found for userId: 2951571439"`
3. **Use that number** as your User ID folder name

## ✅ **Testing:**

1. **Create the folder structure** as described above
2. **Start the game** and join as a player
3. **Purchase units** from the shop
4. **Check Workspace** for physical unit models
5. **Verify positioning** and cleanup when leaving

## 🎨 **Customization:**

### **Spawn Point Parts**
- **Add Parts** to each folder for visual reference
- **Position them** where you want units to appear
- **Size them** appropriately for your unit models

### **Visual Organization**
- **Color-code** different areas (bench vs board)
- **Add labels** to identify different sections
- **Group related** spawn points together

Your physical unit spawning system should now work correctly!
