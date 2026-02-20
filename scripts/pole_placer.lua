-- Pole Placer - Places ghost electric poles/substations in the gaps between paired miner rows
--
-- Poles are placed along the belt line gap between paired drill rows.
-- The placement algorithm:
--   1. Reads the pole prototype data at runtime (supply area, wire reach, collision box)
--   2. Calculates the maximum spacing between poles so that:
--      a. All drills are within the pole's supply area
--      b. Consecutive poles are within wire reach of each other
--   3. Places poles along each belt line at the calculated interval
--
-- For NS orientation: poles are placed along the vertical gap, spaced vertically
-- For EW orientation: poles are placed along the horizontal gap, spaced horizontally
--
-- Multi-tile poles (e.g., 2x2 substations) are centered in the gap. If the pole
-- is too wide to fit in the free rows (middle gap rows not occupied by belts),
-- can_place_entity will reject the placement and the pole is skipped.

local ghost_util = require("scripts.ghost_util")

local pole_placer = {}

--- Get prototype data for an electric pole entity.
--- @param pole_name string Prototype name of the pole/substation
--- @return table|nil {supply_area_distance, max_wire_distance, width, height} or nil if not found
function pole_placer.get_pole_info(pole_name)
    local proto = prototypes.entity[pole_name]
    if not proto then
        return nil
    end

    -- Get collision box dimensions to determine entity footprint
    local cbox = proto.collision_box
    local width = math.ceil(cbox.right_bottom.x - cbox.left_top.x)
    local height = math.ceil(cbox.right_bottom.y - cbox.left_top.y)

    return {
        name = pole_name,
        supply_area_distance = proto.get_supply_area_distance(),
        max_wire_distance = proto.get_max_wire_distance(),
        width = width,
        height = height,
    }
end

--- Calculate the maximum spacing between poles along a belt line.
---
--- The spacing is limited by two constraints:
---   1. Supply coverage: each drill must be within the pole's supply area.
---      Two consecutive poles placed at distance D apart will have overlapping
---      supply areas if D <= 2 * supply_area_distance. We use this as the
---      supply constraint.
---
---   2. Wire connectivity: consecutive poles must be within max_wire_distance
---      of each other.
---
--- We use the minimum of these two constraints, rounded down to an integer.
---
--- @param pole_info table Pole prototype info from get_pole_info()
--- @return number spacing Maximum spacing between pole centers along the belt line
function pole_placer.calculate_spacing(pole_info)
    local supply_spacing = math.floor(2 * pole_info.supply_area_distance)
    local wire_spacing = math.floor(pole_info.max_wire_distance)
    local spacing = math.min(supply_spacing, wire_spacing)

    if spacing < 1 then
        spacing = 1
    end

    return spacing
end

