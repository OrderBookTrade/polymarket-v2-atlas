# Snapshot · pUSD

| Field | Value |
|---|---|
| Role | Exchange-side collateral (ERC20 wrapper over USDC/USDC.e, 6 decimals) |
| Proxy address | `0xC011a7E12a19f7B1f670d46F03B03f3342E82DFB` |
| Implementation at block `85671485` | `0x6bBCef9f7ef3B6C592c99e0f206a0DE94Ad0925f` |
| Upgradability | UUPS |
| Verified on Polygonscan | yes (proxy + impl) |
| First observed in atlas | [`entries/0001-ctfexchangev2-mint`](../../../entries/0001-ctfexchangev2-mint/README.md) |

## Why snapshot

pUSD is UUPS-upgradable. A silent implementation swap changes `unwrap`
semantics, decimals, or reserve-custody rules — and the exchange has pUSD in
flight inside every `matchOrders` call. We pin the verified source at a known
block so we can detect behavioral drift in later entries.

## Fetching

Into `./source/proxy/` and `./source/impl/`:

```sh
# Proxy source
polygonscan-source-fetcher 0xC011a7E12a19f7B1f670d46F03B03f3342E82DFB ./source/proxy
# Implementation source (impl_at_block_85671485)
polygonscan-source-fetcher 0x6bBCef9f7ef3B6C592c99e0f206a0DE94Ad0925f ./source/impl
```

(Substitute any Polygonscan-source-fetching tool. The upstream Polymarket
source lives in [`contracts/upstream/ctf-exchange-v2/src/collateral/CollateralToken.sol`](../../upstream/ctf-exchange-v2/src/collateral/CollateralToken.sol)
and should match the deployed impl — if it doesn't, note the divergence
here.)
