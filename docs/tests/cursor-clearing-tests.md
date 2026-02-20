# Cursor Clearing Tests

## Overview
These tests verify that the player's cursor is cleared after using the selection tool to place miners or remove ghost entities, preventing the selection tool from remaining in the player's hand.

## Test Setup
1. Start a new Factorio game
2. Enable the Miner Planner mod
3. Research basic technologies to unlock electric-mining-drill
4. Place some ore patches on the ground

## Test Cases

### Test 1: Cursor Cleared After Placement with Remembered Settings
**Preconditions:** Player has previously used the tool and "Remember settings" is enabled

**Steps:**
1. Use Miner Planner selection tool to select an ore patch
2. Configure settings and enable "Remember settings"
3. Click "Place" to create the mining setup
4. Wait for placement to complete
5. Open the tool again using ALT+M
6. Select another ore patch (should skip GUI due to remembered settings)
7. Check player's cursor_stack after placement

**Expected Results:**
- After step 3: Cursor should be empty (no selection tool in hand)
- After step 6: Cursor should be empty (no selection tool in hand)
- Player should need to press ALT+M again to get the selection tool

### Test 2: Cursor Cleared After Placement via GUI
**Preconditions:** New game or "Remember settings" is disabled

**Steps:**
1. Use ALT+M to get the Miner Planner selection tool
2. Drag-select an ore patch
3. Configure settings in the GUI
4. Click "Place" button
5. Immediately check player's cursor_stack

**Expected Results:**
- Cursor should be empty after placement
- Selection tool should not remain in hand
- Player should need to use ALT+M again to get the selection tool

### Test 3: Cursor Cleared After Ghost Removal
**Preconditions:** Existing ghost entities placed by the mod

**Steps:**
1. Use Miner Planner to place some ghost miners (via normal selection)
2. Use ALT+M to get the selection tool again
3. Hold SHIFT and drag-select over the ghost entities (alt-selection)
4. Wait for removal confirmation message
5. Check player's cursor_stack

**Expected Results:**
- Ghost entities should be removed
- Flying text confirms removal count
- Cursor should be empty (no selection tool in hand)

### Test 4: Cursor Clearing with No Resources Found
**Preconditions:** Empty area with no ore patches

**Steps:**
1. Use ALT+M to get selection tool
2. Drag-select an empty area (no resources)
3. Observe flying text message
4. Check player's cursor_stack

**Expected Results:**
- Flying text shows "No resources found"
- Note: Currently cursor is NOT cleared in this case (selection tool remains)
- This is expected behavior - player can try again immediately

### Test 5: Cursor Clearing with No Ghosts Found
**Preconditions:** Area with no ghost entities

**Steps:**
1. Use ALT+M to get selection tool
2. Hold SHIFT and drag-select an area with no ghosts
3. Observe flying text message
4. Check player's cursor_stack

**Expected Results:**
- Flying text shows "No ghosts found"
- Cursor should be empty even when no ghosts were removed

### Test 6: Cursor State After Closing GUI
**Preconditions:** GUI is open after selecting ore patch

**Steps:**
1. Use ALT+M and select an ore patch
2. GUI opens with configuration options
3. Press ESC or click Cancel button
4. Check player's cursor_stack

**Expected Results:**
- GUI closes without placing anything
- Note: Cursor should still have selection tool (not cleared on cancel)
- This is expected - player might want to select a different area

## Console Commands for Testing

### Check Cursor State
```lua
/c game.print("Cursor: " .. (game.player.cursor_stack.valid_for_read and game.player.cursor_stack.name or "empty"))
```

### Force Clear Cursor (if stuck)
```lua
/c game.player.clear_cursor()
```

### Create Test Ore Patch
```lua
/c local surface = game.player.surface
/c local position = game.player.position
/c for x = -10, 10 do
  for y = -10, 10 do
    surface.create_entity{name="iron-ore", position={position.x + x, position.y + y}, amount=1000}
  end
end
```

### Research Electric Mining
```lua
/c game.player.force.technologies["automation"].researched = true
```

## Regression Tests

### Test 7: Rapid Tool Usage
**Preconditions:** Multiple ore patches available

**Steps:**
1. Use selection tool to place miners
2. Immediately use ALT+M again (should give new tool)
3. Select another patch
4. Verify cursor clears after each placement

**Expected Results:**
- Each placement clears the cursor
- ALT+M always gives a new selection tool when cursor is empty
- No duplicate tools or stuck cursor states

### Test 8: Cursor Clearing Doesn't Break GUI Workflow
**Preconditions:** Normal GUI usage

**Steps:**
1. Select ore patch and open GUI
2. Make various configuration changes
3. Click Place
4. Verify placement succeeded and cursor cleared

**Expected Results:**
- GUI workflow functions normally
- All configuration options work correctly
- Placement executes as expected
- Cursor clears at the right time (after placement, not during GUI interaction)

## Pass Criteria
- All successful placements clear the cursor (both remembered settings and GUI paths)
- Ghost removal clears the cursor regardless of whether ghosts were found
- Failed selections (no resources) do NOT clear cursor (allow retry)
- GUI cancel/close does NOT clear cursor (allow reselection)
- No crashes or errors related to cursor clearing
- Player can repeatedly use the tool without cursor getting stuck
