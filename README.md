# RapidKey

A keyboard-driven command palette for macOS. Press the leader hotkey, then type a key sequence to launch apps, open URLs, or run shell commands defined in `~/.config/rapidkey/rapidkey.toml`.

RapidKey runs as a menu bar utility (no Dock icon). It watches your config file and reloads changes automatically when you save.

## Features

- Global **leader** hotkey opens a command palette
- **Key sequences** with optional **groups** and section titles in the palette header
- Actions: `run` (shell command), `open` (application), `url` (browser)
- Live shell output panel for long-running commands (`show_output`)
- Config hot-reload when `rapidkey.toml` is saved
- Optional launch at login
- Two leader modes:
  - **Chord** — e.g. `alt+space` (no extra permissions)
  - **Double-tap modifier** — e.g. `doubletap+ctrl` (requires Input Monitoring)

## Requirements

- macOS **15.6** or later
- Xcode (Swift 5; uses [TOMLKit](https://github.com/LebJe/TOMLKit) via Swift Package Manager)

## Build and run

### Xcode

1. Open `RapidKey.xcodeproj`
2. Select the **RapidKey** scheme
3. Run (⌘R)

### Command line

```bash
xcodebuild -project RapidKey.xcodeproj -scheme RapidKey -configuration Release -derivedDataPath build build
open build/Build/Products/Release/RapidKey.app
```

The `build/` directory is gitignored.

## First launch

On first run, RapidKey creates `~/.config/rapidkey/` and writes a starter `rapidkey.toml` with example bindings.

Use the menu bar item to:

- **Show [leader]** — open the command palette
- **Open Config Folder** — open the config directory in Finder
- **Grant Input Monitoring…** — shown when the leader is `doubletap+…` and permission is missing
- **Quit** — exit the app

Edit `rapidkey.toml` in any text editor; changes are picked up automatically after you save (debounced file watcher).

## Configuration

Config file: `~/.config/rapidkey/rapidkey.toml`

### Top-level options

| Option | Description |
|--------|-------------|
| `leader` | Global shortcut to open the palette |
| `shell` | Shell for `run` commands (default: `sh`; name on `PATH` or absolute path) |
| `launch_at_login` | Start RapidKey at login (`true` / `false`) |

### Leader

**Chord** — modifiers and key joined with `+`:

```
leader = "alt+space"
```

Modifiers: `ctrl`, `alt`, `cmd`, `shift`. Keys: `a`–`z`, `0`–`9`, `space`, `tab`, `enter`, `esc`, `f1`–`f12`.

**Double-tap modifier** — tap the same modifier twice within the configured window:

```
leader = "doubletap+ctrl"
```

Also accepts `doubletap+alt`, `doubletap+cmd`, `doubletap+shift` (alias: `2tap+…`).

### Sections

| Section | Purpose |
|---------|---------|
| `[panel]` | Where the palette appears: `center`, `cursor`, `top`, `bottom` |
| `[behavior]` | `timeout_ms` — auto-close after idle (0 = disabled); `double_tap_ms` — max gap between modifier taps (default 350) |
| `[groups]` | Optional titles for key prefixes (shown in the palette header) |
| `[bindings]` | Key sequences and their actions |

### Bindings

Keys in a sequence are space-separated. For example, `"f h"` means press `f`, then `h`.

Each binding is an inline table with:

- `title` — label in the palette (required)
- Exactly one of: `run`, `open`, `url`
- `show_output` — with `run` only: show live command output (default `false`)
- `work_dir` — with `run` only: working directory (absolute path or `~`)

Example:

```toml
leader = "alt+space"

[panel]
position = "center"

[behavior]
timeout_ms = 0
double_tap_ms = 350

[groups]
"f" = "Files"
"w" = "Web"

[bindings]
"t"   = { title = "Terminal", open = "Terminal" }
"f h" = { title = "Home", run = "open ~" }
"f l" = { title = "List Home", run = "ls ~", show_output = true }
"w g" = { title = "Google", url = "https://www.google.com" }
```

A group key (e.g. `"f"`) must have bindings under that prefix (e.g. `"f h"`, `"f d"`) to appear as a navigable group.

## Permissions

| Leader type | Permission |
|-------------|------------|
| Chord (e.g. `alt+space`) | None beyond running the app |
| Double-tap modifier | **Input Monitoring** — System Settings → Privacy & Security → Input Monitoring → enable RapidKey |

If Input Monitoring is required but not granted, the leader will not fire. Use **Grant Input Monitoring…** in the menu bar to open the permission dialog again.

## Project layout

```
RapidKey/
  App/                      Entry point, menu bar, AppDelegate
  Models/                   Config, Action, Hotkey
  Services/                 Config load/watch, hotkeys, shell execution
  Features/CommandPalette/  Command palette UI
  UI/                       Panel, key catcher
```

## License

MIT License — see [LICENSE](LICENSE).

Copyright © 2026 Ivan Valkou

## Author

Ivan Valkou
