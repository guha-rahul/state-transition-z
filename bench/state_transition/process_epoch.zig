const std = @import("std");
const zbench = @import("zbench");
const state_transition = @import("state_transition");
const types = @import("consensus_types");
const config = @import("config");

// printf "Date: %s\nKernel: %s\nCPU: %s\nCPUs: %s\nMemory: %sGi\n" "$(date)" "$(uname -sr)" "$(sysctl -n machdep.cpu.brand_string)" "$(sysctl -n hw.ncpu)" "$(echo "$(sysctl -n hw.memsize) / 1024 / 1024 / 1024" | bc)"
// Date: Tue Dec  9 2025
// Kernel: Darwin 25.1.0
// CPU: Apple M3
// CPUs: 8
// Memory: 16Gi
//
// zbuild run bench_process_epoch -Doptimize=ReleaseFast
//
// benchmark              runs     total time     time/run (avg ± σ)     (min ... max)                p75        p99        p995
// -----------------------------------------------------------------------------------------------------------------------------
// justification_finaliza 26       1.321s         50.839ms ± 6.496ms     (45.373ms ... 73.915ms)      52.631ms   73.915ms   73.915ms
// inactivity_updates     35       1.846s         52.77ms ± 6.439ms      (47.059ms ... 69.952ms)      56.388ms   69.952ms   69.952ms
// rewards_and_penalties  33       1.885s         57.124ms ± 5.113ms     (52.116ms ... 71.352ms)      58.551ms   71.352ms   71.352ms
// registry_updates       42       2.336s         55.622ms ± 21.535ms    (44.854ms ... 169.455ms)     55.973ms   169.455ms  169.455ms
// slashings              32       1.887s         58.989ms ± 9.316ms     (45.191ms ... 84.886ms)      62.214ms   84.886ms   84.886ms
// eth1_data_reset        39       1.961s         50.29ms ± 7.933ms      (44.747ms ... 77.361ms)      50.521ms   77.361ms   77.361ms
// pending_deposits       27       1.424s         52.756ms ± 8.889ms     (46.246ms ... 84.788ms)      54.326ms   84.788ms   84.788ms
// pending_consolidations 41       2.185s         53.298ms ± 12.57ms     (45.366ms ... 122.706ms)     54.65ms    122.706ms  122.706ms
// effective_balance_upda 31       1.586s         51.183ms ± 4.754ms     (47.418ms ... 71.893ms)      53.738ms   71.893ms   71.893ms
// slashings_reset        38       1.875s         49.351ms ± 5.82ms      (44.875ms ... 73.459ms)      52.233ms   73.459ms   73.459ms
// randao_mixes_reset     27       1.342s         49.726ms ± 4.887ms     (44.524ms ... 59.195ms)      52.718ms   59.195ms   59.195ms
// historical_summaries   41       1.926s         46.978ms ± 2.409ms     (45.1ms ... 55.991ms)        47.013ms   55.991ms   55.991ms
// participation_flags    63       1.865s         29.617ms ± 1.139ms     (27.794ms ... 33.642ms)      30.019ms   33.642ms   33.642ms
// sync_committee_updates 61       1.877s         30.784ms ± 2.689ms     (27.568ms ... 40.1ms)        31.492ms   40.1ms     40.1ms
// proposer_lookahead     16       1.595s         99.687ms ± 5.406ms     (92.066ms ... 114.437ms)     104.102ms  114.437ms  114.437ms
//
// Benchmark for epoch processing (Fulu)
// https://github.com/ethereum/consensus-specs/blob/master/specs/phase0/beacon-chain.md#epoch-processing
//
// Benchmarks all process_epoch operations per spec:
// - process_justification_and_finalization
// - process_inactivity_updates
// - process_rewards_and_penalties
// - process_registry_updates
// - process_slashings
// - process_eth1_data_reset
// - process_pending_deposits
// - process_pending_consolidations
// - process_effective_balance_updates
// - process_slashings_reset
// - process_randao_mixes_reset
// - process_historical_summaries_update
// - process_participation_flag_updates
// - process_sync_committee_updates
// - process_proposer_lookahead

