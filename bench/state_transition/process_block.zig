const std = @import("std");
const zbench = @import("zbench");
const state_transition = @import("state_transition");
const types = @import("consensus_types");
const config = @import("config");
const preset = state_transition.preset;

// printf "Date: %s\nKernel: %s\nCPU: %s\nCPUs: %s\nMemory: %sGi\n" "$(date)" "$(uname -sr)" "$(sysctl -n machdep.cpu.brand_string)" "$(sysctl -n hw.ncpu)" "$(echo "$(sysctl -n hw.memsize) / 1024 / 1024 / 1024" | bc)"
// Date: Tue Dec  9 2025
// Kernel: Darwin 25.1.0
// CPU: Apple M3
// CPUs: 8
// Memory: 16Gi
//
// zbuild run bench_process_block -Doptimize=ReleaseFast
//
// benchmark              runs     total time     time/run (avg ± σ)     (min ... max)                p75        p99        p995
// -----------------------------------------------------------------------------------------------------------------------------
// process_block_header   61       2.653s         43.494ms ± 40.773ms    (26.787ms ... 306.582ms)     37.671ms   306.582ms  306.582ms
// process_withdrawals    54       1.751s         32.434ms ± 10.277ms    (26.843ms ... 99.635ms)      32.642ms   99.635ms   99.635ms
// process_execution_payl 48       1.556s         32.432ms ± 5.087ms     (26.721ms ... 44.789ms)      36.231ms   44.789ms   44.789ms
// process_randao         64       2.076s         32.443ms ± 23.425ms    (27.134ms ... 212.965ms)     29.506ms   212.965ms  212.965ms
// process_eth1_data      71       2.001s         28.192ms ± 1.228ms     (26.04ms ... 32.299ms)       28.856ms   32.299ms   32.299ms
// process_operations     44       2.401s         54.581ms ± 33.324ms    (41.66ms ... 254.774ms)      51.213ms   254.774ms  254.774ms
// process_sync_aggregate 67       2.086s         31.145ms ± 10.657ms    (26.877ms ... 111.953ms)     30.532ms   111.953ms  111.953ms

const CachedBeaconStateAllForks = state_transition.CachedBeaconStateAllForks;
const BeaconStateAllForks = state_transition.BeaconStateAllForks;
const SignedBlock = state_transition.SignedBlock;
const SignedBeaconBlock = state_transition.SignedBeaconBlock;
const Body = state_transition.Body;
const st_mod = @import("state_transition").state_transition;
const stateTransition = st_mod.stateTransition;
const ValidatorIndex = types.primitive.ValidatorIndex.Type;
const PubkeyIndexMap = state_transition.PubkeyIndexMap(ValidatorIndex);
const Withdrawals = types.capella.Withdrawals.Type;
const WithdrawalsResult = state_transition.WithdrawalsResult;
const BlockExternalData = state_transition.BlockExternalData;
const BeaconState = types.fulu.BeaconState;
const FuluSignedBeaconBlock = types.fulu.SignedBeaconBlock;

// Benchmark for block processing (Fulu)
// https://github.com/ethereum/consensus-specs/blob/master/specs/fulu/beacon-chain.md#block-processing
//
// Uses real mainnet state and block:
// - State: slot 13180928
// - Block: slot 13180929
//
// Run with: zbuild run bench_process_block -Doptimize=ReleaseFast
//
// Benchmarks all process_block operations per spec:
// - process_block_header
// - process_withdrawals (post-Capella)
// - process_execution_payload (post-Bellatrix)
// - process_randao
// - process_eth1_data
// - process_operations
// - process_sync_aggregate (post-Altair)

const ProcessBlockHeaderBench = struct {
    allocator: std.mem.Allocator,
    cached_state: *CachedBeaconStateAllForks,
    signed_block: SignedBlock,

    pub fn run(self: ProcessBlockHeaderBench, allocator: std.mem.Allocator) void {
        _ = allocator;
        const cloned = self.cached_state.clone(self.allocator) catch return;
        defer {
            cloned.deinit();
            self.allocator.destroy(cloned);
        }
        const block = self.signed_block.message();
        state_transition.processBlockHeader(self.allocator, cloned, block) catch return;
    }
};

