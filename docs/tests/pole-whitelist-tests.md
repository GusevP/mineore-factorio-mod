# Pole Whitelist Tests

**Purpose:** Verify that the pole selector only shows the three whitelisted pole types.

**Related Files:**
- `scripts/gui.lua` - `_get_electric_pole_types()` function with whitelist

## Test Cases

### Test 1: Vanilla Game - Basic Poles Available

**Setup:**
1. Start new vanilla Factorio game
2. No technologies researched yet

**Steps:**
1. Select an ore patch with the selection tool
2. Open the configuration GUI
3. Observe the pole selector buttons

**Expected Result:**
- Only `small-electric-pole` (wooden pole) appears in pole selector
- No other pole types are shown

**Actual Result:**
- [ ] PASS
- [ ] FAIL - Reason: _______________

---

### Test 2: Vanilla Game - Medium Pole Researched

**Setup:**
1. Continue from Test 1 or start new game
2. Research "Electric energy distribution 1" technology (unlocks medium-electric-pole)

**Steps:**
1. Select an ore patch with the selection tool
2. Open the configuration GUI
3. Observe the pole selector buttons

**Expected Result:**
- Two poles appear: `small-electric-pole` and `medium-electric-pole`
- No other pole types are shown (big electric pole, substations are excluded even if researched)

**Actual Result:**
- [ ] PASS
- [ ] FAIL - Reason: _______________

---

### Test 3: With Krastorio 2 - Iron Pole Available

**Setup:**
1. Start new game with Krastorio 2 mod installed
2. Research Krastorio 2's iron pole technology (if required)

**Steps:**
1. Select an ore patch with the selection tool
2. Open the configuration GUI
3. Observe the pole selector buttons

**Expected Result:**
- Three poles appear (if iron pole is researched):
  - `small-electric-pole`
  - `kr-small-iron-electric-pole` (Krastorio 2 iron pole)
  - `medium-electric-pole` (if researched)
- Poles sorted by supply area distance (smallest to largest)

**Actual Result:**
- [ ] PASS
- [ ] FAIL - Reason: _______________
- [ ] SKIPPED - Krastorio 2 not installed

---

### Test 4: Exclusion of Large Poles

**Setup:**
1. Vanilla game with all technologies researched
2. Big electric pole and substations should be available

**Steps:**
1. Research all electric technologies including:
   - Electric energy distribution 2 (big electric pole)
   - Electric energy distribution 3 (substation)
2. Select an ore patch with the selection tool
3. Open the configuration GUI
4. Observe the pole selector buttons

**Expected Result:**
- Only two poles appear: `small-electric-pole` and `medium-electric-pole`
- Big electric pole is NOT shown
- Substation is NOT shown
- Other modded large poles are NOT shown

**Actual Result:**
- [ ] PASS
- [ ] FAIL - Reason: _______________

---

### Test 5: Default Selection

**Setup:**
1. New game with medium-electric-pole researched
2. No previous settings saved

**Steps:**
1. Select an ore patch with the selection tool
2. Open the configuration GUI
3. Observe which pole is selected by default

**Expected Result:**
- `medium-electric-pole` is selected by default (pressed button style)
- If medium pole not available, `small-electric-pole` is selected

**Actual Result:**
- [ ] PASS
- [ ] FAIL - Reason: _______________

---

## Test Summary

- Total Test Cases: 5
- Passed: ___
- Failed: ___
- Skipped: ___

**Notes:**
