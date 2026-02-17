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
