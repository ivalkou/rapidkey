import Foundation

enum ConfigPaths {
    static var configURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/rapidkey/rapidkey.toml", isDirectory: false)
    }

    static var configDirectoryURL: URL {
        configURL.deletingLastPathComponent()
    }

    static let defaultConfigToml = #"""
# RapidKey configuration (~/.config/rapidkey/rapidkey.toml)
# Reload from the menu bar after editing.

# Global shortcut to open the command palette.
#
# Variants:
#   chord:               "alt+space"        modifiers: ctrl|alt|cmd|shift; key: a-z, 0-9,
#                                           space, tab, enter, esc, f1-f12.
#                                           No extra permissions required.
#
#   double-tap modifier: "doubletap+ctrl" | "doubletap+alt"
#                      | "doubletap+cmd"  | "doubletap+shift"
#                                           REQUIRES: System Settings -> Privacy & Security
#                                           -> Input Monitoring -> enable RapidKey.
#                                           macOS will show a permission dialog when this leader
#                                           is active; until granted, the leader will NOT fire.
#                                           Use the menu bar item "Grant Input Monitoring..."
#                                           to show the dialog again.
#                                           Tap timing: [behavior] double_tap_ms (max gap, default 350),
#                                           double_tap_min_ms (debounce, default 80),
#                                           double_tap_cooldown_ms (after trigger, default 500).
leader = "alt+space"

# Shell for run commands (default sh). Name on PATH or absolute path.
# shell = "zsh"

# Start RapidKey when you log in (uncomment to enable).
# launch_at_login = true

# Where the command palette and command output panel appear on screen.
[panel]
position = "center"   # center | cursor | top | bottom

# Auto-close the palette after idle time (milliseconds). 0 = never auto-close.
# double_tap_ms: max gap between modifier taps for doubletap+ leader (default 350).
# double_tap_min_ms: min gap; shorter pairs are ignored as bounce (default 80).
# double_tap_cooldown_ms: ignore new double-taps after a trigger (default 500).
[behavior]
timeout_ms = 0
double_tap_ms = 350
double_tap_min_ms = 80
double_tap_cooldown_ms = 500

# Optional section titles for key prefixes (shown in the palette header).
# A group key must have bindings under that prefix (e.g. "f" needs "f h", "f d", …).
[groups]
"f" = "Files"
"w" = "Web"
"x" = "RapidKey Config"

# Key sequences and actions. Keys are space-separated (e.g. "f h" = press f, then h).
# Each binding is an inline table with:
#   title       — label in the palette (required)
#   run         — shell command via configured shell -c (exactly one of run | open | url)
#   open        — application name (macOS open -a)
#   url         — URL opened in the default browser
#   show_output — with run only: open a live output dialog at start; updates while the command runs (default false)
#   work_dir    — with run only: working directory for the shell (absolute path or ~; must exist)
[bindings]
# Root-level leaf: one key runs the action immediately.
"t" = { title = "Terminal", open = "Terminal" }
"s" = { title = "Safari",   open = "Safari" }
……
# Group "f" — shell commands (run).
"f h" = { title = "Home",      run = "open ~" }
"f d" = { title = "Downloads", run = "open ~/Downloads" }
"f l" = { title = "List Home", run = "ls ~", show_output = true }
"f p" = { title = "PWD Home",  run = "pwd", show_output = true, work_dir = "~" }

# Group "w" — URLs.
"w g" = { title = "Google", url = "https://www.google.com" }
"w c" = { title = "GitHub", url = "https://github.com" }

# Group "x" — config maintenance.
"x e" = { title = "Edit Config",             run = "open -t ~/.config/rapidkey/rapidkey.toml" }
"x d" = { title = "Reset Config to Default", run = "rm ~/.config/rapidkey/rapidkey.toml" }
"""#
}
