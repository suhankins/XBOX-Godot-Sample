# GameInput GDExtension Spec

## Overview

This document defines a **GDScript-first** plan for the `godot_gameinput` Godot GDExtension plugin.

`godot_gameinput` owns device discovery, polling, callbacks, haptics, and an optional Godot action bridge. It is the companion input document to `gdext-gdk.md`, but it should be able to ship independently on Windows builds that want GameInput without the rest of the GDK service layer.

The core architectural rule is: **C++ is internal; GDScript is the primary public surface**.

## Design goals

1. **GDScript-first API**: snake_case methods, signals, Godot types, no raw native handles.
2. **GDExtension-only**: no custom Godot fork required.
3. **Standalone plugin**: no hard dependency on `godot_gdk`.
4. **Godot-native ergonomics**: wrappers, signals, scene-tree-friendly mapper nodes, optional `Resource` configs.
5. **Graceful failure in editor/non-target runtime**: no crashes if GameInput is unavailable.

## Scope

| Domain | v1 | Notes |
| --- | --- | --- |
| Runtime init/shutdown | Yes | `GameInputCreate`, callback registration, teardown |
| Device discovery/lifecycle | Yes | connected/disconnected device cache |
| Polling API | Yes | current-reading access |
| Reading callbacks | Yes | optional event-driven device input |
| Vibration/rumble | Yes | `SetRumbleState`-backed |
| Force feedback / advanced haptics | Later | optional follow-on after basic rumble |
| Godot action bridge | Yes | `GameInputMapper` + `GameInputActionMap` |
| Dependency on `godot_gdk` | No | should ship independently |

## Rationale and prior art

