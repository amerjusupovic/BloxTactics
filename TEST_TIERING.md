# Tiering System Test

## Test Cases

### Test 1: Basic Tier 2 Combination
- Start with 2 tier 1 warriors on bench
- Buy 1 tier 1 warrior from shop
- Expected: 3 warriors combine into 1 tier 2 warrior
- Result: ✅ PASS

### Test 2: Basic Tier 3 Combination
- Start with 8 tier 1 warriors on bench
- Buy 1 tier 1 warrior from shop
- Expected: 9 warriors combine into 1 tier 3 warrior
- Result: ✅ PASS

### Test 3: Mixed Tier Combination
- Start with 2 tier 1 warriors + 2 tier 2 warriors on bench
- Buy 1 tier 1 warrior from shop
- Expected: 3 tier 2 warriors combine into 1 tier 3 warrior
- Result: ✅ PASS

### Test 4: Star Indicators
- 2 tier 1 warriors on bench/board
- Shop shows warrior with 2 silver stars
- Expected: Silver stars indicate tier 2 combination possible
- Result: ✅ PASS

- 8 tier 1 warriors on bench/board
- Shop shows warrior with 3 gold stars
- Expected: Gold stars indicate tier 3 combination possible
- Result: ✅ PASS

### Test 5: Unit Scaling
- Tier 1 warrior: Normal size
- Tier 2 warrior: 1.5x size
- Tier 3 warrior: 2.0x size (capped)
- Expected: Units scale with tier
- Result: ✅ PASS

## Implementation Notes

1. **Tiering Logic**: Units automatically combine when 3 of the same type and tier are available
2. **Star Indicators**: 
   - 2 silver stars = tier 2 combination possible
   - 3 gold stars = tier 3 combination possible
3. **Unit Scaling**: Units grow larger with higher tiers using tier multipliers
4. **Combination Priority**: 
   - For tier 3: Prefer 3 tier 2 units over 9 tier 1 units
   - For tier 2: Use 3 tier 1 units

## Files Modified

1. `src/shared/UnitTiering.luau` - New tiering logic module
2. `src/shared/UnitDatabase.luau` - Added size scaling function
3. `src/server/ShopManager.luau` - Integrated tiering into purchase flow
4. `src/server/Shop.luau` - Added star indicator updates
5. `src/server/UnitSpawner.luau` - Added unit scaling based on tier
6. `src/client/UI.luau` - Added star indicator display
7. `src/shared/DataStructures.luau` - Added starIndicator field to Unit type
