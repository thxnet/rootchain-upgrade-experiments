# Pallet Storage/Methods/Calls Change List

**Analysis Date**: 2026-01-19
**Upgrade Version**: v0.9.40 → v0.9.43
**Scope**: Rootchain (mainnet/testnet) and Leafchains (parachains)

---

## Executive Summary

### Change Severity

| Category | Change Count | Risk Level |
|----------|-------------|------------|
| Completely Removed Pallet | 1 (UMP) | HIGH |
| New Pallet | 1 (MessageQueue) | MEDIUM |
| Storage Changes | 8 pallets | MEDIUM |
| Call Changes | 5 pallets | MEDIUM |
| Runtime API Changes | v2 → v4 | LOW |

---

## Part 1: Rootchain Pallet Changes

### 1. parachains_ump (Completely Removed)

**Change Type**: **Completely Removed and Replaced**

| Item | v0.9.40 | v0.9.43 |
|------|---------|---------|
| Status | Exists | **Removed** |
| Replacement | - | `pallet_message_queue` |
| Index | 59 | (Reserved) |

**Removed Storage**:
```rust
// All removed
RelayDispatchQueues: StorageMap<ParaId, Vec<UpwardMessage>>
RelayDispatchQueueSize: StorageMap<ParaId, (u32, u32)>
NeedsDispatch: StorageValue<Vec<ParaId>>
NextDispatchRoundStartWith: StorageValue<ParaId>
Overweight: StorageMap<OverweightIndex, (ParaId, Hash, Vec<u8>)>
OverweightCount: StorageValue<OverweightIndex>
```

**Removed Calls**:
```rust
// All removed
service_overweight(index: OverweightIndex, weight_limit: Weight)
```

**Migration Requirements**:
- UMP dispatch queue needs to be migrated to MessageQueue
- Use `parachains_configuration::migration::v6` for handling

---

### 2. pallet_message_queue (New)

**Change Type**: **New Pallet**

**Pallet Index**: 59 (thxnet), 100 (polkadot reference)

**New Storage**:
```rust
BookStateFor: StorageMap<MessageOrigin, BookState<MessageOrigin>>
ServiceHead: StorageValue<MessageOrigin>
Pages: StorageDoubleMap<MessageOrigin, PageIndex, Page<Size, HeapSize>>
```

**New Calls**:
```rust
reap_page(message_origin: MessageOrigin, page_index: PageIndex)
execute_overweight(
    message_origin: MessageOrigin,
    page: PageIndex,
    index: Size,
    weight_limit: Weight
)
```

**New Events**:
```rust
ProcessingFailed { id: [u8; 32], origin: MessageOrigin, error: ProcessMessageError }
Processed { id: [u8; 32], origin: MessageOrigin, weight_used: Weight, success: bool }
OverweightEnqueued { id: [u8; 32], origin: MessageOrigin, page_index: PageIndex, ... }
PageReaped { origin: MessageOrigin, index: PageIndex }
```

---

### 3. parachains_configuration

**Change Type**: **Storage Version Upgrade v4 → v6**

**Removed Storage Fields**:
```rust
// v4 → v5 removed
ump_service_total_weight: Weight
ump_max_individual_weight: Weight

// v5 → v6 removed
dispute_conclusion_by_time_out_period: BlockNumber
```

**New Storage Fields**:
```rust
// v6 new
async_backing_params: AsyncBackingParams {
    max_candidate_depth: u32,
    allowed_ancestry_len: u32,
}
executor_params: ExecutorParams
```

**Removed Calls**:
```rust
set_ump_service_total_weight(new: Weight)       // call_index 26
set_ump_max_individual_weight(new: Weight)      // call_index 40
set_dispute_conclusion_by_time_out_period(new: BlockNumber)  // call_index 17
```

**New Calls**:
```rust
set_async_backing_params(new: AsyncBackingParams)  // call_index 45
set_config_with_executor_params()                   // call_index 46
```

---

### 4. parachains_dmp

**Change Type**: **Call Removed, New Fee Mechanism Added**

