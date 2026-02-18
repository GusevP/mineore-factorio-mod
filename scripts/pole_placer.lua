-- Pole Placer - Places ghost electric poles/substations in the gaps between paired miner rows
--
-- Poles are placed along the belt line gap between paired drill rows.
-- The placement algorithm:
--   1. Reads the pole prototype data at runtime (supply area, wire reach, collision box)
--   2. Calculates the maximum spacing between poles so that:
--      a. All drills are within the pole's supply area
--      b. Consecutive poles are within wire reach of each other
--   3. Places poles along each belt line at the calculated interval
--
-- For NS orientation: poles are placed along the vertical gap, spaced vertically
-- For EW orientation: poles are placed along the horizontal gap, spaced horizontally

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

--- Calculate the maximum spacing between poles along a belt line.
---
--- The spacing is limited by two constraints:
---   1. Supply coverage: each drill must be within the pole's supply area.
---      The supply area is a square centered on the pole with side length
---      2 * supply_area_distance + 1 (for 1x1 poles) or larger for bigger poles.
---      Along the belt line direction, the effective reach is supply_area_distance.
---      Two consecutive poles can cover drills between them if their supply areas overlap.
---      Max spacing for full coverage = 2 * supply_area_distance + 1 (the supply diameter).
---      But we want no gaps, so spacing <= 2 * supply_area_distance + 1.
---
---   2. Wire connectivity: consecutive poles must be within max_wire_distance of each other.
---      So spacing <= max_wire_distance.
---
--- We use the minimum of these two constraints, rounded down to an integer for clean placement.
---
--- @param pole_info table Pole prototype info from get_pole_info()
--- @return number spacing Maximum spacing between pole centers along the belt line
function pole_placer.calculate_spacing(pole_info)
    -- Supply area coverage along the belt line direction
    -- supply_area_distance is the reach from the pole center in each direction
    -- Two consecutive poles placed at distance D apart will have overlapping supply areas
    -- if D <= 2 * supply_area_distance (they share coverage at the midpoint)
    -- We use the full diameter for coverage (slightly conservative)
    local supply_spacing = math.floor(2 * pole_info.supply_area_distance)

    -- Wire reach constraint
    local wire_spacing = math.floor(pole_info.max_wire_distance)

    -- Use the more restrictive constraint
    local spacing = math.min(supply_spacing, wire_spacing)

    -- Ensure at least 1 tile spacing
    if spacing < 1 then
        spacing = 1
    end

    return spacing
end

--- Place ghost electric poles along all belt lines.
--- @param surface LuaSurface The game surface
--- @param force string Force name for ghost placement
--- @param player LuaPlayer The player requesting placement
--- @param belt_lines table Array of belt line metadata from calculator
--- @param drill_info table Drill info (width, height) for computing coverage extent
--- @param pole_name string Electric pole prototype name
--- @param pole_quality string Quality name for pole ghosts
--- @param gap number Gap size between paired rows
--- @return number placed Count of pole ghosts placed
--- @return number skipped Count of positions where placement failed
function pole_placer.place(surface, force, player, belt_lines, drill_info, pole_name, pole_quality, gap)
    if not pole_name or pole_name == "" then
        return 0, 0
    end

    local pole_info = pole_placer.get_pole_info(pole_name)
    if not pole_info then
        return 0, 0
    end

    local spacing = pole_placer.calculate_spacing(pole_info)
    local quality = pole_quality or "normal"

    local half_w = drill_info.width / 2
    local half_h = drill_info.height / 2

    local placed = 0
    local skipped = 0

    for _, belt_line in ipairs(belt_lines) do
        if belt_line.orientation == "NS" then
            local p, s = pole_placer._place_ns_poles(
                surface, force, player, belt_line, half_h, spacing, pole_name, quality, gap)
            placed = placed + p
            skipped = skipped + s
        elseif belt_line.orientation == "EW" then
            local p, s = pole_placer._place_ew_poles(
                surface, force, player, belt_line, half_w, spacing, pole_name, quality, gap)
            placed = placed + p
            skipped = skipped + s
        end
    end

    return placed, skipped
end

--- Place poles along a north-south oriented belt line.
--- Poles are placed vertically along the gap at calculated intervals.
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param belt_line table Belt line metadata from calculator
--- @param half_h number Half the drill height
--- @param spacing number Distance between pole centers
--- @param pole_name string Pole prototype name
--- @param quality string Quality name
--- @param gap number Gap size in tiles
--- @return number placed
--- @return number skipped
function pole_placer._place_ns_poles(surface, force, player, belt_line, half_h, spacing, pole_name, quality, gap)
    local placed = 0
    local skipped = 0

    -- The belt line center x is the midpoint of the gap
    local x_center = belt_line.x

    -- y extent: from the top edge of the first drill to the bottom edge of the last drill
    local y_start = belt_line.y_min - half_h
    local y_end = belt_line.y_max + half_h

    -- Place first pole near the start, then at regular intervals
    -- Start at the first position that's within the drill extent
    local y = y_start + spacing / 2
    while y <= y_end do
        local pos = {x = x_center, y = y}
        local p, s = pole_placer._place_ghost(surface, force, player, pole_name, pos, quality)
        placed = placed + p
        skipped = skipped + s
        y = y + spacing
    end

    return placed, skipped
end

--- Place poles along an east-west oriented belt line.
--- Poles are placed horizontally along the gap at calculated intervals.
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param belt_line table Belt line metadata from calculator
--- @param half_w number Half the drill width
--- @param spacing number Distance between pole centers
--- @param pole_name string Pole prototype name
--- @param quality string Quality name
--- @param gap number Gap size in tiles
--- @return number placed
--- @return number skipped
function pole_placer._place_ew_poles(surface, force, player, belt_line, half_w, spacing, pole_name, quality, gap)
    local placed = 0
    local skipped = 0

    -- The belt line center y is the midpoint of the gap
    local y_center = belt_line.y

    -- x extent: from the left edge of the first drill to the right edge of the last drill
    local x_start = belt_line.x_min - half_w
    local x_end = belt_line.x_max + half_w

    -- Place first pole near the start, then at regular intervals
    local x = x_start + spacing / 2
    while x <= x_end do
        local pos = {x = x, y = y_center}
        local p, s = pole_placer._place_ghost(surface, force, player, pole_name, pos, quality)
        placed = placed + p
        skipped = skipped + s
        x = x + spacing
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
--- @return number placed 1 if placed, 0 if not
--- @return number skipped 1 if skipped, 0 if not
function pole_placer._place_ghost(surface, force, player, entity_name, position, quality)
    local can_place = surface.can_place_entity({
        name = entity_name,
        position = position,
        force = force,
        build_check_type = defines.build_check_type.ghost_place,
    })

    if can_place then
        surface.create_entity({
            name = "entity-ghost",
            inner_name = entity_name,
            position = position,
            force = force,
            player = player,
            quality = quality,
        })
        return 1, 0
    end

    return 0, 1
end

return pole_placer
