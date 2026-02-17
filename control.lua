-- Miner Planner - Main runtime control
-- Handles event registration and dispatching

local resource_scanner = require("scripts.resource_scanner")

local SELECTION_TOOL_NAME = "mineore-selection-tool"
local SHORTCUT_NAME = "mineore-shortcut"

-- Initialize global storage on mod load
script.on_init(function()
    storage.players = storage.players or {}
end)

script.on_configuration_changed(function()
    storage.players = storage.players or {}
end)

-- Get or initialize per-player storage
local function get_player_data(player_index)
    storage.players[player_index] = storage.players[player_index] or {}
    return storage.players[player_index]
end

-- Track new players joining
script.on_event(defines.events.on_player_created, function(event)
    get_player_data(event.player_index)
end)

-- Give the player the selection tool when shortcut is clicked
local function give_selection_tool(player)
    if player.clear_cursor() then
        player.cursor_stack.set_stack({name = SELECTION_TOOL_NAME, count = 1})
    end
end

-- Handle shortcut bar click
script.on_event(defines.events.on_lua_shortcut, function(event)
    if event.prototype_name ~= SHORTCUT_NAME then return end
    local player = game.get_player(event.player_index)
    if player then
        give_selection_tool(player)
    end
end)

-- Handle custom input (keyboard shortcut ALT+M)
script.on_event("mineore-toggle", function(event)
    local player = game.get_player(event.player_index)
    if player then
        give_selection_tool(player)
    end
end)

-- Handle primary selection (drag over ore patch)
script.on_event(defines.events.on_player_selected_area, function(event)
    if event.item ~= SELECTION_TOOL_NAME then return end
    local player = game.get_player(event.player_index)
    if not player then return end

    local entities = event.entities
    if #entities == 0 then
        player.create_local_flying_text({
            text = {"mineore.no-resources-found"},
            create_at_cursor = true,
        })
        return
    end

    -- Scan selected resources and find compatible drills
    local scan_results = resource_scanner.scan(entities, player)
    if not scan_results then
        player.create_local_flying_text({
            text = {"mineore.no-resources-found"},
            create_at_cursor = true,
        })
        return
    end

    -- Store scan results for this player (used by GUI and placer later)
    local player_data = get_player_data(event.player_index)
    player_data.last_scan = scan_results

    -- Print debug info to console (will be replaced by GUI in Task 4)
    resource_scanner.print_results(scan_results, player)

    if #scan_results.compatible_drills == 0 then
        player.create_local_flying_text({
            text = {"mineore.no-compatible-drills"},
            create_at_cursor = true,
        })
    end
end)

-- Handle alt-selection (shift-drag to remove ghost miners)
script.on_event(defines.events.on_player_alt_selected_area, function(event)
    if event.item ~= SELECTION_TOOL_NAME then return end
    local player = game.get_player(event.player_index)
    if not player then return end

    local removed = 0
    for _, entity in pairs(event.entities) do
        if entity.valid and entity.name == "entity-ghost" then
            local ghost_name = entity.ghost_name
            local ghost_proto = prototypes.entity[ghost_name]
            if ghost_proto and ghost_proto.type == "mining-drill" then
                entity.destroy()
                removed = removed + 1
            end
        end
    end

    if removed > 0 then
        player.create_local_flying_text({
            text = {"mineore.ghosts-removed", removed},
            create_at_cursor = true,
        })
    else
        player.create_local_flying_text({
            text = {"mineore.no-ghosts-found"},
            create_at_cursor = true,
        })
    end
end)
