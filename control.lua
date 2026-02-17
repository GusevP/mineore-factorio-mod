-- Miner Planner - Main runtime control
-- Handles event registration and dispatching

-- Initialize global storage on mod load
script.on_init(function()
    storage.players = storage.players or {}
end)

script.on_configuration_changed(function()
    storage.players = storage.players or {}
end)

-- Track new players joining
script.on_event(defines.events.on_player_created, function(event)
    storage.players[event.player_index] = storage.players[event.player_index] or {}
end)

-- Selection tool events will be registered in later tasks
-- script.on_event(defines.events.on_player_selected_area, ...)
-- script.on_event(defines.events.on_player_alt_selected_area, ...)
-- script.on_event(defines.events.on_lua_shortcut, ...)
