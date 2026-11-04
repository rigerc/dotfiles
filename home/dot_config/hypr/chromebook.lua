-- Chromebook-only resource-saving overrides, applied after shared modules.
-- The general bindings, application rules and session startup stay unchanged.
-- No panel, connector name, keyboard mapping or GPU driver is assumed.
hl.config({
    general = { gaps_in = 4, gaps_out = 7 },
    scrolling = { column_width = 0.65, focus_fit_method = 1 },
    decoration = {
        rounding = 8,
        blur = { enabled = false },
        shadow = { enabled = false },
    },
    animations = { enabled = false },
    input = {
        touchpad = { disable_while_typing = true, scroll_factor = 0.75 },
    },
})
