-- Pipe Placer - Places ghost pipes between drills that require fluid input
--
-- When mining resources that need fluid (e.g., uranium ore requiring sulfuric acid),
-- drills need pipe connections. In efficient mode, drills are spaced apart and
-- pipes must bridge the gaps between adjacent drills along each column/row.
-- In productivity mode, drills are touching and share fluid automatically.
--
-- Pipes run along each drill column/row (parallel to belt flow direction),
-- connecting the fluid inputs of adjacent drills.

local ghost_util = require("scripts.ghost_util")

local pipe_placer = {}

--- Place ghost pipes connecting adjacent drills along belt lines.
--- For efficient mode: pipes fill the gap between drill bodies in each column.
--- For productivity mode: drills are touching, no pipes needed.
---
--- @param surface LuaSurface The game surface
--- @param force string Force name for ghost placement
--- @param player LuaPlayer The player requesting placement
--- @param belt_lines table Array of belt line metadata from calculator
--- @param drill_info table Drill info (width, height)
--- @param pipe_name string Pipe prototype name (e.g., "pipe")
--- @param quality string Quality name for pipe ghosts
--- @param gap number Gap size between paired rows (belt gap)
--- @param belt_direction string "north", "south", "east", or "west"
--- @param mode string "productivity" or "efficient"
--- @param polite boolean|nil When true, respect polite placement
--- @return number placed Count of pipe ghosts placed
--- @return number skipped Count of positions where placement failed
function pipe_placer.place(surface, force, player, belt_lines, drill_info, pipe_name, quality, gap, belt_direction, mode, polite)
    if not pipe_name or pipe_name == "" then
        return 0, 0
    end

    -- In productivity mode, drills are touching and share fluid automatically
    if mode == "productivity" then
        return 0, 0
    end

    -- Validate pipe prototype exists
    if not prototypes.entity[pipe_name] then
        return 0, 0
    end

    quality = quality or "normal"

    local placed = 0
    local skipped = 0

    for _, belt_line in ipairs(belt_lines) do
        local p, s = pipe_placer._place_pipes_along_line(
            surface, force, player, belt_line, drill_info,
            pipe_name, quality, belt_direction, gap, polite)
        placed = placed + p
        skipped = skipped + s
    end

    return placed, skipped
end

