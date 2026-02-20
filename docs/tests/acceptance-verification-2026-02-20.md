# Acceptance Verification - Pole/Belt/Selection Tool Fixes

**Test Date:** _________________

**Factorio Version:** _________________

**Mod Version:** _________________

**Tester:** _________________

## Overview

This document consolidates all acceptance criteria for the six-part fix including:
1. Pole selector restricted to three specific pole types
2. Pole placement using fixed spacing pattern (UBO-UBI-Pole)
3. Underground belt direction logic fixed
4. Selection tool removed from inventory
5. Productivity mode as default
6. Burner drill filtered out

## Quick Acceptance Test Checklist

### Test 1: Pole Selector Shows Only Three Types
- [ ] Start new vanilla game with medium-electric-pole researched
- [ ] Select ore patch with selection tool
- [ ] Open GUI and check pole selector
- [ ] VERIFY: Only small-electric-pole and medium-electric-pole appear
- [ ] Research all electric technologies (big poles, substations)
- [ ] VERIFY: Still only small and medium poles appear (big poles excluded)
- [ ] RESULT: PASS / FAIL

**Notes:**
_______________________________________________________________________

---

### Test 2: Pole Spacing Follows UBO-UBI-Pole Pattern
- [ ] Configure: 3x3 drill, belt direction South, medium-electric-pole
- [ ] Place drills on ore patch
- [ ] VERIFY: Each drill has pattern: UBO (north) -> UBI (center) -> Pole (south)
- [ ] VERIFY: Pole is exactly 1 tile south of UBI
- [ ] VERIFY: Pattern repeats every 3 tiles (drill height)
- [ ] Count poles: should be one pole per drill
- [ ] RESULT: PASS / FAIL

**Notes:**
_______________________________________________________________________

---

### Test 3: Underground Belts Move Items Correctly (All Directions)

#### South Flow
- [ ] Configure: belt direction South
- [ ] Place drills and build ghosts
- [ ] Add items to drills
- [ ] VERIFY: Items move south through underground belts
- [ ] VERIFY: UBO faces south, UBI faces south
- [ ] VERIFY: No items stuck or moving wrong direction
- [ ] RESULT: PASS / FAIL

#### North Flow
- [ ] Configure: belt direction North
- [ ] Place drills and build ghosts
- [ ] Add items to drills
- [ ] VERIFY: Items move north through underground belts
- [ ] RESULT: PASS / FAIL

#### East Flow
- [ ] Configure: belt direction East
- [ ] VERIFY: Items move east through underground belts
- [ ] RESULT: PASS / FAIL

#### West Flow
- [ ] Configure: belt direction West
- [ ] VERIFY: Items move west through underground belts
- [ ] RESULT: PASS / FAIL

**Overall Belt Direction Result:** PASS / FAIL

**Notes:**
_______________________________________________________________________

---

### Test 4: Selection Tool Never Appears in Inventory
- [ ] Activate selection tool via shortcut (Alt+M)
- [ ] VERIFY: Tool appears in cursor, NOT in inventory
- [ ] Select ore patch with tool
- [ ] VERIFY: After selection, tool does NOT appear in inventory
- [ ] Configure settings and click "Place"
- [ ] VERIFY: After placement, cursor cleared, tool NOT in inventory
- [ ] Activate tool and do alt-selection (ghost removal)
- [ ] VERIFY: After removal, cursor cleared, tool NOT in inventory
- [ ] RESULT: PASS / FAIL

**Notes:**
_______________________________________________________________________

---

### Test 5: Productivity Mode is Default
- [ ] Start completely new game
- [ ] Open Miner Planner GUI for first time
- [ ] VERIFY: "Productivity" mode is selected by default
- [ ] Change to "Efficient" mode, save and exit
- [ ] Start another new game (different save)
- [ ] VERIFY: New game still defaults to "Productivity"
- [ ] RESULT: PASS / FAIL

**Notes:**
_______________________________________________________________________

---

### Test 6: Burner Drill Not in Drill Selector
- [ ] New game or existing save
- [ ] Select iron or copper ore patch
- [ ] Open GUI and check drill selector
- [ ] VERIFY: Electric-mining-drill appears
- [ ] VERIFY: Burner-mining-drill does NOT appear
- [ ] Even in early game (before automation research)
- [ ] RESULT: PASS / FAIL

