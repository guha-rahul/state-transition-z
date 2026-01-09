const std = @import("std");
const Allocator = std.mem.Allocator;
const state_transition = @import("state_transition");
const TestCachedBeaconState = state_transition.test_utils.TestCachedBeaconState;
const EpochTransitionCache = state_transition.EpochTransitionCache;
const processParticipationFlagUpdates = state_transition.processParticipationFlagUpdates;
const Node = @import("persistent_merkle_tree").Node;
// this function runs without EpochTransionCache so cannot use getTestProcessFn

test "processParticipationFlagUpdates - sanity" {
    const allocator = std.testing.allocator;
    const validator_count_arr = &.{ 256, 10_000 };

    var pool = try Node.Pool.init(allocator, 1024);
    defer pool.deinit();

    inline for (validator_count_arr) |validator_count| {
        var test_state = try TestCachedBeaconState.init(allocator, &pool, validator_count);
        defer test_state.deinit();
        try processParticipationFlagUpdates(allocator, test_state.cached_state);
    }
    defer state_transition.deinitStateTransition();
}
