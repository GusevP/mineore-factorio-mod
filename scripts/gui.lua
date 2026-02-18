-- Configuration GUI - Icon-based selectors following P.U.M.P. mod pattern

local gui = {}

local FRAME_NAME = "mineore_config_frame"
local PLACEMENT_MODES = {"productivity", "loose", "efficient"}

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

    -- Apply default placement mode from mod settings if no previous choice
    if not settings.placement_mode then
        settings.placement_mode = player.mod_settings["mineore-default-mode"].value
    end
    -- Migrate legacy "normal" to "loose"
    if settings.placement_mode == "normal" then
        settings.placement_mode = "loose"
    end

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
    inner.style.minimal_width = 340

    -- Resource info section
    gui._add_resource_info(inner, scan_results)

    -- Resource type selector (when multiple ore types are selected)
    local resource_names = {}
    for name, _ in pairs(scan_results.resource_groups) do
        resource_names[#resource_names + 1] = name
    end
    table.sort(resource_names)

    if #resource_names > 1 then
        inner.add{type = "line", direction = "horizontal"}
        gui._add_resource_selector(inner, resource_names, settings)
    end

    -- Separator
    inner.add{type = "line", direction = "horizontal"}

    -- Drill selector (icon buttons)
    gui._add_drill_selector(inner, scan_results, settings)

    -- Separator
    inner.add{type = "line", direction = "horizontal"}

    -- Belt type selector (icon buttons)
    gui._add_belt_selector(inner, settings)

    -- Separator
    inner.add{type = "line", direction = "horizontal"}

    -- Pole/substation selector (icon buttons)
    gui._add_pole_selector(inner, settings)

    -- Separator
    inner.add{type = "line", direction = "horizontal"}

    -- Beacon selector (icon buttons)
    gui._add_beacon_selector(inner, settings)

    -- Separator
    inner.add{type = "line", direction = "horizontal"}

    -- Placement mode selector
    gui._add_mode_selector(inner, settings)

    -- Separator
    inner.add{type = "line", direction = "horizontal"}

    -- Belt direction selector (N/S/E/W)
    gui._add_belt_direction_selector(inner, settings)

    -- Separator
    inner.add{type = "line", direction = "horizontal"}

    -- Drill module selector (choose-elem-button)
    gui._add_module_selector(inner, scan_results, settings)

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

--- Add resource type selector when multiple ore types are in the selection.
--- @param parent LuaGuiElement
--- @param resource_names string[] Sorted list of resource names
--- @param settings table Player settings
function gui._add_resource_selector(parent, resource_names, settings)
    parent.add{
        type = "label",
        caption = {"mineore.gui-resource-select-header"},
        style = "caption_label",
    }

    local captions = {}
    local selected_index = 1
    for i, name in ipairs(resource_names) do
        captions[i] = {"entity-name." .. name}
        if settings.resource_name and settings.resource_name == name then
            selected_index = i
        end
    end

    local dropdown = parent.add{
        type = "drop-down",
        name = "mineore_resource_dropdown",
        items = captions,
        selected_index = selected_index,
    }
    dropdown.style.horizontally_stretchable = true
    dropdown.tags = {resource_names = resource_names}
end

--- Add drill selector as a row of locked choose-elem-buttons.
--- @param parent LuaGuiElement
--- @param scan_results table
--- @param settings table Player settings
function gui._add_drill_selector(parent, scan_results, settings)
    parent.add{
        type = "label",
        caption = {"mineore.gui-drill-header"},
        style = "caption_label",
    }

    local flow = parent.add{
        type = "flow",
        name = "drill_selector_flow",
        direction = "horizontal",
    }
    flow.style.horizontal_spacing = 4

    local selected_name = settings.drill_name
    -- Default to first drill if no previous selection
    if not selected_name and #scan_results.compatible_drills > 0 then
        selected_name = scan_results.compatible_drills[1].name
    end

    for _, drill in ipairs(scan_results.compatible_drills) do
        local btn = flow.add{
            type = "choose-elem-button",
            name = "mineore_drill_btn_" .. drill.name,
            elem_type = "entity",
            entity = drill.name,
            style = "slot_sized_button",
            tooltip = drill.localised_name,
        }
        btn.locked = true
        btn.tags = {selector_group = "drill", entity_name = drill.name}
        if drill.name == selected_name then
            btn.style = "slot_sized_button_pressed"
        end
    end
end

--- Add belt type selector as locked choose-elem-buttons + "none" sprite-button.
--- @param parent LuaGuiElement
--- @param settings table Player settings
function gui._add_belt_selector(parent, settings)
    parent.add{
        type = "label",
        caption = {"mineore.gui-belt-header"},
        style = "caption_label",
    }

    local row = parent.add{
        type = "flow",
        name = "belt_selector_row",
        direction = "horizontal",
    }
    row.style.vertical_align = "center"
    row.style.horizontal_spacing = 4

    -- Belt icon buttons
    local belt_flow = row.add{
        type = "flow",
        name = "belt_selector_flow",
        direction = "horizontal",
    }
    belt_flow.style.horizontal_spacing = 4

    local belt_types = gui._get_transport_belt_types()
    local selected_belt = settings.belt_name
    local has_selection = false

    for _, belt_name in ipairs(belt_types) do
        local proto = prototypes.entity[belt_name]
        if proto then
            local btn = belt_flow.add{
                type = "choose-elem-button",
                name = "mineore_belt_btn_" .. belt_name,
                elem_type = "entity",
                entity = belt_name,
                style = "slot_sized_button",
                tooltip = proto.localised_name,
            }
            btn.locked = true
            btn.tags = {selector_group = "belt", entity_name = belt_name}
            if belt_name == selected_belt then
                btn.style = "slot_sized_button_pressed"
                has_selection = true
            end
        end
    end

    -- "None" button
    local none_btn = belt_flow.add{
        type = "sprite-button",
        name = "mineore_belt_none",
        sprite = "utility/close",
        style = "slot_sized_button",
        tooltip = {"mineore.gui-none"},
    }
    none_btn.tags = {selector_group = "belt", entity_name = ""}
    if not has_selection then
        none_btn.style = "slot_sized_button_pressed"
    end

    -- Quality dropdown for belts
    if script.feature_flags.quality then
        row.add{type = "empty-widget"}.style.width = 8
        gui._add_inline_quality_dropdown(row, "belt", settings.belt_quality or settings.quality)
    end
end

--- Add pole/substation selector as locked choose-elem-buttons + "none" sprite-button.
--- @param parent LuaGuiElement
--- @param settings table Player settings
function gui._add_pole_selector(parent, settings)
    parent.add{
        type = "label",
        caption = {"mineore.gui-pole-header"},
        style = "caption_label",
    }

    local row = parent.add{
        type = "flow",
        name = "pole_selector_row",
        direction = "horizontal",
    }
    row.style.vertical_align = "center"
    row.style.horizontal_spacing = 4

    local pole_flow = row.add{
        type = "flow",
        name = "pole_selector_flow",
        direction = "horizontal",
    }
    pole_flow.style.horizontal_spacing = 4

    local pole_types = gui._get_electric_pole_types()
    local selected_pole = settings.pole_name
    local has_selection = false

    for _, pole_name in ipairs(pole_types) do
        local proto = prototypes.entity[pole_name]
        if proto then
            local btn = pole_flow.add{
                type = "choose-elem-button",
                name = "mineore_pole_btn_" .. pole_name,
                elem_type = "entity",
                entity = pole_name,
                style = "slot_sized_button",
                tooltip = proto.localised_name,
            }
            btn.locked = true
            btn.tags = {selector_group = "pole", entity_name = pole_name}
            if pole_name == selected_pole then
                btn.style = "slot_sized_button_pressed"
                has_selection = true
            end
        end
    end

    -- "None" button
    local none_btn = pole_flow.add{
        type = "sprite-button",
        name = "mineore_pole_none",
        sprite = "utility/close",
        style = "slot_sized_button",
        tooltip = {"mineore.gui-none"},
    }
    none_btn.tags = {selector_group = "pole", entity_name = ""}
    if not has_selection then
        none_btn.style = "slot_sized_button_pressed"
    end

    -- Quality dropdown for poles
    if script.feature_flags.quality then
        row.add{type = "empty-widget"}.style.width = 8
        gui._add_inline_quality_dropdown(row, "pole", settings.pole_quality or settings.quality)
    end
end

--- Add beacon selector as locked choose-elem-buttons + "none" sprite-button,
--- plus beacon module selector as unlocked choose-elem-button.
--- @param parent LuaGuiElement
--- @param settings table Player settings
function gui._add_beacon_selector(parent, settings)
    parent.add{
        type = "label",
        caption = {"mineore.gui-beacon-header"},
        style = "caption_label",
    }

    local row = parent.add{
        type = "flow",
        name = "beacon_selector_row",
        direction = "horizontal",
    }
    row.style.vertical_align = "center"
    row.style.horizontal_spacing = 4

    local beacon_flow = row.add{
        type = "flow",
        name = "beacon_selector_flow",
        direction = "horizontal",
    }
    beacon_flow.style.horizontal_spacing = 4

    local beacon_types = gui._get_beacon_types()
    local selected_beacon = settings.beacon_name
    local has_selection = false

    for _, beacon_name in ipairs(beacon_types) do
        local proto = prototypes.entity[beacon_name]
        if proto then
            local btn = beacon_flow.add{
                type = "choose-elem-button",
                name = "mineore_beacon_btn_" .. beacon_name,
                elem_type = "entity",
                entity = beacon_name,
                style = "slot_sized_button",
                tooltip = proto.localised_name,
            }
            btn.locked = true
            btn.tags = {selector_group = "beacon", entity_name = beacon_name}
            if beacon_name == selected_beacon then
                btn.style = "slot_sized_button_pressed"
                has_selection = true
            end
        end
    end

    -- "None" button
    local none_btn = beacon_flow.add{
        type = "sprite-button",
        name = "mineore_beacon_none",
        sprite = "utility/close",
        style = "slot_sized_button",
        tooltip = {"mineore.gui-none"},
    }
    none_btn.tags = {selector_group = "beacon", entity_name = ""}
    if not has_selection then
        none_btn.style = "slot_sized_button_pressed"
    end

    -- Quality dropdown for beacons
    if script.feature_flags.quality then
        row.add{type = "empty-widget"}.style.width = 8
        gui._add_inline_quality_dropdown(row, "beacon", settings.beacon_quality or settings.quality)
    end

    -- Beacon module selector (unlocked choose-elem-button + count)
    local mod_row = parent.add{
        type = "flow",
        name = "beacon_module_row",
        direction = "horizontal",
    }
    mod_row.style.vertical_align = "center"
    mod_row.style.horizontal_spacing = 8
    mod_row.style.top_margin = 4

    mod_row.add{
        type = "label",
        caption = {"mineore.gui-beacon-module"},
    }

    local module_btn = mod_row.add{
        type = "choose-elem-button",
        name = "mineore_beacon_module_btn",
        elem_type = "item",
        item = settings.beacon_module_name,
        style = "slot_sized_button",
    }
    module_btn.elem_filters = {{filter = "type", type = "module"}}

    mod_row.add{
        type = "label",
        caption = "x",
    }

    -- Module count dropdown (1-8, default to what's configured or 2)
    local count_items = {}
    for i = 1, 8 do
        count_items[i] = tostring(i)
    end

    mod_row.add{
        type = "drop-down",
        name = "mineore_beacon_module_count",
        items = count_items,
        selected_index = settings.beacon_module_count or 2,
    }
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

    local current_mode = settings.placement_mode or "loose"

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

--- Add belt direction selector (4 arrow buttons for N/S/E/W).
--- @param parent LuaGuiElement
--- @param settings table Player settings
function gui._add_belt_direction_selector(parent, settings)
    parent.add{
        type = "label",
        caption = {"mineore.gui-belt-direction-header"},
        style = "caption_label",
    }

    -- Migrate legacy belt_orientation to direction
    local current = settings.belt_direction
    if not current then
        local orient = settings.belt_orientation
        if orient == "NS" then
            current = "south"
        elseif orient == "EW" then
            current = "east"
        else
            current = "south"
        end
    end

    local flow = parent.add{
        type = "flow",
        name = "belt_direction_flow",
        direction = "horizontal",
    }
    flow.style.horizontal_spacing = 4

    local directions = {"north", "south", "west", "east"}
    for _, dir in ipairs(directions) do
        local btn = flow.add{
            type = "sprite-button",
            name = "mineore_dir_" .. dir,
            caption = {"mineore.gui-dir-" .. dir .. "-icon"},
            tooltip = {"mineore.gui-dir-" .. dir .. "-tooltip"},
            style = "slot_sized_button",
        }
        btn.tags = {selector_group = "direction", direction = dir}
        if dir == current then
            btn.style = "slot_sized_button_pressed"
        end
    end
end

--- Add drill module selector as choose-elem-button + count dropdown.
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
    local selected_drill = nil
    for _, drill in ipairs(scan_results.compatible_drills) do
        if settings.drill_name and settings.drill_name == drill.name then
            selected_drill = drill
            break
        end
    end
    if not selected_drill and #scan_results.compatible_drills > 0 then
        selected_drill = scan_results.compatible_drills[1]
    end

    local max_slots = selected_drill and selected_drill.module_inventory_size or 0

    if max_slots == 0 then
        parent.add{
            type = "label",
            name = "mineore_no_modules_label",
            caption = {"mineore.gui-no-module-slots"},
        }
        return
    end

    local mod_flow = parent.add{
        type = "flow",
        name = "module_flow",
        direction = "horizontal",
    }
    mod_flow.style.vertical_align = "center"
    mod_flow.style.horizontal_spacing = 8

    -- Unlocked choose-elem-button for module selection
    local module_btn = mod_flow.add{
        type = "choose-elem-button",
        name = "mineore_drill_module_btn",
        elem_type = "item",
        item = settings.module_name,
        style = "slot_sized_button",
    }
    module_btn.elem_filters = {{filter = "type", type = "module"}}

    mod_flow.add{
        type = "label",
        caption = "x",
    }

    -- Module count dropdown
    local current_count = settings.module_count or max_slots
    if current_count > max_slots then current_count = max_slots end

    local count_items = {}
    for i = 1, max_slots do
        count_items[i] = tostring(i)
    end

    mod_flow.add{
        type = "drop-down",
        name = "mineore_module_count",
        items = count_items,
        selected_index = current_count,
        tags = {max_slots = max_slots},
    }
end

--- Add a quality dropdown inline in a row.
--- @param parent LuaGuiElement
--- @param prefix string Prefix for the dropdown name (e.g., "belt", "pole", "beacon")
--- @param current_quality string|nil Currently selected quality name
function gui._add_inline_quality_dropdown(parent, prefix, current_quality)
    local qualities = gui._get_quality_list()
    local quality_names = {}
    local quality_captions = {}
    local selected_index = 1

    for i, q in ipairs(qualities) do
        quality_names[i] = q.name
        quality_captions[i] = {"", "[quality=" .. q.name .. "] ", q.localised_name}
        if current_quality and current_quality == q.name then
            selected_index = i
        end
    end

    local dropdown = parent.add{
        type = "drop-down",
        name = "mineore_quality_" .. prefix,
        items = quality_captions,
        selected_index = selected_index,
    }
    dropdown.style.width = 120
    dropdown.tags = {quality_names = quality_names}
end

--- Get sorted list of visible quality prototypes.
--- @return table[] Array of {name, localised_name, level}
function gui._get_quality_list()
    local qualities = {}
    for name, quality in pairs(prototypes.quality) do
        if not quality.hidden then
            qualities[#qualities + 1] = {
                name = name,
                localised_name = quality.localised_name,
                level = quality.level,
            }
        end
    end
    table.sort(qualities, function(a, b) return a.level < b.level end)
    return qualities
end

--- Get all transport belt prototype names sorted by speed.
--- @return string[] Array of belt prototype names
function gui._get_transport_belt_types()
    local belts = prototypes.get_entity_filtered({{filter = "type", type = "transport-belt"}})
    local belt_list = {}
    for name, proto in pairs(belts) do
        belt_list[#belt_list + 1] = {name = name, speed = proto.belt_speed or 0}
    end
    table.sort(belt_list, function(a, b) return a.speed < b.speed end)

    local names = {}
    for _, b in ipairs(belt_list) do
        names[#names + 1] = b.name
    end
    return names
end

--- Get all electric pole prototype names sorted by supply area.
--- @return string[] Array of pole prototype names
function gui._get_electric_pole_types()
    local poles = prototypes.get_entity_filtered({{filter = "type", type = "electric-pole"}})
    local pole_list = {}
    for name, proto in pairs(poles) do
        -- Only include 1x1 poles (filter out substations, big electric poles, etc.)
        local cbox = proto.collision_box
        local width = math.ceil(cbox.right_bottom.x - cbox.left_top.x)
        local height = math.ceil(cbox.right_bottom.y - cbox.left_top.y)
        if width <= 1 and height <= 1 then
            pole_list[#pole_list + 1] = {
                name = name,
                supply_area = proto.get_supply_area_distance() or 0,
            }
        end
    end
    table.sort(pole_list, function(a, b) return a.supply_area < b.supply_area end)

    local names = {}
    for _, p in ipairs(pole_list) do
        names[#names + 1] = p.name
    end
    return names
end

--- Get all beacon prototype names.
--- @return string[] Array of beacon prototype names
function gui._get_beacon_types()
    local beacons = prototypes.get_entity_filtered({{filter = "type", type = "beacon"}})
    local beacon_list = {}
    for name, _ in pairs(beacons) do
        beacon_list[#beacon_list + 1] = name
    end
    table.sort(beacon_list)
    return beacon_list
end

--- Read the current GUI selections and return a settings table.
--- @param player LuaPlayer
--- @return table|nil settings
function gui.read_settings(player)
    local frame = player.gui.screen[FRAME_NAME]
    if not frame then return nil end

    local inner = frame.content.inner
    local settings = {}

    -- Read resource type selection (when multiple ore types)
    local res_dropdown = inner.mineore_resource_dropdown
    if res_dropdown and res_dropdown.selected_index > 0 then
        local resource_names = res_dropdown.tags.resource_names
        settings.resource_name = resource_names[res_dropdown.selected_index]
    end

    -- Read drill selection (from icon buttons)
    settings.drill_name = gui._read_selector_group(inner, "drill_selector_flow", "drill")

    -- Read belt selection (belt_selector_flow is nested inside belt_selector_row)
    local belt_row = inner.belt_selector_row
    if belt_row then
        local belt_flow = belt_row.belt_selector_flow
        settings.belt_name = gui._read_selector_from_flow(belt_flow, "belt")
    end

    -- Read pole selection
    local pole_row = inner.pole_selector_row
    if pole_row then
        local pole_flow = pole_row.pole_selector_flow
        settings.pole_name = gui._read_selector_from_flow(pole_flow, "pole")
    end

    -- Read beacon selection
    local beacon_row = inner.beacon_selector_row
    if beacon_row then
        local beacon_flow = beacon_row.beacon_selector_flow
        settings.beacon_name = gui._read_selector_from_flow(beacon_flow, "beacon")
    end

    -- Read beacon module
    local beacon_mod_row = inner.beacon_module_row
    if beacon_mod_row then
        local mod_btn = beacon_mod_row.mineore_beacon_module_btn
        if mod_btn and mod_btn.elem_value then
            settings.beacon_module_name = mod_btn.elem_value
        end
        local count_dd = beacon_mod_row.mineore_beacon_module_count
        if count_dd then
            settings.beacon_module_count = count_dd.selected_index
        end
    end

    -- Read placement mode
    for _, mode in ipairs(PLACEMENT_MODES) do
        local radio = inner["mineore_mode_" .. mode]
        if radio and radio.state then
            settings.placement_mode = mode
            break
        end
    end

    -- Read belt direction (N/S/E/W icon buttons)
    local dir_flow = inner.belt_direction_flow
    if dir_flow then
        for _, child in pairs(dir_flow.children) do
            if child.tags and child.tags.selector_group == "direction"
                and child.style and child.style.name == "slot_sized_button_pressed" then
                settings.belt_direction = child.tags.direction
                break
            end
        end
    end
    -- Derive belt_orientation from direction for backward compatibility
    if settings.belt_direction == "north" or settings.belt_direction == "south" then
        settings.belt_orientation = "NS"
    elseif settings.belt_direction == "west" or settings.belt_direction == "east" then
        settings.belt_orientation = "EW"
    else
        settings.belt_orientation = "NS"
    end

    -- Read drill module selection
    local mod_flow = inner.module_flow
    if mod_flow then
        local mod_btn = mod_flow.mineore_drill_module_btn
        if mod_btn and mod_btn.elem_value then
            settings.module_name = mod_btn.elem_value
        end

        local count_dropdown = mod_flow.mineore_module_count
        if count_dropdown then
            settings.module_count = count_dropdown.selected_index
        end
    end

    -- Read per-entity quality selections (Space Age only)
    if script.feature_flags.quality then
        settings.belt_quality = gui._read_quality_dropdown(belt_row, "belt")
        settings.pole_quality = gui._read_quality_dropdown(pole_row, "pole")
        settings.beacon_quality = gui._read_quality_dropdown(beacon_row, "beacon")
        -- Use belt quality as the general quality fallback, or "normal"
        settings.quality = settings.belt_quality or "normal"
    end

    -- Read remember checkbox
    local remember = inner.mineore_remember_checkbox
    if remember then
        settings.remember = remember.state
    end

    return settings
end

--- Read a quality dropdown value from a parent flow.
--- @param parent LuaGuiElement|nil
--- @param prefix string
--- @return string|nil quality name
function gui._read_quality_dropdown(parent, prefix)
    if not parent then return nil end
    local dropdown = parent["mineore_quality_" .. prefix]
    if dropdown and dropdown.selected_index > 0 then
        local quality_names = dropdown.tags.quality_names
        return quality_names[dropdown.selected_index]
    end
    return nil
end

--- Read the selected entity name from a flow of selector buttons.
--- @param flow LuaGuiElement The flow containing the buttons
--- @param group string The selector group name
--- @return string|nil Selected entity name, or nil/"" for none
function gui._read_selector_from_flow(flow, group)
    if not flow then return nil end
    for _, child in pairs(flow.children) do
        if child.tags and child.tags.selector_group == group then
            -- Check if this button has the selected style
            if child.style and child.style.name == "slot_sized_button_pressed" then
                local name = child.tags.entity_name
                if name == "" then return nil end
                return name
            end
        end
    end
    return nil
end

--- Read the selected entity from a direct child flow (legacy helper).
--- @param parent LuaGuiElement
--- @param flow_name string
--- @param group string
--- @return string|nil
function gui._read_selector_group(parent, flow_name, group)
    local flow = parent[flow_name]
    return gui._read_selector_from_flow(flow, group)
end

--- Handle click on a locked choose-elem-button to toggle selection.
--- Updates the pressed/unpressed style for the group.
--- @param element LuaGuiElement The clicked element
--- @return boolean handled Whether this was a selector click
function gui.handle_selector_click(element)
    if not element or not element.valid then return false end
    local tags = element.tags
    if not tags or not tags.selector_group then return false end

    local group = tags.selector_group
    local parent = element.parent

    -- Unselect all siblings in the same group
    for _, sibling in pairs(parent.children) do
        if sibling.tags and sibling.tags.selector_group == group then
            sibling.style = "slot_sized_button"
        end
    end

    -- Select the clicked button
    element.style = "slot_sized_button_pressed"
    return true
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

    -- Belt direction buttons are handled by handle_selector_click, not here
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
