# Smart Pole Spacing and Belt Optimization

## Overview

Replace the fixed one-pole-per-drill pattern with supply-area-aware spacing for all pole/substation types. Introduce a single unified function `pole_placer.calculate_positions()` that determines pole/substation placement indices for ALL modes (1x1 poles, substations productive_3x3, efficient, and productive_5x5). Then optimize belt placement by using regular transport belts instead of underground belts (UBO/UBI) at drill positions that don't have a pole/substation. When a pole/substation covers multiple drills, fill ALL intermediate positions with transport belts. Add quality support to all calculations via this unified function.

## Context

- Files involved: `scripts/pole_placer.lua`, `scripts/belt_placer.lua`, `scripts/placer.lua`
- Related patterns: Fixed Pole Spacing, Substation Placement Modes, Underground Belt Type Setting, First-In-Flow Direction
- Dependencies: Factorio 2.0 API `get_supply_area_distance(quality?)` and `get_max_wire_distance(quality?)`

## Key Design: Unified Position Calculator

Currently, three substation placement functions each compute their own `effective_reach` and interval inline (lines 536, 574, 660 in `pole_placer.lua`). This plan introduces ONE deterministic function:

```lua
pole_placer.calculate_positions(pole_info, drill_count, drill_spacing, belt_direction)
-- Returns: { [drill_index] = true } for indices that get a pole/substation
```

This function:
  1. Computes `effective_reach = math.min(pole_info.supply_area_distance * 2, pole_info.max_wire_distance)`
  2. Computes `interval = math.max(1, math.floor(effective_reach / drill_spacing))`
  3. Starting from first-in-flow drill, marks every `interval`-th position
  4. Returns a set of drill indices

All callers use this one function:
  - `pole_placer.place()` for 1x1 poles (NEW - currently places at every drill)
  - `place_substations_productive_3x3()` (REPLACES inline calculation at line 536)
  - `place_substations_efficient()` (REPLACES inline calculation at line 574)
  - `place_substations_productive_5x5()` (REPLACES inline calculation at line 660)
  - `placer.lua` passes the result to `belt_placer` for belt optimization

## Key Insight: Belt Optimization

Underground belts exist to pass under the pole/substation. When a pole's supply area covers multiple drills, we only need UBI/UBO at drills that actually have a pole. Between the UBO exit and the next UBI entrance (which can span many drills), ALL intermediate positions are filled with transport belts.

### Single-column layout (3x3+ drills with 1x1 poles, south flow, interval=3):

```
Drill 0 (HAS pole):
  y=0:  UBI (entrance to underground) -- first drill, no UBO
  y=1:  [POLE]
Drill 1 (no pole, underground section from drill 0):
  y=2:  UBO (exit from underground started at y=0)
  y=3:  belt (drill center, no pole)
  y=4:  belt (gap position, no pole)
Drill 2 (no pole):
  y=5:  belt (UBO position, but previous had no UBI so belt)
  y=6:  belt (drill center, no pole)
  y=7:  belt (gap position, no pole)
Drill 3 (HAS pole):
  y=8:  belt (UBO position, but previous had no UBI so belt)
  y=9:  UBI (entrance to next underground)
  y=10: [POLE]
Drill 4 ...
```

### Dual-column layout (5x5+ drills with substations, south flow, interval=3):

```
Drill 0 (substation after this gap):
  y=0:  Splitter (always placed)
  y=1:  UBI col1+col2 (substation in gap downstream)
  y=2,3: [gap - substation zone]
Drill 1 (no substation after this gap):
  y=4:  UBO col1+col2 (exit underground from y=1)
  y=5:  Splitter (always placed, acts as belt)
  y=6:  belt col1+col2 (no substation, surface run)
  y=7,8: belt col1+col2 (fill gap tiles)
Drill 2 (no substation after this gap):
  y=9:  belt col1+col2 (prev had no UBI, continue surface)
  y=10: Splitter (always placed)
  y=11: belt col1+col2 (no substation)
  y=12,13: belt col1+col2 (fill gap tiles)
Drill 3 (substation after this gap):
  y=14: belt col1+col2 (prev had no UBI, surface)
  y=15: Splitter (always placed)
  y=16: UBI col1+col2 (substation in gap downstream)
  y=17,18: [gap - substation zone]
```

