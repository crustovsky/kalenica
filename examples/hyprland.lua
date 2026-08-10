-- kalenica ⇄ Hyprland integration (native Lua config, Hyprland 0.55+).
-- Merge these into your own config files; nothing here is loaded directly.

-- Blur behind the bar and its popups. xray = true blurs the wallpaper
-- instead of the windows beneath, so window damage never flickers the bar;
-- theme.barAlpha in config.json is calibrated against this.
hl.layer_rule({
    name = "quickshell-blur",
    blur = true,
    blur_popups = true,
    xray = true,
    ignore_alpha = 0,
    match = { namespace = "^quickshell$" },
})

-- Keybinds driving the IPC entry points.
local mainMod = "SUPER"

hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("qs ipc call bar toggle"), { description = "Toggle bar" })
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("qs ipc call expo toggle"), { description = "Window switcher" })

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("qs ipc call brightness raise"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("qs ipc call brightness lower"), { locked = true, repeating = true })
-- Non-consuming: the EC cycles the level itself, the shell just shows it.
hl.bind("XF86KbdLightOnOff", hl.dsp.exec_cmd("qs ipc call osd kbdlight"), { locked = true, non_consuming = true })

-- Volume via wpctl directly — the OSD watches PipeWire and shows itself.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

hl.bind("Print", hl.dsp.exec_cmd("qs ipc call screenshot screen"), { description = "Screenshot fullscreen" })
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("qs ipc call screenshot active"), { description = "Screenshot active window" })
hl.bind(mainMod .. " + ALT + Print", hl.dsp.exec_cmd("qs ipc call screenshot area"), { description = "Screenshot area" })
