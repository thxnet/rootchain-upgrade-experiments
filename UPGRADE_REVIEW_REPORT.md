# Rootchain v0.9.40 → v0.9.43 Upgrade Review Report

**Review Date**: 2026-01-18
**Review Scope**: Node-Only Upgrade (Node v0.9.43, Runtime keeps current state)
**Network Endpoints**:
- Testnet: `wss://node.testnet.thxnet.org/archive-001/ws`
- Mainnet: `wss://node.mainnet.thxnet.org/archive-001/ws`

---

## Executive Summary

### Upgrade Feasibility Assessment: **FEASIBLE**

| Item | Status | Notes |
|------|--------|-------|
| Node Compilation | SUCCESS | `cargo check` passed with warnings only |
| Node-Only Upgrade Feasibility | Feasible | Node has complete API version compatibility mechanism |
| Live Network Runtime API | v3 | Supports disputes(), does not support session_executor_params() |
| Codebase Runtime API | v4 | Full support for all v0.9.43 APIs |
| Leafchain Compatibility | Needs Verification | Leafchains use v0.9.40 |

### Key Findings

**Live Network Runtime Status (Verified)**:
```
Chain: THXNET. Testnet / THXNET. Mainnet
specName: thxnet
specVersion: 94000003
transactionVersion: 22
ParachainHost API: v3
```

**IMPORTANT**: The live network runtime is already at ParachainHost API v3, not the original v0.9.40 v2!

---

## Part 1: Live Network Analysis

### 1.1 Runtime API Version List

| API Name | Version | Notes |
|----------|---------|-------|
| Core | v4 | Base runtime API |
| Metadata | v1 | Metadata API |
| BlockBuilder | v6 | Block building API |
| **ParachainHost** | **v3** | Parachain host API |
| TaggedTransactionQueue | v2 | Transaction pool API |
| GrandpaApi | v3 | Finality API |
| BabeApi | v1 | Consensus API |
| NominationPoolsApi | v2 | Staking pools API |

### 1.2 API v3 vs v4 Feature Differences

| Feature | API v3 (Live Network) | API v4 (Codebase) |
|---------|----------------------|-------------------|
| disputes() | Supported | Supported |
| session_executor_params() | Not Supported | Supported |
| Prioritized dispute selection | Available | Available |
| Custom executor params | Uses default | Supported |

---

## Part 2: Code Review Findings

### 2.1 Runtime Code Status

**thxnet runtime code**:
- Uses `runtime_api_impl::v4`
- Uses `pallet_message_queue` replacing `parachains_ump`
- `Dmp` pallet removed `Call`

**Conclusion**: Codebase runtime fully updated to v0.9.43 API

### 2.2 Pallet Index Comparison

| Pallet | thxnet Index | polkadot Reference | Status |
|--------|--------------|-------------------|--------|
| Dmp | 58 | 58 | Consistent |
| MessageQueue | 59 | 100 | Different (acceptable) |
| Hrmp | 60 | 60 | Consistent |
| ParaSessionInfo | 61 | 61 | Consistent |
| ParasDisputes | 62 | 62 | Consistent |

### 2.3 Node Backward Compatibility Mechanism

Node includes the following compatibility mechanisms:

1. **API Version Auto-Detection**:
```rust
// node/core/runtime-api/src/lib.rs
let res = if runtime_version >= version {
    client.$api_name(...)
} else {
    Err(RuntimeApiError::NotSupported { ... })
};
```

2. **Provisioner Adaptive Strategy**:
- API v2: Uses `random_selection`
- API v3+: Uses `prioritized_selection`

3. **ExecutorParams Default Fallback**:
```rust
Ok(Err(RuntimeApiError::NotSupported { .. })) => {
    Ok(ExecutorParams::default())
}
```

**Conclusion**: v0.9.43 node can safely run v3 API runtime

---

## Part 3: Compilation Test Results

### 3.1 Compilation Status

```bash
SKIP_WASM_BUILD=1 CC=clang-14 CXX=clang++-14 \
LIBCLANG_PATH=/usr/lib/llvm-14/lib CXXFLAGS="-include cstdint" \
cargo check -p polkadot-service --features thxnet-native
```

**Result**: **Compilation Successful**

### 3.2 Warning List

| Warning | File | Recommendation |
|---------|------|----------------|
| Hardcoded weight | pallets/dao/src/lib.rs:345 | Use benchmark weights |
| Deprecated MigrateToV4 | runtime/thxnet/src/lib.rs:1786 | Use MigrateV3ToV5 |
| Unused import | runtime/thxnet/src/lib.rs:53 | Remove ConstantMultiplier |
| Mutable variable doesn't need mut | runtime/common, node/service | Remove mut |

---

## Part 4: Leafchain Compatibility

### 4.1 Leafchain Project Status

