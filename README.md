# GodotGDK

An open-source GDExtension plugin that integrates the Microsoft public GDK
(Game Development Kit) with Godot 4.x — enabling Godot games to ship on the
Xbox app / Microsoft Store with Xbox Live services.

## Features (POC)

- **GDK Runtime Lifecycle** — Initialize/shutdown the GDK runtime with proper async task queue
- **Xbox User Identity** — Sign in with Xbox Live (silent + UI), get gamertag/XUID
- **GameInput Controllers** — Native GameInput support for Xbox controllers with rumble
- **GDScript API** — Clean singleton-based API (`GDK`, `GDKUser`, `GDKInput`)

## Requirements

- Windows 10 (18362+) or Windows 11
- [Microsoft GDK](https://developer.microsoft.com/en-us/games/xbox/partner/resources-gdk) (install via `winget install Microsoft.Gaming.GDK`)
- [Godot 4.3+](https://godotengine.org/download)
- Visual Studio 2022 with C++ Desktop workload
- CMake 3.20+

## Building

```powershell
# Configure (auto-detects GDK install path)
cmake -B build -G "Visual Studio 17 2022" -A x64

# Build debug
cmake --build build --config Debug

# Build release
cmake --build build --config Release
```

The built DLL lands in `addons/godot_gdk/bin/`.

## Usage

1. Copy `addons/godot_gdk/` into your Godot project
2. Enable the plugin in Project → Project Settings → Plugins
3. Use from GDScript:

```gdscript
func _ready():
    GDK.initialize()
    var user = await GDKUser.user_signed_in
    print("Hello, ", user.gamertag)
```

## GDScript API

### GDK (GDKCore singleton)
- `initialize() → Error` — Start the GDK runtime
- `shutdown()` — Clean up
- `tick()` — Dispatch async callbacks (call in `_process`)
- `get_version() → String`
- Signals: `initialized`, `shutdown_completed`, `error_occurred(message)`

### GDKUser (GDKUserManager singleton)
- `sign_in()` — Xbox sign-in with UI
- `sign_in_silently()` — Silent sign-in (falls back to UI)
- `get_current_user() → GDKUser`
- `is_signed_in() → bool`
- Signals: `user_signed_in(user)`, `sign_in_failed(error)`

### GDKInput singleton
- `initialize() → Error` — Start GameInput
- `shutdown()` — Clean up
- `process()` — Poll controllers (call in `_process`)
- `get_connected_device_count() → int`
- Signals: `device_connected(joy_id)`, `device_disconnected(joy_id)`

## License

MIT
