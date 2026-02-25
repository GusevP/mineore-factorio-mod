# Miner Planner - AI Knowledge Base

## Architecture Patterns

### Pole Whitelist Pattern

**Pattern:** Pole selector uses explicit whitelist of three compatible pole types.

**Whitelisted poles:**
- `small-electric-pole` (wooden pole)
- `kr-small-iron-electric-pole` (Krastorio 2 iron pole, may not exist in all games)
- `medium-electric-pole`

**Implementation:**
- Function `gui._get_electric_pole_types()` returns only whitelisted poles that exist in current game
- Technology-based filtering still applies (pole must be researched to appear)
- Sorted by supply area distance

**Rationale:** These three pole types work well with the mod's fixed spacing pattern. Larger poles (big electric pole, substations) are excluded.

### Fixed Pole Spacing Pattern

**Pattern:** Poles are placed at fixed intervals aligned with underground belt pairs, not calculated from pole supply/wire distance.

**Implementation:**
- Function `pole_placer.place()` in `scripts/pole_placer.lua`
- For 3x3+ drills: pole placed after each UBO-UBI underground belt pair
- Pole position: drill center + 1 tile in belt flow direction (after UBI)
- For NS orientation: pattern repeats every (drill height) tiles along belt line
- For EW orientation: pattern repeats every (drill width) tiles along belt line
- For 2x2 drills (plain belts): poles placed at regular drill spacing intervals

**Rationale:** Fixed spacing ensures poles align with the underground belt pattern regardless of pole type. The three whitelisted pole types all provide sufficient coverage at this spacing. Removed the old `calculate_spacing()` function that used supply_area_distance and max_wire_distance.

### Underground Belt Type Setting Pattern

**Pattern:** Underground belt ghosts must have their input/output type specified during creation using the `type` parameter. Both UBI (input/entrance) and UBO (output/exit) face the same direction (belt flow direction) for proper auto-connection. The first drill in a sequence gets only UBI, while subsequent drills get both UBI and UBO.

**Implementation:**
- Function `belt_placer._place_underground_belts()` in `scripts/belt_placer.lua`
- Function `belt_placer._place_underground_ghost()` accepts `belt_type` parameter ("input" or "output")
- Function `ghost_util.place_ghost()` passes `type` parameter via `extra_params` to `surface.create_entity()`
- Both UBI and UBO are set to `belt_dir_define` (the chosen flow direction)
- For south flow: both UBI and UBO face south
- For north flow: both UBI and UBO face north
- For east flow: both UBI and UBO face east
- For west flow: both UBI and UBO face west
- Placement for each drill: UBI created with `type="input"`, UBO created with `type="output"`
- First drill gets only UBI (no UBO placement)

**Critical Implementation Detail:**
```lua
-- When creating underground belt ghosts, MUST pass type during creation:
local ghost = surface.create_entity{
    name = "entity-ghost",
    inner_name = "underground-belt",
    type = "output",  -- REQUIRED: "input" or "output"
    direction = belt_direction,
    position = position,
    force = force,
    player = player,
}
```

**Rationale:** The `belt_to_ground_type` property is read-only after entity creation. Unlike what the API documentation suggests, entity-ghost DOES support a `type` parameter that sets whether the underground belt is input or output. This parameter must be passed during `surface.create_entity()` and cannot be changed afterward. Both UBI and UBO must face the same direction for Factorio's auto-connection system to work. The first drill only needs UBI (entrance) because there's no previous underground section to exit from. Subsequent drills need both UBI (entrance to next section) and UBO (exit from previous section).

**Previous bugs:**
- Version 0.6.0 and earlier: both UBO and UBI faced the same direction, causing sprite misalignment
- Version 0.7.0: UBO rotated 180 degrees from flow direction, causing connection issues
- Version 0.8.0: both UBO and UBI face same direction, first drill skips UBO placement
- Version 0.9.0 attempt: tried to set `belt_to_ground_type` parameter during creation, but property is read-only
- Version 0.10.0 attempt: tried to use `ghost.rotate()` to flip UBO from "input" to "output" after creation, but this doesn't update the ghost sprite
- Fixed in current version: pass `type="output"` parameter during ghost creation for UBO entities

