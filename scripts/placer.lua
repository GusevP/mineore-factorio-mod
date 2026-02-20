-- Placer - Places ghost mining drills on the map based on calculated grid positions

local calculator = require("scripts.calculator")
local belt_placer = require("scripts.belt_placer")
local pipe_placer = require("scripts.pipe_placer")
local pole_placer = require("scripts.pole_placer")
local beacon_placer = require("scripts.beacon_placer")
local ghost_util = require("scripts.ghost_util")

local placer = {}

--- Find the drill info table from scan results matching the given drill name.
--- @param scan_results table Results from resource_scanner.scan()
--- @param drill_name string Prototype name of the drill
--- @return table|nil drill info table
local function find_drill(scan_results, drill_name)
    for _, drill in ipairs(scan_results.compatible_drills) do
        if drill.name == drill_name then
            return drill
        end
    end
    return nil
end

-- Entity types that should NOT be demolished
local preserve_types = {
    ["resource"] = true,
    ["entity-ghost"] = true,
    ["tile-ghost"] = true,
    ["character"] = true,
    -- Elevated rails exist on a different collision layer and don't conflict
    -- with ground-level entities like mining drills
    ["elevated-straight-rail"] = true,
    ["elevated-curved-rail-a"] = true,
    ["elevated-curved-rail-b"] = true,
    ["elevated-half-diagonal-rail"] = true,
    ["rail-ramp"] = true,
    ["rail-support"] = true,
}

-- Entity types that polite mode is allowed to demolish in the obstacle pass
local polite_obstacle_types = {
    ["tree"] = true,
    ["simple-entity"] = true,
    ["cliff"] = true,
}

--- Demolish obstacles in the placement zone by ordering deconstruction.
--- Computes a bounding box from drill positions (plus gap for belts/poles/beacons)
--- and marks trees, rocks, cliffs, and buildings for deconstruction.
--- In polite mode, only demolishes trees, rocks, and cliffs.
--- @param surface LuaSurface The game surface
--- @param force string|LuaForce The force name
--- @param player LuaPlayer The player requesting placement
--- @param positions table Array of {position, direction} entries for drills
--- @param drill table Drill info with width, height
--- @param gap number Gap between paired drill rows
--- @param belt_orientation string "NS" or "EW"
--- @param polite boolean|nil When true, only demolish natural obstacles
local function demolish_obstacles(surface, force, player, positions, drill, gap, belt_orientation, polite)
    if #positions == 0 then
        return
    end

    -- Compute bounding box from all drill positions
    local half_w = drill.width / 2
    local half_h = drill.height / 2

    local min_x = math.huge
    local min_y = math.huge
    local max_x = -math.huge
    local max_y = -math.huge

    for _, entry in ipairs(positions) do
        local pos = entry.position
        local left = pos.x - half_w
        local right = pos.x + half_w
        local top = pos.y - half_h
        local bottom = pos.y + half_h

        if left < min_x then min_x = left end
        if right > max_x then max_x = right end
        if top < min_y then min_y = top end
        if bottom > max_y then max_y = bottom end
    end

    -- Expand bounding box to include the gap area (belts, poles, beacons)
    -- The gap is between paired rows, and beacons extend beyond the drills
    local expand = gap + 3  -- extra margin for beacons (3x3)
    min_x = min_x - expand
    min_y = min_y - expand
    max_x = max_x + expand
    max_y = max_y + expand

    local area = {{min_x, min_y}, {max_x, max_y}}
    local entities = surface.find_entities(area)

    for _, entity in ipairs(entities) do
        if entity.valid and not preserve_types[entity.type] then
            if polite then
                -- In polite mode, only demolish natural obstacles
                if polite_obstacle_types[entity.type] then
                    if not entity.to_be_deconstructed() then
                        entity.order_deconstruction(force, player)
                    end
                end
            else
                if not entity.to_be_deconstructed() then
                    entity.order_deconstruction(force, player)
                end
            end
        end
    end
end

