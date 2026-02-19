-- Belt Placer - Places ghost transport belts and underground belts between paired miner rows
--
-- Gap is always 1 tile between paired drill columns/rows.
--
-- Pattern 1 (2x2 drills): Plain transport belts fill the entire belt column.
--   [Drill =>] [Belt] [<= Drill]
--   [Drill =>] [Belt] [<= Drill]
--        [Pole] [Belt] [Pole]
--
-- Pattern 2 (3x3+ drills): Underground belts connect drill outputs to the
-- center column. UBI at drill center (output), UBO one tile before in flow
-- direction. The 1-tile gap between drill pairs is reserved for poles.
--   [Drill =>] [UBO]  [<= Drill]
--   [Drill =>] [UBI]  [<= Drill]
--   [Drill =>] [Pole] [<= Drill]

local ghost_util = require("scripts.ghost_util")

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

--- Map a belt direction string to a Factorio defines.direction value.
--- @param belt_direction string "north", "south", "east", or "west"
--- @return defines.direction
local function direction_to_define(belt_direction)
    if belt_direction == "north" then return defines.direction.north end
    if belt_direction == "south" then return defines.direction.south end
    if belt_direction == "east" then return defines.direction.east end
    if belt_direction == "west" then return defines.direction.west end
    return defines.direction.south
end

--- Return the opposite direction (rotated 180 degrees).
--- @param dir defines.direction
--- @return defines.direction
local opposite_direction = {
    [defines.direction.north] = defines.direction.south,
    [defines.direction.south] = defines.direction.north,
    [defines.direction.east] = defines.direction.west,
    [defines.direction.west] = defines.direction.east,
}

--- Place ghost transport belts along the gap between paired drill rows.
--- For 2x2 drills: plain belts fill the belt column.
--- For 3x3+ drills: underground belts (UBI/UBO) at drill output positions.
--- @param surface LuaSurface The game surface
--- @param force string Force name for ghost placement
--- @param player LuaPlayer The player requesting placement
--- @param belt_lines table Array of belt line metadata from calculator
--- @param drill_info table Drill info (width, height) for computing belt extent
--- @param belt_name string Transport belt prototype name (e.g., "transport-belt")
--- @param belt_quality string Quality name for belt ghosts
--- @param gap number Gap size between paired rows (always 1)
--- @param belt_direction string|nil "north", "south", "east", or "west" (belt flow direction)
--- @return number placed Count of belt ghosts placed
--- @return number skipped Count of positions where placement failed
function belt_placer.place(surface, force, player, belt_lines, drill_info, belt_name, belt_quality, gap, belt_direction)
    if not belt_name or belt_name == "" then
        return 0, 0
    end

    -- Validate belt prototype exists
    if not prototypes.entity[belt_name] then
        return 0, 0
    end

    local quality = belt_quality or "normal"
    belt_direction = belt_direction or "south"

    local belt_dir_define = direction_to_define(belt_direction)

    -- Determine if we use underground belts (3x3+ drills) or plain belts (2x2)
    -- Use the larger dimension to decide - if drill is bigger than 2x2, use underground
    local body_max = math.max(drill_info.width, drill_info.height)
    local use_underground = body_max >= 3
    local underground_name = nil
    if use_underground then
        underground_name = belt_placer._get_underground_name(belt_name)
        if not underground_name then
            use_underground = false
        end
    end

    local placed = 0
    local skipped = 0

    for _, belt_line in ipairs(belt_lines) do
        local p, s
        if use_underground then
            p, s = belt_placer._place_underground_belts(
                surface, force, player, belt_line, drill_info,
                underground_name, belt_name, quality, belt_dir_define, belt_direction)
        else
            p, s = belt_placer._place_plain_belts(
                surface, force, player, belt_line, drill_info,
                belt_name, quality, belt_dir_define)
        end
        placed = placed + p
        skipped = skipped + s
    end

    return placed, skipped
end

--- Place plain transport belts for 2x2 drills.
--- Fills the entire belt column from first drill top to last drill bottom.
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param belt_line table Belt line metadata from calculator
--- @param drill_info table Drill info (width, height)
--- @param belt_name string Belt prototype name
--- @param quality string Quality name
--- @param belt_dir_define defines.direction Belt flow direction
--- @return number placed
--- @return number skipped
function belt_placer._place_plain_belts(surface, force, player, belt_line, drill_info, belt_name, quality, belt_dir_define)
    local placed = 0
    local skipped = 0

    if belt_line.orientation == "NS" then
        local x = belt_line.x
        local half_h = drill_info.height / 2
        local y_start = math.floor(belt_line.y_min - half_h)
        local y_end = math.ceil(belt_line.y_max + half_h) - 1

        for y = y_start, y_end do
            local pos = {x = x, y = y + 0.5}
            local p, s = belt_placer._place_ghost(
                surface, force, player, belt_name, pos, belt_dir_define, quality)
            placed = placed + p
            skipped = skipped + s
        end
    else -- EW
        local y = belt_line.y
        local half_w = drill_info.width / 2
        local x_start = math.floor(belt_line.x_min - half_w)
        local x_end = math.ceil(belt_line.x_max + half_w) - 1

        for x = x_start, x_end do
            local pos = {x = x + 0.5, y = y}
            local p, s = belt_placer._place_ghost(
                surface, force, player, belt_name, pos, belt_dir_define, quality)
            placed = placed + p
            skipped = skipped + s
        end
    end

    return placed, skipped
