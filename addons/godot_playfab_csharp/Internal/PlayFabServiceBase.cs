using System;
using System.Threading.Tasks;
using Godot;

namespace GodotPlayFab.Internal;

/// <summary>
/// Base class for the <c>PlayFab.&lt;service&gt;</c> namespace wrappers. Adds the
/// async helper (Signal → <see cref="Task{PlayFabResult}"/>) and a uniform signal
/// subscription helper.
/// </summary>
public abstract class PlayFabServiceBase : PlayFabObject
{
    protected PlayFabServiceBase(GodotObject o) : base(o)
    {
    }

    /// <summary>
    /// Connects <paramref name="handler"/> to the native <paramref name="signal"/>.
    /// Handlers receive the raw signal arguments; service wrappers convert them
    /// into typed payloads before raising their public events.
    /// </summary>
    protected void ConnectSignal(string signal, Action<Variant[]> handler)
    {
        _o.Connect(signal, Callable.From(handler));
    }
}
