# Snapshot · CollateralOnramp

| Field | Value |
|---|---|
| Address | `0x93070a847efEf7F70739046A929D47a521F5B8ee` |
| Role | Permissionless wrap: USDC / USDC.e → pUSD |
| ABI | `wrap(address _asset, address _to, uint256 _amount)` |
| Verified on Polygonscan | (verify when fetching) |
| First observed in atlas | *not yet observed in a decoded tx* |
| Upstream | [`contracts/upstream/ctf-exchange-v2/src/collateral/CollateralOnramp.sol`](../../upstream/ctf-exchange-v2/src/collateral/CollateralOnramp.sol) |

## Why snapshot

Public entry point for minting pUSD from raw USDC/USDC.e. If an integrator
wants end-to-end flow (fiat → pUSD → trade), this is where pUSD comes from.
Worth snapshotting so we can detect a future "paused onramp" drift.

## Fetching

Into `./source/`:

```sh
polygonscan-source-fetcher 0x93070a847efEf7F70739046A929D47a521F5B8ee ./source
```
