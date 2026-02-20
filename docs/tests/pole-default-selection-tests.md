# Pole Default Selection Tests

## Purpose
Verify that the pole selector defaults to medium-electric-pole when available, and falls back appropriately when not researched.

## Prerequisites
- Factorio 2.0 installed
- Miner Planner mod enabled
- New game or save with ability to modify research state

## Test Cases

### Test 1: Default to medium-electric-pole when available
**Setup:**
- Start game with medium-electric-pole researched (Electric energy distribution 1)
- Ensure no previous pole selection stored in mod settings
- Have at least one ore patch available

**Steps:**
1. Click Miner Planner shortcut
2. Select an ore patch
3. Check pole selector in GUI

**Expected Result:**
- Medium-electric-pole is selected by default (button appears pressed)
- Other available poles are shown but not selected

### Test 2: Fallback to small-electric-pole when medium not researched
**Setup:**
- Start new game with only basic research (small-electric-pole available)
- Medium-electric-pole NOT researched
- No previous pole selection stored

**Steps:**
1. Click Miner Planner shortcut
2. Select an ore patch
3. Check pole selector in GUI

**Expected Result:**
- Small-electric-pole is selected by default
- Medium-electric-pole not shown in selector (filtered out)

### Test 3: Remember previous selection takes priority
**Setup:**
- Have both small and medium electric poles researched
- Previously selected small-electric-pole in a prior selection

**Steps:**
1. Click Miner Planner shortcut
2. Select an ore patch
3. Check pole selector in GUI

**Expected Result:**
- Small-electric-pole is selected (remembering previous choice)
- Not medium-electric-pole, even though it would be the default

### Test 4: Reset to default when remembered pole unavailable
**Setup:**
- Previously selected medium-electric-pole
- Start new game or use console to disable Electric energy distribution 1 research
- Medium-electric-pole no longer available

**Steps:**
1. Click Miner Planner shortcut
2. Select an ore patch
3. Check pole selector in GUI

**Expected Result:**
- Selection defaults to small-electric-pole (first available)
- Medium-electric-pole not shown in selector
- Previous selection is cleared because entity unavailable

### Test 5: No poles available
**Setup:**
- Use console to disable all electric pole research
- No poles available to player

**Steps:**
1. Click Miner Planner shortcut
2. Select an ore patch
3. Check pole selector in GUI

**Expected Result:**
- Only "None" button is shown in pole selector
- No entity buttons appear
- "None" button is selected by default

### Test 6: Technology progression scenario
**Setup:**
- Start new game (only small-electric-pole available)
- Select an ore patch and note small pole is default
- Research Electric energy distribution 1 (unlocks medium-electric-pole)
- Clear any remembered settings

**Steps:**
1. After research completes, click Miner Planner shortcut
2. Select a new ore patch
3. Check pole selector in GUI

**Expected Result:**
- Medium-electric-pole is now selected by default
- Small-electric-pole still shown but not selected
- Default changes based on newly available technology

### Test 7: Modded poles scenario
**Setup:**
- Install mod that adds custom electric poles to the pole list
- Ensure medium-electric-pole is still available

**Steps:**
1. Click Miner Planner shortcut
2. Select an ore patch
3. Check pole selector in GUI

**Expected Result:**
- Medium-electric-pole is still selected by default
- Modded poles appear if available but don't affect default selection
- Vanilla medium pole has priority over modded poles

### Test 8: Quality integration (Space Age)
**Setup:**
- Space Age DLC enabled
- Medium-electric-pole researched
- Quality research enabled

**Steps:**
1. Click Miner Planner shortcut
2. Select an ore patch
3. Check pole selector and quality dropdown

**Expected Result:**
- Medium-electric-pole selected by default
- Quality dropdown available for poles
- Default quality setting applies to medium pole

## Pass Criteria
All 8 test cases must pass for pole default selection to be considered working correctly.

## Notes
- These tests verify the interaction between technology filtering and default selection
- Default selection only applies when no previous setting exists
- Remembered settings take priority over defaults
