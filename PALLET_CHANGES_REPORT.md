# Pallet Storage/Methods/Calls 變更清單

**分析日期**: 2026-01-19
**升級版本**: v0.9.40 → v0.9.43
**適用範圍**: Rootchain (mainnet/testnet) 和 Leafchains (parachains)

---

## 執行摘要

### 變更嚴重程度

| 類別 | 變更數量 | 風險等級 |
|------|---------|----------|
| 完全移除的 Pallet | 1 (UMP) | 🔴 HIGH |
| 新增的 Pallet | 1 (MessageQueue) | 🟡 MEDIUM |
| Storage 變更 | 8 pallets | 🟡 MEDIUM |
| Call 變更 | 5 pallets | 🟡 MEDIUM |
| Runtime API 變更 | v2 → v4 | 🟢 LOW |

---

## 第一部分：Rootchain Pallet 變更

### 1. ⚠️ parachains_ump (完全移除)

**變更類型**: 🔴 **完全移除並替換**

| 項目 | v0.9.40 | v0.9.43 |
|------|---------|---------|
| 狀態 | 存在 | **已移除** |
| 替代 | - | `pallet_message_queue` |
| 索引 | 59 | (保留空位) |

**移除的 Storage**:
```rust
// 全部移除
RelayDispatchQueues: StorageMap<ParaId, Vec<UpwardMessage>>
RelayDispatchQueueSize: StorageMap<ParaId, (u32, u32)>
NeedsDispatch: StorageValue<Vec<ParaId>>
NextDispatchRoundStartWith: StorageValue<ParaId>
Overweight: StorageMap<OverweightIndex, (ParaId, Hash, Vec<u8>)>
OverweightCount: StorageValue<OverweightIndex>
```

**移除的 Calls**:
```rust
// 全部移除
service_overweight(index: OverweightIndex, weight_limit: Weight)
```

**遷移需求**:
- UMP dispatch queue 需要遷移到 MessageQueue
- 使用 `parachains_configuration::migration::v6` 處理

---

### 2. ✨ pallet_message_queue (新增)

**變更類型**: 🟢 **新增 Pallet**

**Pallet 索引**: 59 (thxnet), 100 (polkadot 參考)

**新增 Storage**:
```rust
BookStateFor: StorageMap<MessageOrigin, BookState<MessageOrigin>>
ServiceHead: StorageValue<MessageOrigin>
Pages: StorageDoubleMap<MessageOrigin, PageIndex, Page<Size, HeapSize>>
```

**新增 Calls**:
```rust
reap_page(message_origin: MessageOrigin, page_index: PageIndex)
execute_overweight(
    message_origin: MessageOrigin,
    page: PageIndex,
    index: Size,
    weight_limit: Weight
)
```

**新增 Events**:
```rust
ProcessingFailed { id: [u8; 32], origin: MessageOrigin, error: ProcessMessageError }
Processed { id: [u8; 32], origin: MessageOrigin, weight_used: Weight, success: bool }
OverweightEnqueued { id: [u8; 32], origin: MessageOrigin, page_index: PageIndex, ... }
PageReaped { origin: MessageOrigin, index: PageIndex }
```

---

### 3. parachains_configuration

**變更類型**: 🟡 **Storage 版本升級 v4 → v6**

**移除的 Storage 欄位**:
```rust
// v4 → v5 移除
ump_service_total_weight: Weight
ump_max_individual_weight: Weight

// v5 → v6 移除
dispute_conclusion_by_time_out_period: BlockNumber
```

**新增的 Storage 欄位**:
```rust
// v6 新增
async_backing_params: AsyncBackingParams {
    max_candidate_depth: u32,
    allowed_ancestry_len: u32,
}
executor_params: ExecutorParams
```

**移除的 Calls**:
```rust
set_ump_service_total_weight(new: Weight)       // call_index 26
set_ump_max_individual_weight(new: Weight)      // call_index 40
set_dispute_conclusion_by_time_out_period(new: BlockNumber)  // call_index 17
```