Splitters always stay at drill centers -- they distribute resources evenly between 2 columns and work like belts for transport purposes.

For substation modes where substations are NOT in the belt gap (productive_3x3, efficient): all belt positions become transport belts since no poles occupy the gap.

## Scope Boundaries

- 2x2 drills already use plain transport belts -- no change needed
- The `_place_plain_belts()` function is unchanged

## Development Approach

- **Testing approach**: Manual testing in-game (no automated test framework)
- Complete each task fully before moving to the next
- Each task leaves the mod in a working state

## Implementation Steps

### Task 1: Quality-aware pole info and unified position calculator

**Files:**
- Modify: `scripts/pole_placer.lua`

- [x] Modify `get_pole_info(pole_name)` to accept optional `quality` parameter. Pass quality to `proto.get_supply_area_distance(quality)` and `proto.get_max_wire_distance(quality)` so returned values are quality-adjusted
- [x] Add new function `pole_placer.calculate_positions(pole_info, drill_count, drill_spacing, belt_direction)`:
  - Computes `effective_reach = math.min(pole_info.supply_area_distance * 2, pole_info.max_wire_distance)`
  - Computes `interval = math.max(1, math.floor(effective_reach / drill_spacing))`
  - Determines first-in-flow index (respects First-In-Flow Direction Pattern): for south/east flow starts from index 1, for north/west flow starts from last index and walks backward
  - Starting from first-in-flow drill, marks every `interval`-th position
  - Returns `positions_set` (table mapping drill index -> true) and `interval`
- [x] Manual test: call `get_pole_info("medium-electric-pole")` with and without quality, verify values differ for non-normal quality

### Task 2: Refactor substation functions to use unified calculator

**Files:**
- Modify: `scripts/pole_placer.lua`
- Modify: `scripts/placer.lua`

- [x] Update `place_substations_productive_3x3()`: replace inline `effective_reach`/`interval` calculation (line 536-537) with call to `calculate_positions()`. Pass quality to `get_pole_info()`
- [x] Update `place_substations_efficient()`: replace inline `effective_reach`/`interval` calculation (line 574-575) with call to `calculate_positions()`. Pass quality to `get_pole_info()`
- [x] Update `place_substations_productive_5x5()`: replace inline `effective_reach`/`spacing` calculation (line 660-661) with call to `calculate_positions()`. Pass quality to `get_pole_info()`
- [x] In `placer.place()`, pass quality when calling `pole_placer.get_pole_info()` for substation mode detection and placement
- [x] Manual test: verify all substation modes still place correctly after refactor (no behavior change yet)

### Task 3: Smart 1x1 pole placement using unified calculator

**Files:**
- Modify: `scripts/pole_placer.lua`
- Modify: `scripts/placer.lua`

- [x] In `placer.place()`, before belt placement, calculate pole positions:
  - Get pole_info with quality: `pole_placer.get_pole_info(settings.pole_name, pole_quality)`
  - Call `pole_placer.calculate_positions(pole_info, drill_count, drill_spacing, belt_direction)`
  - For substation modes NOT in belt gap (productive_3x3, efficient): use empty position set for belt optimization
  - For productive_5x5 substation mode: pre-calculate which inter-drill gaps get substations (from same `calculate_positions()`)
  - For no pole selected: use empty position set
  - Pass position set to both pole_placer and belt_placer
- [x] Modify `_place_ns_poles()` and `_place_ew_poles()` to accept `pole_positions` set parameter and only place poles at positions in the set (skip positions not in set)
- [x] Update `pole_placer.place()` to accept pre-calculated pole position sets and pass through to NS/EW placement functions
- [x] Manual test: 3x3 drills + medium electric pole -> verify poles placed at intervals, not at every drill

### Task 4: Adaptive belt placement for single-column layout (3x3+ drills with 1x1 poles)

**Files:**
- Modify: `scripts/belt_placer.lua`