--- Recompute pole_gap_positions and outer_edge_positions from surviving belt lines.
--- Called after belt-line filtering so that 2x2 pole columns match the filtered layout.
--- @param belt_lines table Filtered belt lines
--- @param drill table Drill info with width, height
--- @param gap number Gap size between paired rows
--- @return table pole_gap_positions
--- @return table outer_edge_positions
function placer._recompute_pole_positions(belt_lines, drill, gap)
    local pole_gap_positions = {}
    local outer_edge_positions = {}

    if #belt_lines == 0 then
        return pole_gap_positions, outer_edge_positions
    end

    local half_w = drill.width / 2
    local half_h = drill.height / 2
    local gap_half = gap / 2
    local orientation = belt_lines[1].orientation or "NS"

    -- Derive pair edges from each surviving belt line's cross-axis center
    local pair_edge_min = {}
    local pair_edge_max = {}
    for _, bl in ipairs(belt_lines) do
        if orientation == "NS" then
            -- belt_line.x = pair_start + half_w + gap/2, so pair_start = x - half_w - gap/2
            local pair_start = bl.x - half_w - gap_half
            pair_edge_min[#pair_edge_min + 1] = pair_start - half_w
            pair_edge_max[#pair_edge_max + 1] = pair_start + drill.width + gap + half_w
        else
            local pair_start = bl.y - half_h - gap_half
            pair_edge_min[#pair_edge_min + 1] = pair_start - half_h
            pair_edge_max[#pair_edge_max + 1] = pair_start + drill.height + gap + half_h
        end
    end

    -- Outer edges: first pair min - 0.5, last pair max + 0.5
    outer_edge_positions[#outer_edge_positions + 1] = pair_edge_min[1] - 0.5
    outer_edge_positions[#outer_edge_positions + 1] = pair_edge_max[#pair_edge_max] + 0.5

    -- Pole gaps between adjacent surviving pairs
    for i = 1, #pair_edge_max - 1 do
        local gap_center = (pair_edge_max[i] + pair_edge_min[i + 1]) / 2
        pole_gap_positions[#pole_gap_positions + 1] = gap_center
    end

    return pole_gap_positions, outer_edge_positions
end

--- Filter belt lines to only include positions where drills were actually placed.
--- This prevents orphaned infrastructure when drills are skipped (e.g., polite mode).
--- @param belt_lines table Array of belt line metadata from calculator
--- @param placed_positions table Array of {position, direction} entries for placed drills
--- @param drill table Drill info with width, height
--- @param gap number Gap size between paired rows
--- @return table Filtered belt lines (empty belt lines removed)
function placer._filter_belt_lines(belt_lines, placed_positions, drill, gap)
    -- Build a set of placed drill coordinates for fast lookup
    local placed_set = {}
    for _, entry in ipairs(placed_positions) do
        local key = entry.position.x .. "," .. entry.position.y
        placed_set[key] = true
    end

    local half_w = drill.width / 2
    local half_h = drill.height / 2
    local gap_half = gap / 2
    local filtered = {}

    for _, belt_line in ipairs(belt_lines) do
        if belt_line.orientation == "NS" then
            -- NS: drills are in left/right columns, positions tracked by y
            local left_x = belt_line.x - gap_half - half_w
            local right_x = belt_line.x + gap_half + half_w

            -- Filter side1 (left column) positions
            local new_side1 = {}
            for _, y in ipairs(belt_line.drill_side1_positions or {}) do
                if placed_set[left_x .. "," .. y] then
                    new_side1[#new_side1 + 1] = y
                end
            end

            -- Filter side2 (right column) positions
            local new_side2 = {}
            for _, y in ipairs(belt_line.drill_side2_positions or {}) do
                if placed_set[right_x .. "," .. y] then
                    new_side2[#new_side2 + 1] = y
                end
            end

            -- Rebuild union of along positions
            local new_along = {}
            local along_set = {}
            for _, y in ipairs(new_side1) do
                if not along_set[y] then
                    along_set[y] = true
                    new_along[#new_along + 1] = y
                end
            end
            for _, y in ipairs(new_side2) do
                if not along_set[y] then
                    along_set[y] = true
                    new_along[#new_along + 1] = y
                end
            end
            table.sort(new_along)

            -- Only keep this belt line if any drills remain
            if #new_along > 0 then
                belt_line.drill_side1_positions = new_side1
                belt_line.drill_side2_positions = new_side2
                belt_line.drill_along_positions = new_along
                belt_line.y_min = new_along[1]
                belt_line.y_max = new_along[#new_along]

                -- Filter gap positions to match new extent
                local new_gaps = {}
                for _, gp in ipairs(belt_line.gap_positions or {}) do
                    if gp.y >= belt_line.y_min and gp.y <= belt_line.y_max then
                        new_gaps[#new_gaps + 1] = gp
                    end
                end
                belt_line.gap_positions = new_gaps

                filtered[#filtered + 1] = belt_line
            end
        else
            -- EW: drills are in top/bottom rows, positions tracked by x
            local top_y = belt_line.y - gap_half - half_h
            local bottom_y = belt_line.y + gap_half + half_h

            -- Filter side1 (top row) positions
            local new_side1 = {}
            for _, x in ipairs(belt_line.drill_side1_positions or {}) do
                if placed_set[x .. "," .. top_y] then
                    new_side1[#new_side1 + 1] = x
                end
            end

            -- Filter side2 (bottom row) positions
            local new_side2 = {}
            for _, x in ipairs(belt_line.drill_side2_positions or {}) do
                if placed_set[x .. "," .. bottom_y] then
                    new_side2[#new_side2 + 1] = x
                end
            end

            -- Rebuild union of along positions
            local new_along = {}
            local along_set = {}
            for _, x in ipairs(new_side1) do
                if not along_set[x] then
                    along_set[x] = true
                    new_along[#new_along + 1] = x
                end
            end
            for _, x in ipairs(new_side2) do
                if not along_set[x] then
                    along_set[x] = true
                    new_along[#new_along + 1] = x
                end
            end
            table.sort(new_along)

            if #new_along > 0 then
                belt_line.drill_side1_positions = new_side1
                belt_line.drill_side2_positions = new_side2
                belt_line.drill_along_positions = new_along
                belt_line.x_min = new_along[1]
                belt_line.x_max = new_along[#new_along]

                local new_gaps = {}
                for _, gp in ipairs(belt_line.gap_positions or {}) do
                    if gp.x >= belt_line.x_min and gp.x <= belt_line.x_max then
                        new_gaps[#new_gaps + 1] = gp
                    end
                end
                belt_line.gap_positions = new_gaps

                filtered[#filtered + 1] = belt_line
            end
        end
    end

    return filtered
end

--- Place ghost mining drills according to the player's settings and scan results.
--- @param player LuaPlayer The player requesting placement
--- @param scan_results table Results from resource_scanner.scan()
--- @param settings table Player settings {drill_name, placement_mode, direction, remember}
--- @return number placed Count of successfully placed ghosts
--- @return number skipped Count of positions that failed placement checks
function placer.place(player, scan_results, settings)
    local drill = find_drill(scan_results, settings.drill_name)
    if not drill then
        player.create_local_flying_text({
            text = {"mineore.no-compatible-drills"},
            create_at_cursor = true,
        })
        return 0, 0
    end

    -- Filter resource groups if a specific resource type was selected
    local all_resource_groups = scan_results.resource_groups
    local resource_groups = all_resource_groups
    local selected_resource = nil
    if settings.resource_name and all_resource_groups[settings.resource_name] then
        resource_groups = {[settings.resource_name] = all_resource_groups[settings.resource_name]}
        selected_resource = settings.resource_name
    end

    -- Validate that the selected drill has fluid input when mining fluid-requiring resources
    local resource_needs_fluid = false
    for _, group in pairs(resource_groups) do
        if group.required_fluid then
            resource_needs_fluid = true
            break
        end
    end
    if resource_needs_fluid and not drill.has_fluid_input then
        player.create_local_flying_text({
            text = {"mineore.drill-no-fluid-input"},
            create_at_cursor = true,
        })
        return 0, 0
    end

    -- Calculate grid positions with paired rows and belt gaps
    -- Derive belt direction: prefer new belt_direction, fall back to legacy belt_orientation
    local belt_direction = settings.belt_direction
    if not belt_direction then
        local orient = settings.belt_orientation or "NS"
        if orient == "NS" then
            belt_direction = "south"
        elseif orient == "EW" then
            belt_direction = "east"
        else
            belt_direction = "south"
        end
    end

    -- Look up beacon width when a beacon is selected, so the calculator
    -- can widen pair stride to make room for beacon columns between pairs
    local beacon_width = 0
    if settings.beacon_name and settings.beacon_name ~= "" then
        local beacon_info = beacon_placer.get_beacon_info(settings.beacon_name)
        if beacon_info then
            beacon_width = beacon_info.width
        end
    end

    local result = calculator.calculate_positions(
        drill,
        scan_results.bounds,
        settings.placement_mode,
        belt_direction,
        resource_groups,
        all_resource_groups,
        selected_resource,
        beacon_width
    )

    local positions = result.positions

    if #positions == 0 then
        player.create_local_flying_text({
            text = {"mineore.no-valid-positions"},
            create_at_cursor = true,
        })
        return 0, 0
    end

    local surface = game.surfaces[scan_results.surface_index]
    if not surface then
        return 0, 0
    end
    local force = scan_results.force_name
    local belt_orientation = calculator.direction_to_orientation(belt_direction)
    local gap = result.gap or calculator.get_pair_gap(drill, belt_orientation)

    -- Step 0: Demolish obstacles in the placement zone before placing ghosts
    -- In polite mode, skip the broad pre-pass. Each per-entity ghost placement
    -- via ghost_util.place_ghost handles polite demolition for its own footprint,
    -- so only trees/rocks directly under placed entities are cleared.
    local polite = settings.polite or false
    if not polite then
        demolish_obstacles(surface, force, player, positions, drill, gap, belt_orientation, false)
    end

    local placed = 0
    local skipped = 0
    local placed_positions = {}  -- track successfully placed drill positions

    for _, entry in ipairs(positions) do
        local pos = entry.position
        local dir = entry.direction

        local ghost, was_placed = ghost_util.place_ghost(
            surface, force, player, drill.name, pos, dir,
            settings.quality or "normal", nil, polite)

        if was_placed then
            -- Set module requests on the ghost if configured
            if ghost and ghost.valid and settings.module_name then
                local count = settings.module_count or 1
                local insert_plan = {}
                for slot = 0, count - 1 do
                    insert_plan[#insert_plan + 1] = {
                        id = {
                            name = settings.module_name,
                            quality = settings.quality or "normal",
                        },
                        items = {
                            in_inventory = {
                                {
                                    inventory = defines.inventory.mining_drill_modules,
                                    stack = slot,
                                    count = 1,
                                },
                            },
                        },
                    }
                end
                ghost.insert_plan = insert_plan
            end

            placed = placed + 1
            placed_positions[#placed_positions + 1] = entry
        else
            skipped = skipped + 1
        end
    end

    -- When drills were skipped (e.g., polite mode), filter infrastructure data
    -- to only reference positions where drills were actually placed
    if skipped > 0 then
        positions = placed_positions
        result.belt_lines = placer._filter_belt_lines(result.belt_lines, positions, drill, gap)

        -- Recompute 2x2 pole positions from surviving belt lines so orphan
        -- pole columns are not placed next to fully-skipped pairs.
        if result.is_small_drill then
            result.pole_gap_positions, result.outer_edge_positions =
                placer._recompute_pole_positions(result.belt_lines, drill, gap)
        end
    end

    -- Placement pipeline: drills -> belts -> poles -> beacons
    -- Each step places ghost entities on the surface. Later steps use
    -- surface.can_place_entity to avoid collisions with earlier ghosts.
    -- The beacon placer also builds an explicit blocked tile set for
    -- efficient pre-filtering of candidate positions.

    -- Step 2: Place belts in the gap between paired drill rows
    local belts_placed = 0
    local belts_skipped = 0
    if settings.belt_name and settings.belt_name ~= "" and #result.belt_lines > 0 then
        belts_placed, belts_skipped = belt_placer.place(
            surface, force, player,
            result.belt_lines,
            drill,
            settings.belt_name,
            settings.belt_quality or settings.quality or "normal",
            gap,
            belt_direction,
            polite
        )
    end

    -- Step 2.5: Place pipes between drills when resource requires fluid
    local pipes_placed = 0
    local pipes_skipped = 0
    if resource_needs_fluid and settings.pipe_name and settings.pipe_name ~= "" and #result.belt_lines > 0 then
        pipes_placed, pipes_skipped = pipe_placer.place(
            surface, force, player,
            result.belt_lines,
            drill,
            settings.pipe_name,
            settings.pipe_quality or settings.quality or "normal",
            gap,
            belt_direction,
            settings.placement_mode,
            polite
        )
    end

    -- Step 3: Place poles/substations in the gaps between paired drill rows
    local poles_placed = 0
    local poles_skipped = 0
    if settings.pole_name and settings.pole_name ~= "" and #result.belt_lines > 0 then
        poles_placed, poles_skipped = pole_placer.place(
            surface, force, player,
            result.belt_lines,
            drill,
            settings.pole_name,
            settings.pole_quality or settings.quality or "normal",
            gap,
            result.pole_gap_positions,
            result.outer_edge_positions,
            result.is_small_drill,
            belt_direction,
            polite
        )
    end

    -- Step 4: Place beacons on the outer edges of drill pairs (last step)
    local beacons_placed = 0
    local beacons_skipped = 0
    if settings.beacon_name and settings.beacon_name ~= "" and #positions > 0 then
        local max_beacons = player.mod_settings["mineore-max-beacons-per-drill"].value
        local preferred_beacons = player.mod_settings["mineore-preferred-beacons-per-drill"].value
        -- Use the lower of max and preferred as the effective limit,
        -- but if preferred is 0 it means no preference limit (use max only)
        local effective_limit = max_beacons
        if preferred_beacons > 0 and preferred_beacons < max_beacons then
            effective_limit = preferred_beacons
        end
        beacons_placed, beacons_skipped = beacon_placer.place(
            surface, force, player,
            positions,
            drill,
            result.belt_lines,
            settings.beacon_name,
            settings.beacon_quality or settings.quality or "normal",
            settings.beacon_module_name,
            settings.beacon_module_count,
            effective_limit,
            gap,
            polite
        )
    end

    -- Show feedback to the player
    if placed > 0 then
        -- Build a summary of what was placed
        local extras = {}
        if belts_placed > 0 then
            extras[#extras + 1] = belts_placed .. " belts"
        end
        if pipes_placed > 0 then
            extras[#extras + 1] = pipes_placed .. " pipes"
        end
        if poles_placed > 0 then
            extras[#extras + 1] = poles_placed .. " poles"
        end
        if beacons_placed > 0 then
            extras[#extras + 1] = beacons_placed .. " beacons"
        end

        if #extras > 0 then
            local extras_text = table.concat(extras, ", ")
            player.create_local_flying_text({
                text = {"mineore.placed-miners-and-extras", placed, extras_text},
                create_at_cursor = true,
            })
        elseif skipped > 0 then
            player.create_local_flying_text({
                text = {"mineore.placed-with-skipped", placed, skipped},
                create_at_cursor = true,
            })
        else
            player.create_local_flying_text({
                text = {"mineore.placed-miners", placed},
                create_at_cursor = true,
            })
        end
    else
        player.create_local_flying_text({
            text = {"mineore.no-valid-positions"},
            create_at_cursor = true,
        })
    end

    return placed, skipped
end

return placer