const CachedBeaconStateAllForks = state_transition.CachedBeaconStateAllForks;
const BeaconStateAllForks = state_transition.BeaconStateAllForks;
const EpochTransitionCache = state_transition.EpochTransitionCache;
const ValidatorIndex = types.primitive.ValidatorIndex.Type;
const PubkeyIndexMap = state_transition.PubkeyIndexMap(ValidatorIndex);
const BeaconState = types.fulu.BeaconState;

const ProcessJustificationAndFinalizationBench = struct {
    allocator: std.mem.Allocator,
    cached_state: *CachedBeaconStateAllForks,

    pub fn run(self: ProcessJustificationAndFinalizationBench, allocator: std.mem.Allocator) void {
        _ = allocator;
        const cloned = self.cached_state.clone(self.allocator) catch return;
        defer {
            cloned.deinit();
            self.allocator.destroy(cloned);
        }
        var cache = EpochTransitionCache.init(self.allocator, cloned) catch return;
        defer {
            cache.deinit();
            self.allocator.destroy(cache);
        }
        state_transition.processJustificationAndFinalization(cloned, cache) catch return;
    }
};

const ProcessInactivityUpdatesBench = struct {
    allocator: std.mem.Allocator,
    cached_state: *CachedBeaconStateAllForks,

    pub fn run(self: ProcessInactivityUpdatesBench, allocator: std.mem.Allocator) void {
        _ = allocator;
        const cloned = self.cached_state.clone(self.allocator) catch return;
        defer {
            cloned.deinit();
            self.allocator.destroy(cloned);
        }
        var cache = EpochTransitionCache.init(self.allocator, cloned) catch return;
        defer {
            cache.deinit();
            self.allocator.destroy(cache);
        }
        state_transition.processInactivityUpdates(cloned, cache) catch return;
    }
};

const ProcessRewardsAndPenaltiesBench = struct {
    allocator: std.mem.Allocator,
    cached_state: *CachedBeaconStateAllForks,

    pub fn run(self: ProcessRewardsAndPenaltiesBench, allocator: std.mem.Allocator) void {
        _ = allocator;
        const cloned = self.cached_state.clone(self.allocator) catch return;
        defer {
            cloned.deinit();
            self.allocator.destroy(cloned);
        }
        var cache = EpochTransitionCache.init(self.allocator, cloned) catch return;
        defer {
            cache.deinit();
            self.allocator.destroy(cache);
        }
        state_transition.processRewardsAndPenalties(self.allocator, cloned, cache) catch return;
    }
};

const ProcessRegistryUpdatesBench = struct {
    allocator: std.mem.Allocator,
    cached_state: *CachedBeaconStateAllForks,

    pub fn run(self: ProcessRegistryUpdatesBench, allocator: std.mem.Allocator) void {
        _ = allocator;
        const cloned = self.cached_state.clone(self.allocator) catch return;
        defer {
            cloned.deinit();
            self.allocator.destroy(cloned);
        }
        var cache = EpochTransitionCache.init(self.allocator, cloned) catch return;
        defer {
            cache.deinit();
            self.allocator.destroy(cache);
        }
        state_transition.processRegistryUpdates(cloned, cache) catch return;
    }
};

const ProcessSlashingsBench = struct {
    allocator: std.mem.Allocator,
    cached_state: *CachedBeaconStateAllForks,

    pub fn run(self: ProcessSlashingsBench, allocator: std.mem.Allocator) void {
        _ = allocator;
        const cloned = self.cached_state.clone(self.allocator) catch return;
        defer {
            cloned.deinit();
            self.allocator.destroy(cloned);
        }
        var cache = EpochTransitionCache.init(self.allocator, cloned) catch return;
        defer {
            cache.deinit();
            self.allocator.destroy(cache);
        }
        state_transition.processSlashings(self.allocator, cloned, cache) catch return;
    }
};

