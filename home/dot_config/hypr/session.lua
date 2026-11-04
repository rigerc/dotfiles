-- Runs only at the next compositor startup, not when the config is reloaded.
hl.on("hyprland.start", function()
    hl.exec_cmd("noctalia")
    hl.exec_cmd("command -v vicinae >/dev/null 2>&1 && vicinae server")
end)
