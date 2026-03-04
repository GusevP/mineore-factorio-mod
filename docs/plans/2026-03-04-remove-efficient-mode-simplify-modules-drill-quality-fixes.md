# Remove Efficient Mode, Simplify Modules, Add Drill Quality, Fix Substation/Belt Bugs

## Overview

Five changes: (1) remove efficient placement mode entirely, (2) remove module count selector and auto-fill all slots, (3) add drill quality dropdown to GUI, (4) fix substation always placed at start endpoint, (5) place UBI at last drill when it has a pole/substation.

## Context

- Files involved: `settings.lua`, `scripts/gui.lua`, `scripts/calculator.lua`, `scripts/placer.lua`, `scripts/pole_placer.lua`, `scripts/belt_placer.lua`, `control.lua`, `locale/*/locale.cfg`, `CLAUDE.md`
- Related patterns: Smart Pole Spacing, Belt Optimization, Substation Placement Modes, Underground Belt Type Setting

## Development Approach

- **Testing approach**: Regular (code first, then manual tests)
- Complete each task fully before moving to the next
- All tests are manual (no automated test suite)

## Implementation Steps

### Task 1: Remove efficient mode

**Files:**
- Modify: `settings.lua` - remove `"efficient"` from allowed_values, or remove the mode setting entirely since only one mode remains
- Modify: `scripts/gui.lua` - remove `PLACEMENT_MODES` constant, remove `_add_mode_selector()` function, remove mode reading from `read_settings()`, remove mode_flow from GUI build
- Modify: `scripts/calculator.lua` - remove `mode` parameter from `get_spacing()`, hardcode productivity spacing
- Modify: `scripts/placer.lua` - remove `determine_substation_mode()` efficient branch, remove `settings.placement_mode` usage (hardcode "productivity"), remove efficient substation mode call
- Modify: `scripts/pole_placer.lua` - remove `place_substations_efficient()` function entirely
- Modify: `control.lua` - remove/simplify legacy mode migration code
- Modify: `locale/*/locale.cfg` - remove mode-related locale strings (gui-mode-header, gui-mode-productivity, gui-mode-efficient, tooltips)

- [x] Remove `"efficient"` from `settings.lua` allowed_values (keep setting for migration compatibility or remove if safe)
- [x] Remove `PLACEMENT_MODES` array and `_add_mode_selector()` from `gui.lua`
- [x] Remove mode radio button reading from `read_settings()`
- [x] Remove mode_flow separator and `_add_mode_selector()` call from GUI build section
- [x] Simplify `calculator.get_spacing()` to remove mode parameter, return only productivity spacing
- [x] Update all callers of `calculator.get_spacing()` to not pass mode
- [x] Simplify `determine_substation_mode()` in `placer.lua` to remove efficient branch
- [x] Remove the call to `pole_placer.place_substations_efficient()` from `placer.lua`
- [x] Remove `place_substations_efficient()` function from `pole_placer.lua`
- [x] Simplify migration in `control.lua` - migrate all legacy modes to "productivity"
- [x] Remove mode-related locale strings from all `locale/*/locale.cfg` files
- [x] Manual test: verify GUI no longer shows mode selector, only productivity layout is used

### Task 2: Remove module count selector, auto-fill all slots

**Files:**
- Modify: `scripts/gui.lua` - remove count dropdown from `_add_module_selector()`, remove count reading from `read_settings()`
- Modify: `scripts/placer.lua` - always use `max_modules` instead of `settings.module_count`

- [ ] In `gui._add_module_selector()`: remove the "x" label and `mineore_module_count` dropdown, keep only the module type choose-elem-button and quality dropdown
- [ ] In `gui.read_settings()`: remove reading of `module_count` from `mod_flow.mineore_module_count`
- [ ] In `placer.lua`: change module insert_plan to always use `max_modules` (remove `settings.module_count` usage)
- [ ] Manual test: verify selecting a module fills all available drill slots

### Task 3: Add drill quality dropdown to GUI

**Files:**
- Modify: `scripts/gui.lua` - add quality dropdown to drill selector row, read it in `read_settings()`
- Modify: `scripts/placer.lua` - use `settings.drill_quality` for drill ghost placement

- [ ] Wrap drill selector in a row flow (like belt_selector_row pattern) to support inline quality dropdown
- [ ] Add quality dropdown via `_add_inline_quality_dropdown(row, "drill", ...)` after drill buttons (only when Space Age quality flag is true)
- [ ] In `read_settings()`: read drill quality from the new row element via `gui._read_quality_dropdown(drill_row, "drill")`; store as `settings.drill_quality`
- [ ] In `placer.lua`: use `settings.drill_quality or settings.quality or "normal"` for drill ghost placement (line 514) instead of just `settings.quality or "normal"`
- [ ] Manual test: verify drill quality dropdown appears, drill ghosts are placed with selected quality

### Task 4: Fix substation always placed at start endpoint

**Files:**
- Modify: `scripts/pole_placer.lua` - remove unconditional endpoint substation placement in `place_substations_productive_5x5()`

The bug is at lines 511-513 where `should_place_set[1] = true` and `should_place_set[#candidates] = true` unconditionally force substations at both endpoints. The `positions_set` from `calculate_positions()` already includes endpoints when needed (it always includes first and last drill indices). The endpoint candidates should only be placed if the corresponding drill index is in `positions_set`.

- [ ] Remove the two unconditional `should_place_set[1] = true` and `should_place_set[#candidates] = true` lines
- [ ] Ensure the mapping from `positions_set` drill indices to candidate indices correctly covers endpoints: for south/east flow, drill 1's upstream candidate (index 1) should be placed if drill 1 is in positions_set; for north/west flow, the last drill's upstream candidate should be placed if last drill is in positions_set
- [ ] Add endpoint candidate placement based on positions_set: if first drill in flow is in positions_set, place its upstream candidate; if last drill in flow is in positions_set, place its downstream candidate
- [ ] Manual test: verify substations are only placed where supply area requires them, not always at start

### Task 5: Place UBI at last drill when pole/substation is present

**Files:**
- Modify: `scripts/belt_placer.lua` - change last drill logic in both `_place_underground_belts()` and `_place_substation_5x5_belts()` for NS and EW orientations

Currently, the `not is_last` check prevents UBI at the last drill. The user wants: if the last drill has a pole/substation, place UBI there so the user can manually place UBO as the output exit.

- [ ] In `_place_underground_belts()` NS block: change `has_pole and not is_last` to `has_pole` for UBI placement at drill center (both first-drill and subsequent-drill branches)
- [ ] In `_place_underground_belts()` EW block: same change for EW orientation
- [ ] In `_place_substation_5x5_belts()` NS block: change `downstream_has_sub and not is_last` to `downstream_has_sub` for UBI placement
- [ ] In `_place_substation_5x5_belts()` EW block: same change for EW orientation
- [ ] Manual test: verify last drill with pole/substation gets UBI; last drill without pole still gets surface belt

### Task 6: Update documentation

- [ ] Update `CLAUDE.md`: remove Substation Placement Modes efficient references, update Belt Optimization Pattern to reflect last-drill UBI change, remove mode selector from GUI Layout Structure, note drill quality in Module Quality Pattern section
- [ ] Move this plan to `docs/plans/completed/`
