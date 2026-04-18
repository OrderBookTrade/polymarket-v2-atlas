# Trust Boundaries

What Polymarket V2 owns, what it does not, and what crosses the line on a real
trade. Cross-references are to [`registry/contracts.json`](../registry/contracts.json)
and the decoded entries under [`entries/`](../entries).

---

## Why this matters for integrators

Every contract named here is either (a) Polymarket-controlled, (b) third-party
and immutable, or (c) third-party and upgradable. A bug, pause, upgrade, or
governance action in **any** of these can break a trade you thought was
self-contained in CTFExchangeV2. Knowing which is which tells you what you
actually need to monitor.

---

## Boundary map (as observed in entry 0001)

```
┌──────────────────┐  tx signed by operator EOA (onlyOperator gate)
│  operator EOA    │   (permissioned hotkey; freshly-provisioned is normal)
└────────┬─────────┘
         ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  CTFExchangeV2  —  Polymarket, non-upgradable, verified source           │
│    · signature verification (ECDSA + factory-derivation + ERC-1271)      │
│    · order accounting (orderStatus, preapproved)                         │
│    · emits OrderFilled / OrdersMatched / FeeCharged                      │
│    · dispatches collateral + CTF ops to dependencies below               │
└──┬────────────────┬──────────────────────────┬─────────────────────────┬─┘
   │                │                          │                         │
   ▼                ▼                          ▼                         ▼
┌────────┐   ┌──────────────────────┐   ┌──────────────────┐   ┌────────────────────┐
│ pUSD   │   │ CtfCollateralAdapter │   │ ConditionalTokens│   │ Proxy/Safe Factory │
│ (Poly, │   │   (Polymarket,       │   │   (Gnosis, immut)│   │   (Polymarket wallet
│  UUPS  │   │    verified)         │   │                  │   │    derivation only;
│  proxy)│   │  pUSD ↔ USDC.e       │   │  ERC1155 position│   │    pure-compute used
│        │   │  translator for     │    │  ledger; split / │   │    in sig-verify)  │
│        │   │  split/merge/redeem │    │  merge / redeem  │   │                    │
└──┬─────┘   └────┬────────────┬────┘   └────────┬─────────┘   └────────────────────┘
   │              │            │                  ▲
   │              ▼            ▼                  │
   │    ┌──────────┐    ┌────────────┐            │
   │    │  pUSD    │    │  USDC.e    │────────────┘
   │    │  reserve │◀───│  (3rd-party│  (CTF pulls USDC.e as
   │    │  vault   │    │   bridged  │   collateral for split /
   │    │ 0xC417…  │    │   USDC on  │   receives on merge)
   │    └──────────┘    │   Polygon) │
   │  (Polymarket,      └────────────┘
   │   undocumented)
   ▼
 end-user wallets
 (EOAs, POLY_PROXY proxies, POLY_GNOSIS_SAFE safes, POLY_1271 contracts)
```

---

## Per-boundary risk notes

### 1. operator EOA → CTFExchangeV2

- **Gate**: `onlyOperator` + `notPaused`.
- **Observed in entry 0001**: a fresh (nonce 0) operator hotkey signed the tx.
- **What can go wrong**: operator key compromise lets an attacker call `matchOrders`
  with attacker-friendly fills against any *already-signed* orders in the orderbook.
  The defense is per-order signature + fee caps + the pause switch, not operator key
  opsec alone.

### 2. CTFExchangeV2 ↔ pUSD

- **Direction**: Exchange calls `pUSD.transferFrom` and `pUSD.unwrap`.
- **Polymarket-owned, UUPS-upgradable.** Implementation at entry 0001 block:
  `0x6bBCef9f…0925f`. An impl swap changes how collateral is moved, decimals, or
  whether burn actually destroys supply.
- **Monitoring**: `Upgraded(address)` on the proxy. Pin the impl for replay testing.

### 3. CTFExchangeV2 ↔ CtfCollateralAdapter

