//! Mutable lookup for the pending-deposit sequence used by builder-routing logic.
//!
//! This is to implement the spec's `is_pending_validator(pending_deposits, pubkey)` lazily:
//! deposits are grouped by pubkey without verifying signatures, and BLS verification is
//! deferred until a builder deposit needs to know whether the same pubkey already has a
//! valid pending validator deposit.
//!
//! Call `add()` whenever a deposit is appended to the represented sequence. A cached `true`
//! result short-circuits all subsequent checks for that pubkey; a cached `false` records
//! how many deposits were already verified, so appending a new deposit only verifies the
//! newly-appended tail rather than re-running BLS on previously-invalid entries.

const std = @import("std");
const Allocator = std.mem.Allocator;
const BeaconConfig = @import("config").BeaconConfig;
const ForkSeq = @import("config").ForkSeq;
const BeaconState = @import("fork_types").BeaconState;
const ct = @import("consensus_types");
const validateDepositSignature = @import("../block/process_deposit.zig").validateDepositSignature;

const BLSPubkey = ct.primitive.BLSPubkey.Type;
const PendingDeposit = ct.electra.PendingDeposit.Type;

pub const PendingDepositsLookup = struct {
    allocator: Allocator,
    deposits_by_pubkey: std.AutoHashMap(BLSPubkey, PendingDeposits),

    const PendingDeposits = struct {
        deposits: std.ArrayList(PendingDeposit) = .empty,
        validated_count: usize = 0,
        has_valid_signature: bool = false,

        fn deinit(self: *PendingDeposits, allocator: Allocator) void {
            self.deposits.deinit(allocator);
        }
    };

    /// Build an empty lookup for a sequence that will be populated incrementally.
    pub fn buildEmpty(allocator: Allocator) PendingDepositsLookup {
        return .{
            .allocator = allocator,
            .deposits_by_pubkey = std.AutoHashMap(BLSPubkey, PendingDeposits).init(allocator),
        };
    }

    /// Build a pubkey -> pending-deposits lookup from `state.pendingDeposits`.
    /// No BLS work is done here; signature verification happens lazily in `hasPendingValidator`.
    pub fn build(comptime fork: ForkSeq, allocator: Allocator, state: *BeaconState(fork)) !PendingDepositsLookup {
        var lookup = PendingDepositsLookup.buildEmpty(allocator);
        errdefer lookup.deinit();

        var pending_deposits = try state.pendingDeposits();
        const pending_deposits_len = try pending_deposits.length();
        var pending_it = pending_deposits.iteratorReadonly(0);

        for (0..pending_deposits_len) |_| {
            const pending_deposit = try pending_it.nextValue(allocator);
            try lookup.add(&pending_deposit);
        }

        return lookup;
    }

    pub fn deinit(self: *PendingDepositsLookup) void {
        var value_iterator = self.deposits_by_pubkey.valueIterator();
        while (value_iterator.next()) |entry| {
            entry.deinit(self.allocator);
        }
        self.deposits_by_pubkey.deinit();
    }

    /// Append a pending deposit to the represented sequence.
    pub fn add(self: *PendingDepositsLookup, pending_deposit: *const PendingDeposit) !void {
        const result = try self.deposits_by_pubkey.getOrPut(pending_deposit.pubkey);
        if (!result.found_existing) {
            result.value_ptr.* = .{};
        }
        try result.value_ptr.deposits.append(self.allocator, pending_deposit.*);
    }

    /// Returns true if any pending deposit for `pubkey` has a valid BLS deposit signature.
    /// Memoizes the result so repeated checks for the same pubkey within a block only verify
    /// deposits that have not already been checked.
    pub fn hasPendingValidator(
        self: *PendingDepositsLookup,
        config: *const BeaconConfig,
        pubkey: *const BLSPubkey,
    ) !bool {
        const entry = self.deposits_by_pubkey.getPtr(pubkey.*) orelse return false;
        if (entry.has_valid_signature) return true;
        if (entry.validated_count == entry.deposits.items.len) return false;

        var i = entry.validated_count;
        while (i < entry.deposits.items.len) : (i += 1) {
            const deposit = &entry.deposits.items[i];
            validateDepositSignature(
                config,
                &deposit.pubkey,
                &deposit.withdrawal_credentials,
                deposit.amount,
                deposit.signature,
            ) catch continue;
            entry.has_valid_signature = true;
            entry.validated_count = i + 1;
            return true;
        }

        entry.validated_count = entry.deposits.items.len;
        return false;
    }
};
