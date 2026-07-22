-- Custom GUI styles for Miner Planner
-- Mostly uses built-in Factorio styles (slot_sized_button / slot_sized_button_pressed).

local styles = data.raw["gui-style"].default

-- Horizontally-scrollable container for entity selector icon rows.
-- With many modded entities the icons overflow the fixed-width row; wrapping the
-- icon flow in this pane keeps the off-screen icons reachable via a scrollbar
-- instead of clipping them. Parented off naked_scroll_pane so it stays visually
-- flush with the compact row layout (no inset frame / background).
local parent_style = styles["naked_scroll_pane"] and "naked_scroll_pane" or "scroll_pane"
styles["mineore_selector_scroll_pane"] = {
    type = "scroll_pane_style",
    parent = parent_style,
    horizontally_stretchable = "on",
    vertically_stretchable = "off",
    padding = 0,
    extra_padding_when_activated = 0,
    vertical_flow_style = {
        type = "vertical_flow_style",
        vertical_align = "center",
    },
}