**Calls Changes**:
```rust
// v0.9.40: Has Call
Dmp: parachains_dmp::{Pallet, Call, Storage}

// v0.9.43: Call Removed
Dmp: parachains_dmp::{Pallet, Storage}
```

**New Storage**:
```rust
// New dynamic fee factor
DeliveryFeeFactor<T>: StorageMap<ParaId, FixedU128>  // Initial value 1.0
```

**New Constants**:
```rust
THRESHOLD_FACTOR = 2
EXPONENTIAL_FEE_BASE = 1.05
MESSAGE_SIZE_FEE_BASE = 0.001
```

---

### 5. parachains_inclusion

**Change Type**: **Config Extended**

**Config Changes**:
```rust
// v0.9.40 Config
impl parachains_inclusion::Config for Runtime {
    type RuntimeEvent = RuntimeEvent;
    type DisputesHandler = ParasDisputes;
    type RewardValidators = RewardValidatorsWithEraPoints<Runtime>;
}

// v0.9.43 Config (new items added)
impl parachains_inclusion::Config for Runtime {
    type RuntimeEvent = RuntimeEvent;
    type DisputesHandler = ParasDisputes;
    type RewardValidators = RewardValidatorsWithEraPoints<Runtime>;
    type MessageQueue = MessageQueue;              // New
    type WeightInfo = weights::runtime_parachains_inclusion::WeightInfo<Runtime>;  // New
}
```

**New Events**:
```rust
UpwardMessagesReceived { from: ParaId, count: u32 }
```

**New Types**:
```rust
AggregateMessageOrigin::Ump(UmpQueueId)
UmpQueueId::Para(ParaId)
UmpAcceptanceCheckErr {
    MoreMessagesThanPermitted { sent: u32, permitted: u32 }
    MessageSize { idx: u32, msg_size: u32, max_size: u32 }
    CapacityExceeded { count: u64, limit: u64 }
    TotalSizeExceeded { total_size: u64, limit: u64 }
    IsOffboarding
}
```

---

### 6. parachains_paras

**Change Type**: **Config Extended**

**Config Changes**:
```rust
// v0.9.43 new
type QueueFootprinter: QueueFootprinter<Origin = UmpQueueId>;
```

**Behavior Changes**:
- Added `is_offboarding(id: ParaId) -> bool` function
- Checks if UMP queue is empty during offboarding

---

### 7. parachains_disputes

**Change Type**: **Storage Version Upgrade v0 → v1**

**Removed Events**:
```rust
DisputeTimedOut(CandidateHash)  // Timeout mechanism removed
```

**New Flags**:
```rust
DisputeStateFlags::AGAINST_BYZANTINE = 0b1000  // f+1 triggers chain freeze
```

---

### 8. parachains_hrmp

**Change Type**: **Logic Relaxed**

**Watermark Rule Changes**:
```rust
// v0.9.40: Strictly increasing
new_watermark > last_watermark

// v0.9.43: Allow catching up to relay parent
new_watermark == relay_chain_parent_number  // Always valid
```

---

### 9. pallet_balances

**Change Type**: **Config Extended**

**New Config Items**:
```rust
type HoldIdentifier = ();
type FreezeIdentifier = ();
type MaxHolds = ConstU32<0>;
type MaxFreezes = ConstU32<0>;
```

---

### 10. pallet_sudo

**Change Type**: **Minor Extension**

**New Config Items**:
```rust
type WeightInfo = ();  // New
```

---

### 11. pallet_collective

**Change Type**: **Config Extended**

**New Config Items**:
```rust
type MaxProposalWeight = MaxCollectiveWeight;  // New
```

---

### 12. pallet_xcm

**Change Type**: **Config Extended**

**New Config Items**:
```rust
type AdminOrigin = EnsureRoot<AccountId>;
type MaxRemoteLockConsumers = ConstU32<0>;
type RemoteLockConsumerIdentifier = ();
```

---

## Part 2: Runtime API Changes

### ParachainHost API

| Version | Methods | Status |
|---------|---------|--------|
| v2 | validators(), validator_groups(), ... | Retained |
| v3 | disputes() | New (v0.9.43) |
| v4 | session_executor_params() | New (v0.9.43) |

