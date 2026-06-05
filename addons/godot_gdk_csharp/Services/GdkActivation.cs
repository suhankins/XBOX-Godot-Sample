using System;
using Godot;
using GodotGdk.Internal;

namespace GodotGdk.Services;

/// <summary><c>GDK.activation</c> — game activation events (protocol/file/invite).</summary>
public sealed class GdkActivation : GdkServiceBase
{
    internal GdkActivation(GodotObject o) : base(o)
    {
        ConnectSignal("protocol_activated", a => ProtocolActivated?.Invoke(a[0].AsString()));
        ConnectSignal("file_activated", a => FileActivated?.Invoke(a[0].AsString()));
        ConnectSignal("pending_invite_received", a => PendingInviteReceived?.Invoke(a[0].AsGodotDictionary()));
        ConnectSignal("invite_accepted", a => InviteAccepted?.Invoke(a[0].AsGodotDictionary()));
        ConnectSignal("activated", a => Activated?.Invoke(a[0].AsGodotDictionary()));
    }

    public event Action<string> ProtocolActivated;
    public event Action<string> FileActivated;
    public event Action<Godot.Collections.Dictionary> PendingInviteReceived;
    public event Action<Godot.Collections.Dictionary> InviteAccepted;
    public event Action<Godot.Collections.Dictionary> Activated;

    public GdkResult AcceptPendingInvite(string inviteUri) =>
        GdkResult.From(Call("accept_pending_invite", inviteUri).AsGodotObject());
}
