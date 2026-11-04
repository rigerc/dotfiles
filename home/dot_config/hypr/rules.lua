-- Application rules adapted from the active desktop; no DMS dependencies.
hl.window_rule({
    match = { class = "^(zen|dev\\.zed\\.Zed|spotify|feishin)$" },
    scrolling_width = 0.8,
})

hl.window_rule({ match = { class = "^org\\.wezfurlong\\.wezterm$" }, tile = true })
hl.window_rule({ match = { class = "^org\\.gnome\\..*$" }, rounding = 12 })
hl.window_rule({ match = { class = "^gnome-control-center$" }, tile = true })
hl.window_rule({ match = { class = "^pavucontrol$" }, tile = true })
hl.window_rule({ match = { class = "^(battlenet\\.exe|Battle\\.net)$" }, tile = true })
hl.window_rule({ match = { class = "^nm-connection-editor$" }, tile = true })
hl.window_rule({ match = { class = "^(org\\.gnome\\.Calculator|gnome-calculator|galculator)$" }, float = true })
hl.window_rule({ match = { class = "^blueman-manager$" }, float = true })
hl.window_rule({ match = { class = "^xdg-desktop-portal$" }, float = true })
hl.window_rule({ match = { class = "^zoom$" }, float = true })

hl.window_rule({
    match = { class = "^steam$", title = "^notificationtoasts" },
    no_initial_focus = true,
    pin = true,
})
hl.window_rule({
    match = { class = "^firefox$", title = "^Picture-in-Picture$" },
    float = true,
})

hl.window_rule({
    match = { class = "^dev\\.noctalia\\.Noctalia$" },
    float = true,
    size = { 1080, 920 },
})
