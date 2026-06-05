using System;
using System.Threading.Tasks;
using Godot;

namespace GodotGdk.Internal;

/// <summary>
/// Base class for the <c>GDK.&lt;service&gt;</c> namespace wrappers. Adds the
/// async helper (Signal → <see cref="Task{GdkResult}"/>) and a uniform signal
/// subscription helper.
/// </summary>
public abstract class GdkServiceBase : GdkObject
{
    protected GdkServiceBase(GodotObject o) : base(o)
    {
    }

    protected Task<GdkResult> CallResultAsync(string method, params Variant[] args)
    {
        Signal completion = _o.Call(method, args).AsSignal();
        return SignalBridge.AwaitResult(completion);
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