**Live Network API**: v3 (supports disputes, does not support session_executor_params)
**Codebase API**: v4 (full support)

---

## Part 3: Leafchain Change Analysis

### Leafchain Current State (v0.9.40)

| Pallet | Index | Purpose |
|--------|-------|---------|
| ParachainSystem | 1 | Parachain system integration |
| XcmpQueue | 30 | XCMP message queue |
| PolkadotXcm | 31 | XCM execution |
| CumulusXcm | 32 | Cumulus XCM |
| DmpQueue | 33 | DMP message handling |

### Compatibility with Upgraded Rootchain

| Item | Compatibility | Notes |
|------|---------------|-------|
| UMP Message Sending | Compatible | UMP sent by Leafchain is processed by Rootchain |
| DMP Message Receiving | Compatible | DMP format unchanged |
| HRMP Channels | Compatible | HRMP format unchanged |
| Collator Protocol | Needs Verification | P2P protocol may differ |
| PVF Execution | Compatible | v0.9.43 node can execute v0.9.40 WASM |

### Leafchain Does Not Need Upgrade

Because:
1. Leafchain runtime WASM executes on Rootchain
2. Message formats are backward compatible at protocol level
3. Collators only need to communicate with Rootchain nodes

---

## Part 4: Migration Checklist

### Required Runtime Migrations

If upgrading Runtime WASM, the following migrations are needed:

```rust
pub type Migrations = (
    // v0.9.38: XCM v1 migration
    pallet_xcm::migration::v1::MigrateToV1<Runtime>,

    // v0.9.40: Nomination Pools
    pallet_nomination_pools::migration::v4::MigrateToV4<Runtime, ...>,
    pallet_nomination_pools::migration::v5::MigrateToV5<Runtime>,

    // v0.9.42: Configuration + Offences
    parachains_configuration::migration::v5::MigrateToV5<Runtime>,
    pallet_offences::migration::v1::MigrateToV1<Runtime>,
    runtime_common::session::migration::ClearOldSessionStorage<Runtime>,

    // v0.9.43: UMP → MessageQueue
    parachains_configuration::migration::v6::MigrateToV6<Runtime>,
    ump_migrations::UpdateUmpLimits,
);
```

### Node-Only Upgrade Does Not Need Migration

If only upgrading the node binary (not upgrading Runtime WASM):
- No storage migration needed
- Node automatically adapts to runtime API version
- Compatibility mechanisms auto-downgrade

---

## Part 5: Call Index Change Summary

### Changed Call Indices

| Pallet | Old Call | New Call | Change |
|--------|----------|----------|--------|
| Configuration | set_ump_service_total_weight (26) | - | Removed |
| Configuration | set_ump_max_individual_weight (40) | - | Removed |
| Configuration | set_dispute_conclusion_by_time_out_period (17) | - | Removed |
| Configuration | - | set_async_backing_params (45) | Added |
| Configuration | - | set_config_with_executor_params (46) | Added |
| Dmp | (all) | - | Removed |
| Ump | service_overweight | - | Removed (entire pallet) |
| MessageQueue | - | reap_page | Added |
| MessageQueue | - | execute_overweight | Added |

---

## Part 6: Summary

### Node-Only Upgrade Impact

| Item | Impact | Action |
|------|--------|--------|
| Rootchain Node | Safe to upgrade | Compile and replace binary |
| Rootchain Runtime | No change | Use on-chain WASM |
| Leafchain Collator | Keep unchanged | No action needed |
| Leafchain Runtime | No change | No action needed |

### Runtime Upgrade Impact (if executed later)

| Item | Impact | Action |
|------|--------|--------|
| Storage Migration | Multiple migrations needed | Add Migrations tuple |
| Pallet Index | Keep unchanged | Verify consistency |
| Call Index | Partial changes | Update frontend/tools |
| API Version | v3 → v4 | Node handles automatically |

---

**Report Generated**: 2026-01-19
**Review Tool**: Claude Code