**新增的 Calls**:
```rust
set_async_backing_params(new: AsyncBackingParams)  // call_index 45
set_config_with_executor_params()                   // call_index 46
```

---

### 4. parachains_dmp

**變更類型**: 🟡 **Call 移除，新增 Fee 機制**

**Calls 變更**:
```rust
// v0.9.40: 有 Call
Dmp: parachains_dmp::{Pallet, Call, Storage}

// v0.9.43: 移除 Call
Dmp: parachains_dmp::{Pallet, Storage}
```

**新增 Storage**:
```rust
// 新增動態費用因子
DeliveryFeeFactor<T>: StorageMap<ParaId, FixedU128>  // 初始值 1.0
```

**新增常數**:
```rust
THRESHOLD_FACTOR = 2
EXPONENTIAL_FEE_BASE = 1.05
MESSAGE_SIZE_FEE_BASE = 0.001
```

---

### 5. parachains_inclusion

**變更類型**: 🟡 **Config 擴展**

**Config 變更**:
```rust
// v0.9.40 Config
impl parachains_inclusion::Config for Runtime {
    type RuntimeEvent = RuntimeEvent;
    type DisputesHandler = ParasDisputes;
    type RewardValidators = RewardValidatorsWithEraPoints<Runtime>;
}

// v0.9.43 Config (新增)
impl parachains_inclusion::Config for Runtime {
    type RuntimeEvent = RuntimeEvent;
    type DisputesHandler = ParasDisputes;
    type RewardValidators = RewardValidatorsWithEraPoints<Runtime>;
    type MessageQueue = MessageQueue;              // 新增
    type WeightInfo = weights::runtime_parachains_inclusion::WeightInfo<Runtime>;  // 新增
}
```

**新增 Events**:
```rust
UpwardMessagesReceived { from: ParaId, count: u32 }
```

**新增 Types**:
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

**變更類型**: 🟡 **Config 擴展**

**Config 變更**:
```rust
// v0.9.43 新增
type QueueFootprinter: QueueFootprinter<Origin = UmpQueueId>;
```

**行為變更**:
- 新增 `is_offboarding(id: ParaId) -> bool` 函數
- Offboarding 時檢查 UMP 隊列是否清空

---

### 7. parachains_disputes

**變更類型**: 🟡 **Storage 版本升級 v0 → v1**

**移除的 Events**:
```rust
DisputeTimedOut(CandidateHash)  // 移除 timeout 機制
```

**新增 Flags**:
```rust
DisputeStateFlags::AGAINST_BYZANTINE = 0b1000  // f+1 即觸發 chain freeze
```

---

### 8. parachains_hrmp

**變更類型**: 🟢 **邏輯放寬**

**Watermark 規則變更**:
```rust
// v0.9.40: 嚴格遞增
new_watermark > last_watermark

// v0.9.43: 允許追趕到 relay parent
new_watermark == relay_chain_parent_number  // 總是有效
```

---

### 9. pallet_balances

**變更類型**: 🟡 **Config 擴展**

**新增 Config 項目**:
```rust
type HoldIdentifier = ();
type FreezeIdentifier = ();
type MaxHolds = ConstU32<0>;
type MaxFreezes = ConstU32<0>;
```

---

### 10. pallet_sudo

**變更類型**: 🟢 **小幅擴展**

**新增 Config 項目**:
```rust
type WeightInfo = ();  // 新增
```

---

### 11. pallet_collective

**變更類型**: 🟡 **Config 擴展**

**新增 Config 項目**:
```rust
type MaxProposalWeight = MaxCollectiveWeight;  // 新增
```

---

### 12. pallet_xcm

**變更類型**: 🟡 **Config 擴展**

**新增 Config 項目**:
```rust
type AdminOrigin = EnsureRoot<AccountId>;
type MaxRemoteLockConsumers = ConstU32<0>;
type RemoteLockConsumerIdentifier = ();
```

