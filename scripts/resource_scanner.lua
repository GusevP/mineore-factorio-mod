-- Resource Scanner - Detects resources and compatible miners in selected area

local resource_scanner = {}

--- Scan selected entities and return grouped resources with compatible drills.
--- @param entities LuaEntity[] Array of resource entities from selection event
--- @param player LuaPlayer The player who made the selection
--- @return table|nil scan_results Table with resource groups and drill info, or nil if no resources
function resource_scanner.scan(entities, player)
    if #entities == 0 then
        return nil
    end

    -- Group resource entities by name and collect positions
    local resource_groups = {}
    for _, entity in pairs(entities) do
        if entity.valid then
            local name = entity.name
            if not resource_groups[name] then
                local proto = prototypes.entity[name]
                local mineable = proto and proto.mineable_properties
                resource_groups[name] = {
                    name = name,
                    category = proto and proto.resource_category or "basic-solid",
                    count = 0,
                    positions = {},
                    required_fluid = mineable and mineable.required_fluid or nil,
                    fluid_amount = mineable and mineable.fluid_amount or nil,
                }
            end
            local group = resource_groups[name]
            group.count = group.count + 1
            group.positions[#group.positions + 1] = entity.position
        end
    end

    -- Collect unique resource categories from the selection
    local selected_categories = {}
    for _, group in pairs(resource_groups) do
        selected_categories[group.category] = true
    end

    -- Find all mining drill prototypes compatible with the selected resources
    local compatible_drills = resource_scanner.find_compatible_drills(selected_categories)

    -- Compute the bounding box of the entire selection
    local bounds = resource_scanner.compute_bounds(entities)

    return {
        resource_groups = resource_groups,
        compatible_drills = compatible_drills,
        bounds = bounds,
        surface_index = player.surface.index,
        force_name = player.force.name,
    }
end

--- Find all mining drill prototypes that can mine at least one of the given resource categories.
--- @param categories table<string, true> Set of resource category IDs
--- @return table[] Array of drill info tables sorted by name
function resource_scanner.find_compatible_drills(categories)
    local drills = prototypes.get_entity_filtered({{filter = "type", type = "mining-drill"}})
    local compatible = {}

    for name, drill in pairs(drills) do
        -- Check if this drill can mine any of the selected resource categories
        local can_mine = false
        if drill.resource_categories then
            for category, _ in pairs(categories) do
                if drill.resource_categories[category] then
                    can_mine = true
                    break
                end
            end
        end

        -- Burner drill filtering for liquid-requiring ores is now handled by GUI
        if can_mine then
            local collision = drill.collision_box
            -- Drill physical size from collision box
            local width = math.ceil(collision.right_bottom.x - collision.left_top.x)
            local height = math.ceil(collision.right_bottom.y - collision.left_top.y)

            -- Extract fluid input connections from fluidbox prototypes
            local fluid_inputs = {}
            if drill.fluidbox_prototypes then
                for _, fb in ipairs(drill.fluidbox_prototypes) do
                    if fb.production_type == "input" or fb.production_type == "input-output" then
                        for _, conn in ipairs(fb.pipe_connections) do
                            fluid_inputs[#fluid_inputs + 1] = {
                                positions = conn.positions,
                                direction = conn.direction,
                            }
                        end
                    end
                end
            end

            compatible[#compatible + 1] = {
                name = name,
                localised_name = drill.localised_name,
                collision_box = collision,
                width = width,
                height = height,
                mining_drill_radius = drill.mining_drill_radius,
                module_inventory_size = drill.module_inventory_size or 0,
                resource_categories = drill.resource_categories,
                has_fluid_input = #fluid_inputs > 0,
                fluid_inputs = fluid_inputs,
            }
        end
    end

    -- Sort by name for consistent ordering
    table.sort(compatible, function(a, b) return a.name < b.name end)

    return compatible
end

--- Compute the axis-aligned bounding box of all entities.
--- @param entities LuaEntity[] Array of entities
--- @return table bounds {left_top={x,y}, right_bottom={x,y}}
function resource_scanner.compute_bounds(entities)
    local min_x, min_y = math.huge, math.huge
    local max_x, max_y = -math.huge, -math.huge

    for _, entity in pairs(entities) do
        if entity.valid then
            local pos = entity.position
            if pos.x < min_x then min_x = pos.x end
            if pos.y < min_y then min_y = pos.y end
            if pos.x > max_x then max_x = pos.x end
            if pos.y > max_y then max_y = pos.y end
        end
    end

    -- Handle edge case: no valid entities
    if min_x == math.huge then
        return {
            left_top = {x = 0, y = 0},
            right_bottom = {x = 0, y = 0},
        }
    end

    return {
        left_top = {x = min_x, y = min_y},
        right_bottom = {x = max_x, y = max_y},
    }
end

--- Print scan results to player console for debugging.
--- @param scan_results table Results from resource_scanner.scan()
--- @param player LuaPlayer The player to print to
function resource_scanner.print_results(scan_results, player)
    player.print("[mineore] --- Scan Results ---")

    -- Print resource groups
    for name, group in pairs(scan_results.resource_groups) do
        player.print({"mineore.resource-found", name, group.count})
        player.print("[mineore]   Category: " .. group.category)
    end

    -- Print compatible drills
    if #scan_results.compatible_drills == 0 then
        player.print("[mineore] No compatible drills found!")
    else
        player.print("[mineore] Compatible drills:")
        for _, drill in ipairs(scan_results.compatible_drills) do
            player.print("[mineore]   " .. drill.name
                .. " (size: " .. drill.width .. "x" .. drill.height
                .. ", mining radius: " .. drill.mining_drill_radius
                .. ", module slots: " .. drill.module_inventory_size .. ")")
        end
    end

    -- Print bounds
    local b = scan_results.bounds
    player.print("[mineore] Selection bounds: ("
        .. string.format("%.1f", b.left_top.x) .. ", " .. string.format("%.1f", b.left_top.y)
        .. ") to ("
        .. string.format("%.1f", b.right_bottom.x) .. ", " .. string.format("%.1f", b.right_bottom.y) .. ")")
end

return resource_scanner
