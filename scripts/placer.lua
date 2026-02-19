-- Placer - Places ghost mining drills on the map based on calculated grid positions

local calculator = require("scripts.calculator")
local belt_placer = require("scripts.belt_placer")
local pole_placer = require("scripts.pole_placer")
local beacon_placer = require("scripts.beacon_placer")

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
}

--- Demolish obstacles in the placement zone by ordering deconstruction.
--- Computes a bounding box from drill positions (plus gap for belts/poles/beacons)
--- and marks trees, rocks, cliffs, and buildings for deconstruction.
--- @param surface LuaSurface The game surface
--- @param force string|LuaForce The force name
--- @param player LuaPlayer The player requesting placement
--- @param positions table Array of {position, direction} entries for drills
--- @param drill table Drill info with width, height
--- @param gap number Gap between paired drill rows
--- @param belt_orientation string "NS" or "EW"
local function demolish_obstacles(surface, force, player, positions, drill, gap, belt_orientation)
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
            -- Check if not already marked for deconstruction
            if not entity.to_be_deconstructed() then
                entity.order_deconstruction(force, player)
            end
        end
    end
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

    local result = calculator.calculate_positions(
        drill,
        scan_results.bounds,
        settings.placement_mode,
        belt_direction,
        resource_groups,
        all_resource_groups,
        selected_resource
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
    demolish_obstacles(surface, force, player, positions, drill, gap, belt_orientation)

    local placed = 0
    local skipped = 0

    for _, entry in ipairs(positions) do
        local pos = entry.position
        local dir = entry.direction

        -- Check if the ghost can be placed at this position
        local can_place = surface.can_place_entity({
            name = drill.name,
            position = pos,
            direction = dir,
            force = force,
            build_check_type = defines.build_check_type.ghost_place,
        })

        if can_place then
            local ghost = surface.create_entity({
                name = "entity-ghost",
                inner_name = drill.name,
                position = pos,
                direction = dir,
                force = force,
                player = player,
                quality = settings.quality or "normal",
            })

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
        else
            skipped = skipped + 1
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
            belt_direction
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
            result.is_small_drill
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
            gap
        )
    end

    -- Show feedback to the player
    if placed > 0 then
        -- Build a summary of what was placed
        local extras = {}
        if belts_placed > 0 then
            extras[#extras + 1] = belts_placed .. " belts"
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
