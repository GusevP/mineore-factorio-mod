# Entity Filtering Tests

## Overview
These tests verify that GUI selectors only show entities whose recipes are enabled for the player's force based on their current technology research.

## Test Setup
1. Start a new Factorio game
2. Enable the Miner Planner mod
3. Use console commands to manipulate technology research state

## Test Cases

### Test 1: Initial State (No Research)
**Preconditions:** New game, no research completed

**Steps:**
1. Place some iron ore on the ground
2. Open Miner Planner selection tool
3. Drag-select the ore patch
4. Observe the GUI

**Expected Results:**
- Drill selector: Only burner-mining-drill appears (electric drills require research)
- Belt selector: Only transport-belt appears (fast/express belts require research)
- Pole selector: Only small-electric-pole appears
- Pipe selector: Only "pipe" (iron pipe) appears
- Beacon selector: No beacons appear (beacons require research)

### Test 2: After Researching Electric Mining
**Preconditions:** Research "Automation" technology (unlocks electric-mining-drill)

**Steps:**
1. Use console: `/c game.player.force.technologies["automation"].researched = true`
2. Repeat Test 1 steps

**Expected Results:**
- Drill selector: Both burner-mining-drill AND electric-mining-drill appear
- Other selectors: Same as Test 1

### Test 3: After Researching Advanced Technologies
**Preconditions:** Research multiple technologies

**Steps:**
1. Use console: `/c game.player.force.technologies["logistics-2"].researched = true`
2. Use console: `/c game.player.force.technologies["electric-energy-distribution-1"].researched = true`
3. Repeat Test 1 steps

**Expected Results:**
- Belt selector: transport-belt, fast-transport-belt, and underground-belt appear
- Pole selector: small-electric-pole and medium-electric-pole appear
- Other selectors: Previous results still valid

### Test 4: No Recipe Entities
**Preconditions:** Default game state

**Steps:**
1. Open GUI and check pole selector

**Expected Results:**
- Entities without recipes (like basic poles) should always be available
- small-electric-pole should appear even without specific research

### Test 5: Fluid Resources with Pipe Filtering
**Preconditions:** Research uranium processing

**Steps:**
1. Place uranium ore on the ground
2. Use console: `/c game.player.force.technologies["uranium-processing"].researched = true`
3. Open Miner Planner and select uranium ore area
4. Observe pipe selector in GUI

**Expected Results:**
- Pipe selector appears (uranium requires sulfuric acid)
- Only "pipe" (iron pipe) appears initially
- If modded pipes exist, only researched pipes appear

## Testing Recipe Availability Check

### Test 6: Verify Recipe Check Logic
**Preconditions:** New game

**Steps:**
1. Use console to check recipe states:
   ```
   /c game.print(game.player.force.recipes["electric-mining-drill"].enabled)
   /c game.print(game.player.force.recipes["fast-transport-belt"].enabled)
   ```
2. Research relevant technologies
3. Re-check recipe states

**Expected Results:**
- Before research: Recipe.enabled = false
- After research: Recipe.enabled = true
- GUI should reflect these states

## Regression Tests

### Test 7: Previously Selected Unavailable Entity
**Preconditions:** Saved game with remembered settings containing unreseached entities

**Steps:**
1. Load a save where settings remember "fast-transport-belt"
2. Start new game (no research)
3. Open GUI

**Expected Results:**
- fast-transport-belt should NOT appear in selector
- Fallback to first available belt (transport-belt)
- No crashes or empty selections

### Test 8: All Selectors Show At Least One Option
**Preconditions:** Various technology states

**Steps:**
1. Test GUI at different research stages
2. Verify each selector has at least one available option (or "none" button)

**Expected Results:**
- Drill selector: Always shows at least burner-mining-drill
- Belt selector: Always shows transport-belt + none option
- Pole selector: Always shows small-electric-pole + none option
- Pipe selector: Always shows pipe + none option
- Beacon selector: Shows none option even if no beacons researched

## Pass Criteria
- All tests pass without errors
- No empty selectors (always at least one option or none button)
- No crashes when interacting with filtered selectors
- Entity buttons only appear when their recipes are enabled