const ProcessEth1DataResetBench = struct {
    allocator: std.mem.Allocator,
    cached_state: *CachedBeaconStateAllForks,

    pub fn run(self: ProcessEth1DataResetBench, allocator: std.mem.Allocator) void {
        _ = allocator;
        const cloned = self.cached_state.clone(self.allocator) catch return;
        defer {
            cloned.deinit();
            self.allocator.destroy(cloned);
        }
        var cache = EpochTransitionCache.init(self.allocator, cloned) catch return;
        defer {
            cache.deinit();
            self.allocator.destroy(cache);
        }
        state_transition.processEth1DataReset(self.allocator, cloned, cache);
    }
};

const ProcessPendingDepositsBench = struct {
    allocator: std.mem.Allocator,
    cached_state: *CachedBeaconStateAllForks,

    pub fn run(self: ProcessPendingDepositsBench, allocator: std.mem.Allocator) void {
        _ = allocator;
        const cloned = self.cached_state.clone(self.allocator) catch return;
        defer {
            cloned.deinit();
            self.allocator.destroy(cloned);
        }
        var cache = EpochTransitionCache.init(self.allocator, cloned) catch return;
        defer {
            cache.deinit();
            self.allocator.destroy(cache);
        }
        state_transition.processPendingDeposits(self.allocator, cloned, cache) catch return;
    }
};

const ProcessPendingConsolidationsBench = struct {
    allocator: std.mem.Allocator,
    cached_state: *CachedBeaconStateAllForks,

    pub fn run(self: ProcessPendingConsolidationsBench, allocator: std.mem.Allocator) void {
        _ = allocator;
        const cloned = self.cached_state.clone(self.allocator) catch return;
        defer {
            cloned.deinit();
            self.allocator.destroy(cloned);
        }
        var cache = EpochTransitionCache.init(self.allocator, cloned) catch return;
        defer {
            cache.deinit();
            self.allocator.destroy(cache);
        }
        state_transition.processPendingConsolidations(self.allocator, cloned, cache) catch return;
    }
};

const ProcessEffectiveBalanceUpdatesBench = struct {
    allocator: std.mem.Allocator,
    cached_state: *CachedBeaconStateAllForks,

    pub fn run(self: ProcessEffectiveBalanceUpdatesBench, allocator: std.mem.Allocator) void {
        _ = allocator;
        const cloned = self.cached_state.clone(self.allocator) catch return;
        defer {
            cloned.deinit();
            self.allocator.destroy(cloned);
        }
        var cache = EpochTransitionCache.init(self.allocator, cloned) catch return;
        defer {
            cache.deinit();
            self.allocator.destroy(cache);
        }
        _ = state_transition.processEffectiveBalanceUpdates(cloned, cache) catch return;
    }
};

const ProcessSlashingsResetBench = struct {
    allocator: std.mem.Allocator,
    cached_state: *CachedBeaconStateAllForks,

    pub fn run(self: ProcessSlashingsResetBench, allocator: std.mem.Allocator) void {
        _ = allocator;
        const cloned = self.cached_state.clone(self.allocator) catch return;
        defer {
            cloned.deinit();
            self.allocator.destroy(cloned);
        }
        var cache = EpochTransitionCache.init(self.allocator, cloned) catch return;
        defer {
            cache.deinit();
            self.allocator.destroy(cache);
        }
        state_transition.processSlashingsReset(cloned, cache);
    }
};

const ProcessRandaoMixesResetBench = struct {
    allocator: std.mem.Allocator,
    cached_state: *CachedBeaconStateAllForks,

    pub fn run(self: ProcessRandaoMixesResetBench, allocator: std.mem.Allocator) void {
        _ = allocator;
        const cloned = self.cached_state.clone(self.allocator) catch return;
        defer {
            cloned.deinit();
            self.allocator.destroy(cloned);
        }
        var cache = EpochTransitionCache.init(self.allocator, cloned) catch return;
        defer {
            cache.deinit();
            self.allocator.destroy(cache);
        }
        state_transition.processRandaoMixesReset(cloned, cache);
    }
};

