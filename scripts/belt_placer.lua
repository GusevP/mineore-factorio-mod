-- Belt Placer - Places ghost transport belts between paired miner rows
--
-- Layout patterns based on drill body size (gap = drill body size in across direction):
--
-- Pattern 1 (2x2 drills, gap=2): Plain transport belts on both gap rows
--   [Drill =>] [Belt v] [Belt v] [<= Drill]
--
-- Pattern 3 (3x3 drills, gap=3): Belts on outer rows, middle free for poles
--   [Drill =>] [Belt v] [Pole slot] [Belt v] [<= Drill]
--   Drills drop items onto the adjacent gap tile (outer row), middle is free.
--
-- Pattern 4 (5x5+ drills, gap=body_size): Belts on outer rows, middle free
--   [Drill =>] [Belt v] [free] ... [free] [Belt v] [<= Drill]

local belt_placer = {}

--- Derive underground belt prototype name from a transport belt name.
--- Factorio convention: "transport-belt" -> "underground-belt"
---                      "fast-transport-belt" -> "fast-underground-belt"
--- @param belt_name string Transport belt prototype name
--- @return string|nil Underground belt prototype name, or nil if not found
function belt_placer._get_underground_name(belt_name)
    local underground_name = string.gsub(belt_name, "transport%-belt", "underground-belt")
    if prototypes.entity[underground_name] then
        return underground_name
    end
    return nil
end

--- Determine what to place on each gap row/column.
--- @param gap number Gap size in tiles
--- @return table Array of {offset, type} where type is "belt" or "free"
function belt_placer._get_gap_layout(gap)
    if gap <= 2 then
        -- Pattern 1: all columns get plain belts
        local layout = {}
        for i = 0, gap - 1 do
            layout[#layout + 1] = {offset = i, type = "belt"}
        end
        return layout
    end

    -- Pattern 3/4: outer columns get belts, middle is free (for poles)
    local layout = {}
    for i = 0, gap - 1 do
        if i == 0 or i == gap - 1 then
            layout[#layout + 1] = {offset = i, type = "belt"}
        else
            layout[#layout + 1] = {offset = i, type = "free"}
        end
    end
    return layout
end

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
--- Belt runs vertically. Columns in the gap get belts or are left free based on layout pattern.
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

    local x_center = belt_line.x
    local y_start = math.floor(belt_line.y_min - half_h)
    local y_end = math.ceil(belt_line.y_max + half_h) - 1

    local layout = belt_placer._get_gap_layout(gap)

    for _, slot in ipairs(layout) do
        if slot.type == "belt" then
            local x_tile = math.floor(x_center - gap / 2) + slot.offset + 0.5

            for y = y_start, y_end do
                local pos = {x = x_tile, y = y + 0.5}
                local p, s = belt_placer._place_ghost(
                    surface, force, player, belt_name, pos, belt_direction, quality)
                placed = placed + p
                skipped = skipped + s
            end
        end
    end

    return placed, skipped
end

--- Place belts for an east-west oriented belt line.
--- Belt runs horizontally. Rows in the gap get belts or are left free based on layout pattern.
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

    local layout = belt_placer._get_gap_layout(gap)

    for _, slot in ipairs(layout) do
        if slot.type == "belt" then
            local y_tile = math.floor(y_center - gap / 2) + slot.offset + 0.5

            for x = x_start, x_end do
                local pos = {x = x + 0.5, y = y_tile}
                local p, s = belt_placer._place_ghost(
                    surface, force, player, belt_name, pos, belt_direction, quality)
                placed = placed + p
                skipped = skipped + s
            end
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
