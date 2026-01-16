const napi = @import("zapi:napi");
const computeEpochAtSlot = @import("state_transition").computeEpochAtSlot;

pub fn Epoch_computeEpochAtSlot(env: napi.Env, cb: napi.CallbackInfo(1)) !napi.Value {
    const slot_i64 = try cb.arg(0).getValueInt64();
    if (slot_i64 < 0) {
        return error.InvalidSlot;
    }
    const slot: u64 = @intCast(slot_i64);
    const epoch = computeEpochAtSlot(slot);
    return try env.createInt64(@intCast(epoch));
}

pub fn register(env: napi.Env, exports: napi.Value) !void {
    const epoch_obj = try env.createObject();
    try epoch_obj.setNamedProperty("computeEpochAtSlot", try env.createFunction(
        "computeEpochAtSlot",
        1,
        Epoch_computeEpochAtSlot,
        null,
    ));
    try exports.setNamedProperty("epoch", epoch_obj);
}
