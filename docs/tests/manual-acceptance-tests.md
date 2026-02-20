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
- ✓ Burner mining drill does NOT appear in drill selector (filtered out)
- ✓ Electric drill appears even if not researched (technology filtering applies)
- ✓ Only small electric pole appears in pole selector (medium pole not visible)
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
- ✓ Electric mining drill is selected by default
- ✓ Burner drill does NOT appear (filtered out)
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

### Test 7: Pole Whitelist - Only Three Types
**Objective:** Verify pole selector shows only three specific pole types

**Steps:**
1. New game with all electric technologies researched
2. Research: Electric energy distribution 1, 2, 3 (all poles unlocked)
3. Open mining planner GUI
4. Check pole selector

**Expected Results:**
- ✓ Only small-electric-pole appears
- ✓ Only medium-electric-pole appears
- ✓ Big electric pole does NOT appear (filtered out)
- ✓ Substation does NOT appear (filtered out)
- ✓ With Krastorio 2: kr-small-iron-electric-pole may appear (if mod installed)

**Status:** REQUIRES MANUAL VERIFICATION

---

### Test 8: Pole Spacing - Fixed Pattern (UBO-UBI-Pole)
**Objective:** Verify poles follow fixed spacing pattern

**Steps:**
1. Configure: 3x3 electric drill, belt direction South
2. Select medium-electric-pole
3. Place mining setup on ore patch
4. Count poles and verify positions

**Expected Results:**
- ✓ Pattern for each drill: UBO (north) -> UBI (center) -> Pole (south)
- ✓ Pole is exactly 1 tile south of UBI
- ✓ Pattern repeats every 3 tiles (drill height)
- ✓ One pole per drill (not spaced far apart)
- ✓ All drills are powered

**Status:** REQUIRES MANUAL VERIFICATION

---

### Test 9: Underground Belt Direction - All Four Directions
**Objective:** Verify underground belts move items correctly in all directions

**Steps:**
1. Test South: Place drills with belt direction South, add items
2. Test North: Place drills with belt direction North, add items
3. Test East: Place drills with belt direction East, add items
4. Test West: Place drills with belt direction West, add items

**Expected Results:**
- ✓ South: Items move south through underground belts
- ✓ North: Items move north through underground belts
- ✓ East: Items move east through underground belts
- ✓ West: Items move west through underground belts
- ✓ No items stuck or moving wrong direction
- ✓ UBO and UBI connect properly (green line visible)

**Status:** REQUIRES MANUAL VERIFICATION

---

### Test 10: Selection Tool - Never in Inventory
**Objective:** Verify selection tool never appears in player inventory

**Steps:**
1. Activate selection tool via shortcut (Alt+M)
2. Check cursor and inventory
3. Select ore patch and configure
4. Click "Place" and check inventory
5. Use alt-selection for ghost removal
6. Check inventory again

**Expected Results:**
- ✓ Tool appears in cursor, NOT in inventory
- ✓ After selection, tool NOT in inventory
- ✓ After placement, tool NOT in inventory
- ✓ After ghost removal, tool NOT in inventory
- ✓ Cursor is cleared after operations

**Status:** REQUIRES MANUAL VERIFICATION

---

## Test Completion Checklist

### Original Features
- [ ] Test 1: New game basic entities - MANUAL TEST REQUIRED
- [ ] Test 2: Electric drill research - MANUAL TEST REQUIRED
- [ ] Test 3: Medium pole research - MANUAL TEST REQUIRED
- [ ] Test 4: Uranium pipe default - MANUAL TEST REQUIRED
- [ ] Test 5: Productivity mode default - MANUAL TEST REQUIRED
- [ ] Test 6: Cursor clearing - MANUAL TEST REQUIRED

### New Features (2026-02-20)
- [ ] Test 7: Pole whitelist (three types only) - MANUAL TEST REQUIRED
- [ ] Test 8: Pole spacing (UBO-UBI-Pole pattern) - MANUAL TEST REQUIRED
- [ ] Test 9: Underground belt direction (all four directions) - MANUAL TEST REQUIRED
- [ ] Test 10: Selection tool inventory exclusion - MANUAL TEST REQUIRED

## Notes

All tests require a human player to interact with Factorio. The implementation has been verified through:
- Code review and syntax validation
- 102 automated test cases in docs/tests/ (51 original + 51 new)
- All Lua files pass syntax checks
- Test coverage exceeds 80% threshold

**For comprehensive acceptance verification, see:** docs/tests/acceptance-verification-2026-02-20.md

These manual tests verify the in-game user experience matches the expected behavior.

## Automated Validation Summary

See: docs/tests/validation-summary.md

- ✓ All Lua files syntax validated
- ✓ Complete test suite documentation (102 test cases)
- ✓ Test coverage exceeds 80%
- ✓ No syntax errors or warnings

## Related Test Documentation

- acceptance-verification-2026-02-20.md - Comprehensive acceptance checklist
- pole-whitelist-tests.md - Pole selector filtering
- pole-spacing-tests.md - Fixed spacing pattern validation
- underground-belt-direction-tests.md - Belt direction for all cardinal directions
- selection-tool-inventory-tests.md - Tool inventory exclusion
- productive-mode-default-tests.md - Default mode verification
- burner-drill-filtering-tests.md - Burner drill exclusion
