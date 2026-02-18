-- Grid Calculator - Computes drill placement positions in paired rows with belt gaps

local calculator = {}

--- Calculate the grid spacing for a given drill and placement mode.
--- @param drill table Drill info from resource_scanner (width, height, mining_drill_radius)
--- @param mode string "productivity", "loose", or "efficient"
--- @return number spacing_along Spacing along the belt line between drill centers
--- @return number spacing_across Spacing across the belt line (between pairs)
--- @return number offset Row offset for staggered placement (0 for non-staggered)
function calculator.get_spacing(drill, mode)
    local body_w = drill.width
    local body_h = drill.height
    local radius = drill.mining_drill_radius

    local mining_diameter = math.floor(radius) * 2 + 1

    if mode == "productivity" then
        return body_w, body_h, 0

    elseif mode == "loose" then
        -- Respect one drill's mining zone: body_size + mining_radius
        local mining_radius = math.floor(radius)
        local spacing_along = body_w + mining_radius
        local spacing_across = body_h + mining_radius
        return spacing_along, spacing_across, 0

    elseif mode == "efficient" then
        return mining_diameter, mining_diameter, math.floor(mining_diameter / 2)
    end

    return mining_diameter, mining_diameter, 0
end

--- Derive the axis orientation ("NS" or "EW") from a belt direction.
--- @param belt_direction string "north", "south", "east", or "west"
--- @return string "NS" or "EW"
function calculator.direction_to_orientation(belt_direction)
    if belt_direction == "east" or belt_direction == "west" then
        return "EW"
    end
    return "NS"
end

--- Calculate the gap size between paired drill rows.
---
--- The gap is always 1 tile. Underground belts (UBI/UBO) are placed within
--- the drill body rows, and the single gap tile is reserved for poles.
--- For 2x2 drills, plain belts fill the gap instead.
---
--- @param drill table Drill info with width and height
--- @param belt_orientation string "NS" or "EW"
--- @return number gap_tiles Always 1
function calculator.get_pair_gap(drill, belt_orientation)
    return 1
end

--- Build a lookup set of resource tile positions for fast membership testing.
--- Resource positions in Factorio are tile-centered (e.g., 0.5, 1.5),
--- so we key by the integer tile coordinate floor(x), floor(y).
--- @param resource_groups table Map of resource_name -> {positions={...}, ...}
--- @return table<string, true> Set keyed by "x,y" strings
local function build_resource_set(resource_groups)
    local set = {}
    for _, group in pairs(resource_groups) do
        for _, pos in ipairs(group.positions) do
            local tx = math.floor(pos.x)
            local ty = math.floor(pos.y)
            set[tx .. "," .. ty] = true
        end
    end
    return set
end

--- Build a lookup set of resource tile positions for all ore types EXCEPT the selected one.
--- Used to filter out drills whose mining area would overlap foreign ore.
--- @param resource_groups table Full (unfiltered) map of resource_name -> {positions={...}, ...}
--- @param selected_resource string|nil The selected ore name to exclude from the foreign set
--- @return table<string, true> Set keyed by "x,y" strings for foreign ore tiles
local function build_foreign_resource_set(resource_groups, selected_resource)
    local set = {}
    for name, group in pairs(resource_groups) do
        if name ~= selected_resource then
            for _, pos in ipairs(group.positions) do
                local tx = math.floor(pos.x)
                local ty = math.floor(pos.y)
                set[tx .. "," .. ty] = true
            end
        end
    end
    return set
end

--- Check if a drill placed at the given center position would overlap
--- at least one resource tile.
--- @param cx number Drill center x
--- @param cy number Drill center y
--- @param radius number Mining drill radius
--- @param resource_set table Set of "x,y" resource positions
--- @return boolean
local function has_resources_in_mining_area(cx, cy, radius, resource_set)
    local r = math.floor(radius)
    for dx = -r, r do
        for dy = -r, r do
            local tx = math.floor(cx) + dx
            local ty = math.floor(cy) + dy
            if resource_set[tx .. "," .. ty] then
                return true
            end
        end
    end
    return false
