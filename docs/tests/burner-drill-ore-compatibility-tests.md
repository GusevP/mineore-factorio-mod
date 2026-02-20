# Burner Drill Ore Compatibility Tests

## Purpose
Verify that the resource scanner includes burner mining drill in the compatible drills list for all ore types, and that GUI filtering correctly excludes burner drills only for liquid-requiring ores.

## Test Setup
- New game with default Factorio (no mods except this one)
- Player has researched basic mining technology
- Test on both normal ores (iron, copper) and liquid-requiring ores (uranium with sulfuric acid)

## Test Cases

### Test 1: Resource Scanner Includes Burner Drill for Normal Ores
**Given:** Iron ore patch is selected
**When:** resource_scanner.scan() is called
**Then:** scan_results.compatible_drills includes burner-mining-drill

**Status:** [ ] Passed  [ ] Failed

**Notes:**


### Test 2: Resource Scanner Includes Burner Drill for Liquid-Requiring Ores
**Given:** Uranium ore patch is selected (requires sulfuric acid)
**When:** resource_scanner.scan() is called
**Then:** scan_results.compatible_drills includes burner-mining-drill

**Status:** [ ] Passed  [ ] Failed

**Notes:**


### Test 3: GUI Drill Selector Shows Burner Drill for Normal Ores
**Given:** GUI is opened with iron ore selected
**When:** Drill selector dropdown is populated
**Then:** burner-mining-drill appears in the drill selector list

**Status:** [ ] Passed  [ ] Failed

**Notes:**


### Test 4: GUI Drill Selector Excludes Burner Drill for Liquid-Requiring Ores
**Given:** GUI is opened with uranium ore selected (requires sulfuric acid)
**When:** Drill selector dropdown is populated
**Then:** burner-mining-drill does NOT appear in the drill selector list

**Status:** [ ] Passed  [ ] Failed

**Notes:**


## Implementation Details

### Resource Scanner Changes
- File: scripts/resource_scanner.lua
- Line 77-79: Removed burner-mining-drill exclusion from find_compatible_drills()
- Changed: `if can_mine and name ~= "burner-mining-drill" then` to `if can_mine then`
- Comment updated to indicate GUI now handles burner drill filtering

### GUI Filtering (to be implemented in Task 2)
- File: scripts/gui.lua
- Location: _add_drill_selector function
- Logic: Filter out burner-mining-drill when needs_fluid is true
- Reason: Burner drills cannot mine liquid-requiring ores

## Test Results Summary

Date: ___________
Tester: ___________

Test 1 (Scanner - Normal Ore): [ ] Pass [ ] Fail
Test 2 (Scanner - Liquid Ore): [ ] Pass [ ] Fail
Test 3 (GUI - Normal Ore): [ ] Pass [ ] Fail (to be tested in Task 2)
Test 4 (GUI - Liquid Ore): [ ] Pass [ ] Fail (to be tested in Task 2)

Overall: [ ] All tests passed [ ] Some tests failed
