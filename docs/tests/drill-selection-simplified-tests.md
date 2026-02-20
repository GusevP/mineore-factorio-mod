# Drill Selection Simplified Tests

## Overview
Tests for simplified drill selection logic that excludes only burner drills and includes all other mining drills regardless of resource category.

## Related Pattern
- Burner Drill Exclusion Pattern (CLAUDE.md)

## Test Cases

### Test 1: All Electric Drills Appear for Basic Resources
**Setup:**
- New game with all technologies researched
- Select iron ore patch

**Expected:**
- Drill selector shows electric-mining-drill
- Drill selector shows any modded electric drills (if installed)
- Burner-mining-drill does NOT appear

**Actual:** [To be filled during manual test]

**Status:** [ ] Pass [ ] Fail

---

### Test 2: All Electric Drills Appear for Fluid-Requiring Resources
**Setup:**
- Game with all technologies researched
- Select uranium ore patch (requires sulfuric acid)

**Expected:**
- Same drills appear as for iron ore
- Electric-mining-drill is available
- Any modded electric drills are available
- Burner-mining-drill does NOT appear

**Actual:** [To be filled during manual test]

**Status:** [ ] Pass [ ] Fail

---

### Test 3: Technology Filtering Still Applies
**Setup:**
- New game, early stage (only burner-mining-drill researched)
- Select iron ore patch

**Expected:**
- No drills appear (burner drill is excluded, electric drill not researched)
- OR: Only researched electric drills appear (if any)

**Actual:** [To be filled during manual test]

**Status:** [ ] Pass [ ] Fail

---

### Test 4: Modded Drills Included
**Setup:**
- Game with mods that add mining drills (e.g., Krastorio 2)
- All technologies researched
- Select any ore patch

**Expected:**
- All electric mining drills from all mods appear
- Burner-mining-drill excluded
- Drills sorted alphabetically by name

**Actual:** [To be filled during manual test]

**Status:** [ ] Pass [ ] Fail

---

### Test 5: Drill Selection Independent of Ore Type
**Setup:**
- All technologies researched
- Test with multiple ore types: iron, copper, coal, uranium, stone

**Expected:**
- Identical drill list appears for ALL ore types
- No variation based on resource category

**Actual:** [To be filled during manual test]

**Status:** [ ] Pass [ ] Fail

---

## Validation Steps

1. Load Factorio with the updated mod
2. Execute each test case above
3. Fill in actual results
4. Mark pass/fail status
5. If any test fails, document the failure details

## Notes
- This replaces the old category-based drill filtering
- Simplified logic means less code complexity
- Players can now choose any electric drill for any ore type
