-- Beacon Placer - Places ghost beacons interleaved between mining drill columns/rows
--
-- Beacons are shared between adjacent drill pairs:
--   [Beacon][Drill][belt][Drill][Beacon][Drill][belt][Drill][Beacon]
--   ^outer                      ^shared                     ^outer
--
-- For NS belt orientation (vertical belt):
--   - Beacon columns are placed between adjacent drill pairs (shared by both)
--   - Plus one beacon column on the far left and far right outer edges
--   - Beacons fill vertically along each column at beacon-height intervals
--
-- For EW belt orientation (horizontal belt):
--   - Beacon rows are placed between adjacent drill pairs (shared by both)
--   - Plus one beacon row on the top and bottom outer edges
--   - Beacons fill horizontally along each row at beacon-width intervals
--
-- Uses a greedy coverage algorithm within each column/row to respect
-- max_beacons_per_drill limits and avoid collisions.
--
-- Beacon prototype data (supply_area_distance, collision_box) is read at runtime.

local ghost_util = require("scripts.ghost_util")

local beacon_placer = {}

--- Get prototype data for a beacon entity.
--- @param beacon_name string Prototype name of the beacon
--- @return table|nil {name, supply_area_distance, width, height} or nil if not found
function beacon_placer.get_beacon_info(beacon_name)
    local proto = prototypes.entity[beacon_name]
    if not proto then
        return nil
    end

    local cbox = proto.collision_box
    local width = math.ceil(cbox.right_bottom.x - cbox.left_top.x)
    local height = math.ceil(cbox.right_bottom.y - cbox.left_top.y)

    return {
        name = beacon_name,
        supply_area_distance = proto.get_supply_area_distance(),
        width = width,
        height = height,
    }
end

--- Check if a beacon placed at the given center would collide with any blocked tiles.
--- @param bx number Beacon center x
--- @param by number Beacon center y
--- @param beacon_info table Beacon prototype info
--- @param blocked table<string, true> Set of blocked tile positions
--- @return boolean true if collision detected
local function beacon_collides(bx, by, beacon_info, blocked)
    local bw_half = beacon_info.width / 2
    local bh_half = beacon_info.height / 2
    local x_min = math.floor(bx - bw_half)
    local x_max = math.floor(bx + bw_half) - 1
    local y_min = math.floor(by - bh_half)
    local y_max = math.floor(by + bh_half) - 1
    for tx = x_min, x_max do
        for ty = y_min, y_max do
            if blocked[tx .. "," .. ty] then
                return true
            end
        end
    end
    return false
end

