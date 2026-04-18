# Entry 0001 — CTFExchangeV2 · MINT match

> First atlas entry. A single real transaction, hand-decoded to every last field,
> with "how I found this" at each step so a reader can reproduce it from scratch.

## 0. Metadata

| Field | Value |
|---|---|
| Tx hash | [`0xc1375cac7b7fd147d57b2cfd639b0a295aa1fa56af3ec00b5de31fba3f00e609`](https://polygonscan.com/tx/0xc1375cac7b7fd147d57b2cfd639b0a295aa1fa56af3ec00b5de31fba3f00e609) |
| Block | `85671485` (`0x51b3e3d`) |
| Timestamp | `1776463014` — 2026-04-17 21:56:54 UTC |
| Chain | Polygon PoS (chainId `137` / `0x89`) |
| From (tx signer) | `0xbcc8fa69f92de26043854e2f472773aea485d4b7` — operator hotkey, nonce = 0 |
| To | `0xE111180000d2663C0091e4f400237545B87B996B` — CTFExchangeV2 |
| Value | 0 |
| Gas used | `448,584` (`0x6d848`) |
| Effective gas price | `1,443.86 gwei` (Polygon runs hot; this is normal) |
| Tx fee | `0.647694 MATIC` |
| Method | `matchOrders(bytes32,Order,Order[],uint256,uint256[],uint256,uint256[])` — selector `0x3c2b4399` |
| Flow classification | **MINT** (both sides are BUY on complementary tokenIds) |

> **How I found this**: Polygonscan contract page → Transactions tab paginated back to the three most recent "Match Orders" txs. The contract has only three fills in its history (it just went live); see [Step 1 analysis](#appendix-a--why-mint-and-not-complementary). Raw data pulled via `eth_getTransactionByHash` and `eth_getTransactionReceipt` against `https://polygon.drpc.org` (public RPCs `polygon-rpc.com` and `rpc.ankr.com/polygon` required an API key; dRPC did not). Archived responses live in [`artifacts/`](./artifacts).

---

## 1. TL;DR

Two BUY orders on complementary outcomes of the same condition were matched. Each side paid pUSD, and CTFExchangeV2 ran them through the `CtfCollateralAdapter`, which **unwrapped pUSD to USDC.e** and called Gnosis CTF's `splitPosition` — minting 2,083,332 shares of each complementary tokenId. Each BUYer got the tokenId they ordered; no fee was charged; no CTF was transferred from a seller because there was no seller.

The interesting edges are all at the **collateral boundary**: Exchange-side collateral is `pUSD`, CTF-side collateral is `USDC.e`, and the adapter bridges between them inside a single external call.

---

## 2. Actor map

| Address | Role | Notes |
|---|---|---|
| `0xbcc8fa69…85d4b7` | **operator** (tx signer) | EOA gated by `onlyOperator`; nonce 0 → freshly provisioned hotkey |
| `0xE111180000d2663C0091e4f400237545B87B996B` | **CTFExchangeV2** | Verified source matches [Polymarket/ctf-exchange-v2](https://github.com/Polymarket/ctf-exchange-v2) |
| `0x361B766227DB19d4C8037595A9d4ced9faD81a24` | **taker order maker** | Polymarket Gnosis Safe proxy — confirmed by signatureType = 2 and the callback chain (see §6) |
| `0xeDC29f520f92685ee8DFE3C3200139D671b044B2` | **taker order signer** | EOA owning the Safe above; present only in order struct, never appears on-chain |
| `0xF5183756a0bE58AA0b0960F1e2D2451894B631d5` | **maker order maker = signer** | Plain EOA (signatureType = 0) |
| `0xc011a7e12a19f7b1f670d46f03b03f3342e82dfb` | **pUSD** (exchange-side collateral, 6 decimals) | UUPS proxy; impl `0x6bbcef…0925f`. Per source: `CollateralToken` wrapping USDC/USDCe |
| `0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174` | **USDC.e** (ctf-side collateral, 6 decimals) | Bridged USDC; impl `0xdd9185…812226` |
| `0xADa100874d00e3331D00F2007a9c336a65009718` | **CtfCollateralAdapter** | Translates pUSD-denominated splits/merges into USDC.e-denominated CTF calls |
| `0x4D97DCd97eC945f40cF65F87097ACe5EA0476045` | **ConditionalTokens** | Gnosis CTF — third-party, unchanged |
| `0xC417fD8E9661c0D2120B64A04BB3278C17E99DB1` | **pUSD reserve vault** | Custodies USDC.e that backs pUSD. Pre-approved pUSD proxy to pull USDC.e |
| `0xe51abdf814f8854941b9fe8e3a4f65cab4e7a4a8` | Safe singleton | Delegatecall target of `0x361B…` — confirms it's a Gnosis Safe proxy |

> **How I found this**: `onlyOperator` identified from `src/exchange/CTFExchange.sol:56`. Safe proxy identity confirmed by walking the trace: the final `safeTransferFrom` of the NO token to `0x361B…` triggers `onERC1155Received(0xf23a6e61)` which `DELEGATECALL`s to `0xe51abdf…` — the Gnosis Safe singleton. Adapter name read from the verified source at [polygonscan address page](https://polygonscan.com/address/0xADa100874d00e3331D00F2007a9c336a65009718).

---

## 3. Flow classification

> **COMPLEMENTARY** (direct buy-vs-sell): same tokenId on both orders, opposite sides.
> **MINT** (both BUY): different tokenIds that are the `[1,2]` partition of the same condition — collateral goes into `splitPosition`.
> **MERGE** (both SELL): different tokenIds, opposite direction — collateral comes out of `mergePositions`.

Here:

- Taker `side = 0` (BUY), Maker `side = 0` (BUY) → both buys.
- Taker `tokenId = 45763018…289693`, Maker `tokenId = 102936224…677216` — these are a complementary pair under `conditionId = 0x182390641d3b1b47cc64274b9da290efd04221c586651ba190880713da6347d9` (confirmed by the single `PositionSplit` in log 10 with that conditionId and partition `[1, 2]`).
- `PositionSplit` event is present → Exchange minted CTF from collateral.

The classification rule is also explicit in source:

```solidity
// Trading.sol:577
function _deriveMatchType(takerOrder, makerOrder) {
    matchType := mul(add(takerOrderSide, 1), eq(takerOrderSide, makerOrderSide))
}
```

- Both BUY (0, 0) → `(0+1) * 1 = 1` = `MINT`.
- Both SELL (1, 1) → `(1+1) * 1 = 2` = `MERGE`.
- Opposite sides → `*0 = 0` = `COMPLEMENTARY`.

> **How I found this**: Read `_deriveMatchType` in [`src/exchange/mixins/Trading.sol:577`](https://github.com/Polymarket/ctf-exchange-v2/blob/main/src/exchange/mixins/Trading.sol). Confirmed MINT by the presence of exactly one `PositionSplit` log (`0x2e6bb91f…6298`) and zero `PositionsMerge` logs in the receipt.

---

## 4. Call trace (depth-collapsed)

```
[0]  matchOrders → CTFExchangeV2                                 gas 448584
 ├─[0.0]  STATICCALL → ecrecover (0x01)             [verify taker sig]
 ├─[0.1]  CALL  → pUSD.transferFrom(taker, Exchange, 999999)
 ├─[0.2]  STATICCALL → CTF.balanceOf(Exchange, takerTokenId)     [pre-delta]
 ├─[0.3]  STATICCALL → ecrecover (0x01)             [verify maker sig]
 ├─[0.4]  CALL  → pUSD.transferFrom(maker, Exchange, 1083333)
 ├─[0.5]  CALL  → CtfCollateralAdapter.splitPosition(pUSD, 0, conditionId, [1,2], 2083332)
 │   ├─[0.5.0]  CALL  → pUSD.transferFrom(Exchange, pUSD-self, 2083332)
 │   ├─[0.5.1]  CALL  → pUSD.unwrap(USDC.e, adapter, 2083332, adapter, ...)
 │   │   └─  (burns pUSD from its own balance) → USDC.e.transferFrom(reserveVault, adapter, 2083332)
 │   ├─[0.5.2]  CALL  → CTF.splitPosition(USDC.e, 0, conditionId, [1,2], 2083332)
 │   │   ├─  USDC.e.transferFrom(adapter, CTF, 2083332)
 │   │   └─  CTF mints both tokenIds to adapter; callback onERC1155BatchReceived → adapter (accept)
 │   └─[0.5.3]  CALL  → CTF.safeBatchTransferFrom(adapter, Exchange, [ids], [values])
 │       └─  callback onERC1155BatchReceived → Exchange (accept)
 ├─[0.6]  CALL  → CTF.safeTransferFrom(Exchange, maker, makerTokenId, 2083332)    [distribute to maker]
 ├─[0.7]  STATICCALL → CTF.balanceOf(Exchange, takerTokenId)     [post-delta]
 ├─[0.8]  CALL  → CTF.safeTransferFrom(Exchange, taker, takerTokenId, 2083332)    [distribute to taker]
 │   └─  callback onERC1155Received → Safe proxy → delegatecall Safe singleton → (accept)
 └─[0.9]  STATICCALL → pUSD.balanceOf(Exchange)     [post-delta; refund = 0]
```

> **How I found this**: `debug_traceTransaction` with `{tracer:"callTracer"}` against dRPC. Selectors translated via `cast sig` for known signatures; unfamiliar ones (`0x72ce4275 = splitPosition`, `0xd600875d = unwrap(address,address,uint256,address,bytes)`) resolved by brute-force matching against candidate signatures from the adapter and CollateralToken interfaces. Raw trace in [`artifacts/trace.json`](./artifacts/trace.json).

---

## 5. Calldata, fully decoded

`cast --calldata-decode 'matchOrders(bytes32,(uint256,address,address,uint256,uint256,uint256,uint8,uint8,uint256,bytes32,bytes32,bytes),(uint256,address,address,uint256,uint256,uint256,uint8,uint8,uint256,bytes32,bytes32,bytes)[],uint256,uint256[],uint256,uint256[])' <input>`:

### conditionId
`0x182390641d3b1b47cc64274b9da290efd04221c586651ba190880713da6347d9`

### takerOrder

| Field | Value | Human-readable |
|---|---|---|
| salt | `853910448971285` | — |
| maker | `0x361B766227DB19d4C8037595A9d4ced9faD81a24` | Safe proxy |
| signer | `0xeDC29f520f92685ee8DFE3C3200139D671b044B2` | EOA owner of Safe |
| tokenId | `45763018441764333771124945243746174684578244015331389396782339063349542289693` | = `getPositionId(USDC.e, getCollectionId(0, conditionId, 2))` — outcome at partition index 2 |
| makerAmount | `1_000_000` | 1.000000 pUSD (6 decimals) — max collateral to spend |
| takerAmount | `2_040_000` | 2.040000 shares (6-dec unit; CTF is scaled to collateral) — min shares to receive |
| side | `0` | BUY |
| signatureType | `2` | POLY_GNOSIS_SAFE |
| timestamp | `1776463011256` | ms — 3 seconds before block timestamp |
| metadata | `0x0000…` | empty (off-chain hash slot) |
| builder | `0x0000…` | empty (builder-code slot) |
| signature | `0x684885ec…1b` | 65 bytes (r,s,v) — ECDSA over EIP-712 `Order` struct |
| **Implied limit price** | `1.0000 / 2.0400 = 0.4902 pUSD / share` | willing to pay ≤ 49.02¢ per "NO" |

### makerOrders[0]

| Field | Value | Human-readable |
|---|---|---|
| salt | `98632907414` | — |
| maker | `0xF5183756a0bE58AA0b0960F1e2D2451894B631d5` | EOA |
| signer | same as maker | — |
| tokenId | `102936224134271070189104847090829839924697394514566827387181305960175107677216` | = partition index 1 of same condition |
| makerAmount | `2_148_333_200` | 2148.33 pUSD — max spend (large order) |
| takerAmount | `4_131_410_000` | 4131.41 shares |
| side | `0` | BUY |
| signatureType | `0` | EOA |
| timestamp | `1776123699467` | ms — ~94 hours earlier; resting order |
| metadata, builder | `0x0000…` | empty |
| signature | `0xfa547e2a…1b` | 65 bytes |
| **Implied limit price** | `2148.3332 / 4131.41 = 0.5200 pUSD / share` | willing to pay ≤ 52¢ per "YES" |

### Fill parameters (operator-supplied)

| Arg | Value | Meaning |
|---|---|---|
| `takerFillAmount` | `999_999` | Of taker's `makerAmount` to consume (all but one unit of dust) |
| `makerFillAmounts[0]` | `1_083_333` | Of maker's `makerAmount` to consume |
| `takerFeeAmount` | `0` | Zero fees this tx |
| `makerFeeAmounts[0]` | `0` | — |

### Price cross-check

For a MINT match to be valid, `takerPrice + makerPrice ≥ 1`:
`0.490196 + 0.520000 = 1.010196 ≥ 1` ✓ — the 1.02¢ of surplus is what lets the operator match the two orders through a fresh split.

> **How I found this**: Function selector `0x3c2b4399` verified by `cast sig "matchOrders(bytes32,(…Order…),(…Order…)[],uint256,uint256[],uint256,uint256[])"`. The `Order` tuple shape was read from [`src/exchange/libraries/Structs.sol:30`](https://github.com/Polymarket/ctf-exchange-v2/blob/main/src/exchange/libraries/Structs.sol#L30). The ORDER_TYPEHASH comment on line 25 lists fields in the exact order the struct is encoded. Human-readable decode in [`artifacts/decoded-calldata.txt`](./artifacts/decoded-calldata.txt).

---

## 6. Signature type identification

V2 has four types, enumerated in `src/exchange/libraries/Structs.sol:59`:

| `signatureType` | Name | Verifier (`src/exchange/mixins/Signatures.sol`) |
|---|---|---|
| 0 | EOA | `_verifyEOASignature`: `signer == maker AND ECDSA.recover(hash, sig) == signer` |
| 1 | POLY_PROXY | `_verifyPolyProxySignature`: `ECDSA.recover == signer AND getProxyWalletAddress(signer) == maker` |
| 2 | POLY_GNOSIS_SAFE | `_verifyPolySafeSignature`: `ECDSA.recover == signer AND getSafeWalletAddress(signer) == maker` |
| 3 | POLY_1271 | `_verifyPoly1271Signature`: `signer == maker AND maker.code.length > 0 AND ERC1271(maker).isValidSignature(hash, sig) == 0x1626ba7e` |

So **all** signature types except POLY_1271 end up doing an ECDSA recover — the difference is what the recovered `signer` is checked *against*. POLY_PROXY and POLY_GNOSIS_SAFE compute a CREATE2-deterministic proxy/safe address off the signer and assert it equals `order.maker`.

### Taker order — `signatureType = 2` (POLY_GNOSIS_SAFE)

- signer `0xeDC29f5…44B2` recovered from `0x684885ec…1b` against EIP-712 hash `0x99c7919a43f8aec7d4ba70a258691ddefa11f274ffe82c49369743047d927630` (this hash surfaces in the `OrderFilled` topic1 for the taker).
- `getSafeWalletAddress(0xeDC29f5…)` expected to return `0x361B7662…1a24`. Can't re-derive without the safe factory address + init bytecode, but the trace itself confirms: the final `safeTransferFrom` to `0x361B…` triggered `onERC1155Received` which `delegatecall`-ed to `0xe51abdf8…` — the Gnosis Safe singleton. That would not happen for a plain EOA.

### Maker order — `signatureType = 0` (EOA)

- signer = maker = `0xF518375…31d5`.
- signature `0xfa547e2a…1b` (65 bytes) ECDSA-recovers to `0xF518375…31d5` against hash `0xe98b71bc…2fc5d6` (`OrderFilled` topic1 for the maker).
- No factory-derivation step.

> **How I found this**: The validator logic is in [`src/exchange/mixins/Signatures.sol:68`](https://github.com/Polymarket/ctf-exchange-v2/blob/main/src/exchange/mixins/Signatures.sol#L68). The precompile call `[0.0]` and `[0.3]` in the trace hit address `0x0000…0001` (ecrecover) — confirming both orders use ECDSA-recover. The *second*-level identity check (plain EOA vs proxy vs safe) happens in-contract with no external call, so you cannot distinguish the four sigtypes purely from the trace — you have to read the calldata's `signatureType` field.

---

## 7. Fund flow (with pennies)

All amounts are raw 6-decimal units; multiply by 10⁻⁶ for pUSD / USDC.e, or treat as "shares" for CTF ERC1155 ids.

```
pUSD side
─────────
 taker (0x361B) ──(999,999 pUSD)──▶ Exchange        [log 0, via transferFrom allowance]
 maker (0xF518) ──(1,083,333)────▶ Exchange         [log 1]
 Exchange        ──(2,083,332)──▶  pUSD-self        [log 2]  ← deposited into pUSD contract
 pUSD-self       ──(2,083,332)──▶  0x0 (burn)       [log 5]  ← unwrap burns the deposited pUSD

USDC.e side (inside pUSD.unwrap)
─────────
 reserveVault (0xC417) ──(2,083,332 USDC.e)──▶ adapter  [log 3]
 adapter ──(2,083,332)──▶ CTF                            [log 7, pulled by splitPosition]

CTF side
─────────
 CTF mints 2,083,332 of id-102936 + 2,083,332 of id-45763 → adapter  [log 9 TransferBatch; log 10 PositionSplit]
 adapter ──both ids, 2,083,332 each──▶ Exchange                        [log 11 TransferBatch]
 Exchange ──(id-102936, 2,083,332)──▶ maker (0xF518)                  [log 12 TransferSingle]
 Exchange ──(id-45763,  2,083,332)──▶ taker (0x361B)                  [log 14 TransferSingle]

Fees:   none (takerFeeAmount = 0, makerFeeAmounts = [0])
Refund: none (Exchange pUSD balance delta = 0; nothing left to return)
```

**Net positions after the tx:**

| Party | pUSD Δ | USDC.e Δ | CTF token-102936 Δ | CTF token-45763 Δ |
|---|---|---|---|---|
| taker (`0x361B…`) | −999,999 | 0 | 0 | +2,083,332 |
| maker (`0xF518…`) | −1,083,333 | 0 | +2,083,332 | 0 |
| CtfCollateralAdapter | 0 | 0 | 0 | 0 |
| pUSD reserveVault | 0 | −2,083,332 | 0 | 0 |
| CTF | 0 | +2,083,332 | 0 | 0 |
| **Total** | **−2,083,332** | **0** | **+2,083,332** | **+2,083,332** |

pUSD total supply drops by 2,083,332 (burned); CTF-USDC.e-backed shares on each side grow by 2,083,332 (fresh supply from the split).

> **How I found this**: Reconstructed from log indices 0–16 of the receipt. Decoded topic hashes via `cast sig-event`. Token → decimals: pUSD declared 6 decimals at [`src/collateral/CollateralToken.sol:118`](https://github.com/Polymarket/ctf-exchange-v2/blob/main/src/collateral/CollateralToken.sol#L118); USDC.e is the bridged USDC on Polygon, also 6 decimals; CTF is ERC1155 and has no decimals — values are "shares" scaled 1:1 with the collateral.

---

## 8. Events, fully decoded

18 logs total. Log 17 is the Polygon fee LogTransfer on `0x…1010` — ignored.

| # | Contract | Event | Key fields |
|---|---|---|---|
| 0 | pUSD | `Transfer` | `from=0x361B… → Exchange, value=999,999` |
| 1 | pUSD | `Transfer` | `from=0xF518… → Exchange, value=1,083,333` |
| 2 | pUSD | `Transfer` | `from=Exchange → pUSD-self, value=2,083,332` |
| 3 | USDC.e | `Transfer` | `from=reserveVault → adapter, value=2,083,332` |
| 4 | USDC.e | `Approval` | reserveVault → pUSD, allowance decremented (infinite pre-approval pattern) |
| 5 | pUSD | `Transfer` | `from=pUSD-self → 0x0, value=2,083,332` (burn) |
| 6 | pUSD | `Unwrapped(address by, address asset, address to, uint256 amount)` | `by=adapter, asset=USDC.e, to=adapter, amount=2,083,332` |
| 7 | USDC.e | `Transfer` | `from=adapter → CTF, value=2,083,332` |
| 8 | USDC.e | `Approval` | adapter → CTF, allowance decremented |
| 9 | CTF | `TransferBatch` | `operator=adapter, from=0x0, to=adapter, ids=[102936…, 45763…], values=[2,083,332, 2,083,332]` (mint) |
| 10 | CTF | `PositionSplit` | `stakeholder=adapter, collateralToken=USDC.e, parentCollectionId=0, conditionId=0x182390…, partition=[1,2], amount=2,083,332` |
| 11 | CTF | `TransferBatch` | `operator=adapter, from=adapter, to=Exchange, same ids, same values` |
| 12 | CTF | `TransferSingle` | `operator=Exchange, from=Exchange, to=0xF518… (maker), id=102936…, value=2,083,332` |
| 13 | Exchange | `OrderFilled` | **maker order**: orderHash `0xe98b71bc…2fc5d6`, maker `0xF518…`, taker `0x361B…`, side `BUY`, tokenId `102936…`, makerAmountFilled `1,083,333`, takerAmountFilled `2,083,332`, fee `0` |
| 14 | CTF | `TransferSingle` | `operator=Exchange, from=Exchange, to=0x361B… (taker), id=45763…, value=2,083,332` |
| 15 | Exchange | `OrderFilled` | **taker order**: orderHash `0x99c7919a…7d927630`, maker `0x361B…`, **taker = Exchange itself**, side `BUY`, tokenId `45763…`, makerAmountFilled `999,999`, takerAmountFilled `2,083,332`, fee `0` |
| 16 | Exchange | `OrdersMatched` | orderHash `0x99c7919a…`, taker `0x361B…`, side `BUY`, tokenId `45763…`, makerAmountFilled `999,999`, takerAmountFilled `2,083,332` |

Event schemas:

```
OrderFilled(
  bytes32 indexed orderHash,
  address indexed maker,
  address indexed taker,
  uint8   side,
  uint256 tokenId,
  uint256 makerAmountFilled,
  uint256 takerAmountFilled,
  uint256 fee,
  bytes32 builder,
  bytes32 metadata
)   // topic0 = 0xd543adfd9457…4d8ee

OrdersMatched(
  bytes32 indexed orderHash,
  address indexed taker,
  uint8   side,
  uint256 tokenId,
  uint256 makerAmountFilled,
  uint256 takerAmountFilled
)   // topic0 = 0x174b381169065…cab7c — emitted exactly once per matchOrders call, tied to taker order
```

> **How I found this**: Topic0 strings cross-referenced with `cast sig-event`. The pUSD event `Unwrapped(address,address,address,uint256)` was guessed from the topic pattern (3 indexed addresses, 1 uint256) and confirmed by `cast sig-event "Unwrapped(address,address,address,uint256)" = 0x18b42b68…9aa7f`, matching log 6's topic0.

---

## 9. Trust boundaries crossed

```
┌────────────────────┐  operator tx (onlyOperator gate)
│  operator EOA      │
│  0xbcc8…d4b7       │
└────────┬───────────┘
         ▼
┌────────────────────────────────────────────────────────────────────┐
│  CTFExchangeV2  (Polymarket, verified, audited scope)              │
│   · validates sigs                                                 │
│   · calculates fills                                               │
│   · emits OrderFilled / OrdersMatched                              │
└──┬────────────┬──────────────────────────────┬────────────────────┘
   │            │                              │
   │            │ (collateral pull)            │ (distribute CTF)
   ▼            ▼                              ▼
┌────────┐  ┌───────────────────────────┐  ┌─────────────────────┐
│ pUSD   │  │  CtfCollateralAdapter     │  │  ConditionalTokens  │
│(Poly)  │  │  0xADa1…9718 (Polymarket) │  │  0x4D97…6045 (CTF — │
│ UUPS   │  │  · unwrap pUSD→USDC.e     │  │   Gnosis, unchanged)│
└──┬─────┘  │  · splitPosition on CTF   │  │  ERC1155, third-    │
   │        │  · shuttles ERC1155 back  │  │  party code.        │
   │        └──────┬───────────┬────────┘  └────────┬────────────┘
   │               ▼           ▼                    ▲
   │        ┌────────┐   ┌────────────┐             │
   │        │pUSD    │   │ USDC.e     │─────────────┘
   │        │reserveV│◀──│ (bridged   │   (CTF pulls USDC.e as
   │        │0xC417..│   │  USDC on   │    collateral for split)
   │        └────────┘   │  Polygon)  │
   │                     └────────────┘
   ▼
(Exchange never calls Gnosis CTF directly for collateral-moving ops.
 All such calls are mediated by CtfCollateralAdapter.)
```

**Boundaries that matter:**

1. **Exchange ↔ pUSD**: Polymarket-owned, but UUPS-upgradeable. An implementation swap changes `unwrap` semantics (what token comes out of the vault, decimals, fees…). Readers integrating should pin the implementation address (`0x6bbcef…0925f` at block 85671485) and set an alarm on `Upgraded(address)`.
2. **Exchange ↔ CtfCollateralAdapter**: Polymarket-owned, thin translator. But: the adapter has max approval on USDC.e to CTF (log 8 shows the decrement, implying a pre-existing large allowance). A bug in the adapter could drain that allowance.
3. **Adapter ↔ Gnosis CTF**: third-party (`@gnosis.pm/conditional-tokens-contracts`). Fully external code, unchanged for years. `splitPosition` escrows collateral until `resolve`/`redeem`.
4. **pUSD ↔ pUSD reserve vault** (`0xC417…99DB1`): the vault holds USDC.e backing pUSD. pUSD proxy has a pre-approved allowance from the vault (log 4's decrement pattern). Vault custody rules aren't in the exchange repo — they're in the collateral sub-repo.
5. **CTF → Safe proxy** (on `safeTransferFrom`): the Safe's `onERC1155Received` does a `delegatecall` to the Safe singleton `0xe51abdf…`. In this tx the singleton accepts and returns. A malicious Safe module could block receive here — something to watch for integrators sending CTF to arbitrary user addresses.

> **How I found this**: Walked the receipt + trace, and noted each distinct contract boundary. Adapter role confirmed by the verified source of `0xADa1…9718`. Safe singleton identity read from the last `DELEGATECALL` in the trace.

---

## 10. Gotcha list (things that stopped me > 30 s)

1. **"COMPLEMENTARY" is V2's name for direct buy-vs-sell**, not "matched order pair." The three match types per source are `COMPLEMENTARY / MINT / MERGE`. Easy to conflate with the V1/colloquial usage of "complementary positions" meaning YES+NO.
2. **Only `matchOrders` exists in V2**. There is no `fillOrder` or `fillOrders`. Every single-fill is still a `matchOrders` call with `makerOrders.length = 1`.
3. **The `Order` struct has no `taker`, no `nonce`, no `expiration`, no `feeRateBps`**. V2 added `timestamp` (ms), `metadata` (bytes32), `builder` (bytes32); fees are supplied per-fill by the operator in `takerFeeAmount`/`makerFeeAmounts[]`, not baked into the order. Translating V1 ABI directly will produce a wrong selector.
4. **The taker's `OrderFilled` event has `taker = Exchange address`**, not the counterparty. This is by design — `_emitTakerFilledEvents` sets `taker: address(this)` (see `Trading.sol:135`, `:288`, `:339`). Only the `OrdersMatched` event uses the counterparty-agnostic `taker = takerOrder.maker`. Don't try to reconstruct counterparty links from the taker `OrderFilled` alone.
5. **`OrdersMatched` is emitted exactly once per `matchOrders` call, tied to the taker** — so `OrdersMatched` count = taker fills, `OrderFilled` count = taker fills + maker fills. Use this to cheaply classify a tx.
6. **`takerAmountFilled` in the taker's `OrderFilled` can exceed the order's `takerAmount` limit.** In this tx the taker ordered `takerAmount = 2_040_000` but actually received `2_083_332`. Why: in MINT, the amount received is driven by the collateral pool's split output (`totalMintAmount = sum of maker takings`), *not* by the taker's ratio. The surplus comes from the maker paying more than the taker needed per share. The taker's "worst case" — their limit price — is enforced via the `_validateOrdersMatch` cross-condition (`taker.taker*maker.maker + maker.taker*taker.maker ≥ taker.taker*maker.taker`), which is price-floor semantics, not volume-ceiling.
7. **`makerFillAmount` and `takerFillAmount` are both denominated in *maker*-amount units** of the respective order. For BUYs that's collateral (pUSD, 6 decimals); for SELLs it's CTF shares. Confused me for a while because of the symmetric parameter names.
8. **`_deriveAssetIds` treats `tokenId = 0` as "collateral"**. `AssetOperations.sol:21` branches on `id == 0`. For a BUY, `makerAssetId = 0` and `takerAssetId = order.tokenId`; for a SELL it's flipped. This is why `OrderFilled` only emits the one tokenId and never the "other leg" — the other leg is always implicitly the collateral.
9. **The Exchange's collateral is pUSD; the CTF's collateral is USDC.e.** Look at `PositionSplit`'s `collateralToken` field (log 10) — it's the USDC.e address, not pUSD. Don't try to use pUSD to compute position IDs via `CTHelpers.getPositionId`. Use the `ctfCollateral` slot (readable via `getCtfCollateral()`), which is USDC.e here.
10. **The pUSD deposit path is counter-intuitive**: Exchange sends pUSD *into pUSD itself* (log 2: `Transfer(Exchange → pUSD-self)`), then pUSD burns that balance from itself (log 5). There is no intermediate "Exchange → adapter → burn" transfer. The adapter is the caller but pUSD is the custodian.
11. **`CtfCollateralAdapter` masquerades as `ConditionalTokens`**: the Exchange's `outcomeTokenFactory` slot points at the adapter, not at Gnosis CTF. The adapter re-implements the `splitPosition / mergePositions / redeemPositions` signatures. Selector collision is intentional — the Exchange doesn't know (or care) that it's talking to an adapter.
12. **Operator nonce = 0** — the signer EOA was freshly provisioned for this tx. The contract's operator set can be large (>20 `AddOperator` events at deployment block). Don't assume "operator" = one well-known address.
13. **No `FeeCharged` event** in this tx, because `feeAmount = 0`. Sample fee-bearing txs separately to confirm the fee flow. Fees land at `getFeeReceiver()`, which is configurable.
14. **Gnosis CTF emits `TransferBatch` with `from = 0x0` on split** — this is a *mint*, not a transfer from a real account. A naive indexer will show the adapter "receiving tokens from the zero address," which is correct but jarring.
15. **Signature recovery alone doesn't distinguish POLY_PROXY vs POLY_GNOSIS_SAFE vs POLY_1271 from on-chain data** — all four types perform `ecrecover` (except POLY_1271 which calls `isValidSignature`), and the proxy/safe address derivation is pure computation. You **must** read the `signatureType` field out of calldata to know which rule was applied.

---

## 11. Registry schema v0 (what I had to look up, turned into a schema)

While decoding this tx I pulled the following fields from on-chain state / verified source. Those are the minimum slots a v0 registry needs to make a second tx solvable.

```json
{
  "version": "0.0.1-seed",
  "chain": {
    "id": 137,
    "name": "polygon"
  },
  "contracts": {
    "CTFExchangeV2": {
      "address": "0xE111180000d2663C0091e4f400237545B87B996B",
      "repo": "https://github.com/Polymarket/ctf-exchange-v2",
      "verifiedSource": "polygonscan",
      "deployedAtBlock": null,
      "deployTx": "0xd313453c195344b3eea2d91343fb840e51130ba5562fb9c9eda83fd0f82c6c97",
      "deployer": "0xca71ea69c54c163d17beb90beb8d001e1eb538a1",
      "role": "exchange-entry",
      "exposedMethods": [
        {
          "name": "matchOrders",
          "selector": "0x3c2b4399",
          "gateModifier": "onlyOperator notPaused",
          "abi": "matchOrders(bytes32,(uint256,address,address,uint256,uint256,uint256,uint8,uint8,uint256,bytes32,bytes32,bytes),(uint256,address,address,uint256,uint256,uint256,uint8,uint8,uint256,bytes32,bytes32,bytes)[],uint256,uint256[],uint256,uint256[])"
        }
      ],
      "events": {
        "OrderFilled": {
          "topic0": "0xd543adfd945773f1a62f74f0ee55a5e3b9b1a28262980ba90b1a89f2ea84d8ee",
          "signature": "OrderFilled(bytes32,address,address,uint8,uint256,uint256,uint256,uint256,bytes32,bytes32)",
          "indexed": ["orderHash", "maker", "taker"]
        },
        "OrdersMatched": {
          "topic0": "0x174b3811690657c217184f89418266767c87e4805d09680c39fc9c031c0cab7c",
          "signature": "OrdersMatched(bytes32,address,uint8,uint256,uint256,uint256)",
          "indexed": ["orderHash", "taker"]
        },
        "FeeCharged": {
          "topic0": "0x55bb3cade9d43b798a4fe5ffdd05024b2d7870df53920673bfc7e68047cd0ab1",
          "signature": "FeeCharged(address,uint256)",
          "indexed": ["receiver"]
        }
      },
      "readSlots": {
        "getCollateral": "address of pUSD",
        "getCtfCollateral": "address of USDC.e (used for CTHelpers.getPositionId)",
        "getCtf": "address of ConditionalTokens",
        "getOutcomeTokenFactory": "address of CtfCollateralAdapter (target of splitPosition)",
        "getFeeReceiver": "address that receives fee transfers",
        "maxFeeRateBps": "uint256 cap enforced lazily when fee != 0"
      },
      "storage": {
        "orderStatus": "mapping(bytes32 orderHash => { bool filled, uint248 remaining })",
        "preapproved": "mapping(bytes32 orderHash => bool)"
      },
      "enums": {
        "SignatureType": { "EOA": 0, "POLY_PROXY": 1, "POLY_GNOSIS_SAFE": 2, "POLY_1271": 3 },
        "Side": { "BUY": 0, "SELL": 1 },
        "MatchType": { "COMPLEMENTARY": 0, "MINT": 1, "MERGE": 2 }
      },
      "orderTypehash": "0xbb86318a2138f5fa8ae32fbe8e659f8fcf13cc6ae4014a707893055433818589",
      "orderStructFields": [
        "uint256 salt", "address maker", "address signer", "uint256 tokenId",
        "uint256 makerAmount", "uint256 takerAmount", "uint8 side", "uint8 signatureType",
        "uint256 timestamp", "bytes32 metadata", "bytes32 builder", "bytes signature"
      ]
    },
    "pUSD": {
      "address": "0xc011a7e12a19f7b1f670d46f03b03f3342e82dfb",
      "impl_at_block_85671485": "0x6bbcef9f7ef3b6c592c99e0f206a0de94ad0925f",
      "role": "collateral-exchange-side",
      "decimals": 6,
      "symbol": "pUSD",
      "kind": "UUPS upgradable ERC20 wrapper over USDC/USDC.e",
      "customEvents": {
        "Unwrapped": {
          "topic0": "0x18b42b684d0b621cc609f4d888916e5ed9e934a476259ec1c11ec116f2b9aa7f",
          "signature": "Unwrapped(address,address,address,uint256)",
          "args": ["by", "asset", "to", "amount"]
        }
      },
      "reserveVault": "0xC417fD8E9661c0D2120B64A04BB3278C17E99DB1"
    },
    "USDCe": {
      "address": "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
      "role": "collateral-ctf-side",
      "decimals": 6,
      "symbol": "USDC.e",
      "kind": "third-party bridged USDC on Polygon"
    },
    "CtfCollateralAdapter": {
      "address": "0xADa100874d00e3331D00F2007a9c336a65009718",
      "role": "collateral-bridge",
      "translates": "pUSD-denominated split/merge/redeem → USDC.e-denominated CTF calls",
      "exposedMethods": [
        { "name": "splitPosition",   "selector": "0x72ce4275" },
        { "name": "mergePositions",  "selector": "0x9e7212ad" },
        { "name": "redeemPositions", "selector": null }
      ]
    },
    "ConditionalTokens": {
      "address": "0x4D97DCd97eC945f40cF65F87097ACe5EA0476045",
      "role": "positions-ledger",
      "kind": "third-party (Gnosis @gnosis.pm/conditional-tokens-contracts)",
      "eventSignatures": {
        "TransferSingle": "TransferSingle(address,address,address,uint256,uint256)",
        "TransferBatch":  "TransferBatch(address,address,address,uint256[],uint256[])",
        "PositionSplit":  "PositionSplit(address,address,bytes32,bytes32,uint256[],uint256)",
        "PositionsMerge": "PositionsMerge(address,address,bytes32,bytes32,uint256[],uint256)",
        "PayoutRedemption":"PayoutRedemption(address,address,bytes32,bytes32,uint256[],uint256)"
      }
    }
  },
  "derivations": {
    "positionId": "CTHelpers.getPositionId(ctfCollateral, collectionId)   // ctfCollateral, NOT collateral",
    "collectionId": "CTHelpers.getCollectionId(parentCollectionId=bytes32(0), conditionId, indexSet)  // partition is [1,2] for binary markets"
  },
  "classifiers": {
    "matchType_from_orderFilled_count_and_transfersingle_pattern": {
      "COMPLEMENTARY": "2 OrderFilled + TransferSingle(s) only between maker and taker; no PositionSplit/PositionsMerge",
      "MINT":           "2+ OrderFilled + 1 PositionSplit (adapter as stakeholder) + TransferBatch(0x0→adapter)",
      "MERGE":          "2+ OrderFilled + 1 PositionsMerge (adapter as stakeholder) + TransferBatch(adapter→0x0)"
    }
  }
}
```

> **How I found this**: Every leaf of this JSON was reached while decoding *this one tx*. If the registry is missing any of these keys, a decoder can't handle a second tx on V2. See Appendix B for the exact commands that produced each field.

---

## Appendix A — why MINT and not COMPLEMENTARY

CTFExchangeV2 launched recently. At the time of this entry, the contract's entire
history contains exactly 3 `matchOrders` transactions (blocks 85669960, 85671485,
85672456). All three have a `PositionSplit` log → all three are MINT. No
COMPLEMENTARY (direct buy-vs-sell on the same tokenId) fill has happened yet,
and the protocol has no `fillOrder` sibling to look at. Documenting MINT first is
also strictly more useful: it crosses the most boundaries (Exchange → adapter →
pUSD.unwrap → USDC.e → CTF.splitPosition → back to Exchange → users). MERGE
will be documented in its own entry when a real one appears. COMPLEMENTARY is
the simplest and will be trivial after this.

## Appendix B — commands I actually ran

```sh
# Contract surface
curl -s https://polygonscan.com/address/0xE111180000d2663C0091e4f400237545B87B996B#code
git clone --depth 1 https://github.com/Polymarket/ctf-exchange-v2
# selectors
cast sig 'matchOrders(bytes32,(uint256,address,address,uint256,uint256,uint256,uint8,uint8,uint256,bytes32,bytes32,bytes),(uint256,address,address,uint256,uint256,uint256,uint8,uint8,uint256,bytes32,bytes32,bytes)[],uint256,uint256[],uint256,uint256[])'
# → 0x3c2b4399

# RPC (public, no key)
RPC=https://polygon.drpc.org
TX=0xc1375cac7b7fd147d57b2cfd639b0a295aa1fa56af3ec00b5de31fba3f00e609
curl -s -X POST $RPC -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","method":"eth_getTransactionByHash","params":["'$TX'"],"id":1}'  > artifacts/tx.json
curl -s -X POST $RPC -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","method":"eth_getTransactionReceipt","params":["'$TX'"],"id":2}' > artifacts/receipt.json
curl -s -X POST $RPC -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","method":"debug_traceTransaction","params":["'$TX'",{"tracer":"callTracer"}],"id":3}' > artifacts/trace.json

# Calldata decode
cast --calldata-decode 'matchOrders(…same sig…)' "$(jq -r .result.input artifacts/tx.json)"

# Event topic hashes
for e in 'OrderFilled(bytes32,address,address,uint8,uint256,uint256,uint256,uint256,bytes32,bytes32)' \
         'OrdersMatched(bytes32,address,uint8,uint256,uint256,uint256)' \
         'FeeCharged(address,uint256)' \
         'Unwrapped(address,address,address,uint256)'; do
  echo "$(cast sig-event "$e")  $e"
done
```

## Appendix C — open follow-ups (out of scope for this entry)

- `CtfCollateralAdapter` verified source at `0xADa100…9718` should be captured and its `splitPosition/mergePositions/redeemPositions` shape diff'd vs. Gnosis CTF.
- `pUSD` reserve vault `0xC417fD8E…99DB1` identity + governance path.
- `getFeeReceiver()` current value (no fee in this tx, so not surfaced).
- A real COMPLEMENTARY and a real MERGE tx — entries 0002 and 0003.
- Operator set snapshot: >20 `AddOperator` events at deploy; capture roster.
- Signature-type dispatch: a tx with `signatureType = 1` (POLY_PROXY) and one with `= 3` (POLY_1271) — sample and decode.
