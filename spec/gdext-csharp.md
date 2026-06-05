# Godot .NET (C#) parallel for `godot_gdk` — GDExtension Spec

## Overview

This document defines a **C# (Godot .NET) parallel surface** for the `godot_gdk`
addon. The goal is to let teams building their title in the **.NET build of Godot**
consume the same Microsoft GDK integration that GDScript callers use today, with
idiomatic C# ergonomics (typed members, `Task`-based async, `event`-based error
surfaces).

The defining architectural fact is that **the native runtime is not re-ported**.
The value-bearing code is the C++ **GDExtension** in `addons/godot_gdk/src/*`, which
registers the `GDK` singleton and ~42 `GDK*` classes into `ClassDB`. GDExtension is
language-agnostic on the consumer side: the **same**
`godot_gdk.windows.{debug,release}.x86_64.dll` loads in a Godot .NET editor/runtime
and exposes the identical surface. The C# track is therefore a thin, **additive**
**managed facade** layered over the unchanged DLL — never a second native
implementation.

This work is **strictly additive**. It introduces no changes to the C++ DLL, to the
GDScript bootstrap, or to the existing GDScript sample/test tracks. The GDScript
surface remains the primary, first-class surface; the C# surface is a parallel
consumer of the same runtime.

## Design goals

1. **Wrap, don't reimplement.** The C++ GDExtension stays the single source of truth
   for all GDK runtime, async, manager, and result-normalization logic. The C# layer
   only adapts the existing `GodotObject` surface into typed C#.
2. **Idiomatic C# ergonomics.** `Task<GdkResult>` instead of awaited `Signal`,
   strongly-typed wrapper classes instead of `GodotObject.Call`/`Get`, C# `event`
   wrappers for `runtime_error` signals.
3. **No DLL changes for C#'s benefit.** Preserve the Signal/`await` contract that the
   GDScript surface and `docs/async-patterns.md` depend on. (See **Rejected
   alternatives**.)
4. **Single shared runtime.** GDScript and C# consume the same DLL, the same `GDK`
   singleton, and the same per-frame `dispatch()` tick. No parallel GDK integration.
5. **Engine-native objects.** C# wrappers hold and surface real Godot objects
   (`GDKUser`, `GDKResult`, `Signal`) so C# scenes, UI, and autoloads compose with the
   rest of the engine for free.
6. **Graceful absence.** When the DLL is not loaded (editor without the extension,
   non-target runtime), the C# facade degrades the same way the GDScript bootstrap
   does — no crashes.

## Scope

| Domain | In scope | Notes |
| --- | --- | --- |
| C# facade over `godot_gdk` | Yes | Typed wrappers for the `GDK` singleton + service namespaces + value/result types |
| Signal → `Task` async bridge | Yes | Generic managed bridge; one-shot completion |
| C# runtime autoload | Yes | C# equivalent of `gdk_bootstrap.gd` (init-on-startup, auto-add-user, shutdown) |
| C# sample track | Yes | Parallel C# port of `sample/tutorial_app`, starting with T1 sign-in |
| C# test host | Yes | In-engine C# tests (GoDotTest) under a new host |
| C# docs | Yes | `docs/gdk/csharp.md` usage + parity notes |
| `godot_playfab` / `godot_gameinput` C# | **No (later)** | This spec covers `godot_gdk` only; siblings follow the same pattern if this lands |
| C++ DLL changes | **No** | The DLL is unchanged; see Rejected alternatives |
| Editor tooling port (`godot_gdk_packaging`, export platform) | **No** | GDScript editor plugins run unchanged in a .NET project |

## Architecture

### Consumption model

Godot generates C# bindings only for **built-in** `ClassDB` classes at **engine-build
time**. Classes a GDExtension registers **at runtime** (`GDK`, `GDKUser`,
`GDKResult`, …) get **no** generated C# types. From C# they are reachable only
dynamically:

```csharp
var gdk = Engine.GetSingleton("GDK");        // GodotObject (untyped)
var users = (GodotObject)gdk.Get("users");
GodotObject result = ... ;                   // via await on the returned Signal
bool ok = (bool)result.Get("ok");
```

The C# facade exists to replace that stringly-typed access with typed members. The
facade **wraps**, never copies: each C# type holds the underlying `GodotObject` and
exposes `Get()`/`Call()`-backed typed properties and methods.

### Target public C# surface

```csharp
GdkResult result = await Gdk.Users.AddDefaultUserAsync();
if (!result.Ok)
{
    GD.PushWarning($"sign-in failed: {result.Message} ({result.Code})");
    return;
}
GdkUser user = result.Data.As<GdkUser>();
GD.Print($"signed in as {user.Gamertag}");
```

```csharp
Gdk.Achievements.RuntimeError += r => GD.PushWarning($"[Ach] {r.Message}");
```

### Layer map

