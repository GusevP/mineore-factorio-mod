# Fix Drill Filtering for Liquid Ores and Underground Belt Direction

## Overview
Fix two issues: (1) Allow burner drills for normal ores but exclude them for liquid-requiring ores in the GUI, and (2) Correct underground belt output direction by rotating it 180 degrees from the flow direction so entrance and exit sprites connect properly.

## Context
- Files involved: scripts/resource_scanner.lua, scripts/gui.lua, scripts/belt_placer.lua
- Related patterns: Burner Drill Exclusion Pattern, Underground Belt Direction Pattern
- Dependencies: None

## Development Approach
- Testing approach: Regular (code first, then tests)
- Complete each task fully before moving to the next
- CRITICAL: every task MUST include new/updated tests
- CRITICAL: all tests must pass before starting next task

## Implementation Steps

### Task 1: Remove universal burner drill exclusion from resource scanner

**Files:**
- Modify: scripts/resource_scanner.lua

- [x] Remove burner-mining-drill exclusion at line 79 (change `if can_mine and name ~= "burner-mining-drill" then` to `if can_mine then`)
- [x] Remove or update comments (lines 77-78) to reflect that burner drill filtering is now GUI responsibility
- [x] Create test file docs/tests/burner-drill-ore-compatibility-tests.md documenting that resource scanner now includes burner drill in compatible drills list for all ores
- [x] Test in-game: verify burner drill appears in scan_results.compatible_drills for normal ore patches
- [x] run project test suite - must pass before task 2

### Task 2: Add burner drill filtering in GUI for liquid-requiring ores

**Files:**
- Modify: scripts/gui.lua

- [x] In _add_drill_selector function around line 387 (after fluid input filtering), add filter to exclude burner-mining-drill when needs_fluid is true
- [x] Implementation approach: iterate through drills_to_show and filter out entries where drill.name == "burner-mining-drill" when needs_fluid is true
- [x] Add comment explaining burner drills cannot mine liquid-requiring ores
- [x] Update docs/tests/burner-drill-ore-compatibility-tests.md with GUI filtering test cases
- [x] Test in-game: verify burner drill appears in selector for iron ore (normal ore)
- [x] Test in-game: verify burner drill does NOT appear in selector for uranium ore (requires sulfuric acid)
- [x] run project test suite - must pass before task 2

### Task 3: Fix underground belt output direction

**Files:**
- Modify: scripts/belt_placer.lua

- [x] In _place_underground_belts function, add helper function or logic to calculate opposite direction (180 degree rotation):
  - north <-> south
  - east <-> west
- [x] Change ubo_dir calculation at line 195 to use opposite direction from belt_dir_define
- [x] Keep ubi_dir as belt_dir_define (flow direction) at line 194
- [x] Update comments (lines 185-195) to explain: UBI faces flow direction, UBO faces opposite direction (180 degrees rotated) for proper sprite connection
- [x] Update docs/tests/underground-belt-direction-tests.md to document the UBO 180-degree rotation behavior
- [x] Test in-game for south flow: verify UBI faces south, UBO faces north, sprites connect properly
- [x] Test in-game for north flow: verify UBI faces north, UBO faces south, sprites connect properly
- [x] Test in-game for east flow: verify UBI faces east, UBO faces west, sprites connect properly
- [x] Test in-game for west flow: verify UBI faces west, UBO faces east, sprites connect properly
- [x] run project test suite - must pass before task 4

### Task 4: Verify acceptance criteria

- [x] manual test: place mining setup on iron ore - verify burner drill appears in drill selector
- [x] manual test: place mining setup on uranium ore - verify burner drill does NOT appear in drill selector
- [x] manual test: verify drill selector shows only compatible drills for each ore type
- [x] manual test: place mining setup with south flow - verify underground belt pair connects properly with correct entrance/exit sprites
- [x] manual test: place mining setup with north flow - verify underground belt pair connects properly
- [x] manual test: place mining setup with east flow - verify underground belt pair connects properly
- [x] manual test: place mining setup with west flow - verify underground belt pair connects properly
- [x] manual test: verify items flow in correct direction through underground belt pairs
- [x] run full test suite (if available)
- [x] verify all test documentation is complete and accurate

### Task 5: Update documentation

- [x] update CLAUDE.md: modify Burner Drill Exclusion Pattern to document GUI-level filtering for liquid ores only (resource scanner includes burner drill in compatible list)
- [x] update CLAUDE.md: update Underground Belt Direction Pattern to document UBO 180-degree rotation (UBI faces flow direction, UBO faces opposite direction)
- [x] move this plan to docs/plans/completed/
