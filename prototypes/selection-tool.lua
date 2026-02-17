local selection_tool = {
    type = "selection-tool",
    name = "mineore-selection-tool",
    icon = "__mineore__/graphics/icons/steel-axe.png",
    icon_size = 64,
    subgroup = "tool",
    order = "c[automated-construction]-d[mineore]",
    stack_size = 1,
    hidden = true,
    select = {
        border_color = {r = 0.0, g = 0.8, b = 0.0, a = 0.7},
        cursor_box_type = "copy",
        mode = {"any-entity"},
        entity_type_filters = {"resource"},
        entity_filter_mode = "whitelist",
    },
    alt_select = {
        border_color = {r = 0.8, g = 0.0, b = 0.0, a = 0.7},
        cursor_box_type = "not-allowed",
        mode = {"entity-ghost", "same-force"},
    },
    alt_reverse_select = {
        border_color = {r = 0.8, g = 0.0, b = 0.0, a = 0.7},
        cursor_box_type = "not-allowed",
        mode = {"entity-ghost", "same-force"},
    },
}

data:extend({selection_tool})
