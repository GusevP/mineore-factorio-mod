-- Beacon Placer - Places ghost beacons around mining drill layouts
--
-- Uses a greedy coverage algorithm:
--   1. Build a set of candidate beacon positions (grid around the drill area)
--   2. Remove positions that collide with drills, belts, or poles
--   3. Score each candidate by how many drills it would affect
--   4. Place the beacon at the highest-scoring position
--   5. Update drill coverage counts and remove candidates that would exceed max beacons per drill
--   6. Repeat until no more beneficial positions exist
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

--- Build a set of blocked tile positions from placed entities.
--- Each entry represents a tile that cannot host any part of a beacon's collision box.
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
        local cx = entry.position.x
        local cy = entry.position.y
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

--- Generate candidate beacon positions around the drill layout.
--- Candidates are placed on a grid covering the drill area plus the beacon's reach.
--- @param drill_positions table Array of drill placements
--- @param drill_info table Drill info {width, height}
--- @param beacon_info table Beacon prototype info
--- @return table Array of {x, y} candidate positions
local function generate_candidates(drill_positions, drill_info, beacon_info)
    if #drill_positions == 0 then
        return {}
    end

    -- Find bounding box of all drill positions
    local min_x, max_x = math.huge, -math.huge
    local min_y, max_y = math.huge, -math.huge
    for _, entry in ipairs(drill_positions) do
        local px, py = entry.position.x, entry.position.y
        if px < min_x then min_x = px end
        if px > max_x then max_x = px end
        if py < min_y then min_y = py end
        if py > max_y then max_y = py end
    end

    -- Extend bounds by beacon reach + drill half-size so beacons outside the drill area
    -- that still affect edge drills are considered
    local reach = beacon_info.supply_area_distance
    local half_w = drill_info.width / 2
    local half_h = drill_info.height / 2
    local ext_x = reach + half_w
    local ext_y = reach + half_h

    local x_start = math.floor(min_x - ext_x) + 0.5
    local x_end = math.ceil(max_x + ext_x) - 0.5
    local y_start = math.floor(min_y - ext_y) + 0.5
    local y_end = math.ceil(max_y + ext_y) - 0.5

    -- For larger beacons (e.g., 3x3), step by the beacon size to avoid excessive candidates
    -- For standard beacons (3x3), step by 1 to allow fine-grained placement
    local step = 1

    local candidates = {}
    local x = x_start
    while x <= x_end do
        local y = y_start
        while y <= y_end do
            candidates[#candidates + 1] = {x = x, y = y}
            y = y + step
        end
        x = x + step
    end

    return candidates
end

--- Place ghost beacons around drill positions using a greedy coverage algorithm.
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

    -- Generate candidate positions
    local candidates = generate_candidates(drill_positions, drill_info, beacon_info)

    -- Track how many beacons affect each drill (by index)
    local drill_beacon_count = {}
    for i = 1, #drill_positions do
        drill_beacon_count[i] = 0
    end

    -- Pre-filter candidates: remove those that collide with blocked tiles
    -- Use a map indexed by integer keys so we can nil out entries during greedy iteration
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
            local bx_min = math.floor(cand.x - bw_half)
            local bx_max = math.floor(cand.x + bw_half) - 1
            local by_min = math.floor(cand.y - bh_half)
            local by_max = math.floor(cand.y + bh_half) - 1
            for tx = bx_min, bx_max do
                for ty = by_min, by_max do
                    blocked[tx .. "," .. ty] = true
                end
            end
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
