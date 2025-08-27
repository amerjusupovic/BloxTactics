# Unit Images Guide

## Overview
The shop system now supports custom images for each unit! Here's how to set up your own unit images.

## ✅ **What's Been Updated:**

### **1. Unit Data Structure**
- **Added `imageAssetId` field** to the Unit type
- **Each unit now has a unique image** that can be customized
- **Images are used in shop buttons** and unit displays

### **2. Current Setup**
All units currently use a placeholder hex image: `rbxassetid://135628423497794`

## 🎨 **How to Add Your Own Images:**

### **Step 1: Upload Images to Roblox**
1. **Go to Roblox Creator Dashboard**
2. **Navigate to "Create" → "Decals"**
3. **Upload your unit images** (PNG/JPG recommended)
4. **Copy the Asset ID** from each uploaded image

### **Step 2: Update UnitDatabase.luau**
Replace the placeholder asset IDs in `src/shared/UnitDatabase.luau`:

```lua
-- Example: Update Knight image
{
    id = "knight",
    name = "Knight",
    cost = 3,
    imageAssetId = "rbxassetid://YOUR_KNIGHT_IMAGE_ID", -- Replace with your image
    baseStats = {
        health = 100,
        attack = 25,
        armor = 15,
        magicResist = 10,
        attackSpeed = 1.0,
        range = 1
    },
    abilities = {}
},
```

### **Step 3: Image Recommendations**
- **Size**: 256x256 or 512x512 pixels
- **Format**: PNG with transparency
- **Style**: Square images work best (not hexagons)
- **Theme**: Match your game's visual style

## 🎯 **Example Unit Images:**

### **Knight**
- **Theme**: Armored warrior with sword/shield
- **Colors**: Silver, blue, or gold accents
- **Style**: Medieval/fantasy

### **Warrior**
- **Theme**: Basic fighter with weapon
- **Colors**: Brown, leather, simple
- **Style**: Simple, basic unit

### **Archer**
- **Theme**: Bow and arrow
- **Colors**: Green, brown, forest theme
- **Style**: Ranged unit indicator

### **Mage**
- **Theme**: Magic staff, spell effects
- **Colors**: Purple, blue, magical
- **Style**: Mystical/magical

### **Tank**
- **Theme**: Heavy armor, shield
- **Colors**: Dark, metallic, heavy
- **Style**: Defensive unit

## 🔧 **Testing Your Images:**

### **Step 1: Update Asset IDs**
1. **Replace placeholder IDs** in UnitDatabase.luau
2. **Save the file**
3. **Sync with Rojo** (if using Rojo)

### **Step 2: Test in Game**
1. **Start the game** in Roblox Studio
2. **Press F** to open shop
3. **Check that your images appear** in shop buttons
4. **Verify images look good** at different sizes

### **Step 3: Troubleshooting**
- **Image not showing**: Check asset ID is correct
- **Wrong image**: Verify you copied the right asset ID
- **Image too small/large**: Adjust image size or UI scaling

## 📝 **Asset ID Format:**
```
rbxassetid://123456789
```
Where `123456789` is your actual asset ID from Roblox.

## 🎨 **Advanced Tips:**

### **Consistent Style**
- **Use similar art style** for all units
- **Maintain consistent color palette**
- **Keep backgrounds transparent** for better integration

### **Performance**
- **Optimize image sizes** (don't use 4K images for small buttons)
- **Use PNG for transparency**
- **Consider using spritesheets** for multiple unit variations

### **Accessibility**
- **Ensure good contrast** between unit and background
- **Make units distinguishable** even in small sizes
- **Consider colorblind-friendly** color schemes

## 🚀 **Next Steps:**

Once you have your unit images set up:
1. **Test the shop system** with your new images
2. **Add more units** with their own images
3. **Create unit tier variations** (different images for tier 2/3)
4. **Add unit models** in the workspace to match the images

Your shop will now have a much more polished and professional look!