end

--- Check if a drill placed at the given center position would overlap
--- any tile from a foreign ore type, considering both the drill body
--- footprint and the mining zone.
--- @param cx number Drill center x
--- @param cy number Drill center y
--- @param body_w number Drill body width
--- @param body_h number Drill body height
--- @param radius number Mining drill radius
--- @param foreign_set table Set of "x,y" foreign ore positions
--- @return boolean true if the body or mining area overlaps foreign ore
local function has_foreign_ore_overlap(cx, cy, body_w, body_h, radius, foreign_set)
    -- The extent covers the drill body + mining zone beyond the body edge.
    -- Use the larger of half-body and floor(radius) on each axis to ensure
    -- both the physical footprint and the mining area are checked.
    local rx = math.max(math.ceil(body_w / 2), math.floor(radius))
    local ry = math.max(math.ceil(body_h / 2), math.floor(radius))
    for dx = -rx, rx do
        for dy = -ry, ry do
            local tx = math.floor(cx) + dx
            local ty = math.floor(cy) + dy
            if foreign_set[tx .. "," .. ty] then
                return true
            end
        end
    end
    return false
end

--- Calculate all drill placement positions in paired rows with belt gaps.
---
--- Drills are arranged in pairs of rows/columns facing each other with a center
--- gap for transport belts and infrastructure. For vertical belt direction (north/south),
--- left column drills face east and right column drills face west. For horizontal
--- belt direction (east/west), top row drills face south and bottom row drills face north.
---
--- The belt_direction parameter controls belt flow. North/south share the same
--- vertical drill layout; east/west share the same horizontal layout. Drill
--- facing always points toward the gap center regardless of belt flow direction.
---
--- @param drill table Drill info from resource_scanner
--- @param bounds table {left_top={x,y}, right_bottom={x,y}} selection bounds
--- @param mode string Placement mode: "productivity", "loose", "efficient"
--- @param belt_direction string "north", "south", "east", or "west" (belt flow direction)
--- @param resource_groups table Resource groups from scan results (already filtered to selected resource for the "has ore" check)
--- @param all_resource_groups table|nil Full unfiltered resource groups (for foreign ore filtering). If nil, no foreign ore filtering is applied.
--- @param selected_resource string|nil The selected ore name. If nil, no foreign ore filtering.
--- @return table {positions=array, belt_lines=array, gap=number, belt_direction=string}
function calculator.calculate_positions(drill, bounds, mode, belt_direction, resource_groups, all_resource_groups, selected_resource)
    -- Support legacy "NS"/"EW" values
    if belt_direction == "NS" then belt_direction = "south" end
    if belt_direction == "EW" then belt_direction = "east" end
    belt_direction = belt_direction or "south"

    local belt_orientation = calculator.direction_to_orientation(belt_direction)
    local spacing_along, spacing_across, row_offset = calculator.get_spacing(drill, mode)
    local resource_set = build_resource_set(resource_groups)

    -- Build foreign ore set for filtering when a specific ore is selected
    local foreign_set = nil
    if all_resource_groups and selected_resource then
        foreign_set = build_foreign_resource_set(all_resource_groups, selected_resource)
    end

    local body_w = drill.width
    local body_h = drill.height
    local radius = drill.mining_drill_radius
    local gap = calculator.get_pair_gap(drill, belt_orientation)

    local half_w = body_w / 2
    local half_h = body_h / 2

    local positions = {}
    local belt_lines = {}

    if belt_orientation == "EW" then
        -- Belt runs east-west (horizontal). Paired rows are top (faces south) and bottom (faces north).
        -- "along" = x-axis (along the belt), "across" = y-axis (perpendicular)

        -- Pair stride: distance from one pair center to the next pair center
        -- Each pair consists of two rows of drills separated by a gap
        local pair_height = body_h + gap + body_h
        local pair_stride = pair_height + (spacing_across - body_h)
        -- spacing_across is the distance between drill centers in the across direction
        -- For paired rows, we use it as the spacing from one pair to the next

        local start_x = math.floor(bounds.left_top.x) + half_w
        local start_y = math.floor(bounds.left_top.y) + half_h

        local extend = math.floor(radius)
        local end_x = bounds.right_bottom.x + extend
        local end_y = bounds.right_bottom.y + extend
        start_x = start_x - extend
        start_y = start_y - extend

        local pair_index = 0
        local y_pair_start = start_y

        while y_pair_start <= end_y do
            -- Top row of the pair: drills face south (output goes down toward belt)
            local y_top = y_pair_start
            -- Bottom row of the pair: drills face north (output goes up toward belt)
            local y_bottom = y_pair_start + body_h + gap
            -- Belt line center y-position: midpoint of the gap between drill edges
            -- Top drill bottom edge = y_pair_start + half_h
            -- Gap center = y_pair_start + half_h + gap/2
            local y_belt = y_pair_start + half_h + (gap / 2)

            -- Track belt line positions for this pair
            local belt_line = {
                orientation = "EW",
                y = y_belt,
                x_min = nil,
                x_max = nil,
                gap_positions = {},  -- positions in the gap for poles/beacons
                drill_along_positions = {},  -- x-positions of drills along this belt line
            }

            local row_for_offset = pair_index

            -- Place top row (faces south)
            local x_offset = 0
            if row_offset > 0 and row_for_offset % 2 == 1 then
                x_offset = row_offset
            end

            local drill_x_set = {}
            local x = start_x + x_offset
            while x <= end_x do
                if has_resources_in_mining_area(x, y_top, radius, resource_set)
                    and not (foreign_set and has_foreign_ore_overlap(x, y_top, body_w, body_h, radius, foreign_set)) then
                    positions[#positions + 1] = {
                        position = {x = x, y = y_top},
                        direction = defines.direction.south,
                    }
                    -- Track belt extent
                    if not belt_line.x_min or x < belt_line.x_min then belt_line.x_min = x end
                    if not belt_line.x_max or x > belt_line.x_max then belt_line.x_max = x end
                    drill_x_set[x] = true
                end
                x = x + spacing_along
            end

            -- Place bottom row (faces north)
            x = start_x + x_offset
            while x <= end_x do
                if has_resources_in_mining_area(x, y_bottom, radius, resource_set)
                    and not (foreign_set and has_foreign_ore_overlap(x, y_bottom, body_w, body_h, radius, foreign_set)) then
                    positions[#positions + 1] = {
                        position = {x = x, y = y_bottom},
                        direction = defines.direction.north,
                    }
                    if not belt_line.x_min or x < belt_line.x_min then belt_line.x_min = x end
                    if not belt_line.x_max or x > belt_line.x_max then belt_line.x_max = x end
                    drill_x_set[x] = true
                end
                x = x + spacing_along
            end

            -- Collect sorted drill x-positions
            for dx, _ in pairs(drill_x_set) do
                belt_line.drill_along_positions[#belt_line.drill_along_positions + 1] = dx
            end
            table.sort(belt_line.drill_along_positions)

            -- Only add belt line if at least one drill was placed in this pair
            if belt_line.x_min then
                -- Add gap center positions along the belt line for pole/beacon placement
                x = start_x + x_offset
                while x <= end_x do
                    if x >= belt_line.x_min and x <= belt_line.x_max then
                        belt_line.gap_positions[#belt_line.gap_positions + 1] = {x = x, y = y_belt}
                    end
                    x = x + spacing_along
                end
                belt_lines[#belt_lines + 1] = belt_line
            end

            y_pair_start = y_pair_start + pair_stride
            pair_index = pair_index + 1
        end
    else
        -- Default: belt runs north-south (vertical). Paired columns: left faces east, right faces west.
        -- "along" = y-axis (along the belt), "across" = x-axis (perpendicular)

        local pair_width = body_w + gap + body_w
        local pair_stride = pair_width + (spacing_across - body_w)

        local start_x = math.floor(bounds.left_top.x) + half_w
        local start_y = math.floor(bounds.left_top.y) + half_h

        local extend = math.floor(radius)
        local end_x = bounds.right_bottom.x + extend
        local end_y = bounds.right_bottom.y + extend
        start_x = start_x - extend
        start_y = start_y - extend

        local pair_index = 0
        local x_pair_start = start_x

        while x_pair_start <= end_x do
            -- Left column: drills face east (output goes right toward belt)
            local x_left = x_pair_start
            -- Right column: drills face west (output goes left toward belt)
            local x_right = x_pair_start + body_w + gap
            -- Belt line center x-position: midpoint of the gap between drill edges
            -- Left drill right edge = x_pair_start + half_w
            -- Gap center = x_pair_start + half_w + gap/2
            local x_belt = x_pair_start + half_w + (gap / 2)

            local belt_line = {
                orientation = "NS",
                x = x_belt,
                y_min = nil,
                y_max = nil,
                gap_positions = {},
                drill_along_positions = {},  -- y-positions of drills along this belt line
            }

            local row_for_offset = pair_index

            local y_offset = 0
            if row_offset > 0 and row_for_offset % 2 == 1 then
                y_offset = row_offset
            end

            -- Place left column (faces east)
            local drill_y_set = {}
            local y = start_y + y_offset
            while y <= end_y do
                if has_resources_in_mining_area(x_left, y, radius, resource_set)
                    and not (foreign_set and has_foreign_ore_overlap(x_left, y, body_w, body_h, radius, foreign_set)) then
                    positions[#positions + 1] = {
                        position = {x = x_left, y = y},
                        direction = defines.direction.east,
                    }
                    if not belt_line.y_min or y < belt_line.y_min then belt_line.y_min = y end
                    if not belt_line.y_max or y > belt_line.y_max then belt_line.y_max = y end
                    drill_y_set[y] = true
                end
                y = y + spacing_along
            end

            -- Place right column (faces west)
            y = start_y + y_offset
            while y <= end_y do
                if has_resources_in_mining_area(x_right, y, radius, resource_set)
                    and not (foreign_set and has_foreign_ore_overlap(x_right, y, body_w, body_h, radius, foreign_set)) then
                    positions[#positions + 1] = {
                        position = {x = x_right, y = y},
                        direction = defines.direction.west,
                    }
                    if not belt_line.y_min or y < belt_line.y_min then belt_line.y_min = y end
                    if not belt_line.y_max or y > belt_line.y_max then belt_line.y_max = y end
                    drill_y_set[y] = true
                end
                y = y + spacing_along
            end

            -- Collect sorted drill y-positions
            for dy, _ in pairs(drill_y_set) do
                belt_line.drill_along_positions[#belt_line.drill_along_positions + 1] = dy
            end
            table.sort(belt_line.drill_along_positions)

            -- Only add belt line if at least one drill was placed
            if belt_line.y_min then
                y = start_y + y_offset
                while y <= end_y do
                    if y >= belt_line.y_min and y <= belt_line.y_max then
                        belt_line.gap_positions[#belt_line.gap_positions + 1] = {x = x_belt, y = y}
                    end
                    y = y + spacing_along
                end
                belt_lines[#belt_lines + 1] = belt_line
            end

            x_pair_start = x_pair_start + pair_stride
            pair_index = pair_index + 1
        end
    end

    return {
        positions = positions,
        belt_lines = belt_lines,
        gap = gap,
        belt_direction = belt_direction,
    }
end

return calculator
