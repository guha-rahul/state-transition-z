const types = @import("consensus_types");
const Block = @import("../types/block.zig").Block;
const BeaconStateAllForks = @import("../types/beacon_state.zig").BeaconStateAllForks;

/// Execution enabled = merge is done.
/// When (A) state has execution data OR (B) block has execution data
pub fn isExecutionEnabled(state: *const BeaconStateAllForks, block: Block) bool {
    if (isMergeTransitionComplete(state)) {
        return true;
    }

    return switch (block) {
        .blinded => !types.bellatrix.ExecutionPayloadHeader.equals(
            &state.bellatrix.latest_execution_payload_header,
            &types.bellatrix.ExecutionPayloadHeader.default_value,
        ),
        .regular => |b| switch (b.beaconBlockBody()) {
            .bellatrix => |bd| !types.bellatrix.ExecutionPayload.equals(
                &bd.execution_payload,
                &types.bellatrix.ExecutionPayload.default_value,
            ),
            else => false,
        },
    };
}

/// Merge is complete when the state includes execution layer data:
/// state.latestExecutionPayloadHeader NOT EMPTY or state is post-Capella
pub fn isMergeTransitionComplete(state: *const BeaconStateAllForks) bool {
    // All networks completed the merge transition before Capella
    if (state.isPostCapella()) {
        return true;
    }

    // For Bellatrix, check if latestExecutionPayloadHeader is not empty
    return switch (state.*) {
        .bellatrix => |s| !types.bellatrix.ExecutionPayloadHeader.equals(
            &s.latest_execution_payload_header,
            &types.bellatrix.ExecutionPayloadHeader.default_value,
        ),
        else => false,
    };
}
