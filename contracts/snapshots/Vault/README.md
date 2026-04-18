# Snapshot · Vault (pUSD reserve)

| Field | Value |
|---|---|
| Address | `0xC417fD8E9661c0D2120B64A04BB3278C17E99DB1` |
| Role | Custodies USDC.e reserves backing pUSD |
| Verified on Polygonscan | (verify when fetching; identity not in Polymarket public docs) |
| First observed in atlas | [`entries/0001-ctfexchangev2-mint`](../../../entries/0001-ctfexchangev2-mint/README.md) (log 3, log 4) |
| Upstream | *unknown — not directly referenced in `ctf-exchange-v2`* |

## Why snapshot

This is the most important undocumented piece of the collateral path: all
USDC.e backing pUSD lives here. On `unwrap`, pUSD pulls USDC.e from this
vault via a pre-existing allowance (observed: log 3 Transfer, log 4 Approval
decrement).

**It does not appear in Polymarket's public contract-addresses doc.** Until
we snapshot the source and governance, we can't say:

- who can withdraw from the vault;
- whether the USDC.e → pUSD peg is 1:1 at all times or if pUSD can over-
  mint / fractionalize;
- whether an admin key (or compromised upgrade) can drain it.

These are load-bearing trust assumptions for **every** pUSD-denominated trade.

## Fetching

Into `./source/`:

```sh
polygonscan-source-fetcher 0xC417fD8E9661c0D2120B64A04BB3278C17E99DB1 ./source
```

If Polygonscan shows this as unverified, dump the runtime bytecode and flag
it in [`annotations/trust-boundaries.md`](../../../annotations/trust-boundaries.md)
as an opaque trust boundary.
