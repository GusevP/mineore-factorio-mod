# Fix Poles, Underground Belts, Default Mode, Selection Tool, and Burner Drill

## Overview

This plan addresses six issues: restricting pole selector to only three specific pole types, fixing pole placement pattern to use fixed spacing with underground belt pattern, correcting underground belt direction logic, removing selection tool from player inventory, ensuring productive mode is default, and filtering out burner-mining-drill from available drills.

## Context

- Files involved:
  - scripts/gui.lua - Pole selector filtering, default mode setting
  - scripts/pole_placer.lua - Pole placement spacing calculation
  - scripts/belt_placer.lua - Underground belt direction logic
  - prototypes/selection-tool.lua - Selection tool definition
  - settings.lua - Default mode setting
  - scripts/resource_scanner.lua - Drill filtering logic
  - control.lua - Selection tool handling
- Related patterns:
  - Technology-based entity filtering (is_entity_available function)
  - Default entity selection pattern
  - Pole placement uses calculate_spacing based on supply area and wire distance
  - Underground belt placement uses input/output types and direction defines

## Development Approach

- Testing approach: Regular (code first, then manual tests)
- Complete each task fully before moving to the next
- CRITICAL: every task MUST include new/updated tests
- CRITICAL: all tests must pass before starting next task

## Implementation Steps

### Task 1: Restrict pole selector to three specific pole types

**Files:**

- Modify: `scripts/gui.lua`

- [x] Update gui.\_get_electric_pole_types() function to return only three specific poles: "small-electric-pole" (wood), "kr-small-iron-electric-pole" (Krastorio 2 iron pole, may not exist), and "medium-electric-pole"
- [x] Remove collision box size filtering (1x1 check) since we now have explicit whitelist
- [x] Keep technology-based filtering in gui.\_add_pole_selector() for these three poles
- [x] Update CLAUDE.md to document the new pole whitelist pattern
- [x] Create manual test documentation in docs/tests/pole-whitelist-tests.md
- [x] Run manual tests - verify only three poles appear in GUI
- [x] Run project test suite (manual validation) - must pass before task 2

### Task 2: Fix pole placement to use fixed spacing pattern

**Files:**

- Modify: `scripts/pole_placer.lua`

- [x] Remove pole_placer.calculate_spacing() function that uses supply_area_distance and max_wire_distance
- [x] Create new fixed spacing pattern: after each underground belt pair (UBO + UBI), place one pole
- [x] For NS orientation: pattern repeats every (drill height) tiles along belt line
- [x] For EW orientation: pattern repeats every (drill width) tiles along belt line
- [x] Update pole placement to place pole at position: drill_center + 1 tile in belt flow direction (after UBI)
- [x] Handle 2x2 drills case (plain belts) - place poles at regular drill spacing intervals
- [x] Update function documentation to reflect new fixed pattern
- [x] Create manual test documentation in docs/tests/pole-spacing-tests.md
- [x] Run manual tests - verify poles follow UBO-UBI-Pole pattern
- [x] Run project test suite (manual validation) - must pass before task 3

### Task 3: Fix underground belt direction handling

**Files:**

- Modify: `scripts/belt_placer.lua`

- [x] Review direction_to_define() function - ensure correct mapping of user direction choice
- [x] Review \_place_underground_belts() logic for UBO/UBI placement
- [x] Fix direction assignment: UBI direction should match belt_direction, UBO direction should be opposite
- [x] For south flow: UBO faces north (items exit south), UBI faces south (items enter north side)
- [x] For north flow: UBO faces south (items exit north), UBI faces north (items enter south side)
- [x] For east flow: UBO faces west (items exit east), UBI faces east (items enter west side)
- [x] For west flow: UBO faces east (items exit west), UBI faces west (items enter east side)
- [x] Verify belt_to_ground_type parameter ("input" vs "output") matches Factorio conventions
- [x] Add inline code comments explaining UBO/UBI direction logic for each cardinal direction
- [x] Create manual test documentation in docs/tests/underground-belt-direction-tests.md
- [x] Run manual tests - verify belts move items in correct direction for all four cardinal directions
- [x] Run project test suite (manual validation) - must pass before task 4

### Task 4: Remove selection tool from player inventory

**Files:**

- Modify: `prototypes/selection-tool.lua`
- Modify: `control.lua`

- [ ] In prototypes/selection-tool.lua, verify flags property has "only-in-cursor" flag to prevent inventory placement
- [ ] If flag doesn't exist, add flags = {"only-in-cursor"} to selection tool definition
- [ ] In control.lua, verify give_selection_tool() uses cursor_stack.set_stack() (already correct)
- [ ] Verify selection tool has hidden = true (already set)
- [ ] Test that tool doesn't appear in inventory after use
- [ ] Create manual test documentation in docs/tests/selection-tool-inventory-tests.md
- [ ] Run manual tests - verify tool never enters inventory, only appears in cursor
- [ ] Run project test suite (manual validation) - must pass before task 5

### Task 5: Ensure productive mode is default

**Files:**

- Modify: `settings.lua`

- [ ] Verify settings.lua line 8 has default_value = "productivity" (already correct per CLAUDE.md)
- [ ] If not set, change default_value to "productivity"
- [ ] Verify gui.lua line 41 correctly reads this default: player.mod_settings["mineore-default-mode"].value
- [ ] Create manual test documentation in docs/tests/productive-mode-default-tests.md
- [ ] Run manual tests - new game should default to productivity mode in GUI
- [ ] Run project test suite (manual validation) - must pass before task 6

### Task 6: Filter out burner-mining-drill from available drills

**Files:**

- Modify: `scripts/resource_scanner.lua`

- [ ] In find_compatible_drills() function, add filter to exclude "burner-mining-drill" by name
- [ ] Add check after can_mine check: if name == "burner-mining-drill" then skip (continue)
- [ ] Add code comment explaining burner drill cannot mine liquid-requiring ores
- [ ] Verify filtering happens before drill info is added to compatible array
- [ ] Update CLAUDE.md to document burner drill exclusion pattern
- [ ] Create manual test documentation in docs/tests/burner-drill-filtering-tests.md
- [ ] Run manual tests - verify burner drill never appears in GUI drill selector
- [ ] Run project test suite (manual validation) - must pass before task 7

### Task 7: Verify acceptance criteria

- [ ] Manual test: select ore patch, verify only three pole types in GUI
- [ ] Manual test: place drills/belts/poles, verify pole spacing follows UBO-UBI-Pole pattern
- [ ] Manual test: select each belt direction (N/S/E/W), verify underground belts move items correctly
- [ ] Manual test: use selection tool, verify it never appears in inventory
- [ ] Manual test: start new game, verify productivity mode is default
- [ ] Manual test: select ore patch, verify burner drill not in drill selector
- [ ] Run full manual test suite (all tests in docs/tests/)
- [ ] Verify all test documentation is complete and accurate

### Task 8: Update documentation

- [ ] Update README.md if pole behavior changed significantly
- [ ] Update CLAUDE.md with new patterns: pole whitelist, fixed pole spacing, burner drill exclusion
- [ ] Update version in info.json and update changelog.txt
- [ ] Move this plan to docs/plans/completed/
