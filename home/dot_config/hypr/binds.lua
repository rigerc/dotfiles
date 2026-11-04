-- Adapted from the active Hyprland + Noctalia session, independently of chezmoi.
-- Commands use the desktop session's PATH; dependency installation is separate.
local ipc = "noctalia msg "
local terminal = require("terminal")

local function run_or_raise(class, command)
    return hl.dsp.exec_cmd(
        "if command -v hyprsummon >/dev/null 2>&1; then "
        .. "hyprsummon run --class " .. class .. " --current-workspace-only -- " .. command
        .. "; else " .. command .. "; fi"
    )
end

-- Prefer Vicinae when installed; otherwise use the built-in Noctalia launcher.
hl.bind("SUPER + Space", hl.dsp.exec_cmd(
    "if command -v vicinae >/dev/null 2>&1; then vicinae toggle; "
    .. "else " .. ipc .. "panel-toggle launcher; fi"
))
hl.bind("SUPER + S", hl.dsp.exec_cmd(ipc .. "panel-toggle control-center"))
hl.bind("SUPER + comma", hl.dsp.exec_cmd(ipc .. "settings-toggle"))
hl.bind("ALT + Tab", hl.dsp.exec_cmd(ipc .. "window-switcher hold"))
hl.bind("ALT + SHIFT + Tab", hl.dsp.exec_cmd(ipc .. "window-switcher hold reverse"))
hl.bind("SUPER + ALT + L", hl.dsp.exec_cmd(ipc .. "session lock"))
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd(ipc .. "session logout"))
hl.bind("SUPER + T", hl.dsp.exec_cmd(terminal.command))
hl.bind("SUPER + Return", run_or_raise(terminal.class, terminal.command))
hl.bind("SUPER + B", run_or_raise("zen", "zen-browser"))
hl.bind("SUPER + E", hl.dsp.exec_cmd("nautilus"))
hl.bind("SUPER + M", hl.dsp.exec_cmd("spotify-launcher"))
hl.bind("SUPER + N", hl.dsp.exec_cmd("feishin"))
hl.bind("SUPER + SHIFT + V", hl.dsp.exec_cmd("fladder"))

-- Audio, media, brightness, and screenshots.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(ipc .. "volume-up"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(ipc .. "volume-down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(ipc .. "volume-mute"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(ipc .. "mic-mute"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(ipc .. "media toggle"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd(ipc .. "media toggle"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd(ipc .. "media previous"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd(ipc .. "media next"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(ipc .. "brightness-up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(ipc .. "brightness-down"), { locked = true, repeating = true })
hl.bind("Print", hl.dsp.exec_cmd(ipc .. "screenshot-region"))
hl.bind("CTRL + Print", hl.dsp.exec_cmd(ipc .. "screenshot-fullscreen all"))

-- Window management. Super+L is focus-right, matching the active session.
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind("SUPER + SHIFT + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + W", hl.dsp.group.toggle())

local directions = {
    { key = "left", direction = "l" },
    { key = "right", direction = "r" },
    { key = "H", direction = "l" },
    { key = "J", direction = "d" },
    { key = "K", direction = "u" },
    { key = "L", direction = "r" },
}

for _, item in ipairs(directions) do
    hl.bind("SUPER + " .. item.key, hl.dsp.focus({ direction = item.direction }))
    hl.bind("SUPER + SHIFT + " .. item.key, hl.dsp.window.move({ direction = item.direction }))
end

for _, item in ipairs({
    { key = "H", monitor = "l" },
    { key = "J", monitor = "d" },
    { key = "K", monitor = "u" },
    { key = "L", monitor = "r" },
}) do
    hl.bind("SUPER + CTRL + " .. item.key, hl.dsp.focus({ monitor = item.monitor }))
    hl.bind("SUPER + CTRL + SHIFT + " .. item.key, hl.dsp.window.move({ monitor = item.monitor }))
end

-- Workspaces: Up/Down retains workspace navigation, not window focus.
hl.bind("SUPER + Page_Down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + Page_Up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + U", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + I", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + SHIFT + U", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind("SUPER + SHIFT + I", hl.dsp.window.move({ workspace = "e-1" }))
hl.bind("SUPER + up", hl.dsp.focus({ workspace = "r-1" }))
hl.bind("SUPER + down", hl.dsp.focus({ workspace = "r+1" }))
hl.bind("SUPER + ALT + up", hl.dsp.window.move({ workspace = "r-1" }))
hl.bind("SUPER + ALT + down", hl.dsp.window.move({ workspace = "r+1" }))
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

for workspace = 1, 10 do
    local key = tostring(workspace % 10)
    hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = workspace }))
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Scrolling equivalents for the old dwindle preselect/togglesplit bindings.
hl.bind("SUPER + bracketleft", hl.dsp.layout("colresize -conf"))
hl.bind("SUPER + bracketright", hl.dsp.layout("colresize +conf"))
hl.bind("SUPER + R", hl.dsp.layout("center"))

-- Mouse, resizing, and display controls.
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Move window" })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window" })
hl.bind("SUPER + minus", hl.dsp.window.resize({ x = -100, y = 0, relative = true }), { repeating = true })
hl.bind("SUPER + equal", hl.dsp.window.resize({ x = 100, y = 0, relative = true }), { repeating = true })
hl.bind("SUPER + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -100, relative = true }), { repeating = true })
hl.bind("SUPER + SHIFT + equal", hl.dsp.window.resize({ x = 0, y = 100, relative = true }), { repeating = true })
hl.bind("SUPER + SHIFT + P", hl.dsp.dpms({ action = "toggle" }))
