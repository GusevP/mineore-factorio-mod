local shortcut = {
    type = "shortcut",
    name = "mineore-shortcut",
    localised_name = {"shortcut.mineore"},
    action = "lua",
    icon = "__mineore__/graphics/icons/mineore_icon_64.png",
    icon_size = 64,
    small_icon = "__mineore__/graphics/icons/mineore_icon_64.png",
    small_icon_size = 64,
    associated_control_input = "mineore-toggle",
    order = "m[mineore]",
}

local custom_input = {
    type = "custom-input",
    name = "mineore-toggle",
    key_sequence = "ALT + M",
    consuming = "none",
}

data:extend({shortcut, custom_input})
