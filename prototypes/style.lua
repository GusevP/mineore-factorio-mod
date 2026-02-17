-- Custom GUI styles for Miner Planner

local styles = data.raw["gui-style"].default

-- Minimal custom styles - mostly rely on built-in Factorio styles
-- These are only defined where we need specific sizing or spacing

styles["mineore_config_content"] = {
    type = "frame_style",
    parent = "inside_shallow_frame_with_padding",
    padding = 12,
}
