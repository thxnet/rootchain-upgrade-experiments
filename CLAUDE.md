# Rootchain Development Notes for Claude

## CRITICAL REMINDER

**Always remember to reference the polkadot and substrate repos in `/root/Works/` directory and switch to the appropriate branches/tags. Don't waste time working blindly!**

Before making ANY changes to substrate/polkadot dependencies:
1. Check `/root/Works/polkadot` - the reference polkadot repo
2. Check `/root/Works/substrate` - the reference substrate repo
3. Switch to the appropriate tag/branch and verify which substrate branch the polkadot version uses

```bash
# Example: Check what substrate branch polkadot v0.9.43 uses
cd /root/Works/polkadot
git checkout v0.9.43
cat node/service/Cargo.toml | grep 'branch = "polkadot'
```

---

## Current State (as of 2026-01-25)

- **rootchain version**: 0.9.43
- **Substrate branch**: `polkadot-v0.9.43`
- **Rust toolchain**: `nightly-2023-05-23` (rustc 1.71.0-nightly 8b4b20836 2023-05-22)
- **Docker base image**: `docker.io/paritytech/ci-linux:production`
- **Build status**: SUCCESS (including WASM runtimes)

---

## Build Environment

### Aligned with Official Polkadot v0.9.43

This repo now uses the same build environment as official Polkadot v0.9.43:

| Component | Version |
|-----------|---------|
| Rust Stable | 1.69.0 |
| Rust Nightly | 1.71.0-nightly (8b4b20836 2023-05-22) |
| Clang | clang-14 |
| Docker Image | paritytech/ci-linux:production |

### Local Build Commands

```bash
# Full build with WASM runtimes
CC=clang-14 CXX=clang++-14 LIBCLANG_PATH=/usr/lib/llvm-14/lib \
cargo build --release

# Skip WASM build (faster for development)
SKIP_WASM_BUILD=1 CC=clang-14 CXX=clang++-14 LIBCLANG_PATH=/usr/lib/llvm-14/lib \
cargo build --release
```

### Environment Variables Explained

1. **`CC=clang-14 CXX=clang++-14`**: Required for RocksDB C++ compatibility
2. **`LIBCLANG_PATH=/usr/lib/llvm-14/lib`**: bindgen requires clang-14 library path

---

## Upgrade Strategy Used (v0.9.40 → v0.9.43)

### What Worked

1. **Copy entire crates from polkadot v0.9.43**:
   - Copying individual files leads to many API incompatibilities
   - Better to copy entire crate directories from the reference repo

2. **Use Cargo.lock from reference repo**:
   - `cp /root/Works/polkadot/Cargo.lock /root/Works/rootchain/`
   - This ensures compatible dependency versions

3. **Key crates that need to be copied**:
   ```
   primitives/
   node/primitives/
   node/core/pvf/
   node/core/pvf/worker/
   node/network/protocol/
   node/subsystem-util/
   node/service/
   node/client/
   xcm/
   runtime/common/
   runtime/parachains/
   cli/
   rpc/
   ```

### API Changes Between v0.9.40 and v0.9.43

| Component | v0.9.40 | v0.9.43 |
|-----------|---------|---------|
| Keystore | `SyncCryptoStorePtr`, async methods | `KeystorePtr`, sync methods |
| Network channels | `futures::channel::mpsc` | `async_channel` |
| PVF | Single crate | Main crate + `worker/` subcrate |
| VRF | `make_transcript()` | `make_vrf_transcript()` |
| fungibles | `fungibles::Transfer` | Moved to different module |

---

## Polkadot Version Mappings (from /root/Works/polkadot)

| Polkadot Version | Substrate Branch |
|------------------|------------------|
| v0.9.40 | polkadot-v0.9.40 |
| v0.9.43 | polkadot-v0.9.43 |

---

## thxnet Runtime DONE (v0.9.43 Compatible)

Both thxnet and thxnet-testnet runtimes have been updated for v0.9.43 compatibility.

### Key Changes Made

1. **Imports updated**:
   - `runtime_api_impl::v2` → `runtime_api_impl::v4`
   - `parachains_ump` replaced with `pallet_message_queue`
   - Added `inclusion::{AggregateMessageOrigin, UmpQueueId}`
   - Added `ProcessMessage`, `ProcessMessageError`, `WeightMeter`