**Notes:**
_______________________________________________________________________

---

## Full Manual Test Suite

Run all individual test files for comprehensive validation:

- [ ] pole-whitelist-tests.md - All test cases
- [ ] pole-spacing-tests.md - All test cases
- [ ] underground-belt-direction-tests.md - All test cases
- [ ] selection-tool-inventory-tests.md - All test cases
- [ ] productive-mode-default-tests.md - All test cases
- [ ] burner-drill-filtering-tests.md - All test cases

**Full Suite Result:** PASS / FAIL

---

## Edge Cases and Regression Tests

### Pole Whitelist with Krastorio 2
- [ ] Install Krastorio 2 mod
- [ ] Research iron pole (kr-small-iron-electric-pole)
- [ ] VERIFY: All three poles appear (small, iron, medium)
- [ ] VERIFY: Sorted by supply area distance
- [ ] RESULT: PASS / FAIL / SKIPPED

### Large Ore Patches (20+ Drills)
- [ ] Find or create large ore patch
- [ ] Place 20+ drills in single belt line
- [ ] VERIFY: Pattern consistency throughout (one pole per drill)
- [ ] VERIFY: All drills powered
- [ ] RESULT: PASS / FAIL

### Multiple Parallel Belt Lines
- [ ] Configure ore patch that creates 3+ parallel belt lines
- [ ] VERIFY: Each line has independent pole placement
- [ ] VERIFY: Fixed pattern applies to all lines
- [ ] VERIFY: No missing or extra poles
- [ ] RESULT: PASS / FAIL

### 2x2 Drills (Plain Belt Pattern)
Note: Requires mod with 2x2 electric drills (burner drill is filtered)
- [ ] Configure 2x2 electric drill (if available)
- [ ] VERIFY: Plain belts used (no underground belts)
- [ ] VERIFY: Pole spacing is calculated (not fixed pattern)
- [ ] RESULT: PASS / FAIL / SKIPPED

---

## Visual Verification

### Old vs New Pole Pattern
Old behavior (before fix):
- Poles spaced 10+ tiles apart based on supply area
- Multiple drills between poles

New behavior (after fix):
- One pole per drill
- Pole always 1 tile after UBI

- [ ] VERIFY: New pattern clearly different from old
- [ ] VERIFY: Pole density increased significantly
- [ ] RESULT: PASS / FAIL

---

## Overall Test Result

**Total Tests Executed:** ___ / 6 core + ___ edge cases

**Tests Passed:** ___

**Tests Failed:** ___

**Tests Skipped:** ___

**FINAL RESULT:** [ ] ALL TESTS PASSED [ ] SOME TESTS FAILED

---

## Failure Investigation

If any tests failed, document here:

**Failed Test:**

**Symptoms:**

**Expected Behavior:**

**Actual Behavior:**

**Code Location (if identified):**

**Fix Required:**

---

## Sign-Off

**Acceptance Criteria Met:** [ ] YES [ ] NO

**Ready for Release:** [ ] YES [ ] NO

**Tester Signature:** _________________

**Date:** _________________

---

## Appendix: Quick Reference

### Expected Implementation Locations

1. **Pole whitelist:** scripts/gui.lua - _get_electric_pole_types()
2. **Fixed pole spacing:** scripts/pole_placer.lua - place() function
3. **Belt direction:** scripts/belt_placer.lua - _place_underground_belts()
4. **Selection tool flags:** prototypes/selection-tool.lua - flags = {"only-in-cursor"}
5. **Default mode:** settings.lua - default_value = "productivity"
6. **Burner drill filter:** scripts/resource_scanner.lua - find_compatible_drills()

### Test File Locations

All test documentation in: /docs/tests/

- pole-whitelist-tests.md
- pole-spacing-tests.md
- underground-belt-direction-tests.md
- selection-tool-inventory-tests.md
- productive-mode-default-tests.md
- burner-drill-filtering-tests.md
- manual-acceptance-tests.md
- validation-summary.md

### CLAUDE.md Documentation

- Pole Whitelist Pattern
- Burner Drill Exclusion Pattern
- Technology-Based Entity Filtering
- Default Entity Selection Pattern
- Cursor Management
