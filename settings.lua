-- Miner Planner - Mod settings

data:extend({
    {
        type = "string-setting",
        name = "mineore-default-mode",
        setting_type = "runtime-per-user",
        default_value = "normal",
        allowed_values = {"productivity", "normal", "efficient"},
        order = "a",
    },
    {
        type = "bool-setting",
        name = "mineore-show-gui-always",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "b",
    },
})
