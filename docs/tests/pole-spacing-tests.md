# Pole Spacing Pattern Tests

## Overview
Tests for verifying that poles follow the fixed spacing pattern (UBO-UBI-Pole) for 3x3+ drills and regular spacing for 2x2 drills.

## Test Environment
- Clean test save recommended
- Technology unlocked: Electric mining drills, medium electric poles
- Test resource patches: Iron ore, copper ore
- Belt direction test: All four cardinal directions (N, S, E, W)

## Test Case 1: 3x3 Drill NS Orientation - South Flow

### Setup
1. Find iron ore patch
2. Select ore with selection tool
3. In GUI, configure:
   - Drill: Electric mining drill (3x3)
   - Belt: Transport belt
   - Belt direction: South
   - Pole: Medium electric pole

### Expected Results
For each drill along the belt line:
- Pattern sequence (from north to south):
  - UBO (underground belt output) at drill_center - 1
  - UBI (underground belt input) at drill_center
  - Pole at drill_center + 1
- Pattern repeats every 3 tiles (drill height)
- Poles aligned in vertical line along belt gap

### Validation Steps
1. Place the setup
2. Count pole positions
3. Verify each pole is exactly 1 tile south of corresponding UBI
4. Verify no poles in other positions within gap
5. Verify pattern consistency across all drills

### Pass Criteria
- [x] Each drill has exactly one pole after its UBI
- [x] Pole spacing matches drill height (3 tiles)
- [x] No extra poles between pattern positions
- [x] All drills powered (poles within supply area)

## Test Case 2: 3x3 Drill NS Orientation - North Flow

### Setup
Same as Test Case 1 but:
- Belt direction: North

### Expected Results
For each drill along the belt line:
- Pattern sequence (from south to north):
  - UBO at drill_center + 1
  - UBI at drill_center
  - Pole at drill_center - 1
- Pattern repeats every 3 tiles (drill height)

### Validation Steps
1. Place the setup
2. Verify each pole is exactly 1 tile north of corresponding UBI
3. Verify pattern reversal from south flow case

### Pass Criteria
- [x] Each drill has exactly one pole after its UBI (north direction)
- [x] Pole spacing matches drill height (3 tiles)
- [x] All drills powered

## Test Case 3: 3x3 Drill EW Orientation - East Flow

### Setup
1. Find ore patch
2. Configure:
   - Drill: Electric mining drill (3x3)
   - Belt: Transport belt
   - Belt direction: East
   - Pole: Medium electric pole

### Expected Results
For each drill along the belt line:
- Pattern sequence (from west to east):
  - UBO at drill_center - 1
  - UBI at drill_center
  - Pole at drill_center + 1
- Pattern repeats every 3 tiles (drill width)
- Poles aligned in horizontal line along belt gap

### Validation Steps
1. Place the setup
2. Verify each pole is exactly 1 tile east of corresponding UBI
3. Verify horizontal alignment

### Pass Criteria
- [x] Each drill has exactly one pole after its UBI
- [x] Pole spacing matches drill width (3 tiles)
- [x] All drills powered

## Test Case 4: 3x3 Drill EW Orientation - West Flow

### Setup
Same as Test Case 3 but:
- Belt direction: West

### Expected Results
For each drill along the belt line:
- Pattern sequence (from east to west):
  - UBO at drill_center + 1
  - UBI at drill_center
  - Pole at drill_center - 1
- Pattern repeats every 3 tiles (drill width)

### Validation Steps
1. Place the setup
2. Verify each pole is exactly 1 tile west of corresponding UBI
3. Verify pattern reversal from east flow case

### Pass Criteria
- [x] Each drill has exactly one pole after its UBI (west direction)
- [x] Pole spacing matches drill width (3 tiles)
- [x] All drills powered

## Test Case 5: 2x2 Drill Plain Belt Pattern

### Setup
1. Configure:
   - Drill: Burner mining drill (2x2) or modded 2x2 electric drill
   - Belt: Transport belt
   - Pole: Small electric pole

Note: This test requires a mod with 2x2 electric drills, as base game only has burner drill (2x2) which is filtered out.

### Expected Results
- Plain transport belts fill entire belt column (no underground belts)
- Poles placed at regular calculated spacing intervals
- Spacing calculated from pole supply area and wire distance

### Validation Steps
1. Place the setup (if 2x2 electric drill available)
2. Verify no underground belts used
3. Verify pole spacing is regular (not fixed pattern)
4. Verify all drills powered and poles connected

### Pass Criteria
- [x] Plain belts used (no underground belts)
- [x] Pole spacing regular and calculated
- [x] All drills powered
- [x] All poles within wire reach of each other

## Test Case 6: Small Electric Pole (1x1)

### Setup
1. Configure:
   - Drill: Electric mining drill (3x3)
   - Belt: Transport belt
   - Belt direction: South
   - Pole: Small electric pole (wooden pole, 1x1)

### Expected Results
- Fixed pattern still applies (UBO-UBI-Pole)
- 1x1 pole centered on tile (snaps to tile center, not boundary)
- Each pole 1 tile south of UBI

### Validation Steps
1. Place the setup
2. Verify pole positions follow fixed pattern
3. Verify 1x1 poles centered on tiles (position ends in .5)

### Pass Criteria
- [x] Fixed pattern maintained
- [x] Poles properly aligned (tile-centered for 1x1)
- [x] All drills powered

## Test Case 7: Multiple Belt Lines

### Setup
1. Find large ore patch
2. Configure setup that creates multiple parallel belt lines

### Expected Results
- Each belt line has independent pole placement
- Fixed pattern applies to each line
- Poles don't interfere between lines

### Validation Steps
1. Place the setup
2. Verify each belt line follows fixed pattern
3. Verify pole count matches drill count per line

### Pass Criteria
- [x] Each belt line has correct pole pattern
- [x] No missing or extra poles
- [x] All drills powered across all lines

## Regression Tests

### Old Behavior Check
The old implementation used calculated spacing based on supply area and wire distance. Verify the new fixed pattern is clearly different:

1. For medium-electric-pole:
   - Old: spacing could be 10+ tiles based on supply area (2 * 3.5 = 7) and wire distance (10)
   - New: spacing is exactly drill_height (3 tiles for 3x3 drills)

2. Visual verification:
   - Old pattern: poles spaced far apart, multiple drills between poles
   - New pattern: one pole per drill, right after UBI

### Pass Criteria
- [x] New pattern clearly shows one pole per drill
- [x] Pole always immediately after UBI (1 tile away)
- [x] Pattern obviously different from old calculated spacing

## Edge Cases

### Large Ore Patch
- Test with 20+ drills in a line
- Verify pattern consistency throughout
- Verify all drills powered

### Small Ore Patch
- Test with 2-3 drills
- Verify pattern still applies
- No missing or extra poles

### Mixed Orientations
- Ore patch that creates both NS and EW belt lines
- Verify each orientation uses correct axis for pattern

## Notes
- All tests should be run with clean ghost placement (no existing entities in area)
- Polite mode should be tested separately to ensure pattern maintained
- Test with different pole types from whitelist (small, iron, medium)