This spec borrows the Godot-facing integration patterns that already work well in platform plugins, especially singleton registration, project settings, callback dispatch, and optional Godot-native adapters. The main prior-art reference is [GodotSteam](https://godotsteam.com/) and its active source tree on [Codeberg](https://codeberg.org/godotsteam/godotsteam), which demonstrates the value of native singletons, project settings, callback dispatch, and optional Godot-facing wrapper types in a platform plugin.

### Why GDScript-first wrappers instead of raw native handles

Godot's scripting model is built around first-class [signals](https://docs.godotengine.org/en/stable/classes/class_signal.html), [`RefCounted`](https://docs.godotengine.org/en/stable/classes/class_refcounted.html), [`Node`](https://docs.godotengine.org/en/stable/classes/class_node.html), and [`Resource`](https://docs.godotengine.org/en/stable/classes/class_resource.html) objects. Exposing raw native handles such as `IGameInputDevice*` or `IGameInputReading*` directly to GDScript would fight both Godot ergonomics and Godot lifetime rules.

Wrapping native state in Godot objects such as `GameInputDevice` and `GameInputReading` keeps the public API aligned with normal GDScript usage patterns and hides COM-style lifetime management inside C++.

### Why polling and callbacks are both part of the public contract

[GameInput fundamentals](https://learn.microsoft.com/en-us/gaming/gdk/docs/features/common/input/overviews/input-fundamentals?view=gdk-2510) and [GameInput callbacks](https://learn.microsoft.com/en-us/gaming/gdk/docs/features/common/input/advanced/input-callbacks?view=gdk-2604) support both current-reading polling and event-driven updates. Godot gameplay code often wants both: deterministic per-frame sampling for movement/gameplay logic and connection or reading notifications for UX and device lifecycle.

The plugin should therefore expose both styles instead of forcing one. Polling covers the normal gameplay loop; callbacks keep device caches and connection state current.

### Why `GameInputMapper` exists

GameInput gives raw device state, but Godot gameplay code commonly goes through [`Input`](https://docs.godotengine.org/en/stable/classes/class_input.html) and [`InputMap`](https://docs.godotengine.org/en/stable/classes/class_inputmap.html). The optional `GameInputMapper` exists so GDScript-heavy projects can keep using `Input.is_action_pressed()` and project-defined actions while still benefiting from GameInput's device coverage and haptics.

## Public API conventions

### Global singleton

- `GameInput`

### Wrapper types exposed to GDScript

| Native concept | GDScript wrapper |
| --- | --- |
| `IGameInputDevice` | `GameInputDevice` |
| Input reading state | `GameInputReading` |

### General rules

1. Public methods use snake_case and Godot-native types.
2. GDScript-facing values stay within Godot's type system: `bool`, `int`, `float`, `String`, `Dictionary`, `Array`, and `PackedByteArray`.
3. Long-lived script objects use `RefCounted`, `Resource`, or `Node` when lifecycle matters.
4. Raw handles, pointers, and native query structs stay internal to C++.

## Plugin spec

### Root singleton

#### Root API

```gdscript
GameInput.initialize() -> bool
GameInput.shutdown() -> void
GameInput.is_initialized() -> bool
GameInput.poll() -> void
GameInput.get_devices(kind_mask := DEVICE_ALL) -> Array[GameInputDevice]
GameInput.get_primary_device(kind_mask := DEVICE_GAMEPAD) -> GameInputDevice
GameInput.get_current_reading(device: GameInputDevice) -> GameInputReading
GameInput.set_vibration(device: GameInputDevice, low_freq: float, high_freq: float, left_trigger := 0.0, right_trigger := 0.0) -> bool
GameInput.stop_haptics(device: GameInputDevice) -> void
GameInput.enable_device_callbacks(enabled := true) -> void
```

#### Signals

```gdscript
device_connected(device: GameInputDevice)
device_disconnected(device_id: int)
reading_available(device_id: int)
```

#### `GameInputDevice`

```gdscript
get_device_id() -> int
get_display_name() -> String
get_kind_mask() -> int
supports_vibration() -> bool
supports_haptics() -> bool
```

#### `GameInputReading`

```gdscript
is_button_down(button: int) -> bool
was_button_pressed(button: int) -> bool
get_axis(axis: int) -> float
get_timestamp() -> int
```

#### Native API mapping

| Wrapper/API | Native API(s) | Notes |
| --- | --- | --- |
| `GameInput.initialize()` | `GameInputCreate`, `IGameInput::RegisterDeviceCallback`, `IGameInput::RegisterReadingCallback` | Creates the root GameInput interface and optionally primes device and reading callbacks. |
| `GameInput.shutdown()` | `IGameInput::UnregisterCallback`, `IGameInput::Release` | Unregister callbacks first, then release the root interface and any cached COM-style objects. |
| `GameInput.poll()` | `IGameInput::GetCurrentReading` | Refreshes cached readings for tracked devices in polling mode. |
| `GameInput.get_devices()` / `GameInput.get_primary_device()` | `IGameInput::RegisterDeviceCallback` | Build a device cache from the initial enumeration delivered by callback registration and keep it current with subsequent device-status callbacks. |
| `GameInput.get_current_reading()` | `IGameInput::GetCurrentReading` | Returns a wrapped `IGameInputReading` snapshot for the requested device. |
| `GameInput.set_vibration()` | `IGameInputDevice::SetRumbleState` | v1 haptics path is controller rumble, including trigger rumble when supported. |
| `GameInput.stop_haptics()` | `IGameInputDevice::SetRumbleState` | Send a zeroed rumble state. Advanced force-feedback work can later layer on the force-feedback APIs. |
| `GameInput.enable_device_callbacks()` | `IGameInput::RegisterDeviceCallback`, `IGameInput::RegisterReadingCallback`, `IGameInput::UnregisterCallback` | Toggles the event-driven device and reading feed. |
| `GameInputDevice` getters | `IGameInputDevice::GetDeviceInfo` | Cache display name, kind mask, and vibration/haptics capability flags from `GameInputDeviceInfo`. |
| `GameInputReading` getters | `IGameInputReading::GetGamepadState`, `IGameInputReading::GetKeyState`, `IGameInputReading::GetMouseState`, `IGameInputReading::GetTimestamp` | Normalize native readings into one Godot-facing wrapper without exposing raw GameInput structs. |

### Action bridge

`GameInput` should expose raw input, but it also needs a Godot-native bridge.

#### Additional types

- `GameInputActionMap` (`Resource`)
- `GameInputMapper` (`Node`)

#### `GameInputMapper`

`GameInputMapper` is a `Node` intended to live in the scene tree. It polls `GameInput` or consumes device updates each frame, then emits synthetic `InputEventAction` events against a configured `GameInputActionMap`.

Use it when gameplay code already depends on `Input`, `InputMap`, and project-defined actions. Skip it when a system needs raw per-device state, custom deadzones, or device-specific UX.

- polls `GameInput` each frame
- translates readings into `InputEventAction`
- lets game code keep using:

```gdscript
Input.is_action_pressed("jump")
```

#### Rationale

Raw API is still the right fit for low-level systems. The mapper exists so GDScript-heavy projects can keep using Godot's normal action flow without having to re-author gameplay code around device-level readings.

## Plugin settings

### Runtime

| Setting | Default | Purpose |
| --- | --- | --- |
| `game_input/runtime/initialize_on_startup` | `false` | Calls `GameInput.initialize()` automatically during startup. |
| `game_input/runtime/embed_dispatch` | `true` | Enables automatic per-frame polling/callback dispatch integration. |
| `game_input/runtime/enable_device_callbacks` | `false` | Registers device connection and disconnection callbacks during initialization. |

### Mapper

| Setting | Default | Purpose |
| --- | --- | --- |
| `game_input/mapper/default_action_map` | `""` | Optional default `GameInputActionMap` resource for `GameInputMapper`. |

## Build and packaging rules

1. **Plugin ships as its own `.gdextension`**
   - `godot_gameinput.gdextension`

2. **Can share internal support code with companion plugins**
   - string conversion
   - logging
   - optional common helper code if `godot_gdk` ships beside it

3. **Soft-fail outside supported runtimes**
   - editor should still load docs/classes
   - runtime-only methods return unavailable errors instead of crashing

4. **No hard dependency on `godot_gdk`**
   - ship together if needed
   - use separately if desired

## Rollout

| Step | Deliverable |
| --- | --- |
| 1 | `GameInput` raw polling + device callbacks + vibration |
| 2 | `GameInputMapper` + action map resource |
