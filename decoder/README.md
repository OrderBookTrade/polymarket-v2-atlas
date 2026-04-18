# decoder/ — week 2+

Not started yet. This directory will hold the programmatic tx decoder that
replaces the hand-decode in each atlas entry.

## When this gets built

After the atlas covers:

- at least one MINT (done — [`entries/0001`](../entries/0001-ctfexchangev2-mint/README.md))
- at least one MERGE
- at least one COMPLEMENTARY
- at least one fee-bearing tx (any flow)
- at least one each of `signatureType` 0, 1, 2, 3

That's the smallest sample that covers every decode branch. Building the
decoder earlier bakes in guesses.

## What it consumes

- [`registry/contracts.json`](../registry/contracts.json) — addresses, event
  topic0s, ABIs.
- [`contracts/upstream/`](../contracts/upstream/) — solc-canonical sources
  for struct layouts / typehashes.
- [`contracts/snapshots/`](../contracts/snapshots/) — deployed-bytecode
  pinning (for verifying decoders match real on-chain contracts).
- The ~10 test fixtures from atlas entries (tx.json / receipt.json / trace.json).

## What it produces

A single structured decode per input tx:

```
{
  matchType: "MINT" | "MERGE" | "COMPLEMENTARY",
  conditionId: "0x…",
  takerOrder: { maker, signer, tokenId, side, sigType, limitPrice, … },
  makerOrders: [{ … }],
  fills: [{ orderHash, makingAmount, takingAmount, fee, counterparty }],
  netFlow: { [address]: { [token]: delta } },
  fees: [{ receiver, token, amount }],
  crossedBoundaries: ["Exchange→pUSD", "Adapter→CTF", …],
  unknowns: [/* anything the decoder couldn't explain */]
}
```

The `unknowns` field is load-bearing: the decoder must **fail loudly** when
it sees a new event topic, selector, or address it hasn't seen before — not
silently skip.

## Language / stack

TBD. Most likely TypeScript + viem so the decoder can also be consumed as
an integrator-facing library. Not committed.
