-- Beacon Placer - Places ghost beacons alongside mining drill columns/rows
--
-- Beacons are placed on the outer sides of each drill pair:
--   [Beacon][Drill =>] [belt gap] [<= Drill][Beacon]
--
-- For NS belt orientation (vertical belt):
--   - Left beacon column: immediately left of the left drill column
--   - Right beacon column: immediately right of the right drill column
--   - Beacons are placed at each drill y-position along the column
--
-- For EW belt orientation (horizontal belt):
--   - Top beacon row: immediately above the top drill row
--   - Bottom beacon row: immediately below the bottom drill row
--   - Beacons are placed at each drill x-position along the row
--
-- Uses a greedy coverage algorithm within each column/row to respect
-- max_beacons_per_drill limits and avoid collisions.
--
-- Beacon prototype data (supply_area_distance, collision_box) is read at runtime.

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
        supply_area_distance = proto.supply_area_distance,
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
--- A beacon affects a drill if the drill's center is within the beacon's supply area.
--- @param bx number Beacon center x
--- @param by number Beacon center y
--- @param beacon_info table Beacon prototype info
--- @param drill_positions table Array of drill placements
--- @return table Array of drill indices that would be affected
local function get_affected_drills(bx, by, beacon_info, drill_positions)
    local reach = beacon_info.supply_area_distance
    local affected = {}
    for i, entry in ipairs(drill_positions) do
        local dx = math.abs(entry.position.x - bx)
        local dy = math.abs(entry.position.y - by)
        -- Beacon supply area is a square: reach tiles in each direction from beacon center
        if dx <= reach and dy <= reach then
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
            local y_end = math.floor(belt_line.y_max + half_h)
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
            local x_end = math.floor(belt_line.x_max + half_w)
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

--- Generate targeted beacon candidate positions alongside drill columns/rows.
--- Instead of a full grid, candidates are placed specifically on the outer edges
--- of each drill pair where the plan diagram shows beacons should go.
---
--- For NS belt orientation:
---   Candidates are in columns to the left and right of each drill pair,
---   at each drill y-position.
---
--- For EW belt orientation:
---   Candidates are in rows above and below each drill pair,
---   at each drill x-position.
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

    local candidates = {}
    local seen = {}  -- avoid duplicate positions

    for _, belt_line in ipairs(belt_lines) do
        if belt_line.orientation == "NS" then
            -- Derive left and right drill column x-centers from belt line
            local left_col_x = belt_line.x - gap / 2 - half_dw
            local right_col_x = belt_line.x + gap / 2 + half_dw

            -- Beacon x positions: adjacent to outer edges of drill columns
            local beacon_left_x = left_col_x - half_dw - half_bw
            local beacon_right_x = right_col_x + half_dw + half_bw

            -- Collect unique drill y-positions from this pair
            local y_positions = {}
            for _, entry in ipairs(drill_positions) do
                local ex = entry.position.x
                -- Check if this drill belongs to this pair's left or right column
                if math.abs(ex - left_col_x) < 0.1 or math.abs(ex - right_col_x) < 0.1 then
                    y_positions[entry.position.y] = true
                end
            end

            -- Generate candidates at each y-position on both sides
            for y, _ in pairs(y_positions) do
                local key_l = beacon_left_x .. "," .. y
                if not seen[key_l] then
                    seen[key_l] = true
                    candidates[#candidates + 1] = {x = beacon_left_x, y = y}
                end
                local key_r = beacon_right_x .. "," .. y
                if not seen[key_r] then
                    seen[key_r] = true
                    candidates[#candidates + 1] = {x = beacon_right_x, y = y}
                end
            end

        elseif belt_line.orientation == "EW" then
            -- Derive top and bottom drill row y-centers from belt line
            local top_row_y = belt_line.y - gap / 2 - half_dh
            local bottom_row_y = belt_line.y + gap / 2 + half_dh

            -- Beacon y positions: adjacent to outer edges of drill rows
            local beacon_top_y = top_row_y - half_dh - half_bh
            local beacon_bottom_y = bottom_row_y + half_dh + half_bh

            -- Collect unique drill x-positions from this pair
            local x_positions = {}
            for _, entry in ipairs(drill_positions) do
                local ey = entry.position.y
                if math.abs(ey - top_row_y) < 0.1 or math.abs(ey - bottom_row_y) < 0.1 then
                    x_positions[entry.position.x] = true
                end
            end

            -- Generate candidates at each x-position on both sides
            for x, _ in pairs(x_positions) do
                local key_t = x .. "," .. beacon_top_y
                if not seen[key_t] then
                    seen[key_t] = true
                    candidates[#candidates + 1] = {x = x, y = beacon_top_y}
                end
                local key_b = x .. "," .. beacon_bottom_y
                if not seen[key_b] then
                    seen[key_b] = true
                    candidates[#candidates + 1] = {x = x, y = beacon_bottom_y}
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
--- @return number placed Count of beacon ghosts placed
--- @return number skipped Count of positions where placement failed
function beacon_placer.place(surface, force, player, drill_positions, drill_info,
                             belt_lines, beacon_name, beacon_quality, beacon_module_name,
                             beacon_module_count, max_beacons_per_drill, gap)
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

    -- Greedy loop: place beacons one at a time at the best scoring position
    while true do
        local best_score = 0
        local best_idx = nil
        local best_affected = nil

        for i = 1, candidate_count do
            local cand = valid_candidates[i]
            if cand then  -- nil entries are removed candidates
                local affected = get_affected_drills(cand.x, cand.y, beacon_info, drill_positions)

                -- Score = number of drills that still have room for more beacons
                local score = 0
                for _, drill_idx in ipairs(affected) do
                    if drill_beacon_count[drill_idx] < max_beacons_per_drill then
                        score = score + 1
                    end
                end

                if score > best_score then
                    best_score = score
                    best_idx = i
                    best_affected = affected
                end
            end
        end

        -- No more beneficial positions
        if best_score == 0 or not best_idx then
            break
        end

        local cand = valid_candidates[best_idx]
        local pos = {x = cand.x, y = cand.y}

        -- Try to place the ghost
        local can_place = surface.can_place_entity({
            name = beacon_name,
            position = pos,
            force = force,
            build_check_type = defines.build_check_type.ghost_place,
        })

        if can_place then
            local ghost = surface.create_entity({
                name = "entity-ghost",
                inner_name = beacon_name,
                position = pos,
                force = force,
                player = player,
                quality = quality,
            })

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

            -- Update drill beacon counts
            for _, drill_idx in ipairs(best_affected) do
                drill_beacon_count[drill_idx] = drill_beacon_count[drill_idx] + 1
            end

            -- Block the tiles occupied by this beacon for future candidates
            local bw_half = beacon_info.width / 2
            local bh_half = beacon_info.height / 2
            block_entity_tiles(blocked, cand.x, cand.y, bw_half, bh_half)
        else
            skipped = skipped + 1
        end

        -- Remove this candidate (placed or skipped)
        valid_candidates[best_idx] = nil

        -- Remove other candidates that now collide with the placed beacon
        if can_place then
            for i = 1, candidate_count do
                local c = valid_candidates[i]
                if c and beacon_collides(c.x, c.y, beacon_info, blocked) then
                    valid_candidates[i] = nil
                end
            end
        end
    end

    return placed, skipped
end

return beacon_placer
