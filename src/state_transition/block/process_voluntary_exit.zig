const std = @import("std");
const Allocator = std.mem.Allocator;
const BeaconConfig = @import("config").BeaconConfig;
const ForkSeq = @import("config").ForkSeq;
const EpochCache = @import("../cache/epoch_cache.zig").EpochCache;
const BeaconState = @import("fork_types").BeaconState;
const types = @import("consensus_types");
const c = @import("constants");
const SignedVoluntaryExit = types.phase0.SignedVoluntaryExit.Type;
const getPendingBalanceToWithdraw = @import("../utils/validator.zig").getPendingBalanceToWithdraw;
const isActiveValidatorView = @import("../utils/validator.zig").isActiveValidatorView;
const verifyVoluntaryExitSignature = @import("../signature_sets/voluntary_exits.zig").verifyVoluntaryExitSignature;
const initiateValidatorExit = @import("./initiate_validator_exit.zig").initiateValidatorExit;
const gloas_utils = @import("../utils/gloas.zig");
const isBuilderIndex = gloas_utils.isBuilderIndex;
const convertValidatorIndexToBuilderIndex = gloas_utils.convertValidatorIndexToBuilderIndex;
const isActiveBuilder = gloas_utils.isActiveBuilder;
const getPendingBalanceToWithdrawForBuilder = gloas_utils.getPendingBalanceToWithdrawForBuilder;
const initiateBuilderExit = gloas_utils.initiateBuilderExit;

const FAR_FUTURE_EPOCH = c.FAR_FUTURE_EPOCH;

pub fn processVoluntaryExit(
    comptime fork: ForkSeq,
    allocator: Allocator,
    config: *const BeaconConfig,
    epoch_cache: *EpochCache,
    state: *BeaconState(fork),
    signed_voluntary_exit: *const SignedVoluntaryExit,
    verify_signature: bool,
) !void {
    const voluntary_exit = signed_voluntary_exit.message;

    const validity = try getVoluntaryExitValidity(fork, allocator, config, epoch_cache, state, signed_voluntary_exit, verify_signature);
    if (validity != .valid) {
        return error.InvalidVoluntaryExit;
    }

    if (fork.gte(.gloas) and isBuilderIndex(voluntary_exit.validator_index)) {
        try initiateBuilderExit(state, allocator, convertValidatorIndexToBuilderIndex(voluntary_exit.validator_index));
        return;
    }

    var validators = try state.validators();
    const validator = try validators.get(@intCast(signed_voluntary_exit.message.validator_index));
    try initiateValidatorExit(fork, config, epoch_cache, state, validator);
}

pub fn isValidVoluntaryExit(
    comptime fork: ForkSeq,
    allocator: Allocator,
    config: *const BeaconConfig,
    epoch_cache: *const EpochCache,
    state: *BeaconState(fork),
    signed_voluntary_exit: *const SignedVoluntaryExit,
    verify_signature: bool,
) !bool {
    return try getVoluntaryExitValidity(fork, allocator, config, epoch_cache, state, signed_voluntary_exit, verify_signature) == .valid;
}

pub const VoluntaryExitValidity = enum {
    valid,
    inactive,
    already_exited,
    early_epoch,
    short_time_active,
    pending_withdrawals,
    invalid_signature,
};

pub fn getVoluntaryExitValidity(
    comptime fork: ForkSeq,
    allocator: Allocator,
    config: *const BeaconConfig,
    epoch_cache: *const EpochCache,
    state: *BeaconState(fork),
    signed_voluntary_exit: *const SignedVoluntaryExit,
    verify_signature: bool,
) !VoluntaryExitValidity {
    const current_epoch = epoch_cache.epoch;
    const voluntary_exit = signed_voluntary_exit.message;

    // Exits must specify an epoch when they become valid; they are not valid before then
    if (current_epoch < voluntary_exit.epoch) {
        return .early_epoch;
    }

    // Check if this is a builder exit
    if (fork.gte(.gloas) and isBuilderIndex(voluntary_exit.validator_index)) {
        return getBuilderVoluntaryExitValidity(allocator, config, epoch_cache, state, signed_voluntary_exit, verify_signature);
    }

    return getValidatorVoluntaryExitValidity(fork, config, epoch_cache, state, signed_voluntary_exit, verify_signature);
}

fn getBuilderVoluntaryExitValidity(
    allocator: Allocator,
    config: *const BeaconConfig,
    epoch_cache: *const EpochCache,
    state: *BeaconState(.gloas),
    signed_voluntary_exit: *const SignedVoluntaryExit,
    verify_signature: bool,
) !VoluntaryExitValidity {
    const builder_index = convertValidatorIndexToBuilderIndex(signed_voluntary_exit.message.validator_index);

    var builders = try state.inner.get("builders");
    const builders_len = try builders.length();
    if (builder_index >= builders_len) {
        return .inactive;
    }

    var builder: types.gloas.Builder.Type = undefined;
    try builders.getValue(allocator, builder_index, &builder);

    // Verify the builder is active
    const finalized_epoch = try state.finalizedEpoch();
    if (!isActiveBuilder(&builder, finalized_epoch)) {
        return if (builder.withdrawable_epoch != FAR_FUTURE_EPOCH)
            VoluntaryExitValidity.already_exited
        else
            VoluntaryExitValidity.inactive;
    }

    // Only exit builder if it has no pending withdrawals in the queue
    if (try getPendingBalanceToWithdrawForBuilder(allocator, state, builder_index) != 0) {
        return .pending_withdrawals;
    }

    // Verify signature
    if (verify_signature) {
        if (!try verifyVoluntaryExitSignature(config, epoch_cache, signed_voluntary_exit)) {
            return .invalid_signature;
        }
    }

    return .valid;
}

fn getValidatorVoluntaryExitValidity(
    comptime fork: ForkSeq,
    config: *const BeaconConfig,
    epoch_cache: *const EpochCache,
    state: *BeaconState(fork),
    signed_voluntary_exit: *const SignedVoluntaryExit,
    verify_signature: bool,
) !VoluntaryExitValidity {
    const voluntary_exit = signed_voluntary_exit.message;

    var validators = try state.validators();
    const validators_len = try validators.length();
    if (voluntary_exit.validator_index >= validators_len) {
        return .inactive;
    }

    var validator = try validators.get(@intCast(voluntary_exit.validator_index));
    const current_epoch = epoch_cache.epoch;

    // verify the validator is active
    if (!try isActiveValidatorView(validator, current_epoch)) {
        return .inactive;
    }

    // verify exit has not been initiated
    const exit_epoch = try validator.get("exit_epoch");
    if (exit_epoch != FAR_FUTURE_EPOCH) {
        return .already_exited;
    }

    // verify the validator had been active long enough
    const activation_epoch = try validator.get("activation_epoch");
    if (current_epoch < activation_epoch + config.chain.SHARD_COMMITTEE_PERIOD) {
        return .short_time_active;
    }

    // only exit validator if it has no pending withdrawals in the queue (Electra+)
    if (comptime fork.gte(.electra)) {
        if (try getPendingBalanceToWithdraw(fork, state, voluntary_exit.validator_index) != 0) {
            return .pending_withdrawals;
        }
    }

    // verify signature
    if (verify_signature) {
        if (!try verifyVoluntaryExitSignature(config, epoch_cache, signed_voluntary_exit)) {
            return .invalid_signature;
        }
    }

    return .valid;
}

// TODO: unit test