### Beacon Inter-Pair Spacing Pattern

**Pattern:** When beacons are selected, the inter-pair gap is sized to exactly match the beacon width, ensuring beacons are flush with drills on both sides. Without beacons, efficient mode spacing is used.

**Implementation:**
- In `calculator.lua`, the `inter_pair` spacing is computed as:
  ```lua
  local inter_pair = beacon_width > 0 and beacon_width or math.max(spacing_across - body_dim, 0)
  ```
- `placer.lua` passes `beacon_width` from `beacon_placer.get_beacon_info()` to the calculator
- The beacon_placer's `generate_candidates()` places shared beacon columns at the midpoint between adjacent pair edges, which with `inter_pair = beacon_width` means the beacon fills the gap exactly

**Rationale:** Previously, the inter-pair gap was `(spacing_across - body_dim) + beacon_width`, making the efficient mode extra spacing and beacon width additive. This left visible gaps between beacons and drills, and for large drills (5x5) could push beacons out of supply range. By using just `beacon_width` when beacons are selected, the beacon is always flush with drills on both sides and within supply range. The efficient mode mining-area-overlap constraint is relaxed between pairs when beacons are used, since players choosing beacons prioritize beacon coverage over mining efficiency.

### Beacon Fill Pass Pattern

**Pattern:** Beacon placement uses a two-phase algorithm: a greedy phase that respects `max_beacons_per_drill` preference, followed by an unconditional fill pass that places beacons in all remaining valid positions.

**Implementation:**
- In `beacon_placer.lua`, the greedy loop scores candidates by counting unsaturated drills (drills below the per-drill cap). A candidate is placed if at least one affected drill benefits.
- The fill pass places beacons in ALL remaining valid positions to ensure full column/row coverage, even if all nearby drills are already at the per-drill cap.

**Rationale:** The fill pass ensures complete visual fill of beacon columns/rows with no gaps. Without it, edge positions (top/bottom of columns) get skipped when nearby drills are already saturated from beacons placed in the middle of the column.

### Fluid Resource Exclusion Pattern

**Pattern:** Resources that produce only fluid products (e.g., crude oil) are excluded from the resource scanner since they are mined by pumpjacks, not mining drills.

**Implementation:**
- In `resource_scanner.scan()`, after reading `mineable_properties.products`, check if ALL products have `type == "fluid"`
- If so, skip the resource entirely — it never appears in `resource_groups`
- This prevents fluid resources from appearing in the ore selector GUI

**Rationale:** Pumpjacks are `mining-drill` type entities in Factorio's data model, so they appear as "compatible drills" when fluid resources are included. The mod is designed for solid ore mining with mining drills, not pumpjack placement. Filtering at the scanner level prevents fluid resources from reaching the GUI at all.

**Key detail:** Uranium ore is NOT filtered out despite requiring sulfuric acid fluid input — its products are solid items (`uranium-ore`), not fluids. Only resources whose products are exclusively fluids (like crude oil producing `crude-oil` fluid) are excluded.

### Burner Drill Exclusion Pattern

**Pattern:** Burner mining drill is excluded from the GUI drill selector only for liquid-requiring ores (e.g., uranium ore with sulfuric acid). For normal ores, burner drills are available.

**Implementation:**
- Function `resource_scanner.find_compatible_drills()` in `scripts/resource_scanner.lua` includes "burner-mining-drill" in the compatible drills list for all ore types
- Function `gui._add_drill_selector()` in `scripts/gui.lua` filters out "burner-mining-drill" when `needs_fluid` is true
- GUI filtering happens after technology-based filtering and fluid input compatibility checks
- Filtering logic: `if needs_fluid and drill.name == "burner-mining-drill" then` skip this drill

**Rationale:** Burner mining drills cannot mine liquid-requiring ores (e.g., uranium ore with sulfuric acid) because they lack fluid input capability. However, they are perfectly functional for normal ores (iron, copper, coal, stone) and players may want to use them in early game scenarios. The resource scanner includes burner drills in the compatible drills list, but the GUI excludes them from the selector when the selected ore requires fluids. This provides flexibility while preventing invalid configurations.

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

### Selection Tool Cursor-Only Pattern

**Pattern:** Selection tool is restricted to cursor-only mode and never enters player inventory.

