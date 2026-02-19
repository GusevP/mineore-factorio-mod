-- Miner Planner - Mod settings

data:extend({
    {
        type = "string-setting",
        name = "mineore-default-mode",
        setting_type = "runtime-per-user",
        default_value = "efficient",
        allowed_values = {"productivity", "efficient"},
        order = "a",
    },
    {
        type = "bool-setting",
        name = "mineore-show-gui-always",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "b",
    },
    {
        type = "int-setting",
        name = "mineore-max-beacons-per-drill",
        setting_type = "runtime-per-user",
        default_value = 4,
        minimum_value = 1,
        maximum_value = 12,
        order = "c",
    },
    {
        type = "int-setting",
        name = "mineore-preferred-beacons-per-drill",
        setting_type = "runtime-per-user",
        default_value = 1,
        minimum_value = 0,
        maximum_value = 12,
        order = "d",
    },
})
