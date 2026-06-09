using System;
using System.Threading.Tasks;
using Godot;
using GodotPlayFab.Internal;

namespace GodotPlayFab.Types;

public sealed class PlayFabPartyPeer : PlayFabObject
{
    internal PlayFabPartyPeer(GodotObject o) : base(o)
    {
        ConnectSignal("connection_state_changed", a =>
            ConnectionStateChanged?.Invoke(a[0].AsInt32()));
        ConnectSignal("network_error", a =>
            NetworkError?.Invoke(PlayFabResult.From(a[0].AsGodotObject())));
        ConnectSignal("chat_control_added", a =>
            ChatControlAdded?.Invoke(a[0].AsInt32(), PlayFabPartyChatControl.From(a[1].AsGodotObject())));
        ConnectSignal("chat_control_removed", a =>
            ChatControlRemoved?.Invoke(a[0].AsInt32()));
        ConnectSignal("text_message_received", a =>
            TextMessageReceived?.Invoke(a[0].AsInt32(), PlayFabPartyChatMessage.From(a[1].AsGodotObject())));
        ConnectSignal("transcription_received", a =>
            TranscriptionReceived?.Invoke(a[0].AsInt32(), PlayFabPartyChatMessage.From(a[1].AsGodotObject())));
        ConnectSignal("chat_permissions_changed", a =>
            ChatPermissionsChanged?.Invoke(a[0].AsInt32(), a[1].AsInt32()));
        ConnectSignal("peer_muted_changed", a =>
            PeerMutedChanged?.Invoke(a[0].AsInt32(), a[1].AsBool()));
    }

    public static PlayFabPartyPeer From(GodotObject o) => o == null ? null : new PlayFabPartyPeer(o);

    public MultiplayerPeer AsMultiplayerPeer => _o as MultiplayerPeer;

    public event Action<int> ConnectionStateChanged;
    public event Action<PlayFabResult> NetworkError;
    public event Action<int, PlayFabPartyChatControl> ChatControlAdded;
    public event Action<int> ChatControlRemoved;
    public event Action<int, PlayFabPartyChatMessage> TextMessageReceived;
    public event Action<int, PlayFabPartyChatMessage> TranscriptionReceived;
    public event Action<int, int> ChatPermissionsChanged;
    public event Action<int, bool> PeerMutedChanged;

    public PlayFabPartyNetwork GetNetwork() =>
        PlayFabPartyNetwork.From(Call("get_network").AsGodotObject());

    public PlayFabUser GetLocalUser() =>
        PlayFabUser.From(Call("get_local_user").AsGodotObject());

    public string GetDescriptor() =>
        Call("get_descriptor").AsString();

    public Godot.Collections.Dictionary GetPeerEntityKey(int peer_id) =>
        Call("get_peer_entity_key", peer_id).AsGodotDictionary();

    public PlayFabPartyMember GetPeerMember(int peer_id) =>
        PlayFabPartyMember.From(Call("get_peer_member", peer_id).AsGodotObject());

    public Godot.Collections.Array GetPeers() =>
        Call("get_peers").AsGodotArray();

    public PlayFabPartyChatControl GetLocalChatControl() =>
        PlayFabPartyChatControl.From(Call("get_local_chat_control").AsGodotObject());

    public PlayFabPartyChatControl GetPeerChatControl(int peer_id) =>
        PlayFabPartyChatControl.From(Call("get_peer_chat_control", peer_id).AsGodotObject());

    public Task<PlayFabResult> SendTextAsync(string message, int[] target_peer_ids = null, PlayFabPartyTextMessageConfig config = null) =>
        CallResultAsync("send_text_async", message, target_peer_ids ?? System.Array.Empty<int>(), config?.Raw);

    public Task<PlayFabResult> SetPeerChatPermissionsAsync(int peer_id, int permissions) =>
        CallResultAsync("set_peer_chat_permissions_async", peer_id, permissions);

    public Task<PlayFabResult> SetPeerMutedAsync(int peer_id, bool muted) =>
        CallResultAsync("set_peer_muted_async", peer_id, muted);

    public void CloseWithReason(string reason = "") =>
        Call("close_with_reason", reason);
}
