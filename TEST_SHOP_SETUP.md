# Shop System Test Setup

## Overview
The shop system is now fully implemented and ready for testing! Here's what you need to do to test it:

## ✅ **What's Been Implemented:**

### **1. Complete Shop System**
- **Shop Manager**: Handles purchases, gold deduction, and unit placement
- **UI Integration**: Shop buttons with hex visuals and unit info
- **Board/Bench Integration**: Units automatically place on bench or board
- **Visual Feedback**: Grayed out buttons, notifications, and unit placement

### **2. Available Units**
The system includes these units for testing:
- **Knight** (Cost: 3) - Balanced melee unit
- **Warrior** (Cost: 1) - Cheap melee unit  
- **Archer** (Cost: 2) - Ranged unit
- **Mage** (Cost: 4) - Magic damage unit
- **Tank** (Cost: 5) - High health unit

### **3. Shop Features**
- **Automatic Placement**: Units go to bench first, then board if bench is full
- **Gold Management**: Automatically deducts gold on purchase
- **Shop Refresh**: Units are replaced after purchase
- **Visual Feedback**: Buttons gray out, notifications show

## 🧪 **Testing Steps:**

### **Step 1: Start the Game**
1. **Open Roblox Studio** with your BloxTactics project
2. **Start the game** (Play button)
3. **Join as a player** (you should see the UI appear)

### **Step 2: Test Shop Interaction**
1. **Press F** to open the shop
2. **Look for the shop buttons** - they should show hex shapes with unit info
3. **Click on a unit** (like the Knight for 3 gold)
4. **Check the results**:
   - Your gold should decrease by the unit cost
   - The unit should appear on your bench (press C to see)
   - A new unit should replace it in the shop
   - You should see a notification

### **Step 3: Test Board Placement**
1. **Buy several units** to fill your bench (6 slots)
2. **Buy one more unit** - it should automatically place on the board
3. **Press C** to see the board and bench

### **Step 4: Test Visual Feedback**
1. **Try to buy a unit you can't afford** - you should see an error message
2. **Check that buttons gray out** after purchase
3. **Verify notifications appear** for successful/failed purchases

## 🔧 **Troubleshooting:**

### **If Shop Doesn't Appear:**
- Check that the UI template is properly set up in Studio
- Verify the RemoteEvents are created in ReplicatedStorage
- Check the Output window for any error messages

### **If Purchases Don't Work:**
- Make sure you have enough gold (start with 100)
- Check that the ShopManager is properly initialized
- Verify the RemoteEvent connections

### **If Units Don't Place:**
- Check that the board/bench hexes are properly named
- Verify the board state is being updated correctly
- Check the Output window for placement messages

## 📝 **Expected Behavior:**

### **Successful Purchase:**
```
1. Click unit button
2. Gold decreases by unit cost
3. Unit appears on bench/board
4. New unit replaces it in shop
5. Notification shows "Unit placed on bench/board!"
```

### **Failed Purchase (Insufficient Gold):**
```
1. Click unit button
2. Gold stays the same
3. Unit remains in shop
4. Notification shows "Insufficient gold! Need X gold."
```

### **Failed Purchase (No Space):**
```
1. Click unit button
2. Gold stays the same
3. Unit remains in shop
4. Notification shows "No space on board or bench!"
```

## 🎯 **Next Steps:**

Once the basic shop is working, you can:
1. **Add more units** to the UnitDatabase
2. **Implement unit tiering** (combining 3 units)
3. **Add unit abilities** and special effects
4. **Create unit models** in the workspace
5. **Add drag-and-drop** for moving units

The foundation is now solid and ready for expansion!