2. **construct_runtime changes**:
   - `Ump: parachains_ump::...` → `MessageQueue: pallet_message_queue::...`
   - `Dmp: parachains_dmp::{Pallet, Call, Storage}` → `Dmp: parachains_dmp::{Pallet, Storage}` (removed Call)

3. **New Config items added**:
   - `pallet_sudo::Config::WeightInfo`
   - `pallet_balances::Config::{HoldIdentifier, FreezeIdentifier, MaxHolds, MaxFreezes}`
   - `pallet_collective::Config::MaxProposalWeight`
   - `parachains_inclusion::Config::{MessageQueue, WeightInfo}`
   - `parachains_paras::Config::QueueFootprinter`
   - `pallet_xcm::Config::{AdminOrigin, MaxRemoteLockConsumers, RemoteLockConsumerIdentifier}`

4. **Runtime API additions**:
   - `sp_api::Metadata::{metadata_at_version, metadata_versions}`
   - `ParachainHost::{disputes, session_executor_params}`

5. **Weight files**:
   - Copied from polkadot v0.9.43: `pallet_balances`, `runtime_parachains_configuration`, `pallet_message_queue`, `runtime_parachains_inclusion`, `frame_system`, `pallet_xcm`
   - Removed deprecated: `runtime_parachains_ump`, `pallet_conviction_voting`, `pallet_referenda`, `pallet_whitelist`

6. **xcm_config fixes**:
   - Removed `close_old_weight` from pallet_collective Call patterns
   - Added `EnsureRoot` import and new pallet_xcm Config items

### Building with thxnet runtimes

```bash
# Build with thxnet-native feature
SKIP_WASM_BUILD=1 CC=clang-14 CXX=clang++-14 LIBCLANG_PATH=/usr/lib/llvm-14/lib CXXFLAGS="-include cstdint" \
cargo build --release -p polkadot-service --features thxnet-native

# Build with thxnet-testnet-native feature
SKIP_WASM_BUILD=1 CC=clang-14 CXX=clang++-14 LIBCLANG_PATH=/usr/lib/llvm-14/lib CXXFLAGS="-include cstdint" \
cargo build --release -p polkadot-service --features thxnet-testnet-native
```

---

## Common Build Errors & Solutions

### Error: wit-bindgen requires Rust 2024 edition
**Cause**: WASM builder downloads newer crates from crates.io
**Solution**: `SKIP_WASM_BUILD=1` for now, or upgrade Rust toolchain to 1.85+

### Error: bindgen panic "enum_unnamed... is not a valid Ident"
**Cause**: bindgen 0.60.1 incompatible with clang 18
**Solution**: `LIBCLANG_PATH=/usr/lib/llvm-14/lib`

### Error: uint8_t/uint16_t undeclared in RocksDB
**Cause**: Missing `<cstdint>` include in RocksDB headers
**Solution**: `CXXFLAGS="-include cstdint"`

### Error: Sender type mismatch (futures vs async_channel)
**Cause**: v0.9.43 uses async_channel instead of futures::channel::mpsc
**Solution**: Copy network/protocol from polkadot v0.9.43

---

## File Locations

- **Root Cargo.toml**: `/root/Works/rootchain/Cargo.toml`
- **Service Cargo.toml**: `/root/Works/rootchain/node/service/Cargo.toml`
- **PVF crate**: `/root/Works/rootchain/node/core/pvf/`
- **PVF worker**: `/root/Works/rootchain/node/core/pvf/worker/`
- **Primitives**: `/root/Works/rootchain/primitives/src/`
- **thxnet runtime**: `/root/Works/rootchain/runtime/thxnet/`
- **thxnet-testnet runtime**: `/root/Works/rootchain/runtime/thxnet-testnet/`

---

## Custom Components

- **pallet-dao**: `/root/Works/rootchain/pallets/dao/` - Needs substrate v0.9.43 dep updates
- **thxnet runtime**: Disabled in polkadot-native feature, needs API updates
- **thxnet-testnet runtime**: Disabled, needs API updates