- **Direction**: Exchange calls the adapter's `splitPosition / mergePositions /
  redeemPositions`. Selectors collide with Gnosis CTF's — the Exchange does not know
  it's talking to an adapter.
- **Polymarket-owned.** Variant for neg-risk markets lives at a different address.
- **Subtle failure mode**: the adapter has **large USDC.e allowances** to both the
  pUSD reserve vault and to ConditionalTokens (decrement pattern observed in
  entry 0001, logs 4 & 8). A bug inside the adapter can drain those allowances.

### 4. CtfCollateralAdapter ↔ Gnosis ConditionalTokens

- **Direction**: adapter calls `splitPosition / mergePositions / redeemPositions`
  with `USDC.e` as the collateral argument.
- **Third-party, immutable.** `@gnosis.pm/conditional-tokens-contracts`, essentially
  frozen for years. This is the "trust anchor" of the whole system — if Gnosis CTF
  is compromised, every conditional-token platform on Polygon is.
- **Assumption**: CTF escrows USDC.e 1:1 until `reportPayouts` is called via UMA
  (`UmaCtfAdapter`), at which point `redeemPositions` pays out.

### 5. pUSD ↔ pUSD reserve vault (`0xC417fD8E…99DB1`)

- **Direction**: on `unwrap`, pUSD proxy uses a pre-approved allowance from the
  vault to pull USDC.e.
- **Polymarket-owned, undocumented in public addresses docs.**
- **Why it matters**: the 1:1 USDC.e → pUSD backing is only real as long as the
  vault is solvent. Any off-chain path that moves USDC.e out of the vault (upgrade,
  admin withdrawal, migration) breaks the peg for *all* outstanding pUSD, including
  pUSD currently in flight through a `matchOrders` call. Should be captured as a
  snapshot and monitored.

### 6. ConditionalTokens → recipient wallets

- **Direction**: `safeTransferFrom` / `safeBatchTransferFrom` with ERC-1155
  receive callbacks.
- **EOAs**: no callback, no risk.
- **POLY_PROXY** (`0xaB45…4052` factory): Polymarket-controlled proxy contract;
  callback behavior known from factory source.
- **POLY_GNOSIS_SAFE** (`0xaacfee…541b` factory): callback delegates to the Safe
  singleton (`0xe51abdf8…` observed). A Safe with a hostile fallback or a rogue
  module can revert receive and DoS a match against that Safe address.
- **POLY_1271** (arbitrary smart contract wallet): most exposed surface — any
  bug in the wallet's `isValidSignature` or ERC-1155 receiver affects its owner
  but not the exchange.

### 7. UMA resolution edge (`UmaCtfAdapter`)

- Not exercised by `matchOrders`, but worth mapping: `UmaCtfAdapter` reports
  outcomes into Gnosis CTF, which is what ultimately decides redemption math.
- **Polymarket-owned, depends on UMA Optimistic Oracle** (third-party, upgradable
  by UMA governance).

---

## Suggested monitoring rules (bootstrap)

| Signal | Where | Why |
|---|---|---|
| `Upgraded(address)` on pUSD proxy | `0xc011…2DFB` | Implementation swap changes collateral semantics mid-flight |
| `Upgraded(address)` on USDC.e proxy | `0x2791…4174` | USDC.e is third-party but still upgradable |
| Allowance of `CtfCollateralAdapter` → `ConditionalTokens` in USDC.e drops abruptly | see log 8 pattern | unexpected drain |
| Allowance of pUSD-reserve-vault → pUSD proxy in USDC.e | `0xC417…99DB1` | peg-breaking event |
| Operator set changes | `AddOperator` / `RemoveOperator` on CTFExchangeV2 | governance action affecting who can fill |
| `Paused(address)` on CTFExchangeV2 or per-user pause flags | exchange | live trading halted |

All thresholds should be calibrated against real traffic once the atlas covers a
MERGE and a COMPLEMENTARY tx.