**Implementation:**
- In `prototypes/selection-tool.lua`, selection tool has `flags = {"only-in-cursor"}`
- Combined with `hidden = true` to prevent tool from appearing in crafting menus
- Tool is given to player via `cursor_stack.set_stack()` in `control.lua`

**Rationale:** The selection tool is a utility item that should only exist temporarily in the player's cursor during use. Allowing it to enter inventory would clutter the player's inventory and create confusion about how to use it. The "only-in-cursor" flag is a Factorio engine feature that prevents items from being placed in inventory slots.

**Related:** See Cursor Management pattern for how cursor is cleared after tool use.

### Foundation Tile Auto-Placement Pattern

**Pattern:** When placing entity ghosts on non-buildable tiles (water, frozen ocean, etc.), foundation tile ghosts are automatically placed underneath so bots lay foundation before building the entity.

**Implementation:**
- Local function `place_foundation_if_needed()` in `scripts/ghost_util.lua`
- Called from `ghost_util.place_ghost()` before entity ghost creation — all entity types (drills, belts, poles, pipes, beacons) get foundation coverage automatically
- Foundation tile discovery: `get_foundation_tiles()` iterates `prototypes.tile` for `is_foundation = true`, cached after first call
- Tile check: `surface.get_tile(tx, ty).collides_with("water_tile")` — only attempts foundation on tiles with the `water_tile` collision layer
- Tries each foundation tile via `surface.create_entity{name="tile-ghost", inner_name=tile_name}`, caching the last successful one (`preferred` index) since a given surface uses the same foundation type throughout

**Planet/surface support:**
- Nauvis: places `landfill` on water
- Aquilo: places `ice-platform` on frozen ocean
- Any modded surface: automatically discovers and uses the correct `is_foundation` tile

**Alt-selection cleanup:** The `on_player_alt_selected_area` handler in `control.lua` also removes `tile-ghost` entities in the selected area via `surface.find_entities_filtered{type="tile-ghost"}`.

**Key lesson:** `surface.create_entity` for `tile-ghost` does NOT validate whether the tile actually needs foundation — it succeeds on land tiles too. The `collides_with("water_tile")` pre-check is required to avoid placing unnecessary foundation everywhere.

### Polite Mode Rail Infrastructure Handling

**Pattern:** Ghost placement distinguishes between elevated rails (in the air) and ground-level rail infrastructure (ramps, supports). Elevated rails are completely ignored. Rail ramps and rail supports block polite mode placement but are never deconstructed.

**Entity classification in `ghost_util.lua`:**
- `no_decon_types`: resources, characters, ghosts, and elevated rail types (`elevated-straight-rail`, `elevated-curved-rail-a`, `elevated-curved-rail-b`, `elevated-half-diagonal-rail`) — completely invisible to placement logic
- `ground_rail_types`: `rail-ramp`, `rail-support` — block polite mode, never deconstructed in any mode
- `polite_decon_types`: trees, rocks, cliffs — demolished in both modes

**Behavior by mode:**
| Entity type | Normal mode | Polite mode |
|---|---|---|
| Elevated rails | Ignored (in the air) | Ignored (in the air) |
| Rail ramps/supports | Ignored (ghost placed) | Blocks placement |
| Trees/rocks/cliffs | Demolished | Demolished |
| Other buildings | Demolished | Blocks placement |

**Mod compatibility:** Checks use `entity.type` (prototype class), not `entity.name`. Modded entities (e.g., Krastorio 2) that use standard Factorio entity types are automatically handled.

**Also in `placer.lua`:** The `preserve_types` set in `demolish_obstacles()` preserves both elevated rails and rail ramps/supports from the broad area sweep.

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
- `burner-drill-filtering-tests.md` - Burner drill exclusion validation
- `pole-whitelist-tests.md` - Pole selector whitelist validation
- `pole-spacing-tests.md` - Fixed pole spacing pattern validation
- `underground-belt-direction-tests.md` - Underground belt direction validation
- `selection-tool-inventory-tests.md` - Selection tool cursor-only validation
- `productive-mode-default-tests.md` - Productivity mode default validation
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
  - `ghost_util.lua` - Ghost entity placement with conflict resolution and foundation tiles
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