- [ ] Modify `belt_placer.place()` to accept new optional parameter `pole_position_sets` (table mapping belt_line index -> pole position set). Pass through to `_place_underground_belts()`
- [ ] Modify `_place_underground_belts()` to accept `pole_positions` parameter (set of drill indices with poles in belt gap)
- [ ] Implement state-machine logic for NS orientation:
  - Track `last_had_ubi` (whether previous drill in flow order created UBI underground entrance)
  - For first drill in flow:
    - Has pole: place UBI. Set `last_had_ubi = true`
    - No pole: place transport belt at drill center + transport belt at gap position. Set `last_had_ubi = false`
  - For subsequent drills:
    - UBO/belt position (upstream of drill center):
      - If `last_had_ubi`: place UBO (underground exit). Set `last_had_ubi = false` (UBO consumes the underground section)
      - Else: place transport belt
    - Drill center:
      - Has pole: place UBI. Set `last_had_ubi = true`
      - No pole: place transport belt. `last_had_ubi` stays false
    - Gap position (downstream of drill center):
      - Has pole: skip (pole_placer handles this)
      - No pole: place transport belt
- [ ] Implement same logic for EW orientation (mirror NS with x/y swap)
- [ ] Handle edge case: if `pole_positions` is nil or empty, place all transport belts (no poles = no underground needed)
- [ ] Manual test: verify belt continuity -- surface belts fill all positions between UBO and UBI across multiple drills

### Task 5: Adaptive belt placement for dual-column layout (5x5+ drills with substations)

**Files:**
- Modify: `scripts/belt_placer.lua`

- [ ] Modify `_place_substation_5x5_belts()` to accept `substation_gap_set` parameter (set of gap indices between consecutive drills that have a substation)
- [ ] Implement state-machine logic for NS orientation:
  - Track `last_had_ubi` per the same pattern as Task 4
  - Splitter at drill center is ALWAYS placed (unaffected by optimization -- splitters act as belts distributing between columns)
  - For first drill in flow:
    - Gap has substation downstream: place UBI col1+col2. Set `last_had_ubi = true`
    - Gap has no substation: place transport belt col1+col2 at UBI position. Set `last_had_ubi = false`
  - For subsequent drills:
    - UBO position (upstream of splitter):
      - If `last_had_ubi`: place UBO col1+col2 (underground exit). Set `last_had_ubi = false`
      - Else: place transport belt col1+col2
    - UBI position (downstream of splitter):
      - Gap has substation downstream: place UBI col1+col2. Set `last_had_ubi = true`
      - No substation (or last drill): place transport belt col1+col2. `last_had_ubi` stays false
  - After each drill, fill inter-drill gap tiles:
    - If `last_had_ubi` is true: gap tiles are empty (items travel underground) -- no belts needed
    - If `last_had_ubi` is false: place transport belt col1+col2 at EVERY empty gap tile to carry resources on surface to the next splitter
- [ ] Implement same logic for EW orientation
- [ ] Manual test: 5x5 drills + substation with quality -> verify transport belts fill both columns and all gap tiles at positions without substations, splitters always at drill centers

### Task 6: Testing and documentation

- [ ] Manual test: 3x3 drills + medium-electric-pole (normal quality) -> poles at intervals, transport belts filling all positions between poles across multiple drills
- [ ] Manual test: 3x3 drills + small-electric-pole -> different interval (supply area smaller)
- [ ] Manual test: 3x3 drills + substation (productive 3x3) -> all transport belts in belt gap (no poles in gap)
- [ ] Manual test: 3x3 drills + substation (efficient) -> all transport belts in belt gap
- [ ] Manual test: 5x5 drills + substation (productive 5x5) -> transport belts in BOTH columns AND all gap tiles at positions without substations, splitters always at drill centers
- [ ] Manual test: 5x5 drills + substation + quality -> fewer substations, more transport belt pairs filling columns and gaps
- [ ] Manual test: 5x5 drills + medium pole -> verify correct spacing with belt fill
- [ ] Manual test: no pole selected -> all transport belts (no underground)
- [ ] Manual test: north/west flow directions -> verify first-in-flow correctness
- [ ] Manual test: quality pole (if Space Age DLC available) -> wider spacing
- [ ] Update CLAUDE.md: replace "Fixed Pole Spacing Pattern" with "Smart Pole Spacing Pattern" describing supply-area-aware placement with unified calculator
- [ ] Update CLAUDE.md: add "Belt Optimization Pattern" describing transport belt substitution for UBO/UBI in both single-column and dual-column layouts, including gap filling across multiple drills for large supply areas
- [ ] Move this plan to `docs/plans/completed/`
