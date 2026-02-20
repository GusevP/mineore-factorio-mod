# Miner Planner - AI Knowledge Base

## Architecture Patterns

### Technology-Based Entity Filtering

**Pattern:** GUI selectors filter entities based on player's force technology research status.

**Implementation:**
- Local helper function `is_entity_available(player, entity_name)` in `scripts/gui.lua`
- Checks if entity's recipe is enabled for player's force
- Returns `true` if no recipe exists (e.g., basic poles available from start)
- Applied to all entity selectors: drills, belts, poles, beacons, pipes

**Usage:**
```lua
local function is_entity_available(player, entity_name)
    local recipe = player.force.recipes[entity_name]
    if recipe then
        return recipe.enabled
    end
    -- If no recipe exists, entity is available
    return true
end
```

All GUI selector functions (`_add_drill_selector`, `_add_belt_selector`, `_add_pole_selector`, `_add_pipe_selector`, `_add_beacon_selector`) filter their entity lists using this function before display.

### Default Entity Selection Pattern

**Pattern:** Entity selectors prefer specific default entities when no saved settings exist, with fallback to first available entity.

**Defaults established:**
- **Drill:** `electric-mining-drill` (fallback to first available)
- **Pole:** `medium-electric-pole` (fallback to first available)
- **Pipe:** `pipe` (iron pipe, fallback to first available)
- **Belt:** No specific default (uses first available)
- **Beacon:** No specific default (uses "none")

**Implementation:** Each selector function:
1. Builds list of available entities (filtered by technology)
2. Validates remembered selection is still in the available list
3. Checks for preferred default entity
4. Falls back to first available entity if preferred not found

### Cursor Management

**Pattern:** Player cursor is cleared after selection tool operations to prevent tool remaining in hand.

**Locations:**
- After placement in `on_player_selected_area` event handler (`control.lua`)
- After ghost removal in `on_player_alt_selected_area` event handler (`control.lua`)
- After placement from GUI button click (`control.lua`)

**Implementation:**
```lua
if not player.clear_cursor() then
    player.print({"mineore.cursor-not-cleared-warning"})
end
```

Called immediately after `placer.place()` completes. Checks return value to handle failures (e.g., inventory full).

## Configuration Defaults

### Placement Mode Default
- Changed from "efficient" to "productivity" in `settings.lua`
- Defined in `mineore-default-mode` setting (line 8)

## Build/Package Commands

```bash
./package.sh  # Creates mod zip file for distribution
```

## Testing

Test files located in `docs/tests/`:
- `entity-filtering-tests.md` - Technology-based filtering validation
- `drill-default-selection-tests.md` - Electric drill default
- `pole-default-selection-tests.md` - Medium pole default
- `pipe-default-selection-tests.md` - Iron pipe default
- `default-mode-selection-tests.md` - Productivity mode default
- `cursor-clearing-tests.md` - Cursor management validation
- `manual-acceptance-tests.md` - Full integration tests
- `validation-summary.md` - Test results summary

Note: All tests are currently manual test documentation, not automated tests.

## Project Structure

- `/scripts/` - Core Lua modules
  - `gui.lua` - Configuration GUI with entity selectors
  - `placer.lua` - Ghost entity placement logic
  - `resource_scanner.lua` - Ore patch scanning
  - `calculator.lua` - Grid calculation for drill placement
  - `beacon_placer.lua` - Beacon placement algorithm
  - `belt_placer.lua` - Belt placement logic
  - `pole_placer.lua` - Electric pole placement
  - `pipe_placer.lua` - Pipe placement for fluid resources
- `/prototypes/` - Factorio data-stage definitions
- `/locale/` - Localization strings
- `/docs/plans/` - Development plans (active)
- `/docs/plans/completed/` - Completed plans archive
- `/docs/tests/` - Test documentation

## Common Patterns

### Remembered Settings Validation

When loading remembered settings, always validate that selected entities are still available (researched). Pattern:

```lua
if selected_entity then
    local found = false
    for _, entity_name in ipairs(available_entities) do
        if entity_name == selected_entity then
            found = true
            break
        end
    end
    if not found then
        selected_entity = nil  -- Reset to trigger default selection
    end
end
```

This prevents showing unavailable entities when loading saves from games with different technology progress.

## Debugging

- Check logs in Factorio's `factorio-current.log` for runtime errors
- Use `player.print()` for in-game debugging messages
- GUI state stored in `storage.player_data[player.index]`
