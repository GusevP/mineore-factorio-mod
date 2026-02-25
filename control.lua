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
            player_data.gui_draft = nil

            -- Migrate legacy placement modes
            if player_data.settings and player_data.settings.placement_mode then
                local mode = player_data.settings.placement_mode
                if mode == "loose" or mode == "normal" then
                    player_data.settings.placement_mode = "efficient"
                elseif mode == "efficient" then
                    -- Migrate stale "efficient" default to "productivity" (default changed in v0.6.0)
                    local default_mode = player.mod_settings["mineore-default-mode"].value
                    if default_mode == "productivity" then
                        player_data.settings.placement_mode = "productivity"
                    end
                end
            end
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
    else
        player.print({"mineore.cursor-not-cleared-warning"})
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

        -- Also verify the drill has fluid input when the selected resource requires it
        local selected_resource = settings.resource_name
        local resource_groups = scan_results.resource_groups
        local resource_needs_fluid = false
        if selected_resource and resource_groups[selected_resource] then
            if resource_groups[selected_resource].required_fluid then
                resource_needs_fluid = true
            end
        else
            -- No specific resource selected; check all groups
            for _, group in pairs(resource_groups) do
                if group.required_fluid then
                    resource_needs_fluid = true
                    break
                end
            end
        end

        if resource_needs_fluid and drill_still_valid then
            -- Find the drill info to check has_fluid_input
            for _, drill in ipairs(scan_results.compatible_drills) do
                if drill.name == settings.drill_name and not drill.has_fluid_input then
                    drill_still_valid = false
                    break
                end
            end
        end

        -- Also verify the drill recipe is enabled (technology check)
        if drill_still_valid then
            local recipe = player.force.recipes[settings.drill_name]
            if recipe and not recipe.enabled then
                drill_still_valid = false
            end
        end

        if drill_still_valid then
            -- Clear remembered entity names whose prototypes no longer exist or aren't researched
            if settings.belt_name then
                local proto = prototypes.entity[settings.belt_name]
                local recipe = player.force.recipes[settings.belt_name]
                if not proto or (recipe and not recipe.enabled) then
                    settings.belt_name = nil
                    settings.belt_quality = nil
                end
            end
            if settings.pipe_name then
                local proto = prototypes.entity[settings.pipe_name]
                local recipe = player.force.recipes[settings.pipe_name]
                if not proto or (recipe and not recipe.enabled) then
                    settings.pipe_name = nil
                    settings.pipe_quality = nil
                end
            end
            if settings.pole_name then
                local proto = prototypes.entity[settings.pole_name]
                local recipe = player.force.recipes[settings.pole_name]
                -- Also verify pole is in the whitelist
                local in_whitelist = false
                for _, whitelisted_pole in ipairs(config_gui.POLE_WHITELIST) do
                    if settings.pole_name == whitelisted_pole then
                        in_whitelist = true
                        break
                    end
                end
                if not proto or (recipe and not recipe.enabled) or not in_whitelist then
                    settings.pole_name = nil
                    settings.pole_quality = nil
                end
            end
            if settings.beacon_name then
                local proto = prototypes.entity[settings.beacon_name]
                local recipe = player.force.recipes[settings.beacon_name]
                if not proto or (recipe and not recipe.enabled) then
                    settings.beacon_name = nil
                    settings.beacon_quality = nil
                    settings.beacon_module_name = nil
                    settings.beacon_module_count = nil
                end
            end
            if settings.module_name and not prototypes.item[settings.module_name] then
                settings.module_name = nil
            end
            if settings.beacon_module_name and not prototypes.item[settings.beacon_module_name] then
                settings.beacon_module_name = nil
            end

            -- Skip GUI, go straight to placement
            player.print({"mineore.using-remembered-settings"})
            placer.place(player, scan_results, settings)
            if not player.clear_cursor() then
                player.print({"mineore.cursor-not-cleared-warning"})
            end
            return
        end
    end

    -- Show configuration GUI
    config_gui.create(player, scan_results, player_data)
end)