--- Place pipes along a single belt line, connecting adjacent drills.
--- For NS orientation: drills are in left/right columns, pipes connect vertically.
--- For EW orientation: drills are in top/bottom rows, pipes connect horizontally.
---
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param belt_line table Belt line metadata
--- @param drill_info table Drill info (width, height)
--- @param pipe_name string Pipe prototype name
--- @param underground_name string|nil Pipe-to-ground prototype name
--- @param quality string Quality name
--- @param belt_direction string Belt flow direction
--- @param belt_gap number Gap size between paired rows (belt gap)
--- @param polite boolean|nil Polite mode flag
--- @return number placed
--- @return number skipped
function pipe_placer._place_pipes_along_line(surface, force, player, belt_line, drill_info, pipe_name, quality, belt_direction, belt_gap, polite)
    local placed = 0
    local skipped = 0

    local drill_positions = belt_line.drill_along_positions or {}
    if #drill_positions < 2 then
        return 0, 0
    end

    if belt_line.orientation == "NS" then
        -- NS belt: drills in left/right columns, pipes connect along y-axis
        -- Left drill column center = belt_line.x - belt_gap/2 - half_w
        -- Right drill column center = belt_line.x + belt_gap/2 + half_w
        -- Pipes go on the outer edges: one tile outside each drill column
        local half_w = drill_info.width / 2
        local half_h = drill_info.height / 2
        local left_drill_x = belt_line.x - belt_gap / 2 - half_w
        local right_drill_x = belt_line.x + belt_gap / 2 + half_w
        local x_left = left_drill_x - half_w - 0.5
        local x_right = right_drill_x + half_w + 0.5

        -- Use per-side positions to avoid orphan pipes on asymmetric layouts
        local side1_positions = belt_line.drill_side1_positions or drill_positions
        local side2_positions = belt_line.drill_side2_positions or drill_positions
        local side_positions_list = {
            {col_x = x_left, positions = side1_positions},
            {col_x = x_right, positions = side2_positions},
        }

        -- Place pipes between adjacent drills in each column
        for _, side in ipairs(side_positions_list) do
            for i = 1, #side.positions - 1 do
                local y_current = side.positions[i]
                local y_next = side.positions[i + 1]

                -- Gap runs from bottom edge of current drill to top edge of next drill
                local gap_start = y_current + half_h
                local gap_end = y_next - half_h
                local gap_tiles = math.floor(gap_end - gap_start + 0.5)

                if gap_tiles > 0 then
                    local p, s = pipe_placer._fill_gap(
                        surface, force, player, pipe_name,
                        quality, side.col_x, gap_start, gap_tiles, "y", polite)
                    placed = placed + p
                    skipped = skipped + s
                end
            end
        end
    else
        -- EW belt: drills in top/bottom rows, pipes connect along x-axis
        -- Top drill row center = belt_line.y - belt_gap/2 - half_h
        -- Bottom drill row center = belt_line.y + belt_gap/2 + half_h
        -- Pipes go on the outer edges: one tile outside each drill row
        local half_w = drill_info.width / 2
        local half_h = drill_info.height / 2
        local top_drill_y = belt_line.y - belt_gap / 2 - half_h
        local bottom_drill_y = belt_line.y + belt_gap / 2 + half_h
        local y_top = top_drill_y - half_h - 0.5
        local y_bottom = bottom_drill_y + half_h + 0.5

        -- Use per-side positions to avoid orphan pipes on asymmetric layouts
        local side1_positions = belt_line.drill_side1_positions or drill_positions
        local side2_positions = belt_line.drill_side2_positions or drill_positions
        local side_positions_list = {
            {row_y = y_top, positions = side1_positions},
            {row_y = y_bottom, positions = side2_positions},
        }

        for _, side in ipairs(side_positions_list) do
            for i = 1, #side.positions - 1 do
                local x_current = side.positions[i]
                local x_next = side.positions[i + 1]

                local gap_start = x_current + half_w
                local gap_end = x_next - half_w
                local gap_tiles = math.floor(gap_end - gap_start + 0.5)

                if gap_tiles > 0 then
                    local p, s = pipe_placer._fill_gap(
                        surface, force, player, pipe_name,
                        quality, side.row_y, gap_start, gap_tiles, "x", polite)
                    placed = placed + p
                    skipped = skipped + s
                end
            end
        end
    end

    return placed, skipped
end

--- Fill a gap between two drills with regular pipes.
---
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param pipe_name string Regular pipe prototype
--- @param quality string Quality name
--- @param fixed_coord number The fixed coordinate (x for y-axis gaps, y for x-axis gaps)
--- @param gap_start number Start of the gap (edge of first drill)
--- @param gap_tiles number Number of tiles in the gap
--- @param axis string "x" or "y" - which axis the gap runs along
--- @param polite boolean|nil Polite mode flag
--- @return number placed
--- @return number skipped
function pipe_placer._fill_gap(surface, force, player, pipe_name, quality, fixed_coord, gap_start, gap_tiles, axis, polite)
    local placed = 0
    local skipped = 0

    for i = 1, gap_tiles do
        local pos
        if axis == "y" then
            pos = {x = fixed_coord, y = gap_start + i - 0.5}
        else
            pos = {x = gap_start + i - 0.5, y = fixed_coord}
        end
        local p, s = pipe_placer._place_ghost(surface, force, player, pipe_name, pos, quality, polite)
        placed = placed + p
        skipped = skipped + s
    end

    return placed, skipped
end

--- Place a single pipe ghost.
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param entity_name string Pipe prototype name
--- @param position table {x, y}
--- @param quality string Quality name
--- @param polite boolean|nil Polite mode flag
--- @return number placed 1 if placed, 0 if not
--- @return number skipped 1 if skipped, 0 if not
function pipe_placer._place_ghost(surface, force, player, entity_name, position, quality, polite)
    local _, was_placed = ghost_util.place_ghost(
        surface, force, player, entity_name, position, nil, quality, nil, polite)
    if was_placed then
        return 1, 0
    end
    return 0, 1
end

return pipe_placer
