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
--
-- CRITICAL: Underground Belt Type Setting
-- ========================================
-- When creating underground belt GHOSTS via surface.create_entity(), you MUST pass
-- the 'type' parameter ("input" or "output") during creation. The belt_to_ground_type
-- property is READ-ONLY after creation and cannot be changed.
--
-- Example:
--   surface.create_entity{name = "entity-ghost", inner_name = "underground-belt",
--                         type = "output", direction = south, ...}
--
-- DO NOT try to use ghost.rotate() after creation - it changes the belt_to_ground_type
-- property value but does NOT update the ghost's visual sprite or functional behavior.

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

--- Calculate the opposite direction (180 degree rotation).
--- @param direction defines.direction
--- @return defines.direction
local function opposite_direction(direction)
    if direction == defines.direction.north then return defines.direction.south end
    if direction == defines.direction.south then return defines.direction.north end
    if direction == defines.direction.east then return defines.direction.west end
    if direction == defines.direction.west then return defines.direction.east end
    return defines.direction.north
end

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
--- @param polite boolean|nil When true, respect polite placement
--- @return number placed Count of belt ghosts placed
--- @return number skipped Count of positions where placement failed
function belt_placer.place(surface, force, player, belt_lines, drill_info, belt_name, belt_quality, gap, belt_direction, polite)
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
                underground_name, belt_name, quality, belt_dir_define, belt_direction, polite)
        else
            p, s = belt_placer._place_plain_belts(
                surface, force, player, belt_line, drill_info,
                belt_name, quality, belt_dir_define, polite)
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
--- @param polite boolean|nil Polite mode flag
--- @return number placed
--- @return number skipped
function belt_placer._place_plain_belts(surface, force, player, belt_line, drill_info, belt_name, quality, belt_dir_define, polite)
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
                surface, force, player, belt_name, pos, belt_dir_define, quality, polite)
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
                surface, force, player, belt_name, pos, belt_dir_define, quality, polite)
            placed = placed + p
            skipped = skipped + s
        end
    end

    return placed, skipped
end

