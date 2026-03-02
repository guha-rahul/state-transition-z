const preset = @import("preset").preset;
const EpochCache = @import("../cache/epoch_cache.zig").EpochCache;
const getBalanceChurnLimitFromCache = @import("./validator.zig").getBalanceChurnLimitFromCache;
const getChurnLimit = @import("./validator.zig").getChurnLimit;

const ETH_TO_GWEI: u64 = 1_000_000_000;
const SAFETY_DECAY: u64 = 10;

/// Returns the epoch of the latest weak subjectivity checkpoint.
pub fn getLatestWeakSubjectivityCheckpointEpoch(epoch_cache: *const EpochCache) u64 {
    const current_epoch = epoch_cache.epoch;
    const ws_period = computeWeakSubjectivityPeriodCachedState(epoch_cache);
    return current_epoch - ws_period;
}

fn computeWeakSubjectivityPeriodCachedState(epoch_cache: *const EpochCache) u64 {
    if (epoch_cache.isPostElectra()) {
        return computeWeakSubjectivityPeriodFromConstituentsElectra(epoch_cache);
    } else {
        return computeWeakSubjectivityPeriodFromConstituentsPhase0(epoch_cache);
    }
}

fn computeWeakSubjectivityPeriodFromConstituentsPhase0(epoch_cache: *const EpochCache) u64 {
    const config = epoch_cache.config;
    const current_shuffling = epoch_cache.getCurrentShuffling();
    const N: u64 = @intCast(current_shuffling.active_indices.len);

    const t: u64 = @divFloor(epoch_cache.total_active_balance_increments, N);
    const T: u64 = preset.MAX_EFFECTIVE_BALANCE / ETH_TO_GWEI;
    const delta: u64 = @intCast(getChurnLimit(config, @intCast(N)));
    const Delta: u64 = preset.MAX_DEPOSITS * preset.SLOTS_PER_EPOCH;
    const D: u64 = SAFETY_DECAY;

    var ws_period: u64 = config.chain.MIN_VALIDATOR_WITHDRAWABILITY_DELAY;

    if (T * (200 + 3 * D) < t * (200 + 12 * D)) {
        const epochs_for_validator_set_churn = @divFloor(N * (t * (200 + 12 * D) - T * (200 + 3 * D)), 600 * delta * (2 * t + T));
        const epochs_for_balance_top_ups = @divFloor(N * (200 + 3 * D), 600 * Delta);
        ws_period += @max(epochs_for_validator_set_churn, epochs_for_balance_top_ups);
    } else {
        ws_period += @divFloor(3 * N * D * t, 200 * Delta * (T - t));
    }

    return ws_period;
}

fn computeWeakSubjectivityPeriodFromConstituentsElectra(epoch_cache: *const EpochCache) u64 {
    const config = epoch_cache.config;
    const t: u64 = epoch_cache.total_active_balance_increments;
    const delta: u64 = getBalanceChurnLimitFromCache(epoch_cache);

    const epochs_for_validator_set_churn = @divFloor(SAFETY_DECAY * t, 2 * delta * 100) * preset.EFFECTIVE_BALANCE_INCREMENT;
    return config.chain.MIN_VALIDATOR_WITHDRAWABILITY_DELAY + epochs_for_validator_set_churn;
}
