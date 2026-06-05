using System;
using System.Threading.Tasks;
using Godot;
using GodotGdk.Internal;
using GodotGdk.Types;

namespace GodotGdk.Services;

/// <summary><c>GDK.stats</c> — title-managed and user statistics.</summary>
public sealed class GdkStats : GdkServiceBase
{
    internal GdkStats(GodotObject o) : base(o)
    {
        ConnectSignal("stats_updated", a =>
            StatsUpdated?.Invoke(GdkUser.From(a[0].AsGodotObject()), a[1].AsGodotDictionary()));
        ConnectSignal("stat_changed", a =>
            StatChanged?.Invoke(GdkUser.From(a[0].AsGodotObject()), a[1].AsString(), a[2]));
        ConnectSignal("stats_flushed", a =>
            StatsFlushed?.Invoke(GdkUser.From(a[0].AsGodotObject()), GdkResult.From(a[1].AsGodotObject())));
    }

    public event Action<GdkUser, Godot.Collections.Dictionary> StatsUpdated;
    public event Action<GdkUser, string, Variant> StatChanged;
    public event Action<GdkUser, GdkResult> StatsFlushed;

    public Task<GdkResult> QueryUserStatsAsync(GdkUser user, string[] statNames) =>
        CallResultAsync("query_user_stats_async", user?.Raw, statNames);

    public Task<GdkResult> QueryUsersStatsAsync(GdkUser user, string[] xuids, string[] statNames) =>
        CallResultAsync("query_users_stats_async", user?.Raw, xuids, statNames);

    public GdkResult SetStatInteger(GdkUser user, string statName, long value) =>
        GdkResult.From(Call("set_stat_integer", user?.Raw, statName, value).AsGodotObject());

    public GdkResult SetStatNumber(GdkUser user, string statName, double value) =>
        GdkResult.From(Call("set_stat_number", user?.Raw, statName, value).AsGodotObject());

    public Task<GdkResult> FlushStatsAsync(GdkUser user) =>
        CallResultAsync("flush_stats_async", user?.Raw);

    public GdkResult TrackStats(GdkUser user, string[] statNames) =>
        GdkResult.From(Call("track_stats", user?.Raw, statNames).AsGodotObject());

    public GdkResult StopTrackingStats(GdkUser user, string[] statNames) =>
        GdkResult.From(Call("stop_tracking_stats", user?.Raw, statNames).AsGodotObject());

    public Godot.Collections.Dictionary GetCachedStats(GdkUser user) =>
        Call("get_cached_stats", user?.Raw).AsGodotDictionary();
}