const ProcessWithdrawalsBench = struct {
    allocator: std.mem.Allocator,
    cached_state: *CachedBeaconStateAllForks,
    signed_block: SignedBlock,

    pub fn run(self: ProcessWithdrawalsBench, allocator: std.mem.Allocator) void {
        _ = allocator;
        const cloned = self.cached_state.clone(self.allocator) catch return;
        defer {
            cloned.deinit();
            self.allocator.destroy(cloned);
        }

        // Compute expected withdrawals
        var withdrawals_result = WithdrawalsResult{
            .withdrawals = Withdrawals.initCapacity(self.allocator, preset.MAX_WITHDRAWALS_PER_PAYLOAD) catch return,
        };
        defer withdrawals_result.withdrawals.deinit(self.allocator);

        var withdrawal_balances = std.AutoHashMap(ValidatorIndex, usize).init(self.allocator);
        defer withdrawal_balances.deinit();

        state_transition.getExpectedWithdrawals(self.allocator, &withdrawals_result, &withdrawal_balances, cloned) catch return;

        // Get payload withdrawals root from block
        const block = self.signed_block.message();
        const beacon_body = block.beaconBlockBody();
        const payload_withdrawals_root: [32]u8 = switch (beacon_body) {
            .regular => |b| blk: {
                const actual_withdrawals = b.executionPayload().getWithdrawals();
                var root: [32]u8 = undefined;
                types.capella.Withdrawals.hashTreeRoot(self.allocator, &actual_withdrawals, &root) catch {
                    return;
                };
                break :blk root;
            },
            .blinded => |b| b.executionPayloadHeader().getWithdrawalsRoot(),
        };

        state_transition.processWithdrawals(self.allocator, cloned, withdrawals_result, payload_withdrawals_root) catch return;
    }
};

const ProcessExecutionPayloadBench = struct {
    allocator: std.mem.Allocator,
    cached_state: *CachedBeaconStateAllForks,
    body: Body,

    pub fn run(self: ProcessExecutionPayloadBench, allocator: std.mem.Allocator) void {
        _ = allocator;
        const cloned = self.cached_state.clone(self.allocator) catch return;
        defer {
            cloned.deinit();
            self.allocator.destroy(cloned);
        }

        const external_data = BlockExternalData{
            .execution_payload_status = .valid,
            .data_availability_status = .available,
        };

        state_transition.processExecutionPayload(self.allocator, cloned, self.body, external_data) catch return;
    }
};

const ProcessRandaoBench = struct {
    allocator: std.mem.Allocator,
    cached_state: *CachedBeaconStateAllForks,
    signed_block: SignedBlock,

    pub fn run(self: ProcessRandaoBench, allocator: std.mem.Allocator) void {
        _ = allocator;
        const cloned = self.cached_state.clone(self.allocator) catch return;
        defer {
            cloned.deinit();
            self.allocator.destroy(cloned);
        }
        const block = self.signed_block.message();
        const body = block.beaconBlockBody();
        state_transition.processRandao(cloned, body, block.proposerIndex(), true) catch return;
    }
};

const ProcessEth1DataBench = struct {
    allocator: std.mem.Allocator,
    cached_state: *CachedBeaconStateAllForks,
    signed_block: SignedBlock,

    pub fn run(self: ProcessEth1DataBench, allocator: std.mem.Allocator) void {
        _ = allocator;
        const cloned = self.cached_state.clone(self.allocator) catch return;
        defer {
            cloned.deinit();
            self.allocator.destroy(cloned);
        }
        const block = self.signed_block.message();
        const body = block.beaconBlockBody();
        state_transition.processEth1Data(self.allocator, cloned, body.eth1Data()) catch return;
    }
};

const ProcessOperationsBench = struct {
    allocator: std.mem.Allocator,
    cached_state: *CachedBeaconStateAllForks,
    signed_block: SignedBlock,

    pub fn run(self: ProcessOperationsBench, allocator: std.mem.Allocator) void {
        _ = allocator;
        const cloned = self.cached_state.clone(self.allocator) catch return;
        defer {
            cloned.deinit();
            self.allocator.destroy(cloned);
        }
        const block = self.signed_block.message();
        const body = block.beaconBlockBody();
        state_transition.processOperations(self.allocator, cloned, body, .{ .verify_signature = true }) catch return;
    }
};