const ProcessHistoricalSummariesUpdateBench = struct {
    allocator: std.mem.Allocator,
    cached_state: *CachedBeaconStateAllForks,

    pub fn run(self: ProcessHistoricalSummariesUpdateBench, allocator: std.mem.Allocator) void {
        _ = allocator;
        const cloned = self.cached_state.clone(self.allocator) catch return;
        defer {
            cloned.deinit();
            self.allocator.destroy(cloned);
        }
        var cache = EpochTransitionCache.init(self.allocator, cloned) catch return;
        defer {
            cache.deinit();
            self.allocator.destroy(cache);
        }
        state_transition.processHistoricalSummariesUpdate(self.allocator, cloned, cache) catch return;
    }
};

const ProcessParticipationFlagUpdatesBench = struct {
    allocator: std.mem.Allocator,
    cached_state: *CachedBeaconStateAllForks,

    pub fn run(self: ProcessParticipationFlagUpdatesBench, allocator: std.mem.Allocator) void {
        _ = allocator;
        const cloned = self.cached_state.clone(self.allocator) catch return;
        defer {
            cloned.deinit();
            self.allocator.destroy(cloned);
        }
        state_transition.processParticipationFlagUpdates(self.allocator, cloned) catch return;
    }
};

const ProcessSyncCommitteeUpdatesBench = struct {
    allocator: std.mem.Allocator,
    cached_state: *CachedBeaconStateAllForks,

    pub fn run(self: ProcessSyncCommitteeUpdatesBench, allocator: std.mem.Allocator) void {
        _ = allocator;
        const cloned = self.cached_state.clone(self.allocator) catch return;
        defer {
            cloned.deinit();
            self.allocator.destroy(cloned);
        }
        state_transition.processSyncCommitteeUpdates(self.allocator, cloned) catch return;
    }
};

