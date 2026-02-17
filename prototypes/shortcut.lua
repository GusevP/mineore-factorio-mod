local shortcut = {
    type = "shortcut",
    name = "miner-planner-shortcut",
    localised_name = {"shortcut.miner-planner"},
    action = "lua",
    icon = "__base__/graphics/icons/steel-axe.png",
    icon_size = 64,
    small_icon = "__base__/graphics/icons/steel-axe.png",
    small_icon_size = 64,
    associated_control_input = "miner-planner-toggle",
    order = "m[miner-planner]",
}

local custom_input = {
    type = "custom-input",
    name = "miner-planner-toggle",
    key_sequence = "ALT + M",
    consuming = "none",
}

data:extend({shortcut, custom_input})
