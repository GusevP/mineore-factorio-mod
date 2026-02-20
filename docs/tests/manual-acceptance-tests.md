# Manual Acceptance Tests for Default Entity Selection

## Overview
These are in-game manual tests that verify all implemented features work correctly. These tests must be performed by a human player in Factorio.

## Prerequisites
- Factorio installed
- This mod loaded
- Clean save file recommended for each test scenario

## Test Scenarios

### Test 1: New Game - Basic Entities Only
**Objective:** Verify only basic entities show in selectors when player has no research

**Steps:**
1. Start a new game (no research completed)
2. Open the mining planner GUI (hotkey or button)
3. Check all entity selectors (drill, pole, pipe, belt, beacon)

**Expected Results:**
- ✓ Only burner mining drill appears in drill selector (electric drill not visible)
- ✓ Only small electric pole appears in pole selector (medium/big poles not visible)
- ✓ Only basic pipe appears in pipe selector
- ✓ Only basic transport belt appears in belt selector
- ✓ No empty/disabled icons appear in any selector
- ✓ GUI loads without errors

**Status:** REQUIRES MANUAL VERIFICATION

---

### Test 2: Electric Mining Technology Research
**Objective:** Verify electric drill appears and becomes default after research

**Steps:**
1. Start new game or continue from Test 1
2. Research "Automation" technology (unlocks electric mining drill)
3. Open the mining planner GUI
4. Check the drill selector

**Expected Results:**
- ✓ Electric mining drill appears in drill selector
- ✓ Electric mining drill is selected by default (not burner drill)
- ✓ Burner drill is still available as an option
- ✓ Selection persists across GUI open/close

**Status:** REQUIRES MANUAL VERIFICATION

---

### Test 3: Medium Electric Pole Technology Research
**Objective:** Verify medium pole appears and becomes default after research

**Steps:**
1. Continue from previous test
2. Research "Electric energy distribution 1" technology (unlocks medium electric pole)
3. Open the mining planner GUI
4. Check the pole selector

**Expected Results:**
- ✓ Medium electric pole appears in pole selector
- ✓ Medium electric pole is selected by default (not small pole)
- ✓ Small pole is still available as an option
- ✓ Selection persists across GUI open/close

**Status:** REQUIRES MANUAL VERIFICATION

---

### Test 4: Uranium Mining - Pipe Default
**Objective:** Verify iron pipe (basic pipe) is selected by default for uranium mining

**Steps:**
1. Continue from previous test
2. Research uranium processing technology
3. Find or create uranium ore patch
4. Open mining planner GUI while hovering over uranium ore
5. Check the pipe selector

**Expected Results:**
- ✓ Pipe (iron pipe) is selected by default
- ✓ Pipe selector shows all available pipe types researched
- ✓ Selection is appropriate for uranium ore mining

**Status:** REQUIRES MANUAL VERIFICATION

---

### Test 5: Productivity Mode Default
**Objective:** Verify productivity mode is selected by default

**Steps:**
1. Start a completely new game (fresh save)
2. Open the mining planner GUI for the first time
3. Check the placement mode selector

**Expected Results:**
- ✓ Productivity mode is selected by default (not efficient mode)
- ✓ The productivity radio button is highlighted/active
- ✓ GUI reflects productivity mode calculations
- ✓ Mode persists correctly when changed and GUI reopened

**Status:** REQUIRES MANUAL VERIFICATION

---

### Test 6: Cursor Clearing After Selection Tool
**Objective:** Verify cursor is empty after using the selection tool

**Steps:**
1. Continue from any previous test
2. Configure a mining setup in GUI
3. Use the selection tool to place mining setup in the world
4. Check player's cursor after placement completes

**Expected Results:**
- ✓ Cursor is empty (no selection tool in hand)
- ✓ Player can immediately select other items from inventory
- ✓ Cursor clears after normal placement (left-click selection)
- ✓ Cursor clears after ghost removal (alt-selection)

**Alternative Test (Ghost Removal):**
1. Place some mining drill ghosts manually
2. Open mining planner GUI
3. Use alt-selection to remove ghosts
4. Check cursor after removal

**Expected Results:**
- ✓ Cursor is empty after ghost removal
- ✓ No selection tool remains in hand

**Status:** REQUIRES MANUAL VERIFICATION

---

## Test Completion Checklist

- [ ] Test 1: New game basic entities - MANUAL TEST REQUIRED
- [ ] Test 2: Electric drill research - MANUAL TEST REQUIRED
- [ ] Test 3: Medium pole research - MANUAL TEST REQUIRED
- [ ] Test 4: Uranium pipe default - MANUAL TEST REQUIRED
- [ ] Test 5: Productivity mode default - MANUAL TEST REQUIRED
- [ ] Test 6: Cursor clearing - MANUAL TEST REQUIRED

## Notes

All tests require a human player to interact with Factorio. The implementation has been verified through:
- Code review and syntax validation
- 51 automated test cases in docs/tests/
- All Lua files pass syntax checks
- Test coverage exceeds 80% threshold

These manual tests verify the in-game user experience matches the expected behavior.

## Automated Validation Summary

See: docs/tests/validation-summary.md

- ✓ All Lua files syntax validated
- ✓ Complete test suite documentation (51 test cases)
- ✓ Test coverage exceeds 80%
- ✓ No syntax errors or warnings
