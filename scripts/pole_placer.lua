-- Pole Placer - Places ghost electric poles in fixed pattern with underground belts
--
-- Poles are placed along the belt line gap between paired drill rows.
-- The placement algorithm uses a fixed spacing pattern:
--
-- For 3x3+ drills (using underground belts):
--   Pattern: UBO - UBI - Pole (repeats at each drill position)
--   - Pole placed after each underground belt pair (UBI)
--   - Position: drill_center + 1 tile in belt flow direction
--   - For NS orientation: pattern repeats every drill height tiles
--   - For EW orientation: pattern repeats every drill width tiles
--
-- For 2x2 drills (using plain belts):
--   - Poles placed at regular drill spacing intervals along belt columns
--   - Uses calculated spacing to ensure coverage and connectivity
--
-- Multi-tile poles are centered in the gap. If the pole
-- is too wide to fit in the free rows, placement is skipped.

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

--- Place ghost electric poles along all belt lines.
--- For 3x3+ drills: uses fixed pattern (UBO-UBI-Pole) at each drill position.
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
--- @param belt_direction string|nil Belt flow direction ("north", "south", "east", "west")
--- @param polite boolean|nil When true, respect polite placement
--- @return number placed Count of pole ghosts placed
--- @return number skipped Count of positions where placement failed
function pole_placer.place(surface, force, player, belt_lines, drill_info, pole_name, pole_quality, gap, pole_gap_positions, outer_edge_positions, is_small_drill, belt_direction, polite)
    if not pole_name or pole_name == "" then
        return 0, 0
    end

    local pole_info = pole_placer.get_pole_info(pole_name)
    if not pole_info then
        return 0, 0
    end

    local quality = pole_quality or "normal"

    local half_w = drill_info.width / 2
    local half_h = drill_info.height / 2

    local placed = 0
    local skipped = 0

    if is_small_drill then
        -- 2x2 drills: place poles at regular drill spacing intervals
        -- Use drill dimensions as spacing to align with drill pattern
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

            -- For 2x2 drills, use drill dimensions as spacing
            local spacing = orientation == "NS" and drill_info.height or drill_info.width

            for _, cross_pos in ipairs(all_cross_positions) do
                local p, s = pole_placer._place_pole_column(
                    surface, force, player, orientation, cross_pos,
                    along_start, along_end, spacing, pole_info, quality, polite)
                placed = placed + p
                skipped = skipped + s
            end
        end
    else
        -- 3x3+ drills: poles use fixed pattern (UBO-UBI-Pole at each drill position)
        belt_direction = belt_direction or "south"
        for _, belt_line in ipairs(belt_lines) do
            if belt_line.orientation == "NS" then
                local p, s = pole_placer._place_ns_poles(
                    surface, force, player, belt_line, half_h, pole_info, quality, belt_direction, polite)
                placed = placed + p
                skipped = skipped + s
            elseif belt_line.orientation == "EW" then
                local p, s = pole_placer._place_ew_poles(
                    surface, force, player, belt_line, half_w, pole_info, quality, belt_direction, polite)
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