--- Place ghost electric poles along all belt lines.
--- For 3x3+ drills: poles go in the belt line gap (existing behavior).
--- For 2x2 drills: poles go in the pole gap columns between pairs AND on outer edges.
--- @param surface LuaSurface The game surface
--- @param force string Force name for ghost placement
--- @param player LuaPlayer The player requesting placement
--- @param belt_lines table Array of belt line metadata from calculator
--- @param drill_info table Drill info (width, height) for computing coverage extent
--- @param pole_name string Electric pole prototype name
--- @param pole_quality string Quality name for pole ghosts
--- @param gap number Gap size between paired rows
--- @param pole_gap_positions table|nil Cross-axis positions of pole gaps between pairs (2x2 drills)
--- @param outer_edge_positions table|nil Cross-axis positions of outer edges (2x2 drills)
--- @param is_small_drill boolean|nil Whether this is a 2x2 (small) drill
--- @param polite boolean|nil When true, respect polite placement
--- @return number placed Count of pole ghosts placed
--- @return number skipped Count of positions where placement failed
function pole_placer.place(surface, force, player, belt_lines, drill_info, pole_name, pole_quality, gap, pole_gap_positions, outer_edge_positions, is_small_drill, polite)
    if not pole_name or pole_name == "" then
        return 0, 0
    end

    local pole_info = pole_placer.get_pole_info(pole_name)
    if not pole_info then
        return 0, 0
    end

    local spacing = pole_placer.calculate_spacing(pole_info)
    local quality = pole_quality or "normal"

    local half_w = drill_info.width / 2
    local half_h = drill_info.height / 2

    local placed = 0
    local skipped = 0

    if is_small_drill then
        -- 2x2 drills: place poles in pole gap columns between pairs and on outer edges
        -- Combine pole_gap_positions and outer_edge_positions into one list
        local all_cross_positions = {}
        if outer_edge_positions then
            for _, pos in ipairs(outer_edge_positions) do
                all_cross_positions[#all_cross_positions + 1] = pos
            end
        end
        if pole_gap_positions then
            for _, pos in ipairs(pole_gap_positions) do
                all_cross_positions[#all_cross_positions + 1] = pos
            end
        end

        -- Determine the along-axis extent from belt lines
        local along_min, along_max
        local orientation = belt_lines[1] and belt_lines[1].orientation or "NS"

        for _, belt_line in ipairs(belt_lines) do
            if orientation == "NS" then
                if not along_min or belt_line.y_min < along_min then along_min = belt_line.y_min end
                if not along_max or belt_line.y_max > along_max then along_max = belt_line.y_max end
            else
                if not along_min or belt_line.x_min < along_min then along_min = belt_line.x_min end
                if not along_max or belt_line.x_max > along_max then along_max = belt_line.x_max end
            end
        end

        if along_min and along_max then
            local half_along = orientation == "NS" and half_h or half_w
            local along_start = along_min - half_along
            local along_end = along_max + half_along

            for _, cross_pos in ipairs(all_cross_positions) do
                local p, s = pole_placer._place_pole_column(
                    surface, force, player, orientation, cross_pos,
                    along_start, along_end, spacing, pole_info, quality, polite)
                placed = placed + p
                skipped = skipped + s
            end
        end
    else
        -- 3x3+ drills: poles go in the belt line gap (existing behavior)
        for _, belt_line in ipairs(belt_lines) do
            if belt_line.orientation == "NS" then
                local p, s = pole_placer._place_ns_poles(
                    surface, force, player, belt_line, half_h, spacing, pole_info, quality, gap, polite)
                placed = placed + p
                skipped = skipped + s
            elseif belt_line.orientation == "EW" then
                local p, s = pole_placer._place_ew_poles(
                    surface, force, player, belt_line, half_w, spacing, pole_info, quality, gap, polite)
                placed = placed + p
                skipped = skipped + s
            end
        end
    end

    return placed, skipped
end

--- Place poles along a column or row at a given cross-axis position.
--- Used for 2x2 drills where poles go in gap columns between pairs and on outer edges.
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param orientation string "NS" or "EW"
--- @param cross_pos number The cross-axis position (x for NS, y for EW)
--- @param along_start number Start of the along-axis extent
--- @param along_end number End of the along-axis extent
--- @param spacing number Distance between pole centers
--- @param pole_info table Pole prototype info
--- @param quality string Quality name
--- @param polite boolean|nil Polite mode flag
--- @return number placed
--- @return number skipped
function pole_placer._place_pole_column(surface, force, player, orientation, cross_pos, along_start, along_end, spacing, pole_info, quality, polite)
    local placed = 0
    local skipped = 0

    local along = along_start + spacing / 2
    while along <= along_end do
        local pos
        if orientation == "NS" then
            -- Cross-axis is x, along-axis is y
            local snap_y
            if pole_info.height % 2 == 0 then
                snap_y = math.floor(along)
            else
                snap_y = math.floor(along) + 0.5
            end
            pos = {x = cross_pos, y = snap_y}
        else
            -- Cross-axis is y, along-axis is x
            local snap_x
            if pole_info.width % 2 == 0 then
                snap_x = math.floor(along)
            else
                snap_x = math.floor(along) + 0.5
            end
            pos = {x = snap_x, y = cross_pos}
        end

        local p, s = pole_placer._place_ghost(surface, force, player, pole_info.name, pos, quality, polite)
        placed = placed + p
        skipped = skipped + s
        along = along + spacing
    end

    return placed, skipped
end

--- Place poles along a north-south oriented belt line.
--- Poles are placed vertically along the gap at calculated intervals.
--- The x-position is the center of the gap, snapped to the correct tile
--- alignment for the pole's width.
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param belt_line table Belt line metadata from calculator
--- @param half_h number Half the drill height
--- @param spacing number Distance between pole centers
--- @param pole_info table Pole prototype info (name, width, height)
--- @param quality string Quality name
--- @param gap number Gap size in tiles
--- @param polite boolean|nil Polite mode flag
--- @return number placed
--- @return number skipped
function pole_placer._place_ns_poles(surface, force, player, belt_line, half_h, spacing, pole_info, quality, gap, polite)
    local placed = 0
    local skipped = 0

    -- For NS belts, the gap spans the x-axis. x_center is the midpoint.
    -- For odd-width poles (1x1, 3x3): center on x_center (tile-centered)
    -- For even-width poles (2x2): snap so the pole straddles the gap center
    local x_center = belt_line.x

    -- y extent: from the top edge of the first drill to the bottom edge of the last drill
    local y_start = belt_line.y_min - half_h
    local y_end = belt_line.y_max + half_h

    local y = y_start + spacing / 2
    while y <= y_end do
        -- Snap y to tile center for proper alignment based on pole height
        local snap_y
        if pole_info.height % 2 == 0 then
            snap_y = math.floor(y)  -- even-height: place on tile boundary
        else
            snap_y = math.floor(y) + 0.5  -- odd-height: place on tile center
        end
        local pos = {x = x_center, y = snap_y}
        local p, s = pole_placer._place_ghost(surface, force, player, pole_info.name, pos, quality, polite)
        placed = placed + p
        skipped = skipped + s
        y = y + spacing
    end

    return placed, skipped
end

--- Place poles along an east-west oriented belt line.
--- Poles are placed horizontally along the gap at calculated intervals.
--- The y-position is the center of the gap, snapped to the correct tile
--- alignment for the pole's height.
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param belt_line table Belt line metadata from calculator
--- @param half_w number Half the drill width
--- @param spacing number Distance between pole centers
--- @param pole_info table Pole prototype info (name, width, height)
--- @param quality string Quality name
--- @param gap number Gap size in tiles
--- @param polite boolean|nil Polite mode flag
--- @return number placed
--- @return number skipped
function pole_placer._place_ew_poles(surface, force, player, belt_line, half_w, spacing, pole_info, quality, gap, polite)
    local placed = 0
    local skipped = 0

    -- For EW belts, the gap spans the y-axis. y_center is the midpoint.
    local y_center = belt_line.y

    -- x extent: from the left edge of the first drill to the right edge of the last drill
    local x_start = belt_line.x_min - half_w
    local x_end = belt_line.x_max + half_w

    local x = x_start + spacing / 2
    while x <= x_end do
        -- Snap x to tile center for proper alignment based on pole width
        local snap_x
        if pole_info.width % 2 == 0 then
            snap_x = math.floor(x)  -- even-width: place on tile boundary
        else
            snap_x = math.floor(x) + 0.5  -- odd-width: place on tile center
        end
        local pos = {x = snap_x, y = y_center}
        local p, s = pole_placer._place_ghost(surface, force, player, pole_info.name, pos, quality, polite)
        placed = placed + p
        skipped = skipped + s
        x = x + spacing
    end

    return placed, skipped
end

--- Place a single ghost entity, checking placement first.
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param entity_name string Prototype name
--- @param position table {x, y}
--- @param quality string Quality name
--- @param polite boolean|nil Polite mode flag
--- @return number placed 1 if placed, 0 if not
--- @return number skipped 1 if skipped, 0 if not
function pole_placer._place_ghost(surface, force, player, entity_name, position, quality, polite)
    local _, was_placed = ghost_util.place_ghost(
        surface, force, player, entity_name, position, nil, quality, nil, polite)
    if was_placed then
        return 1, 0
    end
    return 0, 1
end

return pole_placer
