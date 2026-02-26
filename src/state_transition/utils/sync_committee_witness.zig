const std = @import("std");
const Node = @import("persistent_merkle_tree").Node;
const ForkSeq = @import("config").ForkSeq;
const AnyBeaconState = @import("fork_types").AnyBeaconState;

pub const SyncCommitteeWitness = struct {
    witness: []const [32]u8,
    current_sync_committee_root: [32]u8,
    next_sync_committee_root: [32]u8,

    // witness is allocated, caller must free
    allocator: std.mem.Allocator,

    pub fn deinit(self: *SyncCommitteeWitness) void {
        self.allocator.free(self.witness);
    }
};

pub fn getSyncCommitteesWitness(allocator: std.mem.Allocator, state: *AnyBeaconState, p: *Node.Pool) !SyncCommitteeWitness {
    const fork_seq = state.forkSeq();
    if (fork_seq.lt(.altair)) {
        return error.UnsupportedFork;
    }

    try state.commit();
    const n1 = switch (state.*) {
        inline else => |*s| s.base_view.data.root,
    };

    if (fork_seq.gte(.electra)) {
        // Electra path: gindex 86/87
        const n2 = try n1.getLeft(p);
        const n5 = try n2.getRight(p);
        const n10 = try n5.getLeft(p);
        const n21 = try n10.getRight(p);
        const n43 = try n21.getRight(p);

        const current_root = (try n43.getLeft(p)).getRoot(p); // n86
        const next_root = (try n43.getRight(p)).getRoot(p); // n87

        // Witness sorted by descending gindex: 42, 20, 11, 4, 3
        const witness = try allocator.alloc([32]u8, 5);
        witness[0] = (try n21.getLeft(p)).getRoot(p).*; // n42
        witness[1] = (try n10.getLeft(p)).getRoot(p).*; // n20
        witness[2] = (try n5.getRight(p)).getRoot(p).*; // n11
        witness[3] = (try n2.getLeft(p)).getRoot(p).*; // n4
        witness[4] = (try n1.getRight(p)).getRoot(p).*; // n3

        return .{
            .witness = witness,
            .current_sync_committee_root = current_root.*,
            .next_sync_committee_root = next_root.*,
            .allocator = allocator,
        };
    } else {
        // Pre-electra path: gindex 54/55
        const n3 = try n1.getRight(p);
        const n6 = try n3.getLeft(p);
        const n13 = try n6.getRight(p);
        const n27 = try n13.getRight(p);

        const current_root = (try n27.getLeft(p)).getRoot(p); // n54
        const next_root = (try n27.getRight(p)).getRoot(p); // n55

        // Witness sorted by descending gindex: 26, 12, 7, 2
        const witness = try allocator.alloc([32]u8, 4);
        witness[0] = (try n13.getLeft(p)).getRoot(p).*; // n26
        witness[1] = (try n6.getLeft(p)).getRoot(p).*; // n12
        witness[2] = (try n3.getRight(p)).getRoot(p).*; // n7
        witness[3] = (try n1.getLeft(p)).getRoot(p).*; // n2

        return .{
            .witness = witness,
            .current_sync_committee_root = current_root.*,
            .next_sync_committee_root = next_root.*,
            .allocator = allocator,
        };
    }
}