--- Place poles along a north-south oriented belt line using fixed pattern.
--- For 3x3+ drills: places one pole after each UBI (drill_center + 1 tile in flow direction).
--- The x-position is the center of the gap, snapped to the correct tile alignment.
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param belt_line table Belt line metadata from calculator
--- @param half_h number Half the drill height
--- @param pole_info table Pole prototype info (name, width, height)
--- @param quality string Quality name
--- @param belt_direction string Belt flow direction ("north" or "south")
--- @param polite boolean|nil Polite mode flag
--- @return number placed
--- @return number skipped
function pole_placer._place_ns_poles(surface, force, player, belt_line, half_h, pole_info, quality, belt_direction, polite)
    local placed = 0
    local skipped = 0

    -- For NS belts, the gap spans the x-axis. x_center is the midpoint.
    local x_center = belt_line.x

    -- Use fixed pattern: place pole at drill_center + 1 tile in belt flow direction
    -- This places the pole after the UBI (which is at drill_center)
    local drill_positions = belt_line.drill_along_positions or {}

    for _, drill_center in ipairs(drill_positions) do
        local pole_y
        if belt_direction == "south" then
            -- Belt flows south: pole goes 1 tile south of drill center (after UBI)
            pole_y = drill_center + 1
        else
            -- Belt flows north: pole goes 1 tile north of drill center (after UBI)
            pole_y = drill_center - 1
        end

        -- Snap y to tile center for proper alignment based on pole height
        local snap_y
        if pole_info.height % 2 == 0 then
            snap_y = math.floor(pole_y)  -- even-height: place on tile boundary
        else
            snap_y = math.floor(pole_y) + 0.5  -- odd-height: place on tile center
        end

        local pos = {x = x_center, y = snap_y}
        local p, s = pole_placer._place_ghost(surface, force, player, pole_info.name, pos, quality, polite)
        placed = placed + p
        skipped = skipped + s
    end

    return placed, skipped
end

--- Place poles along an east-west oriented belt line using fixed pattern.
--- For 3x3+ drills: places one pole after each UBI (drill_center + 1 tile in flow direction).
--- The y-position is the center of the gap, snapped to the correct tile alignment.
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param belt_line table Belt line metadata from calculator
--- @param half_w number Half the drill width
--- @param pole_info table Pole prototype info (name, width, height)
--- @param quality string Quality name
--- @param belt_direction string Belt flow direction ("east" or "west")
--- @param polite boolean|nil Polite mode flag
--- @return number placed
--- @return number skipped
function pole_placer._place_ew_poles(surface, force, player, belt_line, half_w, pole_info, quality, belt_direction, polite)
    local placed = 0
    local skipped = 0

    -- For EW belts, the gap spans the y-axis. y_center is the midpoint.
    local y_center = belt_line.y

    -- Use fixed pattern: place pole at drill_center + 1 tile in belt flow direction
    -- This places the pole after the UBI (which is at drill_center)
    local drill_positions = belt_line.drill_along_positions or {}

    for _, drill_center in ipairs(drill_positions) do
        local pole_x
        if belt_direction == "east" then
            -- Belt flows east: pole goes 1 tile east of drill center (after UBI)
            pole_x = drill_center + 1
        else
            -- Belt flows west: pole goes 1 tile west of drill center (after UBI)
            pole_x = drill_center - 1
        end

        -- Snap x to tile center for proper alignment based on pole width
        local snap_x
        if pole_info.width % 2 == 0 then
            snap_x = math.floor(pole_x)  -- even-width: place on tile boundary
        else
            snap_x = math.floor(pole_x) + 0.5  -- odd-width: place on tile center
        end

        local pos = {x = snap_x, y = y_center}
        local p, s = pole_placer._place_ghost(surface, force, player, pole_info.name, pos, quality, polite)
        placed = placed + p
        skipped = skipped + s
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

