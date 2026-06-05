using System;
using System.Threading.Tasks;
using Godot;
using GodotGdk.Internal;
using GodotGdk.Types;

namespace GodotGdk.Services;

/// <summary><c>GDK.achievements</c> — query and update player achievements.</summary>
public sealed class GdkAchievements : GdkServiceBase
{
    internal GdkAchievements(GodotObject o) : base(o)
    {
        ConnectSignal("achievement_unlocked", a =>
            AchievementUnlocked?.Invoke(GdkUser.From(a[0].AsGodotObject()), a[1].AsString()));
        ConnectSignal("achievements_updated", a =>
            AchievementsUpdated?.Invoke(GdkUser.From(a[0].AsGodotObject())));
        ConnectSignal("runtime_error", a =>
            RuntimeError?.Invoke(GdkResult.From(a[0].AsGodotObject())));
    }

    public event Action<GdkUser, string> AchievementUnlocked;
    public event Action<GdkUser> AchievementsUpdated;
    public event Action<GdkResult> RuntimeError;

    public Task<GdkResult> QueryPlayerAchievementsAsync(GdkUser user) =>
        CallResultAsync("query_player_achievements_async", user?.Raw);

    public Task<GdkResult> UpdateAchievementAsync(GdkUser user, string achievementId, int percentComplete) =>
        CallResultAsync("update_achievement_async", user?.Raw, achievementId, percentComplete);

    public Godot.Collections.Array GetCachedAchievements(GdkUser user) =>
        Call("get_cached_achievements", user?.Raw).AsGodotArray();
}
