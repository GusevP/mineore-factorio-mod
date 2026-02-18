# Miner Planner v0.3: Belts, Poles, Beacons

## Overview

Major upgrade to the Miner Planner mod adding:

1. Refactor the transport belt placement between paired miner rows logic. Look at the Layout Concept
2. Polish the Electric pole / substation placement logic in the gaps between miner rows. Now we support only 1x1 poles, not substances.
3. Adjust Beacon placement logic. Look at the Layout Concept
4. Fix Drill placement to respect ore selecting. Each drill has a zone of mining. So if the user select exact ore to mine, we shouldn't place drill if its zone is on the other ore because this drill will mine other ore. So we can just don't place this drill.
5. The mod should demolish all things like stone, trees, building in the planned placement zone.
6. Add support 4 directions - N, S, W, E, In GUI it's better to use existing arrows icons instead of words.

## Development Approach

- Code first, then manual testing in Factorio
- Wait to approve by manual testing to move to the next step/iteration.
- No automated test framework (Factorio mods run inside the game engine)
- Each task should be loaded into Factorio and manually verified before proceeding
- Complete each task fully before moving to the next

## Layout Concept

Symbols for patterns:

```
B - Belt
UB - Underground Belt
UBI - Underground Belt Entrance
UBO - Underground Belt Exit
```

The miner productive layout follows this patterns (viewed from above, drills output toward center belt), the direction is South (to the bottom):

1. Starter,cheap variant - only for 2x2 drills (Burner mining drill), without beacons. Actually beacons haven't been available there yet.

```
[1L.Drill =>] [Belt] [<= 1R.Drill]
[1L.Drill =>] [Belt] [<= 1R.Drill]
[2L.Drill =>] [Belt] [<= 2R.Drill]
[2L.Drill =>] [Belt] [<= 2R.Drill]
       [Pole] [Belt] [Pole]
[3L.Drill =>] [Belt] [<= 3R.Drill]
[3L.Drill =>] [Belt] [<= 3R.Drill]
[4L.Drill =>] [Belt] [<= 4R.Drill]
[4L.Drill =>] [Belt] [<= 4R.Drill]
```

2. Most-used variant for electric 3x3 drills, without beacon.

```
[1L.Drill =>] [UBO]  [<= 1R.Drill]
[1L.Drill =>] [UBI]  [<= 1R.Drill]
[1L.Drill =>] [Pole] [<= 1R.Drill]
[2L.Drill =>] [UBO]  [<= 2R.Drill]
[2L.Drill =>] [UBI]  [<= 2R.Drill]
[2L.Drill =>] [Pole] [<= 2R.Drill]
[3L.Drill =>] [UBO]  [<= 3R.Drill]
[3L.Drill =>] [UBI]  [<= 3R.Drill]
[3L.Drill =>] [Pole] [<= 3R.Drill]
```

3. Most-used variant for electric 3x3 drills, with beacons.

```
[1L.Beacon][1L.Drill =>] [UBO]  [<= 1R.Drill][1R.Beacon]
[1L.Beacon][1L.Drill =>] [UBI]  [<= 1R.Drill][1R.Beacon]
[1L.Beacon][1L.Drill =>] [Pole] [<= 1R.Drill][1R.Beacon]
[2L.Beacon][2L.Drill =>] [UBO]  [<= 2R.Drill][2R.Beacon]
[2L.Beacon][2L.Drill =>] [UBI]  [<= 2R.Drill][2R.Beacon]
[2L.Beacon][2L.Drill =>] [Pole] [<= 2R.Drill][2R.Beacon]
[3L.Beacon][3L.Drill =>] [UBO]  [<= 3R.Drill][3R.Beacon]
[3L.Beacon][3L.Drill =>] [UBI]  [<= 3R.Drill][3R.Beacon]
[3L.Beacon][3L.Drill =>] [Pole] [<= 3R.Drill][3R.Beacon]
```

4. For bigger drills we should use the previous pattern #2 Most-used variant. But the [UBI] should be near the drill output (usually the center) and the [UBO] is before the [UBI]. The beacons have the same logic, but the size of beacons could be different with size of drills, so just place as much beacons as we can to fill the length of drill columns. For example for 5x5 drills: The size of beacon is usually 3x3. So we can place 2-3 beacons for one 5x5 drill. Or 4-5 beacons for two 5x5 drills.

5. Effective mod should respect the zone of mining of each drill. It's just about the free space between drills, nothing more. It should respect described patterns.

6. Third normal mode should be renamed to 'Loose'. I imagine it as something between productive and effective modes. Like next drill should respect the zone of other drill, but not it's own. Fo example drill is 3x3 size and the full zone coverage is 5x5. So the productive mode will place drills next to each other. Effective mode place the next drill in 4 tiles from previous drill. 2 tiles for one drill and 2 tiles for second. `(5 - 3 = 2; 2 * 2 = 4)`. Loose mode just place the next drill in 2 tiles from previous. Like it respect the mining zone of one drill, not both.

For belt orientation = North-South (belt runs vertically):

- Left column drills face east, right column drills face west
- A belt line runs vertically between the two columns of drills
- Underground belts connect each drill's output to the center belt
- Underground belts has orientations
- Poles are placed in the space freed by underground belts

The calculator produces paired rows/columns of drills with a center gap for infrastructure.

## Implementation Steps
