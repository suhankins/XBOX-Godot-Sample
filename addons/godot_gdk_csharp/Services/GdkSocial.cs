using System;
using System.Threading.Tasks;
using Godot;
using GodotGdk.Internal;
using GodotGdk.Types;

namespace GodotGdk.Services;

/// <summary><c>GDK.social</c> — social graph, groups, and reputation feedback.</summary>
public sealed class GdkSocial : GdkServiceBase
{
    internal GdkSocial(GodotObject o) : base(o)
    {
        ConnectSignal("social_graph_changed", a =>
            SocialGraphChanged?.Invoke(GdkUser.From(a[0].AsGodotObject())));
        ConnectSignal("social_group_updated", a =>
            SocialGroupUpdated?.Invoke(GdkSocialGroup.From(a[0].AsGodotObject())));
        ConnectSignal("social_user_changed", a =>
            SocialUserChanged?.Invoke(a[0].AsString(), GdkSocialUser.From(a[1].AsGodotObject())));
        ConnectSignal("runtime_error", a =>
            RuntimeError?.Invoke(GdkResult.From(a[0].AsGodotObject())));
    }

    public event Action<GdkUser> SocialGraphChanged;
    public event Action<GdkSocialGroup> SocialGroupUpdated;
    public event Action<string, GdkSocialUser> SocialUserChanged;
    public event Action<GdkResult> RuntimeError;

    public GdkResult StartSocialGraph(GdkUser user) =>
        GdkResult.From(Call("start_social_graph", user?.Raw).AsGodotObject());

    public void StopSocialGraph(GdkUser user) => Call("stop_social_graph", user?.Raw);

    public Task<GdkResult> GetFriendsAsync(GdkUser user) =>
        CallResultAsync("get_friends_async", user?.Raw);

    public GdkResult CreateSocialGroup(GdkUser user, GdkSocialFilter filter) =>
        GdkResult.From(Call("create_social_group", user?.Raw, filter?.Raw).AsGodotObject());

    public GdkResult CreateSocialGroupFromXuids(GdkUser user, string[] xuids) =>
        GdkResult.From(Call("create_social_group_from_xuids", user?.Raw, xuids).AsGodotObject());

    public void DestroySocialGroup(GdkSocialGroup group) => Call("destroy_social_group", group?.Raw);

    public GdkResult GetGroupUsers(GdkSocialGroup group) =>
        GdkResult.From(Call("get_group_users", group?.Raw).AsGodotObject());

    public Task<GdkResult> SubmitReputationFeedbackAsync(
        GdkUser user, string targetXuid, string feedbackType, string reason, string evidenceId) =>
        CallResultAsync("submit_reputation_feedback_async", user?.Raw, targetXuid, feedbackType, reason, evidenceId);

    public Task<GdkResult> SubmitBatchReputationFeedbackAsync(GdkUser user, Godot.Collections.Array feedbackItems) =>
        CallResultAsync("submit_batch_reputation_feedback_async", user?.Raw, feedbackItems);
}