const ProcessSyncAggregateBench = struct {
    allocator: std.mem.Allocator,
    cached_state: *CachedBeaconStateAllForks,
    signed_block: SignedBlock,

    pub fn run(self: ProcessSyncAggregateBench, allocator: std.mem.Allocator) void {
        _ = allocator;
        const cloned = self.cached_state.clone(self.allocator) catch return;
        defer {
            cloned.deinit();
            self.allocator.destroy(cloned);
        }
        const block = self.signed_block.message();
        const body = block.beaconBlockBody();
        state_transition.processSyncAggregate(self.allocator, cloned, body.syncAggregate(), true) catch return;
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const stdout = std.io.getStdOut().writer();

    try stdout.print("Loading state and block from SSZ files...\n", .{});

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

    // Load block from SSZ
    const block_file = try std.fs.cwd().openFile("bench/state_transition/block.ssz", .{});
    defer block_file.close();
    const block_bytes = try block_file.readToEndAlloc(allocator, 100_000_000);
    defer allocator.free(block_bytes);

    try stdout.print("Block file loaded: {} bytes\n", .{block_bytes.len});

    const signed_block_data = try allocator.create(FuluSignedBeaconBlock.Type);
    signed_block_data.* = FuluSignedBeaconBlock.default_value;
    try FuluSignedBeaconBlock.deserializeFromBytes(allocator, block_bytes, signed_block_data);

    try stdout.print("Block deserialized: slot={}, proposer={}\n", .{ signed_block_data.message.slot, signed_block_data.message.proposer_index });

    const block_body = &signed_block_data.message.body;
    try stdout.print("Block contents: attestations={}\n", .{block_body.attestations.items.len});

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

    try stdout.print("Cached state created\n", .{});

    // Advance state to block slot
    const block_slot = signed_block_data.message.slot;
    try stdout.print("Advancing state from slot {} to {}\n", .{ cached_state.state.slot(), block_slot });
    try st_mod.processSlotsWithTransientCache(allocator, cached_state, block_slot, .{});
    try stdout.print("State advanced to slot {}\n", .{cached_state.state.slot()});

    // Create block wrappers
    const signed_beacon_block = SignedBeaconBlock{ .fulu = signed_block_data };
    const signed_block = SignedBlock{ .regular = signed_beacon_block };
    const body = Body{ .regular = signed_beacon_block.beaconBlock().beaconBlockBody() };

    try stdout.print("\nStarting process_block benchmarks...\n\n", .{});

    var bench = zbench.Benchmark.init(allocator, .{});
    defer bench.deinit();

    // process_block_header
    const process_block_header_bench = ProcessBlockHeaderBench{
        .allocator = allocator,
        .cached_state = cached_state,
        .signed_block = signed_block,
    };
    try bench.addParam("process_block_header", &process_block_header_bench, .{});

    // process_withdrawals
    const process_withdrawals_bench = ProcessWithdrawalsBench{
        .allocator = allocator,
        .cached_state = cached_state,
        .signed_block = signed_block,
    };
    try bench.addParam("process_withdrawals", &process_withdrawals_bench, .{});

    // process_execution_payload
    const process_execution_payload_bench = ProcessExecutionPayloadBench{
        .allocator = allocator,
        .cached_state = cached_state,
        .body = body,
    };
    try bench.addParam("process_execution_payload", &process_execution_payload_bench, .{});

    // process_randao
    const process_randao_bench = ProcessRandaoBench{
        .allocator = allocator,
        .cached_state = cached_state,
        .signed_block = signed_block,
    };
    try bench.addParam("process_randao", &process_randao_bench, .{});

    // process_eth1_data
    const process_eth1_data_bench = ProcessEth1DataBench{
        .allocator = allocator,
        .cached_state = cached_state,
        .signed_block = signed_block,
    };
    try bench.addParam("process_eth1_data", &process_eth1_data_bench, .{});

    // process_operations
    const process_operations_bench = ProcessOperationsBench{
        .allocator = allocator,
        .cached_state = cached_state,
        .signed_block = signed_block,
    };
    try bench.addParam("process_operations", &process_operations_bench, .{});

    // process_sync_aggregate
    const process_sync_aggregate_bench = ProcessSyncAggregateBench{
        .allocator = allocator,
        .cached_state = cached_state,
        .signed_block = signed_block,
    };
    try bench.addParam("process_sync_aggregate", &process_sync_aggregate_bench, .{});

    try bench.run(stdout);
}
