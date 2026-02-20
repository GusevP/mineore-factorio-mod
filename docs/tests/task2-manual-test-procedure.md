# Task 2 Manual Test Procedure: Productivity Mode Default Fix

## Test Date
2026-02-20

## Objective
Verify that the productivity mode default fix works correctly when a fresh player opens the GUI for the first time.

## Prerequisites
1. Factorio installed with the modified Miner Planner mod (v0.7.0 with Task 2 fix)
2. Clean save file OR ability to delete mod data for fresh test

## Test Steps

### Test 1: Fresh Player - Default Mode
1. Start a new Factorio game or load a save where you haven't used Miner Planner before
2. If testing on existing save, delete mod data to reset:
   - Delete the save file's mod-settings.dat OR
   - Use console command to clear player data: `/c storage.players = {}`
3. Select an ore patch with the Miner Planner selection tool
4. Observe the configuration GUI that opens
5. **Check the console for debug messages:**
   - Should see: `[DEBUG] Default mode from settings: productivity`
   - Should see: `[DEBUG] settings.placement_mode before: nil`
   - Should see: `[DEBUG] settings.placement_mode after: productivity`
6. **Check the Placement Mode selector in GUI:**
   - The "Productivity" radio button should be selected (filled circle)
   - The "Efficient" radio button should NOT be selected (empty circle)

**Expected Result:**
- Debug messages confirm default mode is loaded as "productivity"
- Productivity radio button is selected by default
- No errors in console

**Pass Criteria:**
- [ ] Debug message shows default mode = "productivity"
- [ ] Debug message shows placement_mode before = nil
- [ ] Debug message shows placement_mode after = "productivity"
- [ ] Productivity radio button is visually selected in GUI

### Test 2: GUI Rebuild Preservation
1. With GUI still open from Test 1, click on a different resource type if multiple ores were selected
2. This triggers a GUI rebuild
3. **Check that:**
   - Productivity mode remains selected
   - No additional debug messages appear (gui_draft already has the value)

**Expected Result:**
- Productivity mode remains selected after GUI rebuild
- No new debug messages (because settings.placement_mode is no longer nil)

**Pass Criteria:**
- [ ] Productivity radio button still selected after resource type change
- [ ] No new debug messages (gui_draft preserved the default)

### Test 3: Changed Mode Persistence
1. In the GUI, manually select "Efficient" mode
2. Place the mining layout (or cancel)
3. Select another ore patch to open GUI again
4. **Check that:**
   - Efficient mode is now selected (because gui_draft remembers the change)
   - No debug messages appear

**Expected Result:**
- Efficient mode is selected (user's choice persists)
- No debug messages

**Pass Criteria:**
- [ ] Efficient radio button selected on second GUI open
- [ ] No debug messages (settings.placement_mode is set from gui_draft)

### Test 4: Mod Settings Override
1. Exit to main menu
2. Go to Settings > Mod settings > Per player > Miner Planner
3. Change "Default placement mode" from "productivity" to "efficient"
4. Start a NEW game
5. Open Miner Planner GUI on an ore patch
6. **Check that:**
   - Debug messages show default mode = "efficient"
   - Efficient radio button is selected

**Expected Result:**
- Debug shows default_mode from settings = "efficient"
- Efficient mode is selected by default

**Pass Criteria:**
- [ ] Debug message shows default mode = "efficient"
- [ ] Efficient radio button is selected in GUI

## Debug Logging Cleanup
After all tests pass, the debug logging should be removed from scripts/gui.lua lines 50-52 to avoid console spam for end users.

## Test Results

### Test 1: Fresh Player Default
- [ ] Pass
- [ ] Fail - Notes: _______________

### Test 2: GUI Rebuild Preservation
- [ ] Pass
- [ ] Fail - Notes: _______________

### Test 3: Changed Mode Persistence
- [ ] Pass
- [ ] Fail - Notes: _______________

### Test 4: Mod Settings Override
- [ ] Pass
- [ ] Fail - Notes: _______________

## Overall Result
- [ ] All tests passed - Fix is working correctly
- [ ] Some tests failed - Additional fixes needed

## Notes
(Add any observations, issues, or additional findings here)
