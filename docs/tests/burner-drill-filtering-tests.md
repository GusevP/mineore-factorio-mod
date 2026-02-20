# Burner Drill Filtering Tests

## Purpose
Verify that burner-mining-drill is excluded from the drill selector in the GUI.

## Background
Burner mining drills cannot mine liquid-requiring ores (like uranium ore which requires sulfuric acid) and are generally not suitable for automated mining operations. They should not appear as an option in the mod's drill selector.

## Test Cases

### Test 1: Burner Drill Not in Selector (Basic Ores)
**Preconditions:**
- New or existing save
- No special mods installed (vanilla Factorio)
- Player has researched basic mining technology

**Steps:**
1. Open GUI (default: Shift+M)
2. Use selection tool to select an iron or copper ore patch
3. Examine the drill selector dropdown in the GUI

**Expected Results:**
- Electric mining drill appears in selector
- Burner mining drill does NOT appear in selector
- Even though burner drill can mine basic-solid category ores

**Actual Results:**
- [ ] PASS
- [ ] FAIL: _____________________

---

### Test 2: Burner Drill Not in Selector (Modded Drills)
**Preconditions:**
- Save with mod that adds additional mining drills (e.g., Krastorio 2, Bob's Mining)
- Player has researched relevant mining technologies

**Steps:**
1. Open GUI
2. Use selection tool to select a basic ore patch (iron/copper)
3. Examine drill selector dropdown
4. Count number of drill types shown

**Expected Results:**
- Electric mining drill appears
- Any modded electric drills appear (if researched)
- Burner mining drill does NOT appear
- Total drill count matches (electric drills only)

**Actual Results:**
- [ ] PASS
- [ ] FAIL: _____________________

---

### Test 3: Early Game Scenario
**Preconditions:**
- Fresh new game start
- Player has NOT researched automation (only burner phase available)
- Only burner-mining-drill and electric-mining-drill exist

**Steps:**
1. Open GUI immediately in new game
2. Use selection tool on iron ore patch
3. Check drill selector

**Expected Results:**
- Electric mining drill appears (even if not yet researched, due to technology filtering)
- Burner mining drill does NOT appear
- If electric drill is not yet researched and gets filtered by technology check, selector may show "no drills available" rather than showing burner drill

**Actual Results:**
- [ ] PASS
- [ ] FAIL: _____________________

---

### Test 4: No Burner Drill in Debug Messages
**Preconditions:**
- Any save with ore patches

**Steps:**
1. Open GUI
2. Select ore patch with selection tool
3. Check console output / debug messages for compatible drills list

**Expected Results:**
- Compatible drills list printed to console
- Burner mining drill name does NOT appear in list
- Only electric-type drills appear

**Actual Results:**
- [ ] PASS
- [ ] FAIL: _____________________

---

## Implementation Verification

**Code Location:** scripts/resource_scanner.lua, find_compatible_drills() function

**Expected Implementation:**
```lua
-- Around line 77, after can_mine check:
if can_mine and name ~= "burner-mining-drill" then
    -- ... drill info extraction ...
end
```

**Verification Checklist:**
- [ ] Exclusion check happens after can_mine check
- [ ] Uses exact string match "burner-mining-drill"
- [ ] Code comment explains why burner drill is excluded
- [ ] Filtering prevents drill from being added to compatible array

---

## Notes
- This filtering is independent of technology research status
- Burner drill is excluded by explicit name check, not by capabilities
- The exclusion happens in resource_scanner.lua, before GUI sees the drill list
- This is a design decision to keep the mod focused on automated electric mining operations