--- Place underground belts for 3x3+ drills.
--- For each drill along the belt line, places underground belt pairs:
---   - First drill: only UBI (entrance to underground section)
---   - Subsequent drills: UBI (entrance to next section) then UBO (exit from previous section)
--- The 1-tile gap between drill pairs is left free for poles.
---
--- CRITICAL: Underground belt input/output type must be specified during creation.
--- Both UBI and UBO face the same direction (belt flow direction) for proper auto-connection.
--- UBI is created with type="input", UBO is created with type="output".
--- The belt_to_ground_type property is read-only and cannot be changed after creation.
---
--- For NS orientation (belt flows south):
---   First drill: only UBI at drill_center_y (type="input")
---   Subsequent drills: UBI at drill_center_y (type="input"), UBO at drill_center_y - 1 (type="output")
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
--- @param polite boolean|nil Polite mode flag
--- @return number placed
--- @return number skipped
function belt_placer._place_underground_belts(surface, force, player, belt_line, drill_info, underground_name, belt_name, quality, belt_dir_define, belt_direction, polite)
    local placed = 0
    local skipped = 0

    -- Both UBI (entrance/input) and UBO (exit/output) face the same direction (belt flow direction).
    -- This allows Factorio's auto-connection system to properly pair them.
    -- The belt_to_ground_type parameter ("input"/"output") determines which sprite is shown:
    --   - "input" uses UndergroundBeltPrototype.structure.direction_in (entrance visual)
    --   - "output" uses UndergroundBeltPrototype.structure.direction_out (exit visual)
    -- For a south-flowing belt: both UBI and UBO have direction=south
    -- For a north-flowing belt: both UBI and UBO have direction=north
    -- For an east-flowing belt: both UBI and UBO have direction=east
    -- For a west-flowing belt: both UBI and UBO have direction=west
    local ubi_dir = belt_dir_define
    local ubo_dir = belt_dir_define

    local drill_positions = belt_line.drill_along_positions or {}

    if belt_line.orientation == "NS" then
        local x = belt_line.x
        -- Positions are sorted ascending. For south flow, first in flow = index 1.
        -- For north flow, first in flow = last index (largest y = southernmost).
        local first_in_flow = (belt_direction == "south") and 1 or #drill_positions

        for drill_index, drill_center in ipairs(drill_positions) do
            -- drill_center is the y-position of the drill center
            -- First drill in flow: only UBI (entrance to underground section)
            -- Subsequent drills: UBO (exit from previous section) then UBI (entrance to next section)
            local ubi_y, ubo_y
            if belt_direction == "south" then
                ubo_y = drill_center - 1
                ubi_y = drill_center
            else
                ubo_y = drill_center + 1
                ubi_y = drill_center
            end

            -- Place UBI (entrance) for all drills
            local ubi_pos = {x = x, y = ubi_y}
            local ubi_ghost, p, s = belt_placer._place_underground_ghost(
                surface, force, player, underground_name, ubi_pos, ubi_dir, quality, "input", polite)
            placed = placed + p
            skipped = skipped + s

            -- Place UBO (exit) for all drills except the first in flow direction
            if drill_index ~= first_in_flow then
                local ubo_pos = {x = x, y = ubo_y}
                local ubo_ghost, p2, s2 = belt_placer._place_underground_ghost(
                    surface, force, player, underground_name, ubo_pos, ubo_dir, quality, "output", polite)

                placed = placed + p2
                skipped = skipped + s2
            end
        end
    else -- EW
        local y = belt_line.y
        -- Positions are sorted ascending. For east flow, first in flow = index 1.
        -- For west flow, first in flow = last index (largest x = rightmost).
        local first_in_flow = (belt_direction == "east") and 1 or #drill_positions

        for drill_index, drill_center in ipairs(drill_positions) do
            -- drill_center is the x-position of the drill center
            -- First drill in flow: only UBI (entrance to underground section)
            -- Subsequent drills: UBO (exit from previous section) then UBI (entrance to next section)
            local ubi_x, ubo_x
            if belt_direction == "east" then
                ubo_x = drill_center - 1
                ubi_x = drill_center
            else
                ubo_x = drill_center + 1
                ubi_x = drill_center
            end

            -- Place UBI (entrance) for all drills
            local ubi_pos = {x = ubi_x, y = y}
            local ubi_ghost, p, s = belt_placer._place_underground_ghost(
                surface, force, player, underground_name, ubi_pos, ubi_dir, quality, "input", polite)
            placed = placed + p
            skipped = skipped + s

            -- Place UBO (exit) for all drills except the first in flow direction
            if drill_index ~= first_in_flow then
                local ubo_pos = {x = ubo_x, y = y}
                local ubo_ghost, p2, s2 = belt_placer._place_underground_ghost(
                    surface, force, player, underground_name, ubo_pos, ubo_dir, quality, "output", polite)

                placed = placed + p2
                skipped = skipped + s2
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
--- @param polite boolean|nil Polite mode flag
--- @return number placed 1 if placed, 0 if not
--- @return number skipped 1 if skipped, 0 if not
function belt_placer._place_ghost(surface, force, player, entity_name, position, direction, quality, polite)
    local _, was_placed = ghost_util.place_ghost(
        surface, force, player, entity_name, position, direction, quality, nil, polite)
    if was_placed then
        return 1, 0
    end
    return 0, 1
end

--- Derive splitter prototype name from a transport belt name.
--- Factorio convention: "transport-belt" -> "splitter"
---                      "fast-transport-belt" -> "fast-splitter"
--- @param belt_name string Transport belt prototype name
--- @return string|nil Splitter prototype name, or nil if not found
function belt_placer._get_splitter_name(belt_name)
    local splitter_name = string.gsub(belt_name, "transport%-belt", "splitter")
    if prototypes.entity[splitter_name] then
        return splitter_name
    end
    return nil
end

