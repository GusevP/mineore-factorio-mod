-- Miner Planner - Main runtime control
-- Handles event registration and dispatching

local resource_scanner = require("scripts.resource_scanner")
local config_gui = require("scripts.gui")
local placer = require("scripts.placer")

local SELECTION_TOOL_NAME = "mineore-selection-tool"
local SHORTCUT_NAME = "mineore-shortcut"

-- Initialize global storage on mod load
script.on_init(function()
    storage.players = storage.players or {}
end)

script.on_configuration_changed(function()
    storage.players = storage.players or {}

    -- Close any open config GUIs and clear stale scan data on config change
    for player_index, player_data in pairs(storage.players) do
        local player = game.get_player(player_index)
        if player then
            config_gui.destroy(player)
            player_data.last_scan = nil
        else
            -- Remove data for players that no longer exist
            storage.players[player_index] = nil
        end
    end
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

-- Clean up when a player is removed
script.on_event(defines.events.on_player_removed, function(event)
    if storage.players then
        storage.players[event.player_index] = nil
    end
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

    -- Store scan results for this player
    local player_data = get_player_data(event.player_index)
    player_data.last_scan = scan_results

    if #scan_results.compatible_drills == 0 then
        player.create_local_flying_text({
            text = {"mineore.no-compatible-drills"},
            create_at_cursor = true,
        })
        return
    end

    -- Check if "remember settings" is enabled and we have previous settings
    local show_gui_always = player.mod_settings["mineore-show-gui-always"].value
    local settings = player_data.settings
    if settings and settings.remember and not show_gui_always then
        -- Verify the remembered drill is still compatible with this selection
        local drill_still_valid = false
        for _, drill in ipairs(scan_results.compatible_drills) do
            if drill.name == settings.drill_name then
                drill_still_valid = true
                break
            end
        end

        if drill_still_valid then
            -- Skip GUI, go straight to placement
            player.print({"mineore.using-remembered-settings"})
            placer.place(player, scan_results, settings)
            return
        end
    end

    -- Show configuration GUI
    config_gui.create(player, scan_results, player_data)
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

-- GUI event handlers

-- Handle button clicks (Place, Cancel, Close)
script.on_event(defines.events.on_gui_click, function(event)
    local element = event.element
    if not element or not element.valid then return end
    if not config_gui.is_mineore_element(element) then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    if element.name == "mineore_close_button" or element.name == "mineore_cancel_button" then
        config_gui.destroy(player)
        return
    end

    if element.name == "mineore_place_button" then
        local settings = config_gui.read_settings(player)
        if settings then
            local player_data = get_player_data(event.player_index)
            player_data.settings = settings

            config_gui.destroy(player)

            -- Place ghost drills using calculated grid positions
            if player_data.last_scan then
                placer.place(player, player_data.last_scan, settings)
            end
        end
        return
    end
end)

-- Handle radiobutton changes (placement mode and direction)
script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    local element = event.element
    if not element or not element.valid then return end
    if not config_gui.is_mineore_element(element) then return end

    config_gui.handle_radio_change(element)
end)

-- Handle dropdown selection changes
script.on_event(defines.events.on_gui_selection_state_changed, function(event)
    local element = event.element
    if not element or not element.valid then return end
    if not config_gui.is_mineore_element(element) then return end
    -- No additional action needed - selection is read when Place is clicked
end)

-- Handle ESC key closing the GUI
script.on_event(defines.events.on_gui_closed, function(event)
    local element = event.element
    if not element or not element.valid then return end

    if element.name == "mineore_config_frame" then
        element.destroy()
    end
end)