--- Get the list of drill indices affected by a beacon at the given position.
--- A beacon affects a drill if the drill's collision box overlaps the beacon's supply area.
--- In Factorio, supply_area_distance extends from the beacon's collision box edge,
--- so effective reach from beacon center = supply_area_distance + beacon_half_size.
--- A drill is affected if its collision box overlaps this area, adding drill_half_size.
--- @param bx number Beacon center x
--- @param by number Beacon center y
--- @param beacon_info table Beacon prototype info
--- @param drill_positions table Array of drill placements
--- @param drill_info table Drill info {width, height}
--- @return table Array of drill indices that would be affected
local function get_affected_drills(bx, by, beacon_info, drill_positions, drill_info)
    local reach_x = beacon_info.supply_area_distance + beacon_info.width / 2 + drill_info.width / 2
    local reach_y = beacon_info.supply_area_distance + beacon_info.height / 2 + drill_info.height / 2
    local affected = {}
    for i, entry in ipairs(drill_positions) do
        local dx = math.abs(entry.position.x - bx)
        local dy = math.abs(entry.position.y - by)
        if dx <= reach_x and dy <= reach_y then
            affected[#affected + 1] = i
        end
    end
    return affected
end

--- Block tiles occupied by an entity centered at (cx, cy) with given half-dimensions.
--- @param blocked table<string, true> Set of blocked tile positions to update
--- @param cx number Center x
--- @param cy number Center y
--- @param half_w number Half width
--- @param half_h number Half height
local function block_entity_tiles(blocked, cx, cy, half_w, half_h)
    local x_min = math.floor(cx - half_w)
    local x_max = math.floor(cx + half_w) - 1
    local y_min = math.floor(cy - half_h)
    local y_max = math.floor(cy + half_h) - 1
    for tx = x_min, x_max do
        for ty = y_min, y_max do
            blocked[tx .. "," .. ty] = true
        end
    end
end

--- Build a set of blocked tile positions from placed entities.
--- @param drill_positions table Array of {position={x,y}, direction=...} drill placements
--- @param drill_info table Drill info {width, height}
--- @param belt_lines table Belt line metadata from calculator
--- @param gap number Gap size between paired rows
--- @return table<string, true> Set keyed by "x,y" tile coordinate strings
function beacon_placer.build_blocked_set(drill_positions, drill_info, belt_lines, gap)
    local blocked = {}

    local half_w = drill_info.width / 2
    local half_h = drill_info.height / 2

    -- Block tiles occupied by drills
    for _, entry in ipairs(drill_positions) do
        block_entity_tiles(blocked, entry.position.x, entry.position.y, half_w, half_h)
    end

    -- Block tiles occupied by belts (in the gap between drill pairs)
    for _, belt_line in ipairs(belt_lines) do
        if belt_line.orientation == "NS" then
            local x_center = belt_line.x
            local y_start = math.floor(belt_line.y_min - half_h)
            local y_end = math.floor(belt_line.y_max + half_h) - 1
            local x_start_tile = math.floor(x_center - gap / 2)
            for tile_offset = 0, gap - 1 do
                local tx = x_start_tile + tile_offset
                for ty = y_start, y_end do
                    blocked[tx .. "," .. ty] = true
                end
            end
        elseif belt_line.orientation == "EW" then
            local y_center = belt_line.y
            local x_start = math.floor(belt_line.x_min - half_w)
            local x_end = math.floor(belt_line.x_max + half_w) - 1
            local y_start_tile = math.floor(y_center - gap / 2)
            for tile_offset = 0, gap - 1 do
                local ty = y_start_tile + tile_offset
                for tx = x_start, x_end do
                    blocked[tx .. "," .. ty] = true
                end
            end
        end
    end

    return blocked
end

--- Generate targeted beacon candidate positions between drill columns/rows.
--- Beacons are interleaved between adjacent drill pairs so that each beacon
--- column/row is shared by the pairs on either side. The outermost edges
--- also get beacon columns/rows.
---
--- Layout (NS example):
---   [Beacon][Drill][belt][Drill][Beacon][Drill][belt][Drill][Beacon]
---   ^outer                      ^shared                     ^outer
---
--- @param drill_positions table Array of drill placements
--- @param drill_info table Drill info {width, height}
--- @param beacon_info table Beacon prototype info
--- @param belt_lines table Belt line metadata from calculator
--- @param gap number Gap size between paired rows
--- @return table Array of {x, y} candidate positions
local function generate_candidates(drill_positions, drill_info, beacon_info, belt_lines, gap)
    if #drill_positions == 0 or #belt_lines == 0 then
        return {}
    end

    local half_dw = drill_info.width / 2
    local half_dh = drill_info.height / 2
    local half_bw = beacon_info.width / 2
    local half_bh = beacon_info.height / 2
    local beacon_w = beacon_info.width
    local beacon_h = beacon_info.height

    local candidates = {}
    local seen = {}  -- avoid duplicate positions

    --- Add a candidate at (cx, cy) if not already seen.
    local function add_candidate(cx, cy)
        local key = cx .. "," .. cy
        if not seen[key] then
            seen[key] = true
            candidates[#candidates + 1] = {x = cx, y = cy}
        end
    end

    local orientation = belt_lines[1].orientation

    if orientation == "NS" then
        -- Collect per-pair info: outer edges and y-extent
        -- Sort belt lines by x position to get left-to-right order
        local pair_infos = {}
        for _, belt_line in ipairs(belt_lines) do
            local left_col_x = belt_line.x - gap / 2 - half_dw
            local right_col_x = belt_line.x + gap / 2 + half_dw
            local left_outer = left_col_x - half_dw   -- left edge of left drill column
            local right_outer = right_col_x + half_dw  -- right edge of right drill column

            -- Find the y-extent of drills in this pair
            local y_min, y_max
            for _, entry in ipairs(drill_positions) do
                local ex = entry.position.x
                if math.abs(ex - left_col_x) < 0.1 or math.abs(ex - right_col_x) < 0.1 then
                    local ey = entry.position.y
                    if not y_min or ey < y_min then y_min = ey end
                    if not y_max or ey > y_max then y_max = ey end
                end
            end

            if y_min then
                pair_infos[#pair_infos + 1] = {
                    left_outer = left_outer,
                    right_outer = right_outer,
                    y_min = y_min,
                    y_max = y_max,
                }
            end
        end

        -- Sort pairs left to right
        table.sort(pair_infos, function(a, b) return a.left_outer < b.left_outer end)

        -- Compute beacon column x-positions:
        -- 1. Leftmost outer edge
        -- 2. Between each adjacent pair (midpoint of right edge of pair i and left edge of pair i+1)
        -- 3. Rightmost outer edge
        local beacon_x_positions = {}
        if #pair_infos > 0 then
            -- Leftmost beacon column: adjacent to the left outer edge of the first pair
            beacon_x_positions[#beacon_x_positions + 1] = pair_infos[1].left_outer - half_bw

            -- Shared beacon columns between adjacent pairs
            for i = 1, #pair_infos - 1 do
                local mid_x = (pair_infos[i].right_outer + pair_infos[i + 1].left_outer) / 2
                beacon_x_positions[#beacon_x_positions + 1] = mid_x
            end

            -- Rightmost beacon column: adjacent to the right outer edge of the last pair
            beacon_x_positions[#beacon_x_positions + 1] = pair_infos[#pair_infos].right_outer + half_bw
        end

        -- Global y-extent across all pairs
        local global_y_min, global_y_max
        for _, info in ipairs(pair_infos) do
            if not global_y_min or info.y_min < global_y_min then global_y_min = info.y_min end
            if not global_y_max or info.y_max > global_y_max then global_y_max = info.y_max end
        end

        -- Fill each beacon column with candidates
        if global_y_min then
            for _, bx in ipairs(beacon_x_positions) do
                local col_top = global_y_min - half_dh + half_bh
                local extent_bottom = global_y_max + half_dh
                local y = col_top
                while (y - half_bh) < extent_bottom - 0.01 do
                    add_candidate(bx, y)
                    y = y + beacon_h
                end
            end
        end

    elseif orientation == "EW" then
        -- Collect per-pair info: outer edges and x-extent
        local pair_infos = {}
        for _, belt_line in ipairs(belt_lines) do
            local top_row_y = belt_line.y - gap / 2 - half_dh
            local bottom_row_y = belt_line.y + gap / 2 + half_dh
            local top_outer = top_row_y - half_dh     -- top edge of top drill row
            local bottom_outer = bottom_row_y + half_dh -- bottom edge of bottom drill row

            -- Find the x-extent of drills in this pair
            local x_min, x_max
            for _, entry in ipairs(drill_positions) do
                local ey = entry.position.y
                if math.abs(ey - top_row_y) < 0.1 or math.abs(ey - bottom_row_y) < 0.1 then
                    local ex = entry.position.x
                    if not x_min or ex < x_min then x_min = ex end
                    if not x_max or ex > x_max then x_max = ex end
                end
            end

            if x_min then
                pair_infos[#pair_infos + 1] = {
                    top_outer = top_outer,
                    bottom_outer = bottom_outer,
                    x_min = x_min,
                    x_max = x_max,
                }
            end
        end

        -- Sort pairs top to bottom
        table.sort(pair_infos, function(a, b) return a.top_outer < b.top_outer end)

        -- Compute beacon row y-positions:
        -- 1. Topmost outer edge
        -- 2. Between each adjacent pair
        -- 3. Bottommost outer edge
        local beacon_y_positions = {}
        if #pair_infos > 0 then
            beacon_y_positions[#beacon_y_positions + 1] = pair_infos[1].top_outer - half_bh

            for i = 1, #pair_infos - 1 do
                local mid_y = (pair_infos[i].bottom_outer + pair_infos[i + 1].top_outer) / 2
                beacon_y_positions[#beacon_y_positions + 1] = mid_y
            end

            beacon_y_positions[#beacon_y_positions + 1] = pair_infos[#pair_infos].bottom_outer + half_bh
        end

        -- Global x-extent across all pairs
        local global_x_min, global_x_max
        for _, info in ipairs(pair_infos) do
            if not global_x_min or info.x_min < global_x_min then global_x_min = info.x_min end
            if not global_x_max or info.x_max > global_x_max then global_x_max = info.x_max end
        end

        -- Fill each beacon row with candidates
        if global_x_min then
            for _, by in ipairs(beacon_y_positions) do
                local row_left = global_x_min - half_dw + half_bw
                local extent_right = global_x_max + half_dw
                local x = row_left
                while (x - half_bw) < extent_right - 0.01 do
                    add_candidate(x, by)
                    x = x + beacon_w
                end
            end
        end
    end

    return candidates
end

--- Place ghost beacons alongside drill columns/rows using a greedy coverage algorithm.
--- @param surface LuaSurface The game surface
--- @param force string Force name for ghost placement
--- @param player LuaPlayer The player requesting placement
--- @param drill_positions table Array of {position, direction} drill placements
--- @param drill_info table Drill info {width, height, name}
--- @param belt_lines table Belt line metadata from calculator
--- @param beacon_name string Beacon prototype name
--- @param beacon_quality string Quality name for beacon ghosts
--- @param beacon_module_name string|nil Module to insert into beacons
--- @param beacon_module_count number|nil Number of modules per beacon
--- @param max_beacons_per_drill number Maximum beacons that can affect any single drill
--- @param gap number Gap size between paired drill rows
--- @param polite boolean|nil When true, respect polite placement
--- @return number placed Count of beacon ghosts placed
--- @return number skipped Count of positions where placement failed
function beacon_placer.place(surface, force, player, drill_positions, drill_info,
                             belt_lines, beacon_name, beacon_quality, beacon_module_name,
                             beacon_module_count, max_beacons_per_drill, gap, polite)
    if not beacon_name or beacon_name == "" then
        return 0, 0
    end

    local beacon_info = beacon_placer.get_beacon_info(beacon_name)
    if not beacon_info then
        return 0, 0
    end

    if #drill_positions == 0 then
        return 0, 0
    end

    max_beacons_per_drill = max_beacons_per_drill or 4
    local quality = beacon_quality or "normal"

    -- Build blocked positions from drills and belts
    local blocked = beacon_placer.build_blocked_set(drill_positions, drill_info, belt_lines, gap)

    -- Generate targeted candidate positions alongside drill columns/rows
    local candidates = generate_candidates(drill_positions, drill_info, beacon_info, belt_lines, gap)

    -- Track how many beacons affect each drill (by index)
    local drill_beacon_count = {}
    for i = 1, #drill_positions do
        drill_beacon_count[i] = 0
    end

    -- Pre-filter candidates: remove those that collide with blocked tiles
    local valid_candidates = {}
    local candidate_count = 0
    for _, cand in ipairs(candidates) do
        if not beacon_collides(cand.x, cand.y, beacon_info, blocked) then
            candidate_count = candidate_count + 1
            valid_candidates[candidate_count] = cand
        end
    end

    local placed = 0
    local skipped = 0

    -- Helper: attempt to place a beacon ghost at a candidate position.
    -- Returns true if placed, false if skipped. Updates blocked set on success.
    local function try_place_beacon(cand)
        local pos = {x = cand.x, y = cand.y}

        local ghost, was_placed = ghost_util.place_ghost(
            surface, force, player, beacon_name, pos, nil, quality, nil, polite)

        if was_placed then
            -- Set module requests on the beacon ghost
            if ghost and ghost.valid and beacon_module_name and beacon_module_name ~= "" then
                local count = beacon_module_count or 1
                local insert_plan = {}
                for slot = 0, count - 1 do
                    insert_plan[#insert_plan + 1] = {
                        id = {
                            name = beacon_module_name,
                            quality = quality,
                        },
                        items = {
                            in_inventory = {
                                {
                                    inventory = defines.inventory.beacon_modules,
                                    stack = slot,
                                    count = 1,
                                },
                            },
                        },
                    }
                end
                ghost.insert_plan = insert_plan
            end

            placed = placed + 1

            -- Block the tiles occupied by this beacon for future candidates
            local bw_half = beacon_info.width / 2
            local bh_half = beacon_info.height / 2
            block_entity_tiles(blocked, cand.x, cand.y, bw_half, bh_half)
            return true
        else
            skipped = skipped + 1
            return false
        end
    end

    -- Greedy loop: place beacons one at a time, prioritizing positions that
    -- benefit drills that haven't reached their max_beacons_per_drill limit.
    while true do
        local best_score = 0
        local best_idx = nil
        local best_affected = nil

        for i = 1, candidate_count do
            local cand = valid_candidates[i]
            if cand then  -- nil entries are removed candidates
                local affected = get_affected_drills(cand.x, cand.y, beacon_info, drill_positions, drill_info)

                -- Skip candidates that would push any drill over the cap;
                -- score by number of drills that still have room for more beacons
                local would_exceed = false
                local score = 0
                for _, drill_idx in ipairs(affected) do
                    if drill_beacon_count[drill_idx] >= max_beacons_per_drill then
                        would_exceed = true
                        break
                    end
                end

                if not would_exceed then
                    score = #affected
                end

                if score > best_score then
                    best_score = score
                    best_idx = i
                    best_affected = affected
                end
            end
        end

        -- No more positions that benefit unsaturated drills
        if best_score == 0 or not best_idx then
            break
        end

        local cand = valid_candidates[best_idx]
        local was_placed = try_place_beacon(cand)

        if was_placed then
            -- Update drill beacon counts
            for _, drill_idx in ipairs(best_affected) do
                drill_beacon_count[drill_idx] = drill_beacon_count[drill_idx] + 1
            end
        end

        -- Remove this candidate (placed or skipped)
        valid_candidates[best_idx] = nil

        -- Remove other candidates that now collide with the placed beacon
        if was_placed then
            for i = 1, candidate_count do
                local c = valid_candidates[i]
                if c and beacon_collides(c.x, c.y, beacon_info, blocked) then
                    valid_candidates[i] = nil
                end
            end
        end
    end

    -- Fill pass: place beacons in remaining valid positions, but only if doing so
    -- would not exceed max_beacons_per_drill for any affected drill.
    for i = 1, candidate_count do
        local cand = valid_candidates[i]
        if cand then
            -- Re-check collision since blocked set may have changed
            if not beacon_collides(cand.x, cand.y, beacon_info, blocked) then
                -- Check that placing this beacon won't exceed the cap for any drill
                local affected = get_affected_drills(cand.x, cand.y, beacon_info, drill_positions, drill_info)
                local would_exceed = false
                for _, drill_idx in ipairs(affected) do
                    if drill_beacon_count[drill_idx] >= max_beacons_per_drill then
                        would_exceed = true
                        break
                    end
                end

                if not would_exceed then
                    local was_placed = try_place_beacon(cand)

                    if was_placed then
                        -- Update drill beacon counts
                        for _, drill_idx in ipairs(affected) do
                            drill_beacon_count[drill_idx] = drill_beacon_count[drill_idx] + 1
                        end

                        -- Remove other candidates that now collide with the placed beacon
                        for j = i + 1, candidate_count do
                            local c = valid_candidates[j]
                            if c and beacon_collides(c.x, c.y, beacon_info, blocked) then
                                valid_candidates[j] = nil
                            end
                        end
                    end
                end
            end
            valid_candidates[i] = nil
        end
    end

    return placed, skipped
end

return beacon_placer
