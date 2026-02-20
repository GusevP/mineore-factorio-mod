# Selection Tool Inventory Tests

## Test Objective

Verify that the mineore selection tool never appears in the player's inventory and only exists in the cursor when activated.

## Test Prerequisites

- Fresh save or new game
- Mineore mod installed and active
- Player has access to ore patches

## Test Cases

### Test 1: Selection tool activation via shortcut

**Steps:**
1. Click the mineore shortcut button in the toolbar (or press ALT+M)
2. Observe the player cursor
3. Check inventory slots

**Expected results:**
- Selection tool appears in cursor (green selection box appears when hovering)
- Selection tool does NOT appear in any inventory slot
- Cursor is holding the selection tool item

### Test 2: Selection tool after ore selection

**Steps:**
1. Activate selection tool via shortcut
2. Drag selection over an ore patch
3. After GUI appears, observe cursor and inventory

**Expected results:**
- Cursor is cleared (no tool in hand)
- Selection tool does NOT appear in inventory
- Configuration GUI is displayed

### Test 3: Selection tool after placement

**Steps:**
1. Activate selection tool and select ore patch
2. Configure settings in GUI
3. Click "Place" button
4. After placement completes, check cursor and inventory

**Expected results:**
- Cursor is cleared
- Selection tool does NOT appear in inventory
- Ghost entities are placed on the map

### Test 4: Selection tool after ghost removal

**Steps:**
1. Place ghost entities using mineore
2. Activate selection tool via shortcut
3. Hold SHIFT and drag selection over placed ghosts (alt-selection)
4. After removal, check cursor and inventory

**Expected results:**
- Ghosts are removed
- Cursor is cleared
- Selection tool does NOT appear in inventory

### Test 5: Selection tool after GUI cancel

**Steps:**
1. Activate selection tool and select ore patch
2. In the configuration GUI, click "Cancel" or "X" button
3. Check cursor and inventory

**Expected results:**
- GUI is closed
- Cursor may still have tool (not cleared on cancel)
- Selection tool does NOT appear in inventory slots

### Test 6: Selection tool flags verification

**Steps:**
1. Open prototypes/selection-tool.lua in editor
2. Verify flags property is set to {"only-in-cursor"}
3. Verify hidden property is set to true

**Expected results:**
- flags = {"only-in-cursor"} is present in selection tool definition
- hidden = true is present in selection tool definition

## Implementation Details

**File:** prototypes/selection-tool.lua
- Line 9: flags = {"only-in-cursor"} prevents tool from entering inventory
- Line 10: hidden = true prevents tool from appearing in crafting menu

**File:** control.lua
- Line 59: cursor_stack.set_stack() places tool directly in cursor
- Lines 212, 264, 304: clear_cursor() removes tool after use

## Notes

- The "only-in-cursor" flag is a Factorio engine feature that prevents items from being placed in inventory slots
- The selection tool should automatically disappear when the cursor is cleared
- If the player tries to place the tool in inventory manually, it should fail silently