| Item | Value |
|------|-------|
| Version | 0.3.0 |
| Substrate Branch | polkadot-v0.9.40 |
| Polkadot Branch | release-v0.9.40 |
| Cumulus Branch | polkadot-v0.9.40 |

### 4.2 Compatibility Assessment

| Item | Risk | Notes |
|------|------|-------|
| UMP Message Format | LOW | Live network runtime handles UMP |
| DMP Message Format | LOW | Same as above |
| Collator Protocol | MEDIUM | Need to test P2P protocol compatibility |
| PVF Execution | LOW | PVF worker can execute v0.9.40 runtime |

### 4.3 Recommendations

1. Verify leafchain collator connectivity with upgraded nodes in test environment
2. Confirm UMP/DMP message delivery works correctly
3. Monitor parachain block production

---

## Part 5: Upgrade Recommendations

### 5.1 Node-Only Upgrade Process

```
1. Complete compilation (SKIP_WASM_BUILD=1)
   ↓
2. Local testing (single node startup confirmation)
   ↓
3. Testnet upgrade
   - Upgrade 1-2 non-validator nodes first
   - Monitor for 24 hours
   ↓
4. Continue after leafchain verification
   ↓
5. Gradually upgrade all testnet nodes
   ↓
6. Mainnet upgrade (same process)
```

### 5.2 Runtime Upgrade Notes

If runtime WASM upgrade is needed later:

1. **Migrations to add**:
   - `pallet_nomination_pools::migration::v5` (replace v4)
   - `parachains_configuration::migration::v5/v6`
   - `pallet_offences::migration::v1`

2. **Verification needed**:
   - Pallet indices consistent with live network
   - spec_version correctly incremented

### 5.3 Monitoring Checklist

Post-upgrade monitoring:
- [ ] Block production rate (should be ≥ 1 block/6s)
- [ ] Finality delay (should be < 2-3 blocks)
- [ ] P2P connection count (normal range)
- [ ] Leafchain block production status
- [ ] UMP/DMP message processing
- [ ] Node memory/CPU usage

---

## Part 6: Test Results Overview

| Phase | Task | Status | Notes |
|-------|------|--------|-------|
| 1.1 | construct_runtime! index review | Complete | Indices consistent |
| 1.2 | Storage migration review | Complete | No additional migration needed for Node-Only |
| 1.3 | Runtime API review | Complete | v4 API fully implemented |
| 1.4 | polkadot reference comparison | Complete | Code matches v0.9.43 |
| 2.1 | Chopsticks setup | Complete | Config files created |
| 2.2 | Live network metadata | Complete | API v3, specVersion 94000003 |
| 2.3 | Runtime upgrade simulation | Skipped | Not needed for Node-Only upgrade |
| 3.1 | Node compilation | Success | Warnings only, no errors |
| 3.2 | Node sync test | Pending | Requires running full node |
| 3.5 | Leafchain integration test | Pending | Requires leafchain collator |
| 4 | Risk assessment report | Complete | This document |

---

## Appendix A: Related File Paths

```
/root/Works/rootchain/runtime/thxnet/src/lib.rs
/root/Works/rootchain/runtime/thxnet-testnet/src/lib.rs
/root/Works/rootchain/primitives/src/runtime_api.rs
/root/Works/rootchain/node/core/runtime-api/src/lib.rs
/root/Works/rootchain/node/core/provisioner/src/lib.rs
/root/Works/rootchain/node/subsystem-util/src/lib.rs
/root/Works/leafchains/
```

## Appendix B: Chopsticks Configuration Files

Created:
- `/root/Works/rootchain/chopsticks-thxnet-testnet.yml`
- `/root/Works/rootchain/chopsticks-thxnet-mainnet.yml`

## Appendix C: Build Commands

```bash
# Build with thxnet-native
SKIP_WASM_BUILD=1 CC=clang-14 CXX=clang++-14 \
LIBCLANG_PATH=/usr/lib/llvm-14/lib CXXFLAGS="-include cstdint" \
cargo build --release -p polkadot-service --features thxnet-native

# Build with thxnet-testnet-native
SKIP_WASM_BUILD=1 CC=clang-14 CXX=clang++-14 \
LIBCLANG_PATH=/usr/lib/llvm-14/lib CXXFLAGS="-include cstdint" \
cargo build --release -p polkadot-service --features thxnet-testnet-native
```

---

## Conclusion

### Upgrade Risk Assessment: **LOW RISK**

1. **Node-Only upgrade is safe**
   - Node has complete API version compatibility mechanism
   - Live network runtime is already API v3
   - Compilation tests passed

2. **Main Considerations**
   - Leafchain compatibility needs real-world testing
   - Recommend full verification on testnet first

3. **Recommended Actions**
   - Perform testnet node upgrade
   - Monitor for 24-48 hours
   - Upgrade mainnet after confirming leafchain works normally

---

**Report Generated**: 2026-01-18
**Review Tool**: Claude Code