--- Place a single splitter ghost entity.
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param splitter_name string Splitter prototype name
--- @param position table {x, y}
--- @param direction defines.direction
--- @param quality string Quality name
--- @param polite boolean|nil Polite mode flag
--- @return number placed 1 if placed, 0 if not
--- @return number skipped 1 if skipped, 0 if not
function belt_placer._place_splitter_ghost(surface, force, player, splitter_name, position, direction, quality, polite)
    local _, was_placed = ghost_util.place_ghost(
        surface, force, player, splitter_name, position, direction, quality, nil, polite)
    if was_placed then
        return 1, 0
    end
    return 0, 1
end

--- Place the 2-column belt layout for 5x5+ drills in productive substation mode.
--- Uses a 2-tile gap between paired drill columns. Layout per drill (NS south flow):
---   Col1(left)  Col2(right)
---   [UBO]       [UBO]         <- exits from previous underground (skip for first drill)
---   [Splitter spans both]     <- catches ore from both drills, splits to two output lines
---   [UBI]       [UBI]         <- entrances to next underground (two parallel belt lines)
---
--- This gives two parallel belt output lines for doubled throughput.
--- Remaining tiles in each drill zone are empty (substations placed by pole_placer).
---
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param belt_lines table Array of belt line metadata from calculator
--- @param drill_info table Drill info (width, height)
--- @param belt_name string Transport belt prototype name
--- @param belt_quality string Quality name
--- @param belt_dir_define defines.direction Belt flow direction define
--- @param belt_direction string "north", "south", "east", or "west"
--- @param polite boolean|nil Polite mode flag
--- @return number placed Total belt/splitter ghosts placed
--- @return number skipped Total positions skipped
function belt_placer._place_substation_5x5_belts(surface, force, player, belt_lines, drill_info, belt_name, belt_quality, belt_dir_define, belt_direction, polite)
    local placed = 0
    local skipped = 0

    local quality = belt_quality or "normal"
    local underground_name = belt_placer._get_underground_name(belt_name)
    local splitter_name = belt_placer._get_splitter_name(belt_name)

    if not underground_name then return 0, 0 end

    -- Layout per drill (south flow example):
    --   1. Splitter at drill_center — catches ore from both left+right drills
    --   2. UBO col1 + UBO col2 at drill_center - 1 — exits from previous underground (skip for first drill)
    --   3. UBI col1 + UBI col2 at drill_center + 1 — entrances to next underground
    --   Remaining tiles in drill zone are empty (substations placed by pole_placer)
    --
    -- The splitter splits output evenly to col1 and col2, giving two parallel belt lines.

    for _, belt_line in ipairs(belt_lines) do
        local drill_positions = belt_line.drill_along_positions or {}
        if #drill_positions == 0 then goto continue_belt_line end

        if belt_line.orientation == "NS" then
            local col1_x = belt_line.x - 0.5
            local col2_x = belt_line.x + 0.5
            local first_in_flow = (belt_direction == "south") and 1 or #drill_positions

            for drill_index, drill_center in ipairs(drill_positions) do
                local ubo_along, splitter_along, ubi_along

                if belt_direction == "south" then
                    ubo_along = drill_center - 1
                    splitter_along = drill_center
                    ubi_along = drill_center + 1
                else -- north
                    ubo_along = drill_center + 1
                    splitter_along = drill_center
                    ubi_along = drill_center - 1
                end

                -- 1. Splitter at drill center (catches ore from both drills)
                local p, s
                if splitter_name then
                    p, s = belt_placer._place_splitter_ghost(
                        surface, force, player, splitter_name,
                        {x = belt_line.x, y = splitter_along}, belt_dir_define, quality, polite)
                    placed = placed + p
                    skipped = skipped + s
                end

                -- 2. UBO in both columns before splitter (skip for first drill in flow direction)
                if drill_index ~= first_in_flow then
                    _, p, s = belt_placer._place_underground_ghost(
                        surface, force, player, underground_name,
                        {x = col1_x, y = ubo_along}, belt_dir_define, quality, "output", polite)
                    placed = placed + p
                    skipped = skipped + s

                    _, p, s = belt_placer._place_underground_ghost(
                        surface, force, player, underground_name,
                        {x = col2_x, y = ubo_along}, belt_dir_define, quality, "output", polite)
                    placed = placed + p
                    skipped = skipped + s
                end

                -- 3. UBI in both columns after splitter
                _, p, s = belt_placer._place_underground_ghost(
                    surface, force, player, underground_name,
                    {x = col1_x, y = ubi_along}, belt_dir_define, quality, "input", polite)
                placed = placed + p
                skipped = skipped + s

                _, p, s = belt_placer._place_underground_ghost(
                    surface, force, player, underground_name,
                    {x = col2_x, y = ubi_along}, belt_dir_define, quality, "input", polite)
                placed = placed + p
                skipped = skipped + s
            end

        else -- EW orientation
            local col1_y = belt_line.y - 0.5
            local col2_y = belt_line.y + 0.5
            local first_in_flow = (belt_direction == "east") and 1 or #drill_positions

            for drill_index, drill_center in ipairs(drill_positions) do
                local ubo_along, splitter_along, ubi_along

                if belt_direction == "east" then
                    ubo_along = drill_center - 1
                    splitter_along = drill_center
                    ubi_along = drill_center + 1
                else -- west
                    ubo_along = drill_center + 1
                    splitter_along = drill_center
                    ubi_along = drill_center - 1
                end

                -- 1. Splitter at drill center
                local p, s
                if splitter_name then
                    p, s = belt_placer._place_splitter_ghost(
                        surface, force, player, splitter_name,
                        {x = splitter_along, y = belt_line.y}, belt_dir_define, quality, polite)
                    placed = placed + p
                    skipped = skipped + s
                end

                -- 2. UBO in both columns before splitter (skip for first drill in flow direction)
                if drill_index ~= first_in_flow then
                    _, p, s = belt_placer._place_underground_ghost(
                        surface, force, player, underground_name,
                        {x = ubo_along, y = col1_y}, belt_dir_define, quality, "output", polite)
                    placed = placed + p
                    skipped = skipped + s

                    _, p, s = belt_placer._place_underground_ghost(
                        surface, force, player, underground_name,
                        {x = ubo_along, y = col2_y}, belt_dir_define, quality, "output", polite)
                    placed = placed + p
                    skipped = skipped + s
                end

                -- 3. UBI in both columns after splitter
                _, p, s = belt_placer._place_underground_ghost(
                    surface, force, player, underground_name,
                    {x = ubi_along, y = col1_y}, belt_dir_define, quality, "input", polite)
                placed = placed + p
                skipped = skipped + s

                _, p, s = belt_placer._place_underground_ghost(
                    surface, force, player, underground_name,
                    {x = ubi_along, y = col2_y}, belt_dir_define, quality, "input", polite)
                placed = placed + p
                skipped = skipped + s
            end
        end

        ::continue_belt_line::
    end

    return placed, skipped
end

--- Place a single underground belt ghost with specified input/output type.
--- CRITICAL: Underground belt type must be set during creation via the 'type' parameter.
--- The belt_to_ground_type property is read-only after creation.
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param entity_name string Underground belt prototype name
--- @param position table {x, y}
--- @param direction defines.direction
--- @param quality string Quality name
--- @param belt_type string "input" or "output" - REQUIRED for underground belts
--- @param polite boolean|nil Polite mode flag
--- @return LuaEntity|nil ghost The created ghost entity, or nil if placement failed
--- @return number placed 1 if placed, 0 if not
--- @return number skipped 1 if skipped, 0 if not
function belt_placer._place_underground_ghost(surface, force, player, entity_name, position, direction, quality, belt_type, polite)
    local extra_params = belt_type and {type = belt_type} or nil
    local ghost, was_placed = ghost_util.place_ghost(
        surface, force, player, entity_name, position, direction, quality,
        extra_params, polite)
    if was_placed then
        return ghost, 1, 0
    end
    return nil, 0, 1
end

return belt_placer
