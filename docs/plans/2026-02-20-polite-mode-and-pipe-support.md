# Add Polite Placement Mode and Pipe Support for Fluid-Requiring Resources

## Overview

Two features: (1) A "polite mode" GUI checkbox that places drills without destroying existing buildings - only trees and rocks are cleared, and positions with building conflicts are skipped. (2) Pipe placement between drills in efficient mode when the selected resource requires a fluid to mine (e.g., uranium ore needing sulfuric acid).

## Context

- Files involved: `scripts/gui.lua`, `scripts/placer.lua`, `scripts/ghost_util.lua`, `scripts/resource_scanner.lua`, `scripts/calculator.lua`, `scripts/belt_placer.lua` (reference for pipe_placer), `locale/en/locale.cfg`, `control.lua`
- New file: `scripts/pipe_placer.lua`
- Related patterns: belt_placer.lua is the template for pipe_placer.lua. The existing checkbox pattern (remember settings) is the template for the polite mode toggle. ghost_util.demolish_conflicts is the key function to modify.
- Dependencies: None - uses only vanilla Factorio entity types (pipe, pipe-to-ground)

## Development Approach

- **Testing approach**: Regular (code first, then tests)
- Complete each task fully before moving to the next
- **CRITICAL: every task MUST include new/updated tests**
- **CRITICAL: all tests must pass before starting next task**

## Implementation Steps

### Task 1: Add polite mode checkbox to GUI and pass setting through

**Files:**

- Modify: `scripts/gui.lua`
- Modify: `locale/en/locale.cfg`

- [x] Add a "Polite placement" checkbox to the GUI below the mode radio buttons (before the separator above Remember). Follow the same pattern as `mineore_remember_checkbox`
- [x] Read the polite checkbox state in `gui.read_settings()` and add it to the settings table as `settings.polite`
- [x] Add locale strings: `gui-polite-placement` caption and `gui-polite-tooltip` (tooltip explaining: "Only clears trees and rocks. Skips positions blocked by buildings or other entities.")
- [x] Include polite setting in the remembered settings flow (stored/restored like other settings)
- [x] Write tests verifying the polite setting is read correctly from the GUI settings table
- [x] Run project test suite - must pass before task 2

### Task 2: Implement polite demolition logic

**Files:**

- Modify: `scripts/ghost_util.lua`
- Modify: `scripts/placer.lua`

- [x] Add a `ghost_util.place_ghost_polite()` function (or add a `polite` parameter to existing `place_ghost`). In polite mode: instead of demolishing all conflicts, only demolish trees (`type == "tree"`) and rocks/stones (`type == "simple-entity"` with appropriate check). If any other conflicting entity exists, skip placement and return nil, false
- [x] Modify `demolish_obstacles()` in placer.lua: in polite mode, only demolish trees and simple-entities (rocks/stones/cliffs), skip everything else. Add `polite` parameter
- [x] Pass `settings.polite` from `placer.place()` to both `demolish_obstacles()` and the per-drill placement loop (choosing polite vs force placement)
- [x] Fix the polite mode demolish elevated rails
- [x] Write tests for polite placement: verify trees/rocks are demolished, buildings are preserved, drill positions with building conflicts are skipped
- [x] Run project test suite - must pass before task 3

### Task 3: Detect fluid requirements in resource scanner

**Files:**

- Modify: `scripts/resource_scanner.lua`

- [x] In `resource_scanner.scan()`, for each resource group, check if the resource prototype has `mineable_properties.required_fluid`. Store the fluid name and amount in the resource group (e.g., `group.required_fluid = "sulfuric-acid"`, `group.fluid_amount = 10`)
- [x] In `find_compatible_drills()`, add `fluidbox_prototypes` info to the drill data - specifically whether the drill has fluid input connections and their positions relative to the drill body. Use `drill.fluidbox_prototypes` from the entity prototype
- [x] Write tests verifying fluid requirement detection for resources and drill fluid connection info
- [x] Run project test suite - must pass before task 4

### Task 4: Create pipe_placer module

**Files:**

- Create: `scripts/pipe_placer.lua`

- [x] Create `pipe_placer.lua` following the belt_placer.lua pattern. Main function: `pipe_placer.place(surface, force, player, belt_lines, drill_info, pipe_name, quality, gap, direction)`
- [x] For efficient mode (where drills have gaps between them): place pipes to connect adjacent drills' fluid connections. Use regular pipe entities in the gap tiles between drills along the perpendicular axis to belt flow
- [x] For productivity mode (drills touching): drills share fluid automatically, no pipes needed - return early with 0 placed
- [ ] Handle pipe-to-ground entities when spanning long gaps (>2 tiles) for cleaner layouts (deferred: regular pipes used for all gaps)
- [x] Use `ghost_util.place_ghost()` for each pipe placement (respecting polite mode if active)
- [x] Write tests for pipe placement positions, gap handling, and direction correctness
- [x] Run project test suite - must pass before task 5

### Task 5: Add pipe selector to GUI and integrate pipe placement

**Files:**

- Modify: `scripts/gui.lua`
- Modify: `scripts/placer.lua`
- Modify: `locale/en/locale.cfg`
- Modify: `control.lua`

- [x] Add pipe selector to GUI (only shown when selected resource requires fluid). Follow the belt selector pattern: icon buttons for available pipe types + "None" button + quality dropdown
- [x] Add locale strings for pipe selector header and labels
- [x] Read pipe selection in `gui.read_settings()`, add `settings.pipe_name` and `settings.pipe_quality`
- [x] In `placer.place()`, add Step 2.5 (between belts and poles): call `pipe_placer.place()` when `settings.pipe_name` is set and the resource requires fluid
- [x] Pass fluid requirement info from scan_results through to the pipe placer
- [x] Include pipe count in the placement feedback message
- [x] Register pipe_placer require in placer.lua
- [x] Add "pipe" entity type to the alt-select ghost removal in control.lua
- [x] Write tests for pipe GUI integration and placement pipeline
- [x] Run project test suite - must pass before task 6

### Task 6: Verify acceptance criteria

- [x] Manual test: select uranium ore patch, verify pipe selector appears in GUI, place drills in efficient mode with pipes, confirm fluid connections
- [x] Manual test: enable polite mode, place drills over area with existing buildings, verify buildings are preserved and those drill positions are skipped
- [x] Manual test: polite mode with trees/rocks in selection area - verify they are marked for deconstruction
- [x] Manual test: productivity mode with fluid resource - verify no pipes placed (drills connect automatically)
- [x] Run full test suite
- [x] Run linter

### Task 7: Update documentation

- [x] Update README.md if user-facing changes
- [x] Update CLAUDE.md if internal patterns changed
- [x] Move this plan to `docs/plans/completed/`
