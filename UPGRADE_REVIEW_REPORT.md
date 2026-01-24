# Rootchain v0.9.40 → v0.9.43 升級審查報告

**審查日期**: 2026-01-18
**審查範圍**: Node-Only 升級（節點 v0.9.43，Runtime 保持現有狀態）
**網絡端點**:
- Testnet: `wss://node.testnet.thxnet.org/archive-001/ws`
- Mainnet: `wss://node.mainnet.thxnet.org/archive-001/ws`

---

## 執行摘要

### 升級可行性評估: 🟢 **可行**

| 項目 | 狀態 | 說明 |
|------|------|------|
| 節點編譯 | ✅ 成功 | `cargo check` 通過，只有警告 |
| Node-Only 升級可行性 | 🟢 可行 | 節點有完整的 API 版本相容機制 |
| 活躍網絡 Runtime API | 🟡 v3 | 支持 disputes()，不支持 session_executor_params() |
| 代碼庫 Runtime API | 🟢 v4 | 完整支持所有 v0.9.43 API |
| Leafchain 相容性 | 🟡 待驗證 | leafchains 使用 v0.9.40 |

### 關鍵發現

**活躍網絡 Runtime 狀態（已驗證）**:
```
Chain: THXNET. Testnet / THXNET. Mainnet
specName: thxnet
specVersion: 94000003
transactionVersion: 22
ParachainHost API: v3
```

⚠️ **重要**: 活躍網絡的 runtime 已經是 ParachainHost API v3，不是原始 v0.9.40 的 v2！

---

## 第一部分：活躍網絡分析

### 1.1 Runtime API 版本清單

| API 名稱 | 版本 | 說明 |
|----------|------|------|
| Core | v4 | 基礎 runtime API |
| Metadata | v1 | 元數據 API |
| BlockBuilder | v6 | 區塊構建 API |
| **ParachainHost** | **v3** | Parachain 主機 API |
| TaggedTransactionQueue | v2 | 交易池 API |
| GrandpaApi | v3 | Finality API |
| BabeApi | v1 | 共識 API |
| NominationPoolsApi | v2 | 質押池 API |

### 1.2 API v3 vs v4 功能差異

| 功能 | API v3 (活躍網絡) | API v4 (代碼庫) |
|------|-------------------|-----------------|
| disputes() | ✅ 支持 | ✅ 支持 |
| session_executor_params() | ❌ 不支持 | ✅ 支持 |
| 優先級 dispute 選擇 | ✅ 可用 | ✅ 可用 |
| 自訂執行參數 | ❌ 使用預設值 | ✅ 支持 |

---

## 第二部分：代碼審查發現

### 2.1 Runtime 代碼狀態

**thxnet runtime 代碼**:
- 使用 `runtime_api_impl::v4`
- 使用 `pallet_message_queue` 替代 `parachains_ump`
- `Dmp` pallet 移除了 `Call`

**結論**: 代碼庫的 runtime 已完全更新到 v0.9.43 API

### 2.2 Pallet 索引對照

| Pallet | thxnet 索引 | polkadot 參考 | 狀態 |
|--------|-------------|---------------|------|
| Dmp | 58 | 58 | ✅ 一致 |
| MessageQueue | 59 | 100 | ⚠️ 不同（可接受） |
| Hrmp | 60 | 60 | ✅ 一致 |
| ParaSessionInfo | 61 | 61 | ✅ 一致 |
| ParasDisputes | 62 | 62 | ✅ 一致 |

### 2.3 節點向後相容機制

節點包含以下相容機制：

1. **API 版本自動檢測**:
```rust
// node/core/runtime-api/src/lib.rs
let res = if runtime_version >= version {
    client.$api_name(...)
} else {
    Err(RuntimeApiError::NotSupported { ... })
};
```

2. **Provisioner 自適應策略**:
- API v2: 使用 `random_selection`
- API v3+: 使用 `prioritized_selection`

3. **ExecutorParams 預設值回退**:
```rust
Ok(Err(RuntimeApiError::NotSupported { .. })) => {
    Ok(ExecutorParams::default())
}
```

✅ **結論**: v0.9.43 節點可以安全運行 v3 API 的 runtime

---

## 第三部分：編譯測試結果

### 3.1 編譯狀態

```bash
SKIP_WASM_BUILD=1 CC=clang-14 CXX=clang++-14 \
LIBCLANG_PATH=/usr/lib/llvm-14/lib CXXFLAGS="-include cstdint" \
cargo check -p polkadot-service --features thxnet-native
```

**結果**: ✅ **編譯成功**

### 3.2 警告清單

| 警告 | 檔案 | 建議 |
|------|------|------|
| 硬編碼 weight | pallets/dao/src/lib.rs:345 | 使用 benchmark weights |
| 棄用的 MigrateToV4 | runtime/thxnet/src/lib.rs:1786 | 改用 MigrateV3ToV5 |
| 未使用的導入 | runtime/thxnet/src/lib.rs:53 | 移除 ConstantMultiplier |
| 可變變量不需要 mut | runtime/common, node/service | 移除 mut |

---

## 第四部分：Leafchain 相容性

### 4.1 Leafchain 項目狀態

