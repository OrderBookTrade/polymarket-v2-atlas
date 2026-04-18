# Snapshot · PermissionedRamp

| Field | Value |
|---|---|
| Address | `0xebC2459Ec962869ca4c0bd1E06368272732BCb08` |
| Role | Witness-signed wrap / unwrap between USDC.e and pUSD |
| Verified on Polygonscan | (verify when fetching) |
| First observed in atlas | *not yet observed in a decoded tx* |
| Upstream | [`contracts/upstream/ctf-exchange-v2/src/collateral/PermissionedRamp.sol`](../../upstream/ctf-exchange-v2/src/collateral/PermissionedRamp.sol) |

## Why snapshot

The EIP-712 witness-signed variant of on-/off-ramp. Used for permissioned
flows (probably KYC-gated or fiat bridges). Per the upstream README: the
witness signer is a trusted role — if it rotates or is compromised, fiat-
attached USD can be minted or redeemed against the reserve.

Both function signatures from upstream:

- `wrap(...)` — line 76 of `PermissionedRamp.sol`
- `unwrap(...)` — line 113 of `PermissionedRamp.sol`

Exact witness-struct hash should be snapshotted here alongside the deployed
source to detect future witness-format changes.

## Fetching

Into `./source/`:

```sh
polygonscan-source-fetcher 0xebC2459Ec962869ca4c0bd1E06368272732BCb08 ./source
```
