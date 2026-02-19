-- Ghost Utility - Shared helper for placing ghost entities with conflict resolution
--
-- Instead of skipping positions where entities block placement, this module:
--   1. Finds conflicting entities in the target footprint
--   2. Orders them for deconstruction (except characters and resources)
--   3. Places the ghost entity
--
-- Characters cannot be deconstructed but Factorio's ghost_place check ignores
-- them, so they don't block ghost placement after other conflicts are cleared.

local ghost_util = {}

-- Entity types that should never be deconstructed
local no_decon_types = {
    ["resource"] = true,
    ["character"] = true,
    ["entity-ghost"] = true,
    ["tile-ghost"] = true,
}

--- Order deconstruction of entities that would conflict with a ghost placement.
--- Finds all entities overlapping the target footprint and marks them for
--- deconstruction, except resources, characters, and existing ghosts.
--- @param surface LuaSurface The game surface
--- @param force string|LuaForce The force name
--- @param player LuaPlayer The player requesting placement
--- @param name string Entity prototype name (for computing footprint)
--- @param position table {x, y} center position
--- @param direction defines.direction|nil Entity direction
function ghost_util.demolish_conflicts(surface, force, player, name, position, direction)
    local proto = prototypes.entity[name]
    if not proto then return end

    local cbox = proto.collision_box
    local half_w = (cbox.right_bottom.x - cbox.left_top.x) / 2
    local half_h = (cbox.right_bottom.y - cbox.left_top.y) / 2

    -- For rotated entities, swap dimensions
    if direction == defines.direction.east or direction == defines.direction.west then
        half_w, half_h = half_h, half_w
    end

    -- Small margin to avoid floating point edge issues
    local margin = 0.05
    local area = {
        {position.x - half_w + margin, position.y - half_h + margin},
        {position.x + half_w - margin, position.y + half_h - margin},
    }

    local entities = surface.find_entities(area)
    for _, entity in ipairs(entities) do
        if entity.valid and not no_decon_types[entity.type] then
            if not entity.to_be_deconstructed() then
                entity.order_deconstruction(force, player)
            end
        end
    end
end

--- Place a ghost entity, demolishing conflicts first if placement would fail.
--- First tries can_place_entity. If it fails, demolishes conflicts and retries.
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param entity_name string Prototype name
--- @param position table {x, y}
--- @param direction defines.direction|nil
--- @param quality string Quality name
--- @param extra_params table|nil Additional params for create_entity (e.g., belt_to_ground_type)
--- @return LuaEntity|nil ghost The created ghost entity, or nil if placement still failed
--- @return boolean placed Whether the ghost was placed
function ghost_util.place_ghost(surface, force, player, entity_name, position, direction, quality, extra_params)
    local check_params = {
        name = entity_name,
        position = position,
        direction = direction,
        force = force,
        build_check_type = defines.build_check_type.ghost_place,
    }

    local can_place = surface.can_place_entity(check_params)

    if not can_place then
        -- Demolish conflicts and retry
        ghost_util.demolish_conflicts(surface, force, player, entity_name, position, direction)
        can_place = surface.can_place_entity(check_params)
    end

    if can_place then
        local create_params = {
            name = "entity-ghost",
            inner_name = entity_name,
            position = position,
            direction = direction,
            force = force,
            player = player,
            quality = quality or "normal",
        }
        -- Merge extra params (e.g., belt_to_ground_type)
        if extra_params then
            for k, v in pairs(extra_params) do
                create_params[k] = v
            end
        end

        local ghost = surface.create_entity(create_params)
        return ghost, true
    end

    return nil, false
end

return ghost_util
