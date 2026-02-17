-- Configuration GUI - Shows after area selection for drill/mode/direction configuration

local gui = {}

local FRAME_NAME = "mineore_config_frame"
local PLACEMENT_MODES = {"productivity", "normal", "efficient"}

--- Destroy the config GUI for a player if it exists.
--- @param player LuaPlayer
function gui.destroy(player)
    local frame = player.gui.screen[FRAME_NAME]
    if frame then
        frame.destroy()
    end
end

--- Create and show the configuration GUI after a resource scan.
--- @param player LuaPlayer
--- @param scan_results table Results from resource_scanner.scan()
--- @param player_data table Per-player storage table
function gui.create(player, scan_results, player_data)
    gui.destroy(player)

    local settings = player_data.settings or {}

    -- Main frame
    local main_frame = player.gui.screen.add{
        type = "frame",
        name = FRAME_NAME,
        direction = "vertical",
    }
    main_frame.auto_center = true

    -- Titlebar
    local titlebar = main_frame.add{
        type = "flow",
        name = "titlebar",
        direction = "horizontal",
    }
    titlebar.drag_target = main_frame

    titlebar.add{
        type = "label",
        caption = {"mineore.gui-title"},
        style = "frame_title",
        ignored_by_interaction = true,
    }

    local drag_handle = titlebar.add{
        type = "empty-widget",
        style = "draggable_space_header",
        ignored_by_interaction = true,
    }
    drag_handle.style.height = 24
    drag_handle.style.horizontally_stretchable = true

    titlebar.add{
        type = "sprite-button",
        name = "mineore_close_button",
        sprite = "utility/close",
        style = "frame_action_button",
        tooltip = {"gui.close"},
    }

    -- Content area
    local content = main_frame.add{
        type = "frame",
        name = "content",
        direction = "vertical",
        style = "inside_shallow_frame_with_padding",
    }

    local inner = content.add{
        type = "flow",
        name = "inner",
        direction = "vertical",
    }
    inner.style.vertical_spacing = 8
    inner.style.minimal_width = 300

    -- Resource info section
    gui._add_resource_info(inner, scan_results)

    -- Separator
    inner.add{type = "line", direction = "horizontal"}

    -- Drill selector
    gui._add_drill_selector(inner, scan_results, settings)

    -- Separator
    inner.add{type = "line", direction = "horizontal"}

    -- Placement mode selector
    gui._add_mode_selector(inner, settings)

    -- Separator
    inner.add{type = "line", direction = "horizontal"}

    -- Direction selector
    gui._add_direction_selector(inner, settings)

    -- Separator
    inner.add{type = "line", direction = "horizontal"}

    -- Module selector
    gui._add_module_selector(inner, scan_results, settings)

    -- Quality selector (Space Age only)
    if script.feature_flags.quality then
        inner.add{type = "line", direction = "horizontal"}
        gui._add_quality_selector(inner, settings)
    end

    -- Separator
    inner.add{type = "line", direction = "horizontal"}

    -- Remember settings checkbox
    inner.add{
        type = "checkbox",
        name = "mineore_remember_checkbox",
        caption = {"mineore.gui-remember-settings"},
        tooltip = {"mineore.gui-remember-tooltip"},
        state = settings.remember or false,
    }

    -- Action buttons
    local button_flow = inner.add{
        type = "flow",
        name = "button_flow",
        direction = "horizontal",
    }
    button_flow.style.horizontal_spacing = 8
    button_flow.style.top_margin = 4
    button_flow.style.horizontally_stretchable = true
    button_flow.style.horizontal_align = "right"

    button_flow.add{
        type = "button",
        name = "mineore_cancel_button",
        caption = {"mineore.gui-cancel"},
        style = "back_button",
    }

    button_flow.add{
        type = "button",
        name = "mineore_place_button",
        caption = {"mineore.gui-place"},
        style = "confirm_button",
    }

    -- Register so ESC closes the GUI
    player.opened = main_frame
