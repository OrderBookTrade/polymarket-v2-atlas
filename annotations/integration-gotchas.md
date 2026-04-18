# Integration Gotchas

A running corpus of things that stopped me (or a reader) for more than ~30 seconds
while decoding real Polymarket V2 traffic. Every item cites the entry where it
first surfaced, so the claim is grounded and can be invalidated when the on-chain
behavior changes.

New items land here **from** entry §"Gotcha list" sections, not the other way
around — annotations are downstream of observation.

---

## A. Order struct & calldata

- **`Order` struct has no `taker`, no `nonce`, no `expiration`, no `feeRateBps`.** V2 added
  `timestamp` (ms), `metadata` (bytes32), `builder` (bytes32). Fees are passed per-fill
  by the operator in `takerFeeAmount` / `makerFeeAmounts[]`. Translating V1 ABI produces
  a wrong selector. &nbsp;_[entry 0001]_
- **Only `matchOrders` exists.** No `fillOrder` / `fillOrders`. Every single-maker fill
  is still `matchOrders` with `makerOrders.length = 1`. &nbsp;_[entry 0001]_
- **`takerFillAmount` and `makerFillAmounts[i]` are denominated in maker-amount units**
  of the *respective* order. For BUYs that's collateral (pUSD, 6 decimals); for SELLs
  it's CTF shares. The symmetric naming hides the asymmetric denomination. &nbsp;_[entry 0001]_
- **`tokenId = 0` is a sentinel for "collateral"** inside `AssetOperations._transfer` and
  `_deriveAssetIds`. A BUY has `makerAssetId = 0, takerAssetId = order.tokenId`; SELL is
  flipped. That's why `OrderFilled` only emits one tokenId: the other leg is implicit. &nbsp;_[entry 0001]_

## B. Flow classification (COMPLEMENTARY / MINT / MERGE)

- **"COMPLEMENTARY" in V2 source = direct buy-vs-sell on the same tokenId**, not
  "complementary positions" in the colloquial YES+NO sense. That colloquial meaning
  is MINT (both BUY on different partition indices) or MERGE (both SELL). &nbsp;_[entry 0001]_
- **Classification rule** (from `Trading._deriveMatchType`):
  `matchType = (takerSide + 1) * (takerSide == makerSide)` → BUY+BUY=MINT=1, SELL+SELL=MERGE=2,
  otherwise COMPLEMENTARY=0. &nbsp;_[entry 0001]_
- **Classifier from logs alone**:
  - 2+ `OrderFilled` + `PositionSplit` (stakeholder=adapter) + `TransferBatch(0x0→adapter)` ⇒ **MINT**
  - 2+ `OrderFilled` + `PositionsMerge` + `TransferBatch(adapter→0x0)` ⇒ **MERGE**
  - 2+ `OrderFilled` + `TransferSingle`s only between maker and taker ⇒ **COMPLEMENTARY**
  - `OrdersMatched` count = count of distinct `matchOrders` calls = count of distinct taker
    orders in the tx. &nbsp;_[entry 0001]_

## C. Event semantics

- **The taker's `OrderFilled.taker` is the Exchange address**, not the counterparty.
  `_emitTakerFilledEvents` sets `taker = address(this)` (Trading.sol ~:135 / :288 / :339).
  For the counterparty, use the *maker's* `OrderFilled` or the `OrdersMatched` event. &nbsp;_[entry 0001]_
- **`OrdersMatched` emits exactly once per `matchOrders` call**, tied to the taker.
  Cheap way to count "distinct matches" in a block without decoding calldata. &nbsp;_[entry 0001]_
- **`takerAmountFilled` in the taker's `OrderFilled` can exceed the order's `takerAmount`
  limit** in MINT. Surplus comes from the maker paying above the taker's required unit
  price. The taker's protection is the cross-condition in `_validateOrdersMatch` (a price
  floor), not a shares ceiling. &nbsp;_[entry 0001]_
- **Gnosis CTF emits `TransferBatch` with `from = 0x0` on split** and `to = 0x0` on merge.
  Those are mint/burn markers — not transfers from real accounts. Indexers that don't
  special-case this will show "adapter received from zero address," which is correct but
  jarring. &nbsp;_[entry 0001]_
- **No `FeeCharged` when `feeAmount = 0`** — the path is guarded. Sample fee-bearing txs
  explicitly to probe the fee flow. &nbsp;_[entry 0001]_

## D. Collateral plumbing (pUSD ↔ USDC.e ↔ CTF)

- **Exchange collateral is pUSD. CTF collateral is USDC.e.** The `PositionSplit` event's
  `collateralToken` field is USDC.e, not pUSD. Don't feed pUSD to
  `CTHelpers.getPositionId` — use the `ctfCollateral` slot (USDC.e). &nbsp;_[entry 0001]_
- **`CtfCollateralAdapter` masquerades as `ConditionalTokens`**: Exchange's
  `outcomeTokenFactory` slot points at the adapter, which re-implements the
  `splitPosition / mergePositions / redeemPositions` selectors. The Exchange does not
  know (and does not need to know) that it's talking to an adapter. &nbsp;_[entry 0001]_
- **Counter-intuitive pUSD deposit path**: on `splitPosition`, the Exchange sends pUSD
  *into pUSD itself* (`Transfer(Exchange → pUSD-self)`), and pUSD then burns that balance
  from its own account. No intermediate "Exchange → adapter → burn" transfer exists. The
  adapter is caller; pUSD is custodian. &nbsp;_[entry 0001]_
- **pUSD is backed by a reserve vault** (`0xC417fD8E…99DB1`) that pre-approves the pUSD
  proxy with a large USDC.e allowance. On `unwrap`, pUSD pulls USDC.e from the vault
  directly, not from its own balance. This vault is **not** listed in Polymarket's public
  contract-addresses docs. &nbsp;_[entry 0001]_

## E. Signatures

- **Signature-type dispatch cannot be inferred from on-chain data alone.** Types 0/1/2
  all hit the `ecrecover` precompile; 1 and 2 additionally do pure-compute address
  derivation (no external call). 3 (POLY_1271) is the only one that calls out to
  `isValidSignature`. Always read `signatureType` out of calldata. &nbsp;_[entry 0001]_
- **Safe proxies run `onERC1155Received` through a delegatecall to the Safe singleton**
  (`0xe51abdf8…` observed). A Safe with a malicious/misconfigured fallback can reject
  receive and brick a match. Integrators sending CTF to unknown destinations should
  expect this surface. &nbsp;_[entry 0001]_

## F. Operators & governance

- **Operators are a permissioned set**, gated by `onlyOperator` on `matchOrders`. The
  contract had 20+ `AddOperator` events in its deployment block range. Don't assume
  "the operator" is a single well-known address. Operator hotkeys can also be
  nonce-0 EOAs (freshly provisioned per tx). &nbsp;_[entry 0001]_