| Native (`GodotObject`) | C# facade type |
| --- | --- |
| `GDK` singleton | `Gdk` (static entry + lazy singleton resolve) |
| `GDK.users`, `GDK.achievements`, … (~25 service objects) | `GdkUsers`, `GdkAchievements`, … service wrappers |
| `GDKResult` | `GdkResult` (`Ok`, `Message`, `Code`, `Data`, `DataAs<T>()`) |
| `GDKUser`, `GDKLeaderboard`, `GDKPresenceRecord`, … (value types) | thin typed views over the underlying `GodotObject` |
| `*_async()` → one-shot `Signal` | `…Async()` → `Task<GdkResult>` via the async bridge |
| service `runtime_error` signal | C# `event Action<GdkResult>` wrapper |

### Async bridge (the central design problem)

Every `_async` method returns a one-shot Godot `Signal` that resolves to a
`GDKResult` (see `docs/async-patterns.md`). The managed bridge awaits the returned
`Signal` generically — extracting the emitter/owner and signal name from the C#
`Signal` value — so **no DLL change and no dedicated host node are required**:

```csharp
internal static async Task<GdkResult> AwaitResult(Signal completion)
{
    // Await the one-shot completion signal carried by the returned Variant.
    Variant[] payload = await completion.Owner.ToSignal(completion.Owner, completion.Name);
    return new GdkResult((GodotObject)payload[0]);
}
```

Open items to lock down in Phase 0:

- **Direct `Signal` await vs. named emitter signal.** Confirm the exact mechanism for
  awaiting the anonymous returned `Signal` from C# (direct await on the `Signal`
  value vs. awaiting a named completion signal on the service object). The bridge
  shape above assumes the former; fall back to the latter if needed.
- **Main-thread continuation.** Native completions fire on the main thread during the
  per-frame `dispatch()` tick (`gdk/runtime/embed_dispatch` default `true`). Verify
  `Task` continuations resume on the main thread under Godot's C# synchronization
  context; marshal explicitly if not.
- **Shutdown races.** Outstanding signals fire with a failure result on shutdown
  (per `docs/async-patterns.md`); the bridge must resolve, not hang, in that case.

### Runtime autoload (bootstrap parity)

A C# `GdkRuntime : Node` autoload mirrors `addons/godot_gdk/runtime/gdk_bootstrap.gd`:

- reads the same project settings (`gdk/runtime/initialize_on_startup`,
  `gdk/runtime/auto_add_primary_user`),
- calls `GDK.initialize()` / `GDK.users.add_default_user_async()` accordingly,
- binds `initialized` / `shutdown_completed` / `runtime_error` / `user_changed`,
- shuts the runtime down on tree exit,
- skips itself under the headless parse/test paths.

A project uses **one** bootstrap, not both: a C# project registers `GdkRuntime`
instead of `gdk_bootstrap.gd`.

## Repo structure

The C# track lands in **parallel, additive** folders. No existing path changes
behavior.

```
addons/godot_gdk/                 # unchanged: C++ DLL + GDScript bootstrap (source of truth)
addons/godot_gdk_csharp/          # NEW: C# facade class library
  ├─ GodotGdkCSharp.csproj
  ├─ Gdk.cs
  ├─ Services/GdkUsers.cs, Services/GdkAchievements.cs, …
  ├─ Async/GdkResult.cs, Async/SignalBridge.cs
  ├─ Runtime/GdkRuntime.cs        # C# autoload; bootstrap parity
  └─ plugin.cfg                   # references the SAME addons/godot_gdk/bin/*.dll
sample/tutorial_app_csharp/       # NEW: C# port of the tutorial app (.NET project)
tests/godot/gdk_csharp/           # NEW: C# in-engine test host (GoDotTest)
docs/gdk/csharp.md                # NEW: C# usage + GDScript-parity notes
spec/gdext-gdk-csharp.md          # THIS FILE
```

`addons/godot_gdk_csharp` is **pure managed code** and does **not** rebuild the DLL —
it reuses `addons/godot_gdk/bin/*.dll`. CMake and the superproject are untouched. The
C# build is `dotnet build` driven by the Godot .NET sample/test project's generated
`.csproj`/`.sln`.

## Samples

Port `sample/tutorial_app` flows to C#, starting with **T1 sign-in**
(`t01_signin.gd` + `autoload/auth.gd`). The GDScript `Auth` autoload state machine
(check → silent → UI fallback) maps to a C# `Auth : Node` autoload exposing
`Task SignInAsync()` and a `StateChanged` event. The sample requires a **`_mono`**
editor and `dotnet/project/assembly_name` configured in its `project.godot`.

## Tests

GUT is GDScript-only, so the C# track needs a C# runner.

- **Primary:** **GoDotTest** (Chickensoft) — xUnit-style tests that run inside a Godot
  .NET scene; closest analog to GUT for headless CI.
- A **parity test** asserts every native `godot_gdk` service object and `_async`
  method has a corresponding C# wrapper member, to catch drift as the native surface
  evolves.

The C# host is wired into the canonical green bar via a new orchestrator stage (or a
sibling `tools/run_csharp_tests.ps1`) so a C# build + headless test run joins
`tools/run_all_tests.ps1`. Note: the existing `tools/check_gd_scripts_headless.ps1`
parse gate is GDScript-only and does **not** cover C#; the C# track adds its own
`dotnet build` + headless test gate.

## Build & CI integration

