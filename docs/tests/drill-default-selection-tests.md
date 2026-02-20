# Drill Default Selection Tests

## Overview
These tests verify that the drill selector defaults to "electric-mining-drill" when available, and falls back to the first available drill when it's not researched.

## Test Setup
1. Start a new Factorio game
2. Enable the Miner Planner mod
3. Use console commands to manipulate technology research state

## Test Cases

### Test 1: Default to Electric Drill (Normal Game State)
**Preconditions:** Research "Automation" technology (unlocks electric-mining-drill)

**Steps:**
1. Use console: `/c game.player.force.technologies["automation"].researched = true`
2. Place some iron ore on the ground
3. Open Miner Planner selection tool
4. Drag-select the ore patch
5. Observe the GUI drill selector

**Expected Results:**
- Both burner-mining-drill and electric-mining-drill appear as options
- electric-mining-drill is selected by default (shown with pressed button style)
- No saved settings exist yet, so this is the default behavior

### Test 2: Fallback to First Drill (No Electric Research)
**Preconditions:** New game, no research completed

**Steps:**
1. Place some iron ore on the ground
2. Open Miner Planner selection tool
3. Drag-select the ore patch
4. Observe the GUI drill selector

**Expected Results:**
- Only burner-mining-drill appears (electric drill not yet researched)
- burner-mining-drill is selected by default
- electric-mining-drill does NOT appear in the selector

### Test 3: Electric Drill Default with Fluid Resources
**Preconditions:** Research "Automation" and "Uranium processing"

**Steps:**
1. Use console: `/c game.player.force.technologies["automation"].researched = true`
2. Use console: `/c game.player.force.technologies["uranium-processing"].researched = true`
3. Place uranium ore on the ground
4. Open Miner Planner and select uranium ore area
5. Observe the GUI drill selector

**Expected Results:**
- electric-mining-drill appears (has fluid input for sulfuric acid)
- electric-mining-drill is selected by default
- burner-mining-drill is filtered out (no fluid input capability)

### Test 4: Remembered Settings Override Default
**Preconditions:** Research "Automation", previously selected burner-mining-drill with "Remember settings" checked

**Steps:**
1. Complete Test 1 but select burner-mining-drill manually
2. Check "Remember settings" checkbox
3. Click "Place Miners"
4. Open the GUI again on a new ore patch

**Expected Results:**
- Both burner-mining-drill and electric-mining-drill appear
- burner-mining-drill is selected (remembered from previous use)
- electric-mining-drill is NOT selected, even though it would be the default for new users

### Test 5: Big Mining Drill Default (Space Age)
**Preconditions:** Space Age DLC installed, big mining drill researched

**Steps:**
1. Use console: `/c game.player.force.technologies["big-mining-drill"].researched = true`
2. Place some ore on the ground
3. Open Miner Planner and select the ore patch
4. Observe the GUI drill selector

**Expected Results:**
- burner-mining-drill, electric-mining-drill, and big-mining-drill all appear
- electric-mining-drill is selected by default (not big-mining-drill)
- big-mining-drill is available but not auto-selected

### Test 6: Modded Drills with Electric Name
**Preconditions:** Mod that adds custom drills including one named "electric-mining-drill-mk2"

**Steps:**
1. Install a mod with custom drills
2. Research required technologies
3. Open GUI and observe drill selector

**Expected Results:**
- Only exact match "electric-mining-drill" gets priority
- "electric-mining-drill-mk2" or similar names are NOT prioritized
- If "electric-mining-drill" exists, it's selected; otherwise first available drill

### Test 7: Invalid Remembered Drill After Research Regression
**Preconditions:** Saved settings remember "electric-mining-drill" but it's no longer researched

**Steps:**
1. Load a save with remembered electric-mining-drill
2. Use console to unresearch: `/c game.player.force.technologies["automation"].researched = false`
3. Open GUI on ore patch

**Expected Results:**
- electric-mining-drill does NOT appear (filtered out)
- Fallback to first available drill (burner-mining-drill)
- No crash or empty selection

### Test 8: No Drills Available (Edge Case)
**Preconditions:** Modded scenario where all drills are disabled

**Steps:**
1. Use console to disable all drill recipes
2. Open GUI on ore patch

**Expected Results:**
- Drill selector shows no options OR shows warning
- No crash when drill list is empty
- GUI handles gracefully

## Pass Criteria
- All tests pass without errors
- electric-mining-drill is selected by default when available in filtered list
- Fallback to first available drill when electric drill not in list
- Remembered settings always take priority over defaults
- No crashes with empty or invalid drill lists
