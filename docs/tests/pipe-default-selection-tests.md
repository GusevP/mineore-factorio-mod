# Pipe Default Selection Tests

## Purpose
Verify that the pipe selector defaults to "pipe" (iron pipe) when available, and falls back appropriately when not researched. Pipe selector only appears when mining uranium ore or other resources requiring fluid.

## Prerequisites
- Factorio 2.0 installed
- Miner Planner mod enabled
- New game or save with ability to modify research state
- Access to uranium ore patch (requires fluid for mining)

## Test Cases

### Test 1: Default to "pipe" when available
**Setup:**
- Start game with basic pipe recipe enabled (no research required for pipe)
- Ensure no previous pipe selection stored in mod settings
- Have uranium ore patch available (requires sulfuric acid)

**Steps:**
1. Click Miner Planner shortcut
2. Select uranium ore patch
3. Check pipe selector in GUI (should appear because uranium requires fluid)

**Expected Result:**
- "pipe" (iron pipe) is selected by default (button appears pressed)
- Other available pipes are shown but not selected

### Test 2: Fallback to first available pipe when "pipe" unavailable
**Setup:**
- Use console or mod to disable basic pipe recipe
- Have other pipe types available (e.g., modded pipes)
- Select uranium ore patch

**Steps:**
1. Click Miner Planner shortcut
2. Select uranium ore patch
3. Check pipe selector in GUI

**Expected Result:**
- First available pipe (alphabetically sorted) is selected by default
- "pipe" not shown in selector (filtered out)

### Test 3: Remember previous selection takes priority
**Setup:**
- Have multiple pipe types available
- Previously selected a different pipe type in a prior selection

**Steps:**
1. Click Miner Planner shortcut
2. Select uranium ore patch
3. Check pipe selector in GUI

**Expected Result:**
- Previously selected pipe is selected (remembering previous choice)
- Not "pipe", even though it would be the default

### Test 4: Reset to default when remembered pipe unavailable
**Setup:**
- Previously selected a modded pipe type
- Remove or disable the mod providing that pipe
- Basic "pipe" is available

**Steps:**
1. Click Miner Planner shortcut
2. Select uranium ore patch
3. Check pipe selector in GUI

**Expected Result:**
- Selection defaults to "pipe" (basic iron pipe)
- Previously selected modded pipe not shown in selector
- Previous selection is cleared because entity unavailable

### Test 5: No pipes available
**Setup:**
- Use console to disable all pipe recipes (edge case)
- No pipes available to player

**Steps:**
1. Click Miner Planner shortcut
2. Select uranium ore patch
3. Check pipe selector in GUI

**Expected Result:**
- Only "None" button is shown in pipe selector
- No entity buttons appear
- "None" button is selected by default

### Test 6: Pipe selector only appears for fluid-requiring resources
**Setup:**
- Have both iron ore (no fluid) and uranium ore (requires fluid)
- Basic pipe available

**Steps:**
1. Click Miner Planner shortcut
2. Select iron ore patch first
3. Check GUI - pipe selector should NOT appear
4. Cancel and select uranium ore patch
5. Check GUI - pipe selector should appear

**Expected Result:**
- Pipe selector only shown when selecting uranium (or other fluid-requiring ore)
- "pipe" is selected by default when selector appears

### Test 7: Modded pipes scenario
**Setup:**
- Install mod that adds custom pipe types
- Ensure basic "pipe" is still available
- Select uranium ore patch

**Steps:**
1. Click Miner Planner shortcut
2. Select uranium ore patch
3. Check pipe selector in GUI

**Expected Result:**
- "pipe" is still selected by default
- Modded pipes appear if available but don't affect default selection
- Vanilla pipe has priority over modded pipes

### Test 8: Quality integration (Space Age)
**Setup:**
- Space Age DLC enabled
- Basic pipe available
- Quality research enabled
- Select uranium ore patch

**Steps:**
1. Click Miner Planner shortcut
2. Select uranium ore patch
3. Check pipe selector and quality dropdown

**Expected Result:**
- "pipe" selected by default
- Quality dropdown available for pipes
- Default quality setting applies to pipe

## Pass Criteria
All 8 test cases must pass for pipe default selection to be considered working correctly.

## Notes
- These tests verify the interaction between technology filtering and default selection for pipes
- Pipe selector only appears when the selected resource requires fluid input
- Default selection only applies when no previous setting exists
- Remembered settings take priority over defaults
- Basic "pipe" entity has no recipe requirement (always available in vanilla)