--- Place substations for 5x5+ productive mode.
--- Belt layout per drill is: UBO(center-1) → Splitter(center) → UBI(center+1).
--- Substations go in the empty tiles between consecutive drills' belt sections:
---   - Before first drill's UBO (upstream of first belt section)
---   - Between UBI of drill N and UBO of drill N+1 (gap tiles)
---   - After last drill's UBI (downstream of last belt section)
--- Always placed at first and last positions. Intermediate ones spaced by wire distance.
---
--- For south flow with 5x5 drills (spacing=5, drill centers at y, y+5, y+10):
---   UBI(y+1) ... gap(y+2,y+3) ... UBO(y+4) — substation at midpoint of gap
---
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param belt_lines table Array of belt line metadata
--- @param drill_info table Drill info (width, height)
--- @param pole_info table Substation info {name, supply_area_distance, max_wire_distance, width, height}
--- @param quality string Quality name
--- @param belt_direction string Belt flow direction
--- @param gap number Gap size (should be 2 for this mode)
--- @param polite boolean|nil Polite mode flag
--- @return number placed
--- @return number skipped
function pole_placer.place_substations_productive_5x5(surface, force, player, belt_lines, drill_info, pole_info, quality, belt_direction, gap, polite)
    local placed = 0
    local skipped = 0

    -- Max distance between substations: use wire distance to ensure they connect
    local max_spacing = pole_info.max_wire_distance

    for _, belt_line in ipairs(belt_lines) do
        local drill_positions = belt_line.drill_along_positions or {}
        if #drill_positions == 0 then goto continue end

        -- Collect all candidate substation positions along this belt line.
        -- Candidates are in the empty spaces between belt sections:
        --   - Before first drill's UBO
        --   - Between consecutive drills (between UBI of N and UBO of N+1)
        --   - After last drill's UBI
        local candidates = {}

        if belt_line.orientation == "NS" then
            local body_along = drill_info.height
            local half = math.floor(body_along / 2)

            for i, drill_center in ipairs(drill_positions) do
                if i == 1 then
                    -- Before first drill: place upstream of drill body
                    if belt_direction == "south" then
                        candidates[#candidates + 1] = {x = belt_line.x, y = drill_center - half - 1}
                    else
                        candidates[#candidates + 1] = {x = belt_line.x, y = drill_center + half + 1}
                    end
                end

                if i < #drill_positions then
                    -- Between drill i and drill i+1: midpoint of gap between belt sections
                    local next_center = drill_positions[i + 1]
                    if belt_direction == "south" then
                        local mid = (drill_center + 1 + next_center - 1) / 2
                        candidates[#candidates + 1] = {x = belt_line.x, y = mid}
                    else
                        local mid = (drill_center - 1 + next_center + 1) / 2
                        candidates[#candidates + 1] = {x = belt_line.x, y = mid}
                    end
                else
                    -- After last drill: place downstream of drill body
                    if belt_direction == "south" then
                        candidates[#candidates + 1] = {x = belt_line.x, y = drill_center + half + 1}
                    else
                        candidates[#candidates + 1] = {x = belt_line.x, y = drill_center - half - 1}
                    end
                end
            end

        else -- EW
            local body_along = drill_info.width
            local half = math.floor(body_along / 2)

            for i, drill_center in ipairs(drill_positions) do
                if i == 1 then
                    if belt_direction == "east" then
                        candidates[#candidates + 1] = {x = drill_center - half - 1, y = belt_line.y}
                    else
                        candidates[#candidates + 1] = {x = drill_center + half + 1, y = belt_line.y}
                    end
                end

                if i < #drill_positions then
                    local next_center = drill_positions[i + 1]
                    if belt_direction == "east" then
                        local mid = (drill_center + 1 + next_center - 1) / 2
                        candidates[#candidates + 1] = {x = mid, y = belt_line.y}
                    else
                        local mid = (drill_center - 1 + next_center + 1) / 2
                        candidates[#candidates + 1] = {x = mid, y = belt_line.y}
                    end
                else
                    if belt_direction == "east" then
                        candidates[#candidates + 1] = {x = drill_center + half + 1, y = belt_line.y}
                    else
                        candidates[#candidates + 1] = {x = drill_center - half - 1, y = belt_line.y}
                    end
                end
            end
        end

        -- Place substations at candidates:
        -- - Always place at first and last positions (so all drills have power)
        -- - Space intermediate ones by wire distance (so they connect to each other)
        -- - Skip positions that would overlap with existing entity ghosts (belt/splitter)
        local sub_half = pole_info.width / 2
        local last_placed_pos = nil
        for idx, cand in ipairs(candidates) do
            local is_first = (idx == 1)
            local is_last = (idx == #candidates)
            local should_place = is_first or is_last

            if not should_place and last_placed_pos then
                local dist
                if belt_line.orientation == "NS" then
                    dist = math.abs(cand.y - last_placed_pos.y)
                else
                    dist = math.abs(cand.x - last_placed_pos.x)
                end
                -- Place when approaching wire distance limit (with margin for entity size)
                if dist >= max_spacing - pole_info.height then
                    should_place = true
                end
            end

            if should_place then
                -- Snap to integer coordinates for 2x2 entity
                local pos = {
                    x = math.floor(cand.x + 0.5),
                    y = math.floor(cand.y + 0.5),
                }

                -- Check for existing belt/splitter ghosts in substation footprint.
                -- For 5x5 drills, the gap between belt sections is only 2 tiles,
                -- so the substation collision box can overlap with UBO/UBI ghosts.
                local check_area = {
                    {pos.x - sub_half + 0.05, pos.y - sub_half + 0.05},
                    {pos.x + sub_half - 0.05, pos.y + sub_half - 0.05},
                }
                local existing = surface.find_entities_filtered{
                    area = check_area,
                    type = "entity-ghost",
                    ghost_type = {"underground-belt", "splitter", "transport-belt"},
                }
                if #existing == 0 then
                    local p, s = pole_placer._place_ghost(surface, force, player, pole_info.name, pos, quality, polite)
                    placed = placed + p
                    skipped = skipped + s
                    if p > 0 then
                        last_placed_pos = pos
                    end
                end
            end
        end

        ::continue::
    end

    return placed, skipped
end

--- Place substations for 3x3-4x4 productive mode.
--- Every Nth drill pair: replace the side2 drill (right column for NS, bottom row for EW)
--- with a 2x2 substation at that position. The replaced drill ghost is destroyed.
---
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param belt_lines table Array of belt line metadata
--- @param drill_info table Drill info (width, height)
--- @param pole_info table Substation info
--- @param quality string Quality name
--- @param belt_direction string Belt flow direction
--- @param gap number Gap size (1 for this mode)
--- @param polite boolean|nil Polite mode flag
--- @return number placed Count of substations placed
--- @return number skipped Count of positions skipped
--- @return table removed_positions Array of {x, y} positions of removed drills
function pole_placer.place_substations_productive_3x3(surface, force, player, belt_lines, drill_info, pole_info, quality, belt_direction, gap, polite)
    local placed = 0
    local skipped = 0
    local removed_positions = {}

    local body_along = nil
    local spacing_along = nil

    for _, belt_line in ipairs(belt_lines) do
        local side2_positions = belt_line.drill_side2_positions or {}
        if #side2_positions == 0 then goto continue end

        if belt_line.orientation == "NS" then
            body_along = drill_info.height
            spacing_along = body_along

            local effective_reach = math.min(pole_info.supply_area_distance * 2, pole_info.max_wire_distance)
            local interval = math.max(1, math.floor(effective_reach / spacing_along))

            -- Right column x-position: belt center + gap/2 + half drill width
            local right_x = belt_line.x + gap / 2 + drill_info.width / 2

            for i, drill_center_y in ipairs(side2_positions) do
                if (i - 1) % interval == 0 then
                    -- Find and destroy the existing drill ghost at this position
                    local drill_pos = {x = right_x, y = drill_center_y}
                    local area = {
                        {drill_pos.x - 0.1, drill_pos.y - 0.1},
                        {drill_pos.x + 0.1, drill_pos.y + 0.1},
                    }
                    local ghosts = surface.find_entities_filtered{
                        area = area,
                        type = "entity-ghost",
                        ghost_type = "mining-drill",
                    }
                    for _, ghost in ipairs(ghosts) do
                        if ghost.valid then
                            ghost.destroy()
                        end
                    end

                    -- Place substation at the drill's position
                    local pos = {x = right_x, y = drill_center_y}
                    local p, s = pole_placer._place_ghost(surface, force, player, pole_info.name, pos, quality, polite)
                    placed = placed + p
                    skipped = skipped + s
                    removed_positions[#removed_positions + 1] = drill_pos
                end
            end

        else -- EW
            body_along = drill_info.width
            spacing_along = body_along

            local effective_reach = math.min(pole_info.supply_area_distance * 2, pole_info.max_wire_distance)
            local interval = math.max(1, math.floor(effective_reach / spacing_along))

            -- Bottom row y-position: belt center + gap/2 + half drill height
            local bottom_y = belt_line.y + gap / 2 + drill_info.height / 2

            for i, drill_center_x in ipairs(side2_positions) do
                if (i - 1) % interval == 0 then
                    local drill_pos = {x = drill_center_x, y = bottom_y}
                    local area = {
                        {drill_pos.x - 0.1, drill_pos.y - 0.1},
                        {drill_pos.x + 0.1, drill_pos.y + 0.1},
                    }
                    local ghosts = surface.find_entities_filtered{
                        area = area,
                        type = "entity-ghost",
                        ghost_type = "mining-drill",
                    }
                    for _, ghost in ipairs(ghosts) do
                        if ghost.valid then
                            ghost.destroy()
                        end
                    end

                    local pos = {x = drill_center_x, y = bottom_y}
                    local p, s = pole_placer._place_ghost(surface, force, player, pole_info.name, pos, quality, polite)
                    placed = placed + p
                    skipped = skipped + s
                    removed_positions[#removed_positions + 1] = drill_pos
                end
            end
        end

        ::continue::
    end

    return placed, skipped, removed_positions
end

--- Place substations in efficient mode (all 3x3+ drills).
--- Substations go in the inter-pair gap between adjacent drill pairs,
--- spaced along the belt direction based on wire reach.
--- Only places if inter-pair gap >= 2 tiles.
---
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param belt_lines table Array of belt line metadata
--- @param drill_info table Drill info (width, height)
--- @param pole_info table Substation info
--- @param quality string Quality name
--- @param belt_direction string Belt flow direction
--- @param inter_pair_centers table Array of cross-axis center positions between pairs
--- @param polite boolean|nil Polite mode flag
--- @return number placed
--- @return number skipped
function pole_placer.place_substations_efficient(surface, force, player, belt_lines, drill_info, pole_info, quality, belt_direction, inter_pair_centers, polite)
    local placed = 0
    local skipped = 0

    if #inter_pair_centers == 0 or #belt_lines == 0 then
        return 0, 0
    end

    local orientation = belt_lines[1].orientation or "NS"

    -- Determine along-axis extent from all belt lines
    local along_min, along_max
    for _, belt_line in ipairs(belt_lines) do
        if orientation == "NS" then
            if not along_min or belt_line.y_min < along_min then along_min = belt_line.y_min end
            if not along_max or belt_line.y_max > along_max then along_max = belt_line.y_max end
        else
            if not along_min or belt_line.x_min < along_min then along_min = belt_line.x_min end
            if not along_max or belt_line.x_max > along_max then along_max = belt_line.x_max end
        end
    end

    if not along_min then return 0, 0 end

    local half_along = orientation == "NS" and drill_info.height / 2 or drill_info.width / 2
    local along_start = along_min - half_along
    local along_end = along_max + half_along

    -- Calculate spacing along belt direction based on wire reach
    local body_along = orientation == "NS" and drill_info.height or drill_info.width
    local effective_reach = math.min(pole_info.supply_area_distance * 2, pole_info.max_wire_distance)
    local spacing = math.max(body_along, math.floor(effective_reach / body_along) * body_along)
    if spacing < body_along then spacing = body_along end

    for _, cross_pos in ipairs(inter_pair_centers) do
        local along = along_start + spacing / 2
        while along <= along_end do
            local pos
            if orientation == "NS" then
                pos = {x = cross_pos, y = math.floor(along)}
            else
                pos = {x = math.floor(along), y = cross_pos}
            end

            local p, s = pole_placer._place_ghost(surface, force, player, pole_info.name, pos, quality, polite)
            placed = placed + p
            skipped = skipped + s
            along = along + spacing
        end
    end

    return placed, skipped
end

return pole_placer
