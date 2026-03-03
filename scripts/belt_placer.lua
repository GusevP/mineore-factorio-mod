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
--- @param pole_position_sets table|nil Per-belt-line pole positions {[belt_line_index] = {[drill_index]=true}}
--- @return number placed Count of belt ghosts placed
--- @return number skipped Count of positions where placement failed
function belt_placer.place(surface, force, player, belt_lines, drill_info, belt_name, belt_quality, gap, belt_direction, polite, pole_position_sets)
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

    for i, belt_line in ipairs(belt_lines) do
        local p, s
        if use_underground then
            local pole_positions = pole_position_sets and pole_position_sets[i] or nil
            p, s = belt_placer._place_underground_belts(
                surface, force, player, belt_line, drill_info,
                underground_name, belt_name, quality, belt_dir_define, belt_direction, polite, pole_positions)
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

--- Place belts for 3x3+ drills using adaptive placement.
--- When pole_positions is provided, uses a state machine to place underground belts
--- only where poles occupy the gap, and transport belts everywhere else.
--- When pole_positions is nil or empty, places all transport belts (no underground needed).
---
--- State machine logic (iterates in flow direction):
---   First drill: if has pole -> UBI at center; if no pole -> belt at center + belt at gap
---   Subsequent drills:
---     UBO position: if last_had_ubi -> UBO (exit); else -> belt
---     Center: if has pole -> UBI (entrance); else -> belt
---     Gap: if has pole -> skip (pole_placer handles); else -> belt
---
--- CRITICAL: Underground belt input/output type must be specified during creation.
--- Both UBI and UBO face the same direction (belt flow direction) for proper auto-connection.
---
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param belt_line table Belt line metadata from calculator
--- @param drill_info table Drill info (width, height)
--- @param underground_name string Underground belt prototype name
--- @param belt_name string Regular belt prototype name (used for surface belt sections)
--- @param quality string Quality name
--- @param belt_dir_define defines.direction Belt flow direction
--- @param belt_direction string "north", "south", "east", or "west"
--- @param polite boolean|nil Polite mode flag
--- @param pole_positions table|nil Set of drill indices with poles {[index]=true}, nil/empty = all belts
--- @return number placed
--- @return number skipped
function belt_placer._place_underground_belts(surface, force, player, belt_line, drill_info, underground_name, belt_name, quality, belt_dir_define, belt_direction, polite, pole_positions)
    local placed = 0
    local skipped = 0

    local drill_positions = belt_line.drill_along_positions or {}
    if #drill_positions == 0 then
        return 0, 0
    end

    -- Both UBI and UBO face the same direction (belt flow direction)
    local ubi_dir = belt_dir_define
    local ubo_dir = belt_dir_define

    -- Check if any poles exist in the position set
    local has_any_poles = false
    if pole_positions then
        for _ in pairs(pole_positions) do
            has_any_poles = true
            break
        end
    end

    if belt_line.orientation == "NS" then
        local x = belt_line.x

        -- Build iteration order: state machine requires flow direction order
        local order = {}
        if belt_direction == "south" then
            for i = 1, #drill_positions do order[#order + 1] = i end
        else -- north
            for i = #drill_positions, 1, -1 do order[#order + 1] = i end
        end

        local last_had_ubi = false

        for iter_idx, drill_index in ipairs(order) do
            local drill_center = drill_positions[drill_index]
            local has_pole = has_any_poles and pole_positions[drill_index]
            local is_first = (iter_idx == 1)
            local is_last = (iter_idx == #order)

            -- ubo_y: upstream of drill center (where UBO exits previous underground)
            -- ubi_y: at drill center (where UBI enters next underground)
            -- gap_y: downstream of drill center (where pole goes, or belt if no pole)
            local ubo_y, ubi_y, gap_y
            if belt_direction == "south" then
                ubo_y = drill_center - 1
                ubi_y = drill_center
                gap_y = drill_center + 1
            else
                ubo_y = drill_center + 1
                ubi_y = drill_center
                gap_y = drill_center - 1
            end

            if is_first then
                -- First drill in flow: no UBO position
                if has_pole then
                    -- UBI at drill center (entrance to underground to pass under pole)
                    local _, p, s = belt_placer._place_underground_ghost(
                        surface, force, player, underground_name,
                        {x = x, y = ubi_y}, ubi_dir, quality, "input", polite)
                    placed = placed + p
                    skipped = skipped + s
                    last_had_ubi = true
                    -- Gap: pole_placer handles this position
                else
                    -- Transport belt at drill center
                    local p, s = belt_placer._place_ghost(
                        surface, force, player, belt_name,
                        {x = x, y = ubi_y}, belt_dir_define, quality, polite)
                    placed = placed + p
                    skipped = skipped + s
                    -- Transport belt at gap position
                    p, s = belt_placer._place_ghost(
                        surface, force, player, belt_name,
                        {x = x, y = gap_y}, belt_dir_define, quality, polite)
                    placed = placed + p
                    skipped = skipped + s
                    last_had_ubi = false
                end
            else
                -- Subsequent drills: handle UBO/belt, center, and gap positions

                -- 1. UBO/belt position (upstream of drill center)
                if last_had_ubi then
                    -- UBO exits the underground section from previous UBI
                    local _, p, s = belt_placer._place_underground_ghost(
                        surface, force, player, underground_name,
                        {x = x, y = ubo_y}, ubo_dir, quality, "output", polite)
                    placed = placed + p
                    skipped = skipped + s
                    last_had_ubi = false
                else
                    -- Surface transport belt
                    local p, s = belt_placer._place_ghost(
                        surface, force, player, belt_name,
                        {x = x, y = ubo_y}, belt_dir_define, quality, polite)
                    placed = placed + p
                    skipped = skipped + s
                end

                -- 2. Drill center position
                if has_pole then
                    -- UBI at drill center (entrance to underground to pass under pole)
                    local _, p, s = belt_placer._place_underground_ghost(
                        surface, force, player, underground_name,
                        {x = x, y = ubi_y}, ubi_dir, quality, "input", polite)
                    placed = placed + p
                    skipped = skipped + s
                    last_had_ubi = true
                else
                    -- Surface transport belt
                    local p, s = belt_placer._place_ghost(
                        surface, force, player, belt_name,
                        {x = x, y = ubi_y}, belt_dir_define, quality, polite)
                    placed = placed + p
                    skipped = skipped + s
                    -- last_had_ubi stays false
                end

                -- 3. Gap position (downstream of drill center)
                if has_pole then
                    -- Skip: pole_placer puts the pole here
                else
                    -- Surface transport belt
                    local p, s = belt_placer._place_ghost(
                        surface, force, player, belt_name,
                        {x = x, y = gap_y}, belt_dir_define, quality, polite)
                    placed = placed + p
                    skipped = skipped + s
                end
            end

            -- 4. Fill inter-drill gap tiles when items travel on surface
            -- For 4x4+ drills, there are unfilled tiles between consecutive drills
            if not is_last and not last_had_ubi then
                local next_drill_index = order[iter_idx + 1]
                local next_center = drill_positions[next_drill_index]

                local fill_y_min, fill_y_max
                if belt_direction == "south" then
                    fill_y_min = gap_y + 1
                    fill_y_max = next_center - 2
                else
                    fill_y_min = next_center + 2
                    fill_y_max = gap_y - 1
                end

                for y = fill_y_min, fill_y_max do
                    local p, s = belt_placer._place_ghost(
                        surface, force, player, belt_name,
                        {x = x, y = y}, belt_dir_define, quality, polite)
                    placed = placed + p
                    skipped = skipped + s
                end
            end
        end

    else -- EW orientation
        local y = belt_line.y

        -- Build iteration order: state machine requires flow direction order
        local order = {}
        if belt_direction == "east" then
            for i = 1, #drill_positions do order[#order + 1] = i end
        else -- west
            for i = #drill_positions, 1, -1 do order[#order + 1] = i end
        end

        local last_had_ubi = false

        for iter_idx, drill_index in ipairs(order) do
            local drill_center = drill_positions[drill_index]
            local has_pole = has_any_poles and pole_positions[drill_index]
            local is_first = (iter_idx == 1)
            local is_last = (iter_idx == #order)

            local ubo_x, ubi_x, gap_x
            if belt_direction == "east" then
                ubo_x = drill_center - 1
                ubi_x = drill_center
                gap_x = drill_center + 1
            else
                ubo_x = drill_center + 1
                ubi_x = drill_center
                gap_x = drill_center - 1
            end

            if is_first then
                if has_pole then
                    local _, p, s = belt_placer._place_underground_ghost(
                        surface, force, player, underground_name,
                        {x = ubi_x, y = y}, ubi_dir, quality, "input", polite)
                    placed = placed + p
                    skipped = skipped + s
                    last_had_ubi = true
                else
                    local p, s = belt_placer._place_ghost(
                        surface, force, player, belt_name,
                        {x = ubi_x, y = y}, belt_dir_define, quality, polite)
                    placed = placed + p
                    skipped = skipped + s
                    p, s = belt_placer._place_ghost(
                        surface, force, player, belt_name,
                        {x = gap_x, y = y}, belt_dir_define, quality, polite)
                    placed = placed + p
                    skipped = skipped + s
                    last_had_ubi = false
                end
            else
                -- 1. UBO/belt position (upstream of drill center)
                if last_had_ubi then
                    local _, p, s = belt_placer._place_underground_ghost(
                        surface, force, player, underground_name,
                        {x = ubo_x, y = y}, ubo_dir, quality, "output", polite)
                    placed = placed + p
                    skipped = skipped + s
                    last_had_ubi = false
                else
                    local p, s = belt_placer._place_ghost(
                        surface, force, player, belt_name,
                        {x = ubo_x, y = y}, belt_dir_define, quality, polite)
                    placed = placed + p
                    skipped = skipped + s
                end

                -- 2. Center position
                if has_pole then
                    local _, p, s = belt_placer._place_underground_ghost(
                        surface, force, player, underground_name,
                        {x = ubi_x, y = y}, ubi_dir, quality, "input", polite)
                    placed = placed + p
                    skipped = skipped + s
                    last_had_ubi = true
                else
                    local p, s = belt_placer._place_ghost(
                        surface, force, player, belt_name,
                        {x = ubi_x, y = y}, belt_dir_define, quality, polite)
                    placed = placed + p
                    skipped = skipped + s
                end

                -- 3. Gap position (downstream of drill center)
                if has_pole then
                    -- Skip: pole_placer handles this position
                else
                    local p, s = belt_placer._place_ghost(
                        surface, force, player, belt_name,
                        {x = gap_x, y = y}, belt_dir_define, quality, polite)
                    placed = placed + p
                    skipped = skipped + s
                end
            end

            -- 4. Fill inter-drill gap tiles when items travel on surface
            if not is_last and not last_had_ubi then
                local next_drill_index = order[iter_idx + 1]
                local next_center = drill_positions[next_drill_index]

                local fill_x_min, fill_x_max
                if belt_direction == "east" then
                    fill_x_min = gap_x + 1
                    fill_x_max = next_center - 2
                else
                    fill_x_min = next_center + 2
                    fill_x_max = gap_x - 1
                end

                for x = fill_x_min, fill_x_max do
                    local p, s = belt_placer._place_ghost(
                        surface, force, player, belt_name,
                        {x = x, y = y}, belt_dir_define, quality, polite)
                    placed = placed + p
                    skipped = skipped + s
                end
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
--- When substation_gap_sets is provided, uses a state machine to optimize belt placement:
--- only places UBI/UBO where substations occupy the inter-drill gap, and fills all other
--- positions (including gap tiles) with transport belts for surface transport.
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
--- @param substation_gap_sets table|nil Per-belt-line gap sets {[bl_index] = {[gap_index]=true}}
--- @return number placed Total belt/splitter ghosts placed
--- @return number skipped Total positions skipped
function belt_placer._place_substation_5x5_belts(surface, force, player, belt_lines, drill_info, belt_name, belt_quality, belt_dir_define, belt_direction, polite, substation_gap_sets)
    local placed = 0
    local skipped = 0

    local quality = belt_quality or "normal"
    local underground_name = belt_placer._get_underground_name(belt_name)
    local splitter_name = belt_placer._get_splitter_name(belt_name)

    if not underground_name then return 0, 0 end

    for bl_idx, belt_line in ipairs(belt_lines) do
        local drill_positions = belt_line.drill_along_positions or {}
        if #drill_positions == 0 then goto continue_belt_line end

        local gap_set = substation_gap_sets and substation_gap_sets[bl_idx] or nil

        if belt_line.orientation == "NS" then
            local col1_x = belt_line.x - 0.5
            local col2_x = belt_line.x + 0.5

            -- Build iteration order in flow direction
            local order = {}
            if belt_direction == "south" then
                for i = 1, #drill_positions do order[#order + 1] = i end
            else -- north
                for i = #drill_positions, 1, -1 do order[#order + 1] = i end
            end

            local last_had_ubi = false

            for iter_idx, drill_index in ipairs(order) do
                local drill_center = drill_positions[drill_index]
                local is_first = (iter_idx == 1)
                local is_last = (iter_idx == #order)

                -- Determine if this drill's downstream gap has a substation
                -- gap_set includes endpoint entries (gap_set[0] and gap_set[#drills])
                -- so last drill correctly detects the endpoint substation
                local downstream_has_sub
                if gap_set == nil then
                    -- No optimization info: old behavior (UBI/UBO at every drill)
                    downstream_has_sub = true
                elseif belt_direction == "south" then
                    downstream_has_sub = gap_set[drill_index] or false
                else
                    downstream_has_sub = gap_set[drill_index - 1] or false
                end

                local ubo_y, splitter_y, ubi_y
                if belt_direction == "south" then
                    ubo_y = drill_center - 1
                    splitter_y = drill_center
                    ubi_y = drill_center + 1
                else
                    ubo_y = drill_center + 1
                    splitter_y = drill_center
                    ubi_y = drill_center - 1
                end

                local p, s, _

                -- 1. UBO/belt position (skip for first drill in flow)
                if not is_first then
                    if last_had_ubi then
                        -- UBO in both columns (exit underground)
                        _, p, s = belt_placer._place_underground_ghost(
                            surface, force, player, underground_name,
                            {x = col1_x, y = ubo_y}, belt_dir_define, quality, "output", polite)
                        placed = placed + p
                        skipped = skipped + s
                        _, p, s = belt_placer._place_underground_ghost(
                            surface, force, player, underground_name,
                            {x = col2_x, y = ubo_y}, belt_dir_define, quality, "output", polite)
                        placed = placed + p
                        skipped = skipped + s
                        last_had_ubi = false
                    else
                        -- Transport belt in both columns
                        p, s = belt_placer._place_ghost(
                            surface, force, player, belt_name,
                            {x = col1_x, y = ubo_y}, belt_dir_define, quality, polite)
                        placed = placed + p
                        skipped = skipped + s
                        p, s = belt_placer._place_ghost(
                            surface, force, player, belt_name,
                            {x = col2_x, y = ubo_y}, belt_dir_define, quality, polite)
                        placed = placed + p
                        skipped = skipped + s
                    end
                end

                -- 2. Splitter at drill center (always placed)
                if splitter_name then
                    p, s = belt_placer._place_splitter_ghost(
                        surface, force, player, splitter_name,
                        {x = belt_line.x, y = splitter_y}, belt_dir_define, quality, polite)
                    placed = placed + p
                    skipped = skipped + s
                end

                -- 3. UBI/belt position (downstream of splitter)
                if downstream_has_sub then
                    -- UBI in both columns (entrance to underground to pass under substation)
                    _, p, s = belt_placer._place_underground_ghost(
                        surface, force, player, underground_name,
                        {x = col1_x, y = ubi_y}, belt_dir_define, quality, "input", polite)
                    placed = placed + p
                    skipped = skipped + s
                    _, p, s = belt_placer._place_underground_ghost(
                        surface, force, player, underground_name,
                        {x = col2_x, y = ubi_y}, belt_dir_define, quality, "input", polite)
                    placed = placed + p
                    skipped = skipped + s
                    last_had_ubi = true
                else
                    -- Transport belt in both columns
                    p, s = belt_placer._place_ghost(
                        surface, force, player, belt_name,
                        {x = col1_x, y = ubi_y}, belt_dir_define, quality, polite)
                    placed = placed + p
                    skipped = skipped + s
                    p, s = belt_placer._place_ghost(
                        surface, force, player, belt_name,
                        {x = col2_x, y = ubi_y}, belt_dir_define, quality, polite)
                    placed = placed + p
                    skipped = skipped + s
                    last_had_ubi = false
                end

                -- 4. Fill inter-drill gap tiles with transport belts when items travel on surface
                -- If last_had_ubi: items underground, gap tiles empty (substation zone)
                -- If not last_had_ubi: fill all gap tiles with belts for surface transport
                if not is_last and not last_had_ubi then
                    local next_drill_index = order[iter_idx + 1]
                    local next_center = drill_positions[next_drill_index]

                    -- Gap tiles between UBI area and next UBO area
                    local gap_y_min, gap_y_max
                    if belt_direction == "south" then
                        gap_y_min = ubi_y + 1
                        gap_y_max = next_center - 2  -- next UBO at next_center - 1
                    else
                        gap_y_min = next_center + 2  -- next UBO at next_center + 1
                        gap_y_max = ubi_y - 1
                    end

                    for y = gap_y_min, gap_y_max do
                        p, s = belt_placer._place_ghost(
                            surface, force, player, belt_name,
                            {x = col1_x, y = y}, belt_dir_define, quality, polite)
                        placed = placed + p
                        skipped = skipped + s
                        p, s = belt_placer._place_ghost(
                            surface, force, player, belt_name,
                            {x = col2_x, y = y}, belt_dir_define, quality, polite)
                        placed = placed + p
                        skipped = skipped + s
                    end
                end
            end

        else -- EW orientation
            local col1_y = belt_line.y - 0.5
            local col2_y = belt_line.y + 0.5

            -- Build iteration order in flow direction
            local order = {}
            if belt_direction == "east" then
                for i = 1, #drill_positions do order[#order + 1] = i end
            else -- west
                for i = #drill_positions, 1, -1 do order[#order + 1] = i end
            end

            local last_had_ubi = false

            for iter_idx, drill_index in ipairs(order) do
                local drill_center = drill_positions[drill_index]
                local is_first = (iter_idx == 1)
                local is_last = (iter_idx == #order)

                -- Determine if this drill's downstream gap has a substation
                local downstream_has_sub
                if gap_set == nil then
                    downstream_has_sub = true
                elseif belt_direction == "east" then
                    downstream_has_sub = gap_set[drill_index] or false
                else
                    downstream_has_sub = gap_set[drill_index - 1] or false
                end

                local ubo_x, splitter_x, ubi_x
                if belt_direction == "east" then
                    ubo_x = drill_center - 1
                    splitter_x = drill_center
                    ubi_x = drill_center + 1
                else
                    ubo_x = drill_center + 1
                    splitter_x = drill_center
                    ubi_x = drill_center - 1
                end

                local p, s, _

                -- 1. UBO/belt position (skip for first drill in flow)
                if not is_first then
                    if last_had_ubi then
                        _, p, s = belt_placer._place_underground_ghost(
                            surface, force, player, underground_name,
                            {x = ubo_x, y = col1_y}, belt_dir_define, quality, "output", polite)
                        placed = placed + p
                        skipped = skipped + s
                        _, p, s = belt_placer._place_underground_ghost(
                            surface, force, player, underground_name,
                            {x = ubo_x, y = col2_y}, belt_dir_define, quality, "output", polite)
                        placed = placed + p
                        skipped = skipped + s
                        last_had_ubi = false
                    else
                        p, s = belt_placer._place_ghost(
                            surface, force, player, belt_name,
                            {x = ubo_x, y = col1_y}, belt_dir_define, quality, polite)
                        placed = placed + p
                        skipped = skipped + s
                        p, s = belt_placer._place_ghost(
                            surface, force, player, belt_name,
                            {x = ubo_x, y = col2_y}, belt_dir_define, quality, polite)
                        placed = placed + p
                        skipped = skipped + s
                    end
                end

                -- 2. Splitter at drill center (always placed)
                if splitter_name then
                    p, s = belt_placer._place_splitter_ghost(
                        surface, force, player, splitter_name,
                        {x = splitter_x, y = belt_line.y}, belt_dir_define, quality, polite)
                    placed = placed + p
                    skipped = skipped + s
                end

                -- 3. UBI/belt position (downstream of splitter)
                if downstream_has_sub then
                    _, p, s = belt_placer._place_underground_ghost(
                        surface, force, player, underground_name,
                        {x = ubi_x, y = col1_y}, belt_dir_define, quality, "input", polite)
                    placed = placed + p
                    skipped = skipped + s
                    _, p, s = belt_placer._place_underground_ghost(
                        surface, force, player, underground_name,
                        {x = ubi_x, y = col2_y}, belt_dir_define, quality, "input", polite)
                    placed = placed + p
                    skipped = skipped + s
                    last_had_ubi = true
                else
                    p, s = belt_placer._place_ghost(
                        surface, force, player, belt_name,
                        {x = ubi_x, y = col1_y}, belt_dir_define, quality, polite)
                    placed = placed + p
                    skipped = skipped + s
                    p, s = belt_placer._place_ghost(
                        surface, force, player, belt_name,
                        {x = ubi_x, y = col2_y}, belt_dir_define, quality, polite)
                    placed = placed + p
                    skipped = skipped + s
                    last_had_ubi = false
                end

                -- 4. Fill inter-drill gap tiles with transport belts when items travel on surface
                if not is_last and not last_had_ubi then
                    local next_drill_index = order[iter_idx + 1]
                    local next_center = drill_positions[next_drill_index]

                    local gap_x_min, gap_x_max
                    if belt_direction == "east" then
                        gap_x_min = ubi_x + 1
                        gap_x_max = next_center - 2  -- next UBO at next_center - 1
                    else
                        gap_x_min = next_center + 2  -- next UBO at next_center + 1
                        gap_x_max = ubi_x - 1
                    end

                    for x = gap_x_min, gap_x_max do
                        p, s = belt_placer._place_ghost(
                            surface, force, player, belt_name,
                            {x = x, y = col1_y}, belt_dir_define, quality, polite)
                        placed = placed + p
                        skipped = skipped + s
                        p, s = belt_placer._place_ghost(
                            surface, force, player, belt_name,
                            {x = x, y = col2_y}, belt_dir_define, quality, polite)
                        placed = placed + p
                        skipped = skipped + s
                    end
                end
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