| 項目 | 值 |
|------|-----|
| 版本 | 0.3.0 |
| Substrate 分支 | polkadot-v0.9.40 |
| Polkadot 分支 | release-v0.9.40 |
| Cumulus 分支 | polkadot-v0.9.40 |

### 4.2 相容性評估

| 項目 | 風險 | 說明 |
|------|------|------|
| UMP 訊息格式 | 🟢 LOW | 活躍網絡 runtime 處理 UMP |
| DMP 訊息格式 | 🟢 LOW | 同上 |
| Collator 協議 | 🟡 MEDIUM | 需要測試 P2P 協議相容性 |
| PVF 執行 | 🟢 LOW | PVF worker 可執行 v0.9.40 runtime |

### 4.3 建議

1. 在測試環境驗證 leafchain collator 與升級後節點的連接
2. 確認 UMP/DMP 訊息傳遞正常
3. 監控 parachain 區塊生產

---

## 第五部分：升級建議

### 5.1 Node-Only 升級流程

```
1. 完成編譯 (SKIP_WASM_BUILD=1)
   ↓
2. 本地測試（單節點運行確認啟動）
   ↓
3. Testnet 升級
   - 先升級 1-2 個非驗證者節點
   - 監控 24 小時
   ↓
4. 確認 leafchain 正常後繼續
   ↓
5. 逐步升級所有 testnet 節點
   ↓
6. Mainnet 升級（同樣流程）
```

### 5.2 Runtime 升級注意事項

如果之後需要升級 runtime WASM：

1. **需要添加的遷移**:
   - `pallet_nomination_pools::migration::v5` (替換 v4)
   - `parachains_configuration::migration::v5/v6`
   - `pallet_offences::migration::v1`

2. **需要驗證**:
   - pallet 索引與活躍網絡一致
   - spec_version 正確遞增

### 5.3 監控清單

升級後需要監控：
- [ ] 區塊生產速率（應 ≥ 1 block/6s）
- [ ] Finality 延遲（應 < 2-3 blocks）
- [ ] P2P 連接數（正常範圍）
- [ ] Leafchain 出塊狀態
- [ ] UMP/DMP 訊息處理
- [ ] 節點記憶體/CPU 使用

---

## 第六部分：測試結果總覽

| Phase | 任務 | 狀態 | 備註 |
|-------|------|------|------|
| 1.1 | construct_runtime! 索引審查 | ✅ 完成 | 索引一致 |
| 1.2 | 儲存遷移審查 | ✅ 完成 | Node-Only 不需額外遷移 |
| 1.3 | Runtime API 審查 | ✅ 完成 | v4 API 實現完整 |
| 1.4 | polkadot 參考比較 | ✅ 完成 | 代碼符合 v0.9.43 |
| 2.1 | Chopsticks 設置 | ✅ 完成 | 配置文件已創建 |
| 2.2 | 活躍網絡 metadata | ✅ 完成 | API v3, specVersion 94000003 |
| 2.3 | Runtime 升級模擬 | ⏸️ 略過 | Node-Only 升級不需要 |
| 3.1 | 節點編譯 | ✅ 成功 | 只有警告，無錯誤 |
| 3.2 | 節點同步測試 | ⏸️ 待執行 | 需要運行完整節點 |
| 3.5 | Leafchain 整合測試 | ⏸️ 待執行 | 需要 leafchain collator |
| 4 | 風險評估報告 | ✅ 完成 | 本文件 |

---

## 附錄 A：相關檔案路徑

```
/root/Works/rootchain/runtime/thxnet/src/lib.rs
/root/Works/rootchain/runtime/thxnet-testnet/src/lib.rs
/root/Works/rootchain/primitives/src/runtime_api.rs
/root/Works/rootchain/node/core/runtime-api/src/lib.rs
/root/Works/rootchain/node/core/provisioner/src/lib.rs
/root/Works/rootchain/node/subsystem-util/src/lib.rs
/root/Works/leafchains/
```

## 附錄 B：Chopsticks 配置文件

已創建：
- `/root/Works/rootchain/chopsticks-thxnet-testnet.yml`
- `/root/Works/rootchain/chopsticks-thxnet-mainnet.yml`

## 附錄 C：編譯命令

```bash
# 編譯 thxnet-native
SKIP_WASM_BUILD=1 CC=clang-14 CXX=clang++-14 \
LIBCLANG_PATH=/usr/lib/llvm-14/lib CXXFLAGS="-include cstdint" \
cargo build --release -p polkadot-service --features thxnet-native

# 編譯 thxnet-testnet-native
SKIP_WASM_BUILD=1 CC=clang-14 CXX=clang++-14 \
LIBCLANG_PATH=/usr/lib/llvm-14/lib CXXFLAGS="-include cstdint" \
cargo build --release -p polkadot-service --features thxnet-testnet-native
```

---

## 結論

### 升級風險評估: 🟢 **低風險**

1. **Node-Only 升級是安全的**
   - 節點有完整的 API 版本相容機制
   - 活躍網絡 runtime 已是 API v3
   - 編譯測試通過

2. **主要考量**
   - Leafchain 相容性需要實際測試
   - 建議先在 testnet 完整驗證

3. **建議行動**
   - 進行 testnet 節點升級
   - 監控 24-48 小時
   - 確認 leafchain 正常後升級 mainnet

---

**報告生成時間**: 2026-01-18
**審查工具**: Claude Code
