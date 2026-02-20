# Default Entity Selection, Cursor Stack Cleanup, and Entity Availability Filtering

## Overview

Update default entity selections in the configuration GUI to use electric drill, medium electric pole, and iron pipe as defaults, set productivity mode as the default placement mode, fix the cursor stack issue where the selection tool remains in hand after use, and filter out unavailable entities from GUI selectors based on player's technology research.

## Context

- Files involved: scripts/gui.lua, control.lua, settings.lua
- Related patterns: GUI element selectors use locked choose-elem-buttons with tags to store selections; defaults are applied when no previous settings exist
- Dependencies: None

## Development Approach

- **Testing approach**: Regular (code first, then tests)
- Complete each task fully before moving to the next
- **CRITICAL: every task MUST include new/updated tests**
- **CRITICAL: all tests must pass before starting next task**

## Implementation Steps

### Task 1: Filter unavailable entities from GUI selectors

**Files:**
- Modify: `scripts/gui.lua`

- [x] Update gui.create function to pass player object to all selector functions (_add_drill_selector, _add_pole_selector, _add_pipe_selector, _add_belt_selector, _add_beacon_selector)
- [x] Update _add_drill_selector function signature to accept player parameter
- [x] Add entity availability check in _add_drill_selector: only show drills whose recipe is enabled for player.force
- [x] Update _add_pole_selector function signature to accept player parameter
- [x] Add entity availability check in _add_pole_selector: only show poles whose recipe is enabled for player.force
- [x] Update _add_pipe_selector function signature to accept player parameter
- [x] Add entity availability check in _add_pipe_selector: only show pipes whose recipe is enabled for player.force
- [x] Update _add_belt_selector function signature to accept player parameter
- [x] Add entity availability check in _add_belt_selector: only show belts whose recipe is enabled for player.force
- [x] Update _add_beacon_selector function signature to accept player parameter
- [x] Add entity availability check in _add_beacon_selector: only show beacons whose recipe is enabled for player.force
- [x] Write tests for entity filtering based on force technology
- [x] Run project test suite - must pass before task 2

### Task 2: Change default placement mode to productivity

**Files:**
- Modify: `settings.lua`
- Modify: `scripts/gui.lua` (update fallback if needed)

- [x] Change default_value for "mineore-default-mode" setting from "efficient" to "productivity" in settings.lua:8
- [x] Verify gui.lua:28 fallback mode uses setting value correctly
- [x] Write tests for default mode selection in test suite
- [x] Run project test suite - must pass before task 3

### Task 3: Set default drill to electric-mining-drill

**Files:**
- Modify: `scripts/gui.lua`

- [x] Update gui._add_drill_selector function to prefer "electric-mining-drill" when available instead of first drill in filtered list
- [x] Ensure fallback to first available drill when electric-mining-drill is not in the filtered/researched drills list
- [x] Write tests for drill default selection logic with technology filtering
- [x] Run project test suite - must pass before task 4

### Task 4: Set default pole to medium-electric-pole

**Files:**
- Modify: `scripts/gui.lua`

- [ ] Update gui._add_pole_selector function to set selected_pole to "medium-electric-pole" when no previous setting exists and entity is available/researched
- [ ] Ensure fallback to first available pole when medium-electric-pole is not researched
- [ ] Write tests for pole default selection logic with technology filtering
- [ ] Run project test suite - must pass before task 5

### Task 5: Set default pipe to pipe (iron pipe)

**Files:**
- Modify: `scripts/gui.lua`

- [ ] Update gui._add_pipe_selector function to set selected_pipe to "pipe" when no previous setting exists and entity is available/researched
- [ ] Ensure fallback behavior when basic pipe is not available
- [ ] Write tests for pipe default selection logic with technology filtering
- [ ] Run project test suite - must pass before task 6

### Task 6: Clear cursor stack after selection tool use

**Files:**
- Modify: `control.lua`

- [ ] After successful placement in on_player_selected_area event handler (around line 187), clear player cursor to prevent selection tool from staying in hand
- [ ] After ghost removal in on_player_alt_selected_area event handler (around line 224-234), clear player cursor
- [ ] Write tests for cursor clearing behavior
- [ ] Run project test suite - must pass before task 7

### Task 7: Verify acceptance criteria

- [ ] Manual test: Start a new game with no research - verify only basic entities show in selectors (no empty icons)
- [ ] Manual test: Research electric mining technology - verify electric drill appears and is selected by default
- [ ] Manual test: Research medium electric pole technology - verify it appears and is selected by default
- [ ] Manual test: When mining uranium ore, verify iron pipe is selected by default
- [ ] Manual test: Verify productivity mode is selected by default
- [ ] Manual test: After using selection tool, verify cursor is empty
- [ ] Run full test suite with project test command
- [ ] Run linter if project has one
- [ ] Verify test coverage meets 80%+

### Task 8: Update documentation

- [ ] Update README.md if user-facing behavior changed (note new defaults and technology-based filtering in Usage section)
- [ ] Move this plan to docs/plans/completed/
