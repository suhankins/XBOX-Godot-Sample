using System;
using Godot;

namespace GodotPlayFab.Internal;

/// <summary>
/// Builds a <see cref="Callable"/> whose arity matches a native signal so that an
/// arity-agnostic <c>Action&lt;Variant[]&gt;</c> handler can subscribe to it.
/// Godot's <see cref="Callable.From"/> overloads are fixed-arity; there is no
/// variadic form, so a uniform handler must be wrapped in a callable that declares
/// the exact number of parameters the signal emits.
/// </summary>
internal static class SignalArity
{
    public static Callable MakeVariadic(GodotObject o, string signal, Action<Variant[]> handler)
    {
        int argc = ArgCount(o, signal);
        return argc switch
        {
            0 => Callable.From(() => handler(System.Array.Empty<Variant>())),
            1 => Callable.From((Variant a0) => handler(new[] { a0 })),
            2 => Callable.From((Variant a0, Variant a1) => handler(new[] { a0, a1 })),
            3 => Callable.From((Variant a0, Variant a1, Variant a2) =>
                handler(new[] { a0, a1, a2 })),
            4 => Callable.From((Variant a0, Variant a1, Variant a2, Variant a3) =>
                handler(new[] { a0, a1, a2, a3 })),
            5 => Callable.From((Variant a0, Variant a1, Variant a2, Variant a3, Variant a4) =>
                handler(new[] { a0, a1, a2, a3, a4 })),
            _ => Callable.From((Variant a0, Variant a1, Variant a2, Variant a3, Variant a4, Variant a5) =>
                handler(new[] { a0, a1, a2, a3, a4, a5 })),
        };
    }

    private static int ArgCount(GodotObject o, string signal)
    {
        foreach (Godot.Collections.Dictionary sig in o.GetSignalList())
        {
            if (sig["name"].AsString() == signal)
            {
                return sig["args"].AsGodotArray().Count;
            }
        }

        return 0;
    }
}
