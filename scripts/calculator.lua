-- Grid Calculator - Computes drill placement positions based on mode and drill specs

local calculator = {}

--- Calculate the grid spacing for a given drill and placement mode.
--- @param drill table Drill info from resource_scanner (width, height, mining_drill_radius)
--- @param mode string "productivity", "normal", or "efficient"
--- @return number spacing_x Horizontal spacing between drill centers
--- @return number spacing_y Vertical spacing between drill centers
--- @return number offset_x Row offset for staggered placement (0 for non-staggered)
function calculator.get_spacing(drill, mode)
    local body_w = drill.width
    local body_h = drill.height
    local radius = drill.mining_drill_radius

    -- Mining area diameter: the full width/height the drill can reach.
    -- In Factorio, mining_drill_radius is measured from the center of the drill.
    -- The mining area is a square with side length = 2 * floor(radius + 0.5) + 1
    -- but for spacing we use 2 * radius as the continuous coverage width.
    -- The effective mining area side length in tiles:
    local mining_diameter = math.floor(radius) * 2 + 1

    if mode == "productivity" then
        -- Drills touching edge-to-edge, maximum number of drills
        return body_w, body_h, 0

    elseif mode == "normal" then
        -- Mining areas just touch without significant overlap
        -- Spacing equals the mining area diameter so adjacent drills'
        -- mining zones barely meet
        return mining_diameter, mining_diameter, 0

    elseif mode == "efficient" then
        -- Staggered rows: offset every other row by half the spacing
        -- This provides full ground coverage with fewer drills
        -- because hexagonal-like packing covers gaps between rows
        return mining_diameter, mining_diameter, math.floor(mining_diameter / 2)
    end

    -- Fallback to normal
    return mining_diameter, mining_diameter, 0
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

--- Calculate all drill placement positions for the given parameters.
--- @param drill table Drill info from resource_scanner
--- @param bounds table {left_top={x,y}, right_bottom={x,y}} selection bounds
--- @param mode string Placement mode: "productivity", "normal", "efficient"
--- @param direction string Drill output direction: "north", "south", "east", "west"
--- @param resource_groups table Resource groups from scan results
--- @return table[] Array of {position={x,y}, direction=defines.direction.*}
function calculator.calculate_positions(drill, bounds, mode, direction, resource_groups)
    local spacing_x, spacing_y, row_offset = calculator.get_spacing(drill, mode)
    local resource_set = build_resource_set(resource_groups)

    local body_w = drill.width
    local body_h = drill.height
    local radius = drill.mining_drill_radius

    -- Convert direction string to Factorio defines
    local dir_map = {
        north = defines.direction.north,
        south = defines.direction.south,
        east = defines.direction.east,
        west = defines.direction.west,
    }
    local factorio_direction = dir_map[direction] or defines.direction.north

    -- Half-sizes for centering drills on the tile grid.
    -- Factorio places entities at their center. For a 3-wide drill,
    -- the center is at x+1.5 relative to the left edge tile.
    -- We want drills aligned to the tile grid, so for odd-width drills
    -- the center is at a tile center (0.5 offset), and for even-width
    -- drills the center is at a tile boundary (0.0 offset).
    local half_w = body_w / 2
    local half_h = body_h / 2

    -- Determine the starting grid anchor point.
    -- Snap to tile grid based on drill body size.
    -- For odd-size drills (e.g., 3x3): half_w=1.5, center lands at tile center (x.5)
    -- For even-size drills (e.g., 2x2): half_w=1.0, center lands at tile edge (x.0)
    local start_x = math.floor(bounds.left_top.x) + half_w
    local start_y = math.floor(bounds.left_top.y) + half_h

    -- Extend the placement area slightly beyond the selection bounds
    -- so drills near the edges can still reach resources inside.
    local extend = math.floor(radius)
    local end_x = bounds.right_bottom.x + extend
    local end_y = bounds.right_bottom.y + extend

    -- Also extend the start backwards
    start_x = start_x - extend
    start_y = start_y - extend

    local positions = {}
    local row = 0
    local y = start_y

    while y <= end_y do
        -- Apply row offset for staggered placement (efficient mode)
        local x_offset = 0
        if row_offset > 0 and row % 2 == 1 then
            x_offset = row_offset
        end

        local x = start_x + x_offset
        while x <= end_x do
            -- Check if this drill position has any resource tiles in its mining area
            if has_resources_in_mining_area(x, y, radius, resource_set) then
                positions[#positions + 1] = {
                    position = {x = x, y = y},
                    direction = factorio_direction,
                }
            end

            x = x + spacing_x
        end

        y = y + spacing_y
        row = row + 1
    end

    return positions
end

return calculator
