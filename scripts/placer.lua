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
    local resource_groups = scan_results.resource_groups
    if settings.resource_name and resource_groups[settings.resource_name] then
        resource_groups = {[settings.resource_name] = resource_groups[settings.resource_name]}
    end

    -- Calculate grid positions with paired rows and belt gaps
    local belt_orientation = settings.belt_orientation or "NS"
    local result = calculator.calculate_positions(
        drill,
        scan_results.bounds,
        settings.placement_mode,
        belt_orientation,
        resource_groups
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
    local gap = calculator.get_pair_gap()

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
            gap
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
            gap
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