end

--- Add resource info labels to the GUI.
--- @param parent LuaGuiElement
--- @param scan_results table
function gui._add_resource_info(parent, scan_results)
    parent.add{
        type = "label",
        caption = {"mineore.gui-resources-header"},
        style = "caption_label",
    }

    for name, group in pairs(scan_results.resource_groups) do
        local flow = parent.add{
            type = "flow",
            direction = "horizontal",
        }
        flow.style.vertical_align = "center"

        flow.add{
            type = "sprite",
            sprite = "entity/" .. name,
        }

        flow.add{
            type = "label",
            caption = {"mineore.gui-resource-line", name, group.count},
        }
    end
end

--- Add drill selector dropdown to the GUI.
--- @param parent LuaGuiElement
--- @param scan_results table
--- @param settings table Player settings
function gui._add_drill_selector(parent, scan_results, settings)
    parent.add{
        type = "label",
        caption = {"mineore.gui-drill-header"},
        style = "caption_label",
    }

    local drill_names = {}
    local drill_captions = {}
    local selected_index = 1

    for i, drill in ipairs(scan_results.compatible_drills) do
        drill_names[i] = drill.name
        drill_captions[i] = drill.localised_name
        if settings.drill_name and settings.drill_name == drill.name then
            selected_index = i
        end
    end

    local dropdown = parent.add{
        type = "drop-down",
        name = "mineore_drill_dropdown",
        items = drill_captions,
        selected_index = selected_index,
    }
    dropdown.style.horizontally_stretchable = true

    -- Store drill name mapping as tags for later retrieval
    dropdown.tags = {drill_names = drill_names}
end

--- Add placement mode radio buttons to the GUI.
--- @param parent LuaGuiElement
--- @param settings table Player settings
function gui._add_mode_selector(parent, settings)
    parent.add{
        type = "label",
        caption = {"mineore.gui-mode-header"},
        style = "caption_label",
    }

    local current_mode = settings.placement_mode or "normal"

    for _, mode in ipairs(PLACEMENT_MODES) do
        parent.add{
            type = "radiobutton",
            name = "mineore_mode_" .. mode,
            caption = {"mineore.gui-mode-" .. mode},
            tooltip = {"mineore.gui-mode-" .. mode .. "-tooltip"},
            state = (mode == current_mode),
        }
    end
end

--- Add direction selector to the GUI.
--- @param parent LuaGuiElement
--- @param settings table Player settings
function gui._add_direction_selector(parent, settings)
    parent.add{
        type = "label",
        caption = {"mineore.gui-direction-header"},
        style = "caption_label",
    }

    local current_dir = settings.direction or "north"
    local directions = {"north", "south", "east", "west"}

    local flow = parent.add{
        type = "flow",
        name = "direction_flow",
        direction = "horizontal",
    }
    flow.style.horizontal_spacing = 8

    for _, dir in ipairs(directions) do
        flow.add{
            type = "radiobutton",
            name = "mineore_dir_" .. dir,
            caption = {"mineore.gui-dir-" .. dir},
            state = (dir == current_dir),
        }
    end
end