-- Handle alt-selection (shift-drag to remove ghost entities)
script.on_event(defines.events.on_player_alt_selected_area, function(event)
    if event.item ~= SELECTION_TOOL_NAME then return end
    local player = game.get_player(event.player_index)
    if not player then return end

    -- Remove ghost mining drills, transport belts, electric poles, and beacons
    local removable_types = {
        ["mining-drill"] = true,
        ["transport-belt"] = true,
        ["underground-belt"] = true,
        ["pipe"] = true,
        ["pipe-to-ground"] = true,
        ["electric-pole"] = true,
        ["beacon"] = true,
    }

    local removed = 0
    for _, entity in pairs(event.entities) do
        if entity.valid and entity.name == "entity-ghost" then
            local ghost_name = entity.ghost_name
            local ghost_proto = prototypes.entity[ghost_name]
            if ghost_proto and removable_types[ghost_proto.type] then
                entity.destroy()
                removed = removed + 1
            end
        end
    end

    -- Also remove landfill tile ghosts in the selected area
    local surface = player.surface
    local tile_ghosts = surface.find_entities_filtered{
        area = {event.area.left_top, event.area.right_bottom},
        type = "tile-ghost",
    }
    for _, tg in pairs(tile_ghosts) do
        if tg.valid then
            tg.destroy()
            removed = removed + 1
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

    if not player.clear_cursor() then
        player.print({"mineore.cursor-not-cleared-warning"})
    end
end)

-- GUI event handlers

-- Handle button clicks (Place, Cancel, Close, and icon selector buttons)
script.on_event(defines.events.on_gui_click, function(event)
    local element = event.element
    if not element or not element.valid then return end
    if not config_gui.is_mineore_element(element) then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    -- Handle locked choose-elem-button clicks (icon selectors)
    if config_gui.handle_selector_click(element) then
        return
    end

    if element.name == "mineore_close_button" or element.name == "mineore_cancel_button" then
        local player_data = get_player_data(event.player_index)
        player_data.gui_draft = nil
        config_gui.destroy(player)
        return
    end

    if element.name == "mineore_place_button" then
        local settings = config_gui.read_settings(player)
        if settings then
            local player_data = get_player_data(event.player_index)
            player_data.settings = settings
            player_data.gui_draft = nil

            config_gui.destroy(player)

            -- Place ghost entities using calculated grid positions
            if player_data.last_scan then
                placer.place(player, player_data.last_scan, settings)
                if not player.clear_cursor() then
                    player.print({"mineore.cursor-not-cleared-warning"})
                end
            end
        end
        return
    end
end)

-- Handle radiobutton changes (placement mode and belt orientation)
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

    -- When the resource dropdown changes, rebuild the GUI so that
    -- fluid-dependent sections (drill filtering, pipe selector) update.
    if element.name == "mineore_resource_dropdown" then
        local player = game.get_player(event.player_index)
        if not player then return end
        local player_data = get_player_data(event.player_index)
        if not player_data.last_scan then return end

        -- Snapshot current GUI state into a draft so the rebuild preserves choices
        -- without persisting to player_data.settings (which drives auto-skip).
        local current = config_gui.read_settings(player)
        if current then
            -- Update resource_name from the dropdown that just changed
            local resource_names = element.tags.resource_names
            if resource_names and element.selected_index > 0 then
                current.resource_name = resource_names[element.selected_index]
            end
            player_data.gui_draft = current
        end

        config_gui.create(player, player_data.last_scan, player_data)
        return
    end
    -- No additional action needed for other dropdowns - selection is read when Place is clicked
end)

-- Handle choose-elem-button value changes (unlocked module pickers)
script.on_event(defines.events.on_gui_elem_changed, function(event)
    local element = event.element
    if not element or not element.valid then return end
    if not config_gui.is_mineore_element(element) then return end
    -- No additional action needed - value is read when Place is clicked
end)

-- Handle ESC key closing the GUI
script.on_event(defines.events.on_gui_closed, function(event)
    local element = event.element
    if not element or not element.valid then return end

    if element.name == "mineore_config_frame" then
        local player_data = get_player_data(event.player_index)
        player_data.gui_draft = nil
        element.destroy()
    end
end)
