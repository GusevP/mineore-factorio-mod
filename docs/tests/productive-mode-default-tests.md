# Productive Mode Default Tests

## Test Objective
Verify that the default placement mode is "productivity" for new games and new players.

## Prerequisites
- Clean Factorio installation or ability to test with new save files
- Miner Planner mod installed

## Test Cases

### Test 1: New Game Default Mode
**Objective:** Verify productivity mode is selected by default in a new game

**Steps:**
1. Start a new Factorio game with Miner Planner mod enabled
2. Complete tutorial if needed, get to free play
3. Open Miner Planner GUI (click button or use shortcut)
4. Observe the selected placement mode in the GUI

**Expected Result:**
- "Productivity" mode should be selected by default
- The productivity radio button should be active/checked

**Actual Result:**
- [ ] Pass
- [ ] Fail - Notes:

---

### Test 2: Fresh Player Settings
**Objective:** Verify each new player in multiplayer gets productivity default

**Steps:**
1. Start or join a multiplayer game
2. Have a new player (who hasn't used the mod before) join
3. New player opens Miner Planner GUI for the first time
4. Check which placement mode is selected

**Expected Result:**
- "Productivity" mode should be selected by default for the new player
- Each player's default should be independent

**Actual Result:**
- [ ] Pass
- [ ] Fail - Notes:

---

### Test 3: Settings Persistence
**Objective:** Verify that changing mode doesn't affect the default for new saves

**Steps:**
1. Start a new game
2. Verify productivity mode is default
3. Change to "efficient" mode
4. Save and exit
5. Start a completely new game (different save)
6. Open Miner Planner GUI

**Expected Result:**
- New game should still default to productivity mode
- The previous game's mode change shouldn't affect the default

**Actual Result:**
- [ ] Pass
- [ ] Fail - Notes:

---

### Test 4: Mod Settings Override
**Objective:** Verify that changing the mod setting changes the default

**Steps:**
1. Go to Settings > Mod settings > Per player > Miner Planner
2. Find "mineore-default-mode" setting
3. Verify it's set to "productivity"
4. Change it to "efficient"
5. Start a new game
6. Open Miner Planner GUI

**Expected Result:**
- With setting changed to "efficient", new games should default to efficient mode
- Changing setting back to "productivity" should restore productivity default

**Actual Result:**
- [ ] Pass
- [ ] Fail - Notes:

---

## Implementation Verification

### Code Verification
- [x] settings.lua line 8 has `default_value = "productivity"`
- [x] scripts/gui.lua line 41 reads `player.mod_settings["mineore-default-mode"].value`
- [x] Default only applies when `settings.placement_mode` is not already set
- [x] Legacy modes ("normal", "loose") correctly migrate to "efficient"

### Test Execution Summary
- Test 1 (New Game Default): [ ] Pass / [ ] Fail
- Test 2 (Fresh Player Settings): [ ] Pass / [ ] Fail
- Test 3 (Settings Persistence): [ ] Pass / [ ] Fail
- Test 4 (Mod Settings Override): [ ] Pass / [ ] Fail

---

## Notes
- The default mode is a per-user runtime setting, not a global mod setting
- Each player can have their own default via mod settings
- The setting only applies when no previous mode selection exists (first time opening GUI)
- After initial selection, the player's choice persists in their saved game data