const ProcessProposerLookaheadBench = struct {
    allocator: std.mem.Allocator,
    cached_state: *CachedBeaconStateAllForks,

    pub fn run(self: ProcessProposerLookaheadBench, allocator: std.mem.Allocator) void {
        _ = allocator;
        const cloned = self.cached_state.clone(self.allocator) catch return;
        defer {
            cloned.deinit();
            self.allocator.destroy(cloned);
        }
        const epoch_cache = cloned.getEpochCache();
        const effective_balance_increments = epoch_cache.getEffectiveBalanceIncrements();
        state_transition.processProposerLookahead.processProposerLookahead(self.allocator, cloned.state, &effective_balance_increments) catch return;
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const stdout = std.io.getStdOut().writer();

    try stdout.print("Loading state from SSZ file...\n", .{});

    // Load state from SSZ
    const state_file = try std.fs.cwd().openFile("bench/state_transition/state.ssz", .{});
    defer state_file.close();
    const state_bytes = try state_file.readToEndAlloc(allocator, 10_000_000_000);
    defer allocator.free(state_bytes);

    try stdout.print("State file loaded: {} bytes\n", .{state_bytes.len});

    const fulu_state = try allocator.create(BeaconState.Type);
    fulu_state.* = BeaconState.default_value;
    try BeaconState.deserializeFromBytes(allocator, state_bytes, fulu_state);

    try stdout.print("State deserialized: slot={}, validators={}\n", .{ fulu_state.slot, fulu_state.validators.items.len });

    // Create beacon state wrapper
    const beacon_state = try allocator.create(BeaconStateAllForks);
    beacon_state.* = .{ .fulu = fulu_state };

    // Create cached state with mainnet config
    const chain_config = config.mainnet_chain_config;
    const beacon_config = try config.BeaconConfig.init(allocator, chain_config, beacon_state.genesisValidatorsRoot());

    const pubkey_index_map = try PubkeyIndexMap.init(allocator);
    const index_pubkey_cache = try allocator.create(state_transition.Index2PubkeyCache);
    index_pubkey_cache.* = state_transition.Index2PubkeyCache.init(allocator);

    try state_transition.syncPubkeys(beacon_state.validators().items, pubkey_index_map, index_pubkey_cache);

    const immutable_data = state_transition.EpochCacheImmutableData{
        .config = beacon_config,
        .index_to_pubkey = index_pubkey_cache,
        .pubkey_to_index = pubkey_index_map,
    };

    const cached_state = try CachedBeaconStateAllForks.createCachedBeaconState(allocator, beacon_state, immutable_data, .{
        .skip_sync_committee_cache = false,
        .skip_sync_pubkeys = false,
    });

    try stdout.print("Cached state created at slot {}\n", .{cached_state.state.slot()});

    try stdout.print("\nStarting process_epoch benchmarks...\n\n", .{});

    var bench = zbench.Benchmark.init(allocator, .{});
    defer bench.deinit();

    const process_justification_bench = ProcessJustificationAndFinalizationBench{
        .allocator = allocator,
        .cached_state = cached_state,
    };
    try bench.addParam("justification_finalization", &process_justification_bench, .{});

    const process_inactivity_bench = ProcessInactivityUpdatesBench{
        .allocator = allocator,
        .cached_state = cached_state,
    };
    try bench.addParam("inactivity_updates", &process_inactivity_bench, .{});

    const process_rewards_bench = ProcessRewardsAndPenaltiesBench{
        .allocator = allocator,
        .cached_state = cached_state,
    };
    try bench.addParam("rewards_and_penalties", &process_rewards_bench, .{});

    const process_registry_bench = ProcessRegistryUpdatesBench{
        .allocator = allocator,
        .cached_state = cached_state,
    };
    try bench.addParam("registry_updates", &process_registry_bench, .{});

    const process_slashings_bench = ProcessSlashingsBench{
        .allocator = allocator,
        .cached_state = cached_state,
    };
    try bench.addParam("slashings", &process_slashings_bench, .{});

    const process_eth1_reset_bench = ProcessEth1DataResetBench{
        .allocator = allocator,
        .cached_state = cached_state,
    };
    try bench.addParam("eth1_data_reset", &process_eth1_reset_bench, .{});

    const process_pending_deposits_bench = ProcessPendingDepositsBench{
        .allocator = allocator,
        .cached_state = cached_state,
    };
    try bench.addParam("pending_deposits", &process_pending_deposits_bench, .{});

    const process_pending_consolidations_bench = ProcessPendingConsolidationsBench{
        .allocator = allocator,
        .cached_state = cached_state,
    };
    try bench.addParam("pending_consolidations", &process_pending_consolidations_bench, .{});

    const process_effective_balance_bench = ProcessEffectiveBalanceUpdatesBench{
        .allocator = allocator,
        .cached_state = cached_state,
    };
    try bench.addParam("effective_balance_updates", &process_effective_balance_bench, .{});

    const process_slashings_reset_bench = ProcessSlashingsResetBench{
        .allocator = allocator,
        .cached_state = cached_state,
    };
    try bench.addParam("slashings_reset", &process_slashings_reset_bench, .{});

    const process_randao_reset_bench = ProcessRandaoMixesResetBench{
        .allocator = allocator,
        .cached_state = cached_state,
    };
    try bench.addParam("randao_mixes_reset", &process_randao_reset_bench, .{});

    const process_historical_bench = ProcessHistoricalSummariesUpdateBench{
        .allocator = allocator,
        .cached_state = cached_state,
    };
    try bench.addParam("historical_summaries", &process_historical_bench, .{});

    const process_participation_bench = ProcessParticipationFlagUpdatesBench{
        .allocator = allocator,
        .cached_state = cached_state,
    };
    try bench.addParam("participation_flags", &process_participation_bench, .{});

    const process_sync_committee_bench = ProcessSyncCommitteeUpdatesBench{
        .allocator = allocator,
        .cached_state = cached_state,
    };
    try bench.addParam("sync_committee_updates", &process_sync_committee_bench, .{});

    const process_proposer_lookahead_bench = ProcessProposerLookaheadBench{
        .allocator = allocator,
        .cached_state = cached_state,
    };
    try bench.addParam("proposer_lookahead", &process_proposer_lookahead_bench, .{});

    try bench.run(stdout);
}