--- Add module selector to the GUI.
--- @param parent LuaGuiElement
--- @param scan_results table
--- @param settings table Player settings
function gui._add_module_selector(parent, scan_results, settings)
    parent.add{
        type = "label",
        caption = {"mineore.gui-module-header"},
        style = "caption_label",
    }

    -- Get the currently selected drill to check module slots
    local drill_index = settings.drill_name and 1 or 1
    for i, drill in ipairs(scan_results.compatible_drills) do
        if settings.drill_name and settings.drill_name == drill.name then
            drill_index = i
            break
        end
    end
    local selected_drill = scan_results.compatible_drills[drill_index]
    local max_slots = selected_drill and selected_drill.module_inventory_size or 0

    if max_slots == 0 then
        parent.add{
            type = "label",
            name = "mineore_no_modules_label",
            caption = {"mineore.gui-no-module-slots"},
        }
        return
    end

    -- Find compatible modules for the selected drill
    local module_names, module_captions = gui._get_compatible_modules(selected_drill)

    -- Module type dropdown
    local mod_flow = parent.add{
        type = "flow",
        name = "module_flow",
        direction = "horizontal",
    }
    mod_flow.style.vertical_align = "center"
    mod_flow.style.horizontal_spacing = 8

    -- "None" option + compatible modules
    local items = {{"mineore.gui-module-none"}}
    local selected_mod_index = 1
    for i, caption in ipairs(module_captions) do
        items[#items + 1] = caption
        if settings.module_name and settings.module_name == module_names[i] then
            selected_mod_index = i + 1
        end
    end

    local mod_dropdown = mod_flow.add{
        type = "drop-down",
        name = "mineore_module_dropdown",
        items = items,
        selected_index = selected_mod_index,
    }
    mod_dropdown.style.horizontally_stretchable = true
    mod_dropdown.tags = {module_names = module_names}

    -- Module count slider
    mod_flow.add{
        type = "label",
        caption = "x",
    }

    local current_count = settings.module_count or max_slots
    if current_count > max_slots then current_count = max_slots end

    local count_dropdown_items = {}
    for i = 1, max_slots do
        count_dropdown_items[i] = tostring(i)
    end

    mod_flow.add{
        type = "drop-down",
        name = "mineore_module_count",
        items = count_dropdown_items,
        selected_index = current_count,
        tags = {max_slots = max_slots},
    }
end

--- Get compatible module prototypes for a drill.
--- @param drill table Drill info from scan results
--- @return string[] module_names
--- @return LocalisedString[] module_captions
function gui._get_compatible_modules(drill)
    local all_modules = prototypes.get_item_filtered({{filter = "type", type = "module"}})

    -- Get drill prototype for allowed_effects and allowed_module_categories
    local drill_proto = prototypes.entity[drill.name]
    local allowed_effects = drill_proto and drill_proto.allowed_effects or nil
    local allowed_categories = drill_proto and drill_proto.allowed_module_categories or nil

    local module_names = {}
    local module_captions = {}

    for mod_name, mod_proto in pairs(all_modules) do
        local category_ok = true
        if allowed_categories then
            category_ok = (allowed_categories[mod_proto.category] == true)
        end

        local effect_ok = true
        if allowed_effects and mod_proto.module_effects then
            for effect_name, _ in pairs(mod_proto.module_effects) do
                if not allowed_effects[effect_name] then
                    effect_ok = false
                    break
                end
            end
        end

        if category_ok and effect_ok then
            module_names[#module_names + 1] = mod_name
            module_captions[#module_captions + 1] = mod_proto.localised_name
        end
    end

    -- Sort by name for consistent ordering
    local indices = {}
    for i = 1, #module_names do indices[i] = i end
    table.sort(indices, function(a, b) return module_names[a] < module_names[b] end)

    local sorted_names = {}
    local sorted_captions = {}
    for _, idx in ipairs(indices) do
        sorted_names[#sorted_names + 1] = module_names[idx]
        sorted_captions[#sorted_captions + 1] = module_captions[idx]
    end

    return sorted_names, sorted_captions
end

--- Add quality selector to the GUI (Space Age only).
--- @param parent LuaGuiElement
--- @param settings table Player settings
function gui._add_quality_selector(parent, settings)
    parent.add{
        type = "label",
        caption = {"mineore.gui-quality-header"},
        style = "caption_label",
    }

    -- Get all quality prototypes sorted by level
    local qualities = {}
    for name, quality in pairs(prototypes.quality) do
        if not quality.hidden then
            qualities[#qualities + 1] = {name = name, localised_name = quality.localised_name, level = quality.level}
        end
    end
    table.sort(qualities, function(a, b) return a.level < b.level end)

    local quality_names = {}
    local quality_captions = {}
    local selected_index = 1
    for i, q in ipairs(qualities) do
        quality_names[i] = q.name
        quality_captions[i] = q.localised_name
        if settings.quality and settings.quality == q.name then
            selected_index = i
        end
    end

    local dropdown = parent.add{
        type = "drop-down",
        name = "mineore_quality_dropdown",
        items = quality_captions,
        selected_index = selected_index,
    }
    dropdown.style.horizontally_stretchable = true
    dropdown.tags = {quality_names = quality_names}
end

--- Read the current GUI selections and return a settings table.
--- @param player LuaPlayer
--- @return table|nil settings {drill_name, placement_mode, direction, remember}
function gui.read_settings(player)
    local frame = player.gui.screen[FRAME_NAME]
    if not frame then return nil end

    local inner = frame.content.inner
    local settings = {}

    -- Read drill selection
    local dropdown = inner.mineore_drill_dropdown
    if dropdown and dropdown.selected_index > 0 then
        local drill_names = dropdown.tags.drill_names
        settings.drill_name = drill_names[dropdown.selected_index]
    end

    -- Read placement mode
    for _, mode in ipairs(PLACEMENT_MODES) do
        local radio = inner["mineore_mode_" .. mode]
        if radio and radio.state then
            settings.placement_mode = mode
            break
        end
    end

    -- Read direction
    local directions = {"north", "south", "east", "west"}
    local dir_flow = inner.direction_flow
    for _, dir in ipairs(directions) do
        local radio = dir_flow["mineore_dir_" .. dir]
        if radio and radio.state then
            settings.direction = dir
            break
        end
    end

    -- Read module selection
    local mod_flow = inner.module_flow
    if mod_flow then
        local mod_dropdown = mod_flow.mineore_module_dropdown
        if mod_dropdown and mod_dropdown.selected_index > 1 then
            local module_names = mod_dropdown.tags.module_names
            settings.module_name = module_names[mod_dropdown.selected_index - 1]
        end

        local count_dropdown = mod_flow.mineore_module_count
        if count_dropdown then
            settings.module_count = count_dropdown.selected_index
        end
    end

    -- Read quality selection (Space Age only)
    local quality_dropdown = inner.mineore_quality_dropdown
    if quality_dropdown and quality_dropdown.selected_index > 0 then
        local quality_names = quality_dropdown.tags.quality_names
        settings.quality = quality_names[quality_dropdown.selected_index]
    end

    -- Read remember checkbox
    local remember = inner.mineore_remember_checkbox
    if remember then
        settings.remember = remember.state
    end

    return settings
end

--- Handle radio button state changes (uncheck siblings in the same group).
--- @param element LuaGuiElement The changed radiobutton
function gui.handle_radio_change(element)
    if not element or not element.valid then return end
    local name = element.name

    -- Placement mode radios
    if name:find("^mineore_mode_") then
        local parent = element.parent
        for _, mode in ipairs(PLACEMENT_MODES) do
            local sibling = parent["mineore_mode_" .. mode]
            if sibling and sibling ~= element then
                sibling.state = false
            end
        end
        element.state = true
        return
    end

    -- Direction radios
    if name:find("^mineore_dir_") then
        local parent = element.parent
        local directions = {"north", "south", "east", "west"}
        for _, dir in ipairs(directions) do
            local sibling = parent["mineore_dir_" .. dir]
            if sibling and sibling ~= element then
                sibling.state = false
            end
        end
        element.state = true
        return
    end
end

--- Check if a GUI element belongs to this mod's config GUI.
--- @param element LuaGuiElement
--- @return boolean
function gui.is_mineore_element(element)
    if not element or not element.valid then return false end
    -- Walk up to find the root frame
    local current = element
    while current do
        if current.name == FRAME_NAME then
            return true
        end
        current = current.parent
    end
    return false
end

return gui