end

--- Place underground belts for 3x3+ drills.
--- For each drill along the belt line, places UBI at the drill's output
--- position (center) and UBO one tile before UBI in the belt flow direction.
--- The 1-tile gap between drill pairs is left free for poles.
---
--- For NS orientation (belt flows south):
---   UBO at drill_center_y - 1 (one tile north of center)
---   UBI at drill_center_y (center of drill body = output position)
---   Remaining rows in drill body left free for poles
---
--- For belt flowing north, UBO/UBI positions are mirrored.
---
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param belt_line table Belt line metadata from calculator
--- @param drill_info table Drill info (width, height)
--- @param underground_name string Underground belt prototype name
--- @param belt_name string Regular belt prototype name (unused but kept for consistency)
--- @param quality string Quality name
--- @param belt_dir_define defines.direction Belt flow direction
--- @param belt_direction string "north", "south", "east", or "west"
--- @return number placed
--- @return number skipped
function belt_placer._place_underground_belts(surface, force, player, belt_line, drill_info, underground_name, belt_name, quality, belt_dir_define, belt_direction)
    local placed = 0
    local skipped = 0

    -- UBI (entrance/input) faces the belt flow direction.
    -- UBO (exit/output) faces the opposite direction (rotated 180 degrees)
    -- so the underground pair connects properly.
    local ubi_dir = belt_dir_define
    local ubo_dir = opposite_direction[belt_dir_define]

    local drill_positions = belt_line.drill_along_positions or {}

    if belt_line.orientation == "NS" then
        local x = belt_line.x

        for _, drill_center in ipairs(drill_positions) do
            -- drill_center is the y-position of the drill center
            -- UBI at center (output position), UBO one tile before in flow direction
            local ubi_y, ubo_y
            if belt_direction == "south" then
                -- Belt flows south: UBI at center, UBO one tile north (before)
                ubo_y = drill_center - 1
                ubi_y = drill_center
            else
                -- Belt flows north: UBI at center, UBO one tile south (before)
                ubo_y = drill_center + 1
                ubi_y = drill_center
            end

            -- Place UBO (exit) - note: Factorio underground belt exit has type "output"
            local ubo_pos = {x = x, y = ubo_y}
            local p, s = belt_placer._place_underground_ghost(
                surface, force, player, underground_name, ubo_pos, ubo_dir, quality, "output")
            placed = placed + p
            skipped = skipped + s

            -- Place UBI (entrance) - has type "input"
            local ubi_pos = {x = x, y = ubi_y}
            p, s = belt_placer._place_underground_ghost(
                surface, force, player, underground_name, ubi_pos, ubi_dir, quality, "input")
            placed = placed + p
            skipped = skipped + s
        end
    else -- EW
        local y = belt_line.y

        for _, drill_center in ipairs(drill_positions) do
            -- drill_center is the x-position of the drill center
            local ubi_x, ubo_x
            if belt_direction == "east" then
                -- Belt flows east: UBI at center, UBO one tile west (before)
                ubo_x = drill_center - 1
                ubi_x = drill_center
            else
                -- Belt flows west: UBI at center, UBO one tile east (before)
                ubo_x = drill_center + 1
                ubi_x = drill_center
            end

            -- Place UBO (exit)
            local ubo_pos = {x = ubo_x, y = y}
            local p, s = belt_placer._place_underground_ghost(
                surface, force, player, underground_name, ubo_pos, ubo_dir, quality, "output")
            placed = placed + p
            skipped = skipped + s

            -- Place UBI (entrance)
            local ubi_pos = {x = ubi_x, y = y}
            p, s = belt_placer._place_underground_ghost(
                surface, force, player, underground_name, ubi_pos, ubi_dir, quality, "input")
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
    local _, was_placed = ghost_util.place_ghost(
        surface, force, player, entity_name, position, direction, quality)
    if was_placed then
        return 1, 0
    end
    return 0, 1
end

--- Place a single underground belt ghost with input/output type.
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param entity_name string Underground belt prototype name
--- @param position table {x, y}
--- @param direction defines.direction
--- @param quality string Quality name
--- @param belt_to_ground_type string "input" or "output"
--- @return number placed 1 if placed, 0 if not
--- @return number skipped 1 if skipped, 0 if not
function belt_placer._place_underground_ghost(surface, force, player, entity_name, position, direction, quality, belt_to_ground_type)
    local _, was_placed = ghost_util.place_ghost(
        surface, force, player, entity_name, position, direction, quality,
        {belt_to_ground_type = belt_to_ground_type})
    if was_placed then
        return 1, 0
    end
    return 0, 1
end

return belt_placer
