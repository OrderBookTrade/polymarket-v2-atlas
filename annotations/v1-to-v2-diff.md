# V1 → V2 diff

Placeholder. This file captures the **behavioral and ABI differences** between
CTFExchange V1 and CTFExchangeV2 from the perspective of an integrator who has
a working V1 decoder and wants to upgrade. Grown from real observation, not
from release notes.

**Status**: seed only. The entries below are observations from entry 0001 that
already imply a difference; they need to be confirmed against V1 source before
being promoted out of the seed section.

---

## Seed observations (need V1 cross-check)

These are things entry 0001 surfaced that look V2-specific — if the
corresponding V1 behavior differs, promote the item out of the seed section
with a citation to the V1 source in `contracts/upstream/` (V1 submodule
pending) or a known-good V1 tx.

### Order struct

V2 `Order` (from `contracts/upstream/ctf-exchange-v2/src/exchange/libraries/Structs.sol`):

```solidity
struct Order {
    uint256  salt;
    address  maker;
    address  signer;
    uint256  tokenId;
    uint256  makerAmount;
    uint256  takerAmount;
    Side     side;
    SignatureType signatureType;
    uint256  timestamp;   // ms since epoch
    bytes32  metadata;    // off-chain hash slot
    bytes32  builder;     // builder-code tag
    bytes    signature;
}
```

V2 **added**: `timestamp` (ms), `metadata`, `builder`.

V2 **removed** (vs. V1's widely-documented shape): `taker`, `expiration`,
`nonce`, `feeRateBps`.

Consequences:
- `ORDER_TYPEHASH` changed → V1 signatures do not validate against V2.
- Per-order fee rate is gone; the operator supplies fees per-fill in
  `takerFeeAmount` / `makerFeeAmounts[]` and the contract enforces a global
  `maxFeeRateBps` cap only when a non-zero fee is passed.
- No `taker` means V2 orders cannot be "private-to-a-specific-counterparty";
  matching is always open.
- No `expiration` means V2 relies on off-chain order expiration via operator
  book-keeping, not on-chain revert.

### `matchOrders` signature

V2:
```
matchOrders(
  bytes32 conditionId,
  Order   takerOrder,
  Order[] makerOrders,
  uint256 takerFillAmount,
  uint256[] makerFillAmounts,
  uint256 takerFeeAmount,
  uint256[] makerFeeAmounts
)   // selector 0x3c2b4399
```

V2 **added**: `conditionId` as the first argument. This lets the contract
validate via `CTHelpers.getPositionId` that every tokenId referenced is
actually a partition of the supplied condition — no silent token-id
mismatches. V1 did not take `conditionId`.

### Match-type classification

V2 formalizes three match types (`COMPLEMENTARY / MINT / MERGE`) as an explicit
enum and dispatches via pure-assembly branching in `_deriveMatchType`. V1's
match logic lived across `fillOrder` / `matchOrders` and did not name
"MINT / MERGE" as first-class concepts.

### Collateral plumbing

V2 uses a two-token model: `collateral` = `pUSD` (6-dec wrapper) for the
exchange side, `ctfCollateral` = `USDC.e` for the CTF side. A
`CtfCollateralAdapter` bridges between them inside `matchOrders`. V1 (as
deployed) used USDC.e directly as both exchange and CTF collateral.

### Signature types

Both V1 and V2 expose `EOA / POLY_PROXY / POLY_GNOSIS_SAFE / POLY_1271`. V2's
verifier helper in `Signatures.sol` reads essentially identical to V1's.
**No known difference** — but this deserves a line-by-line diff once the V1
submodule is added.

### Events

V2 `OrderFilled` signature:
```
OrderFilled(bytes32,address,address,uint8,uint256,uint256,uint256,uint256,bytes32,bytes32)
```
Added: `side (uint8)` as an explicit field, plus `builder` and `metadata`
trailing the fee. V1's `OrderFilled` did not carry `side / builder /
metadata` and had different makerAssetId/takerAssetId encoding.

V2 introduces `OrdersMatched(bytes32,address,uint8,uint256,uint256,uint256)`
as a per-match summary event emitted once per taker, making it cheaper to
classify a tx without decoding every `OrderFilled`. V1 had no equivalent.

---

## To-do before this file can be promoted out of "seed"

1. Add V1 CTFExchange submodule under `contracts/upstream/ctf-exchange/`
   (repo: `Polymarket/ctf-exchange`), pinned at the commit that matches the
   live V1 mainnet deployment.
2. Pin the V1 mainnet address + a canonical V1 "all-match-types" reference tx
   set in `registry/contracts.json` under a new `CTFExchangeV1` entry.
3. Re-derive each of the claims above against the V1 source + a real V1 tx.
4. For each confirmed diff, add a migration note for integrators (e.g. "If
   your V1 indexer keys orders by `(maker, nonce)`, switch to `(maker,
   salt)` and add `timestamp` for staleness checks").

Until step 1 happens, treat every claim here as "V2 observation that looks
V1-specific" rather than "confirmed diff."
