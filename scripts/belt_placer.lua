-- Belt Placer - Places ghost transport belts between paired miner rows
--
-- With gap=2 between paired drill rows, there are two tile columns (or rows)
-- in the gap. Both get transport belts running in the same direction.
-- The drills on each side output directly onto the adjacent belt tile.
--
-- For NS orientation (belt runs north-south):
--   [Drill =>] [Belt v] [Belt v] [<= Drill]
--   Left drills output east onto the left belt column
--   Right drills output west onto the right belt column
--
-- For EW orientation (belt runs east-west):
--   Same concept rotated 90 degrees.

local belt_placer = {}

--- Place ghost transport belts along the gap between paired drill rows.
--- @param surface LuaSurface The game surface
--- @param force string Force name for ghost placement
--- @param player LuaPlayer The player requesting placement
--- @param belt_lines table Array of belt line metadata from calculator
--- @param drill_info table Drill info (width, height) for computing belt extent
--- @param belt_name string Transport belt prototype name (e.g., "transport-belt")
--- @param belt_quality string Quality name for belt ghosts
--- @param gap number Gap size between paired rows (from calculator.get_pair_gap())
--- @return number placed Count of belt ghosts placed
--- @return number skipped Count of positions where placement failed
function belt_placer.place(surface, force, player, belt_lines, drill_info, belt_name, belt_quality, gap)
    if not belt_name or belt_name == "" then
        return 0, 0
    end

    -- Validate belt prototype exists
    if not prototypes.entity[belt_name] then
        return 0, 0
    end

    local half_w = drill_info.width / 2
    local half_h = drill_info.height / 2
    local quality = belt_quality or "normal"
    gap = gap or 2

    local placed = 0
    local skipped = 0

    for _, belt_line in ipairs(belt_lines) do
        if belt_line.orientation == "NS" then
            local p, s = belt_placer._place_ns_belts(
                surface, force, player, belt_line, half_h, gap, belt_name, quality)
            placed = placed + p
            skipped = skipped + s
        elseif belt_line.orientation == "EW" then
            local p, s = belt_placer._place_ew_belts(
                surface, force, player, belt_line, half_w, gap, belt_name, quality)
            placed = placed + p
            skipped = skipped + s
        end
    end

    return placed, skipped
end

--- Place belts for a north-south oriented belt line.
--- Belt runs vertically. Two columns of belts in the gap, both going south.
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param belt_line table Belt line metadata from calculator
--- @param half_h number Half the drill height (for computing belt extent along y-axis)
--- @param gap number Gap tiles between drill edges
--- @param belt_name string Belt prototype name
--- @param quality string Quality name
--- @return number placed
--- @return number skipped
function belt_placer._place_ns_belts(surface, force, player, belt_line, half_h, gap, belt_name, quality)
    local belt_direction = defines.direction.south
    local placed = 0
    local skipped = 0

    -- belt_line.x is the center of the gap (between two tile columns)
    -- With gap=2, the two belt tile columns are at x-0.5 and x+0.5
    -- For gap=N, belt tiles span from x - gap/2 + 0.5 to x + gap/2 - 0.5
    local x_center = belt_line.x
    local y_start = math.floor(belt_line.y_min - half_h)
    local y_end = math.ceil(belt_line.y_max + half_h) - 1

    -- Place belts on each gap tile column
    for tile_offset = 0, gap - 1 do
        local x_tile = math.floor(x_center - gap / 2) + tile_offset + 0.5

        for y = y_start, y_end do
            local pos = {x = x_tile, y = y + 0.5}
            local p, s = belt_placer._place_ghost(surface, force, player, belt_name, pos, belt_direction, quality)
            placed = placed + p
            skipped = skipped + s
        end
    end

    return placed, skipped
end

--- Place belts for an east-west oriented belt line.
--- Belt runs horizontally. Two rows of belts in the gap, both going east.
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param belt_line table Belt line metadata from calculator
--- @param half_w number Half the drill width (for computing belt extent along x-axis)
--- @param gap number Gap tiles between drill edges
--- @param belt_name string Belt prototype name
--- @param quality string Quality name
--- @return number placed
--- @return number skipped
function belt_placer._place_ew_belts(surface, force, player, belt_line, half_w, gap, belt_name, quality)
    local belt_direction = defines.direction.east
    local placed = 0
    local skipped = 0

    local y_center = belt_line.y
    local x_start = math.floor(belt_line.x_min - half_w)
    local x_end = math.ceil(belt_line.x_max + half_w) - 1

    -- Place belts on each gap tile row
    for tile_offset = 0, gap - 1 do
        local y_tile = math.floor(y_center - gap / 2) + tile_offset + 0.5

        for x = x_start, x_end do
            local pos = {x = x + 0.5, y = y_tile}
            local p, s = belt_placer._place_ghost(surface, force, player, belt_name, pos, belt_direction, quality)
            placed = placed + p
            skipped = skipped + s
        end
    end

    return placed, skipped
end

--- Place a single ghost entity, checking placement first.
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param entity_name string Prototype name
--- @param position table {x, y}
--- @param direction defines.direction
--- @param quality string Quality name
--- @return number placed 1 if placed, 0 if not
--- @return number skipped 1 if skipped, 0 if not
function belt_placer._place_ghost(surface, force, player, entity_name, position, direction, quality)
    local can_place = surface.can_place_entity({
        name = entity_name,
        position = position,
        direction = direction,
        force = force,
        build_check_type = defines.build_check_type.ghost_place,
    })

    if can_place then
        surface.create_entity({
            name = "entity-ghost",
            inner_name = entity_name,
            position = position,
            direction = direction,
            force = force,
            player = player,
            quality = quality,
        })
        return 1, 0
    end

    return 0, 1
end

return belt_placer
