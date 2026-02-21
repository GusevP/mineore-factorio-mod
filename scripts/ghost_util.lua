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

-- Entity types that should never be deconstructed and never block placement
local no_decon_types = {
    ["resource"] = true,
    ["character"] = true,
    ["entity-ghost"] = true,
    ["tile-ghost"] = true,
    -- Elevated rails are in the air and don't conflict with ground-level entities
    ["elevated-straight-rail"] = true,
    ["elevated-curved-rail-a"] = true,
    ["elevated-curved-rail-b"] = true,
    ["elevated-half-diagonal-rail"] = true,
}

-- Ground-level rail infrastructure: never deconstructed, but blocks polite mode.
-- Rail ramps and supports have ground-level collision and shouldn't be built over.
-- These are entity prototype types, so modded entities (e.g. Krastorio) that use
-- the same Factorio types are automatically handled.
local ground_rail_types = {
    ["rail-ramp"] = true,
    ["rail-support"] = true,
}

-- Entity types that polite mode is allowed to demolish (natural obstacles)
local polite_decon_types = {
    ["tree"] = true,
    ["simple-entity"] = true,  -- rocks, stones, boulders
    ["cliff"] = true,
}

--- Order deconstruction of entities that would conflict with a ghost placement.
--- Finds all entities overlapping the target footprint and marks them for
--- deconstruction, except resources, characters, and existing ghosts.
--- In polite mode, only demolishes trees and rocks; returns true if blocked by other entities.
--- @param surface LuaSurface The game surface
--- @param force string|LuaForce The force name
--- @param player LuaPlayer The player requesting placement
--- @param name string Entity prototype name (for computing footprint)
--- @param position table {x, y} center position
--- @param direction defines.direction|nil Entity direction
--- @param polite boolean|nil When true, only demolish natural obstacles
--- @return boolean blocked True if polite mode detected non-natural conflicts
function ghost_util.demolish_conflicts(surface, force, player, name, position, direction, polite)
    local proto = prototypes.entity[name]
    if not proto then return false end

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
    local blocked = false
    for _, entity in ipairs(entities) do
        if entity.valid and not no_decon_types[entity.type] then
            if ground_rail_types[entity.type] then
                -- Rail ramps/supports are never deconstructed but block polite mode
                if polite then
                    blocked = true
                end
            elseif polite then
                if polite_decon_types[entity.type] then
                    if not entity.to_be_deconstructed() then
                        entity.order_deconstruction(force, player)
                    end
                else
                    -- Non-natural entity blocks placement in polite mode
                    blocked = true
                end
            else
                if not entity.to_be_deconstructed() then
                    entity.order_deconstruction(force, player)
                end
            end
        end
    end
    return blocked
end

--- Place a ghost entity after demolishing conflicts.
--- In normal mode, demolishes all conflicts then forces ghost placement.
--- In polite mode, only demolishes trees/rocks; skips placement if blocked by buildings.
--- @param surface LuaSurface
--- @param force string
--- @param player LuaPlayer
--- @param entity_name string Prototype name
--- @param position table {x, y}
--- @param direction defines.direction|nil
--- @param quality string Quality name
--- @param extra_params table|nil Additional params for create_entity. For underground belts, must include {type = "input"|"output"}
--- @param polite boolean|nil When true, skip placement if non-natural entities conflict
--- @return LuaEntity|nil ghost The created ghost entity, or nil on engine-level failure
--- @return boolean placed Whether the ghost was placed
function ghost_util.place_ghost(surface, force, player, entity_name, position, direction, quality, extra_params, polite)
    -- Demolish conflicts (in polite mode, only natural obstacles)
    local blocked = ghost_util.demolish_conflicts(surface, force, player, entity_name, position, direction, polite)
    if blocked then
        return nil, false
    end

    local create_params = {
        name = "entity-ghost",
        inner_name = entity_name,
        position = position,
        direction = direction,
        force = force,
        player = player,
        quality = quality or "normal",
    }
    -- Merge extra params (e.g., type for underground belts)
    if extra_params then
        for k, v in pairs(extra_params) do
            create_params[k] = v
        end
    end

    local ghost = surface.create_entity(create_params)
    if ghost then
        return ghost, true
    end

    return nil, false
end

return ghost_util
