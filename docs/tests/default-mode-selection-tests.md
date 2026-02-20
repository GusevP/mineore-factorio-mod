# Default Mode Selection Tests

## Overview
These tests verify that the default placement mode setting works correctly and that the GUI respects the mod settings default value.

## Test Setup
1. Start a new Factorio game
2. Enable the Miner Planner mod
3. Access mod settings to verify or modify default mode

## Test Cases

### Test 1: Fresh Install - Productivity Default
**Preconditions:** New game, mod freshly installed, no previous settings saved

**Steps:**
1. Place some iron ore on the ground
2. Open Miner Planner selection tool
3. Drag-select the ore patch
4. Observe the GUI placement mode selector

**Expected Results:**
- Placement mode should default to "Productivity"
- Productivity mode radio button should be pre-selected
- No need for user to manually select it

### Test 2: Verify Mod Setting Default Value
**Preconditions:** Mod installed

**Steps:**
1. Open Factorio main menu
2. Go to Settings > Mod Settings > Per Player
3. Find "Default placement mode" setting
4. Check the default value

**Expected Results:**
- Setting shows "Productivity" as default value
- Allowed values are "Productivity" and "Efficient"

### Test 3: Change Default Setting to Efficient
**Preconditions:** Fresh install

**Steps:**
1. Open Settings > Mod Settings > Per Player
2. Change "Default placement mode" to "Efficient"
3. Start a new game
4. Open Miner Planner and select an ore patch

**Expected Results:**
- GUI shows "Efficient" as pre-selected mode
- Productivity is still available as an option

### Test 4: Remembered Settings Override Default
**Preconditions:** Previous game session with "Remember settings" enabled

**Steps:**
1. In first session: Select ore patch, choose "Efficient" mode, check "Remember settings", place miners
2. In second session: Select ore patch again

**Expected Results:**
- GUI shows "Efficient" (the remembered setting)
- NOT "Productivity" (the default)
- Remembered settings take precedence over mod setting defaults

### Test 5: GUI Draft Override
**Preconditions:** User opened GUI but didn't place miners yet

**Steps:**
1. Open GUI, change mode to "Efficient"
2. Close GUI without placing
3. Open GUI again for same ore patch

**Expected Results:**
- GUI draft settings preserved
- Mode is still "Efficient" from draft
- Not reset to default "Productivity"

### Test 6: Multiple Players Different Settings
**Preconditions:** Multiplayer game with 2+ players

**Steps:**
1. Player 1: Change their mod setting default to "Efficient"
2. Player 2: Keep default as "Productivity"
3. Both players open Miner Planner on separate ore patches

**Expected Results:**
- Player 1's GUI defaults to "Efficient"
- Player 2's GUI defaults to "Productivity"
- Per-user settings respected

### Test 7: Fallback Logic Verification
**Preconditions:** Code review

**Steps:**
1. Review scripts/gui.lua around line 40-41
2. Verify that when settings.placement_mode is nil/unset, it reads from player.mod_settings["mineore-default-mode"].value

**Expected Results:**
- Code correctly reads mod setting as fallback
- No hardcoded default in Lua code
- Settings.lua controls the default value

## Pass Criteria
- All tests pass without errors
- Default placement mode is "Productivity" after fresh install
- Mod setting in settings.lua has default_value = "productivity"
- GUI fallback logic correctly reads from mod settings
- Remembered settings override defaults when present