- Acquire a **`_mono`** Godot editor (parallel to the existing
  `sample/Godot_v4.6.1-stable_win64.exe`) for the C# sample/test projects.
- C# build = `dotnet build` on the generated sample/test `.csproj`.
- Add a C# stage to the test orchestrator (build + headless GoDotTest run).
- Validate an end-to-end **.NET MSIXVC export** early (see Risks #1).

## Error/result conventions

- All async completions resolve to `GdkResult` (`Ok`, `Message`, `Code`, `Data`).
  `Code` is the same stable string id the GDScript surface branches on.
- `DataAs<T>()` typed-casts the payload to the wrapper type for the operation
  (`GdkUser` for sign-in, etc.).
- Service-level `runtime_error` signals are exposed as C# `event Action<GdkResult>`
  and used for global UI state, exactly as the GDScript side wires them.

## Risks & open questions

1. **GDExtension + .NET co-existence in an exported Xbox-on-PC MSIXVC package.**
   Highest-risk unknown. Both work in-editor; the exported managed-runtime package is
   unverified, and `godot_gdk_packaging` assumes a native/GDScript export profile.
   **Must validate a .NET export in Phase 0** before investing in full coverage.
2. **Anonymous returned `Signal` await from C#** — confirm the bridge mechanism
   (direct `Signal` await vs. named emitter signal). Cheap to verify in the spike.
3. **Main-thread `Task` continuation** after native `dispatch()`.
4. **Two editors in-repo** (`_mono` + non-mono) increases setup friction and the CI
   matrix.
5. **Surface drift** — a parallel C# surface must track the ~42-class native surface.
   Mitigation: keep the facade thin (wrap, don't reimplement) + the parity test.
6. **Export-platform recognition** — confirm the GDScript export platform plugin
   recognizes a .NET project unchanged.

## Rejected alternatives

- **Change the DLL to a `Callable`-completion (or otherwise C#-friendly) async model.**
  Rejected. It does not remove the dominant cost (typed wrappers are unavoidable —
  Godot generates no C# bindings for runtime GDExtension classes regardless), and
  replacing the Signal-return pattern would regress the GDScript surface, whose entire
  documented contract is "`await` is the only thing you need" (`docs/async-patterns.md`).
  Additive `Callable` overloads avoid the GDScript regression but double native
  maintenance for a small managed-side win. Revisit **only** if the Phase-0 spike
  shows awaiting the returned `Signal` from C# is genuinely painful — and then prefer
  additive overloads.
- **A separate C# thunk (P/Invoke) directly to the GDK flat-C API.** Rejected for this
  repo's goals. The C++ GDExtension embeds the hardest, most valuable logic — the
  `XAsyncBlock`/`XTaskQueue` → Godot `dispatch()` → `Signal` bridge, manager `DoWork`
  pump loops, `XUserHandle`/`XblContextHandle` lifetime, and `HRESULT` → `GDKResult`
  normalization. A thunk re-implements all of it in C#, creating a second source of
  truth, losing engine-native object flow into scenes/UI, and violating the
  "wrap, don't reimplement / one runtime" principle. A thunk is only appropriate for a
  **Godot-independent .NET GDK SDK**, which is out of scope. If dynamic
  `GodotObject.Call` ergonomics ever become a real problem, the narrower lever is a few
  `extern "C"` exports on the **existing** GDExtension DLL (a thunk over the C++ layer,
  not the GDK), added only where measured.

## Plan

Phases are additive and each lands its public C# surface **plus** the matching test
tier and doc update in the same change, per the repo's "Before Reporting Completion"
checklist.

- **Phase 0 — Spike / feasibility.** Minimal facade (`Gdk`, `GdkUsers`, `GdkResult`,
  the async bridge) + one C# scene that awaits `AddDefaultUserAsync()` and prints the
  gamertag in a `_mono` editor. **Plus** a throwaway `.NET` MSIXVC export to de-risk
  Risk #1. Decision gate: confirm Risks #1–#3 before committing to full coverage.
  Target tier: manual/smoke.
- **Phase 1 — Facade core.** Hardened async bridge, `GdkResult`, `GdkRuntime`
  autoload (bootstrap parity), and the `users` / `achievements` / `leaderboards`
  services. Parity-test scaffold. Target tier: in-engine unit (GoDotTest).
- **Phase 2 — Full service coverage.** Remaining `godot_gdk` services + value types +
  `runtime_error` event wrappers. Parity test asserts complete coverage.
- **Phase 3 — Sample track.** C# port of `tutorial_app` T1–T2 (sign-in, achievement)
  with a C# `Auth` autoload.
- **Phase 4 — Tests + CI.** GoDotTest host under `tests/godot/gdk_csharp/`, wired into
  the orchestrator; C# build/parse gate.
- **Phase 5 — Docs.** `docs/gdk/csharp.md`, GDScript-parity notes, README addon-table
  update.

## Progress

- Phase 0: 🚧 not started — spec landed on branch `feat/gdk-csharp`.
- Phase 1: ⬜ not started.
- Phase 2: ⬜ not started.
- Phase 3: ⬜ not started.
- Phase 4: ⬜ not started.
- Phase 5: ⬜ not started.