---

## 第二部分：Runtime API 變更

### ParachainHost API

| 版本 | 方法 | 狀態 |
|------|------|------|
| v2 | validators(), validator_groups(), ... | ✅ 保留 |
| v3 | disputes() | ✅ 新增 (v0.9.43) |
| v4 | session_executor_params() | ✅ 新增 (v0.9.43) |

**活躍網絡 API**: v3 (支持 disputes，不支持 session_executor_params)
**代碼庫 API**: v4 (完整支持)

---

## 第三部分：Leafchain 變更分析

### Leafchain 當前狀態 (v0.9.40)

| Pallet | 索引 | 用途 |
|--------|------|------|
| ParachainSystem | 1 | Parachain 系統整合 |
| XcmpQueue | 30 | XCMP 訊息隊列 |
| PolkadotXcm | 31 | XCM 執行 |
| CumulusXcm | 32 | Cumulus XCM |
| DmpQueue | 33 | DMP 訊息處理 |

### 與升級後 Rootchain 的相容性

| 項目 | 相容性 | 說明 |
|------|--------|------|
| UMP 訊息發送 | ✅ 相容 | Leafchain 發送的 UMP 由 Rootchain 處理 |
| DMP 訊息接收 | ✅ 相容 | DMP 格式不變 |
| HRMP 通道 | ✅ 相容 | HRMP 格式不變 |
| Collator 協議 | 🟡 待驗證 | P2P 協議可能有差異 |
| PVF 執行 | ✅ 相容 | v0.9.43 節點可執行 v0.9.40 WASM |

### Leafchain 不需要升級

由於：
1. Leafchain runtime WASM 在 Rootchain 上執行
2. 訊息格式在協議層面向後相容
3. Collator 只需要與 Rootchain 節點通訊

---

## 第四部分：遷移清單

### 需要的 Runtime 遷移

如果升級 Runtime WASM，需要以下遷移：

```rust
pub type Migrations = (
    // v0.9.38: XCM v1 遷移
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

### Node-Only 升級不需要遷移

如果只升級節點二進位檔（不升級 Runtime WASM）：
- ✅ 不需要 storage 遷移
- ✅ 節點自動適應 runtime API 版本
- ✅ 相容機制會自動降級

---

## 第五部分：Call Index 變更摘要

### 變更的 Call Indices

| Pallet | 舊 Call | 新 Call | 變更 |
|--------|---------|---------|------|
| Configuration | set_ump_service_total_weight (26) | - | 移除 |
| Configuration | set_ump_max_individual_weight (40) | - | 移除 |
| Configuration | set_dispute_conclusion_by_time_out_period (17) | - | 移除 |
| Configuration | - | set_async_backing_params (45) | 新增 |
| Configuration | - | set_config_with_executor_params (46) | 新增 |
| Dmp | (全部) | - | 移除 |
| Ump | service_overweight | - | 移除 (整個 pallet) |
| MessageQueue | - | reap_page | 新增 |
| MessageQueue | - | execute_overweight | 新增 |

---

## 第六部分：總結

### Node-Only 升級影響

| 項目 | 影響 | 行動 |
|------|------|------|
| Rootchain 節點 | ✅ 可安全升級 | 編譯並替換二進位檔 |
| Rootchain Runtime | 無變更 | 使用 on-chain WASM |
| Leafchain Collator | ✅ 保持不變 | 無需操作 |
| Leafchain Runtime | 無變更 | 無需操作 |

### Runtime 升級影響 (如果之後執行)

| 項目 | 影響 | 行動 |
|------|------|------|
| Storage 遷移 | 需要多個遷移 | 添加 Migrations tuple |
| Pallet 索引 | 保持不變 | 驗證一致性 |
| Call 索引 | 部分變更 | 更新前端/工具 |
| API 版本 | v3 → v4 | 節點自動處理 |

---

**報告生成時間**: 2026-01-19
**審查工具**: Claude Code
