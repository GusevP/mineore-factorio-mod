# Underground Belt Direction Tests

## Purpose
Verify that underground belts (UBO/UBI pairs) are placed with correct directions so items move in the intended direction for all four cardinal directions.

## Test Prerequisites
- Clean Factorio save with the mod installed
- Access to ore patches large enough for 3x3+ drills (to trigger underground belt usage)
- Electric mining drills unlocked (3x3 size triggers underground belts)

## Test Cases

### Test 1: South-Flowing Belts (Items Move South/Down)

**Setup:**
1. Start new game or load test save
2. Find an ore patch
3. Open mod GUI, select ore patch
4. Choose belt direction: South
5. Select 3x3 drill (electric-mining-drill or larger)
6. Place drills with belts

**Expected Behavior:**
- UBO (underground belt output) placed one tile north of drill center
- UBO faces south (arrow points south)
- UBO type is "output"
- UBI (underground belt input) placed at drill center
- UBI faces south (arrow points south)
- UBI type is "input"
- Items on belts move south (downward on screen)

**Validation:**
- Place the ghost entities
- Build the underground belts
- Add items to drills
- Observe items moving south through underground belts
- Items should exit UBO moving south, enter UBI from north side, continue south

**Pass Criteria:**
- Items flow continuously south through the belt system
- No items stuck or moving wrong direction
- Underground belt pairs connect properly (green connection line visible)

---

### Test 2: North-Flowing Belts (Items Move North/Up)

**Setup:**
1. Find new ore patch
2. Open mod GUI, select ore patch
3. Choose belt direction: North
4. Select 3x3 drill
5. Place drills with belts

**Expected Behavior:**
- UBO placed one tile south of drill center
- UBO faces north (arrow points north)
- UBO type is "output"
- UBI placed at drill center
- UBI faces north (arrow points north)
- UBI type is "input"
- Items on belts move north (upward on screen)

**Validation:**
- Build underground belts
- Add items to drills
- Observe items moving north through underground belts
- Items should exit UBO moving north, enter UBI from south side, continue north

**Pass Criteria:**
- Items flow continuously north through the belt system
- No items stuck or moving wrong direction
- Underground belt pairs connect properly

---

### Test 3: East-Flowing Belts (Items Move East/Right)

**Setup:**
1. Find new ore patch
2. Open mod GUI, select ore patch
3. Choose belt direction: East
4. Select 3x3 drill
5. Place drills with belts

**Expected Behavior:**
- UBO placed one tile west of drill center
- UBO faces east (arrow points east)
- UBO type is "output"
- UBI placed at drill center
- UBI faces east (arrow points east)
- UBI type is "input"
- Items on belts move east (rightward on screen)

**Validation:**
- Build underground belts
- Add items to drills
- Observe items moving east through underground belts
- Items should exit UBO moving east, enter UBI from west side, continue east

**Pass Criteria:**
- Items flow continuously east through the belt system
- No items stuck or moving wrong direction
- Underground belt pairs connect properly

---

### Test 4: West-Flowing Belts (Items Move West/Left)

**Setup:**
1. Find new ore patch
2. Open mod GUI, select ore patch
3. Choose belt direction: West
4. Select 3x3 drill
5. Place drills with belts

**Expected Behavior:**
- UBO placed one tile east of drill center
- UBO faces west (arrow points west)
- UBO type is "output"
- UBI placed at drill center
- UBI faces west (arrow points west)
- UBI type is "input"
- Items on belts move west (leftward on screen)

**Validation:**
- Build underground belts
- Add items to drills
- Observe items moving west through underground belts
- Items should exit UBO moving west, enter UBI from east side, continue west

**Pass Criteria:**
- Items flow continuously west through the belt system
- No items stuck or moving wrong direction
- Underground belt pairs connect properly

---

## Test 5: Different Drill Sizes

**Setup:**
1. Test with 2x2 drills (should use plain belts, not underground)
2. Test with 3x3 drills (should use underground belts)
3. Test with larger drills if available (e.g., 5x5 from mods)

**Expected Behavior:**
- 2x2 drills use plain belts (no underground)
- 3x3+ drills use underground belts
- All belt directions work correctly regardless of drill size

**Pass Criteria:**
- Correct belt type used for each drill size
- Items flow correctly in all cases

---

## Test Results

**Test Date:** _________________

**Factorio Version:** _________________

**Mod Version:** _________________

**Tester:** _________________

| Test Case | Result | Notes |
|-----------|--------|-------|
| Test 1: South Flow | [ ] Pass [ ] Fail | |
| Test 2: North Flow | [ ] Pass [ ] Fail | |
| Test 3: East Flow | [ ] Pass [ ] Fail | |
| Test 4: West Flow | [ ] Pass [ ] Fail | |
| Test 5: Drill Sizes | [ ] Pass [ ] Fail | |

**Overall Result:** [ ] All tests passed [ ] Some tests failed

**Additional Notes:**
