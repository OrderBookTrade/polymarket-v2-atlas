# polymarket-v2-atlas

A working map of Polymarket V2 — for developers, market-makers and auditors
who need to understand the live system from the inside out. Grown from real
transactions, not marketing material.

## Entries

| # | Title | Status |
|---|---|---|
| [0001](./entries/0001-ctfexchangev2-mint/README.md) | CTFExchangeV2 · MINT match — full tx decode | seed |

Each entry is a hand-decoded real transaction. Later entries pull registry,
decoder, and trust-boundary scaffolding out of the concrete needs surfaced in
the earlier entries.

## Conventions

- **One entry = one tx**, unless a broader topic (e.g. a full flow type) is
  covered by two complementary samples.
- Every claim is checkable: each section ends with a "How I found this" note
  giving the exact command / file / UI path used.
- Raw RPC artifacts live alongside each entry under `artifacts/` so the decode
  is reproducible even if third-party explorers go down.
- Gotchas from each entry feed a growing `Integration Gotchas` corpus.
- Registry fields are collected per-entry and merged into a v0 schema in
  entry 0001, §11.

## Not in scope

- V1 → V2 migration diffs (separate document).
- Roadmap / business positioning.
- Anything about signature design beyond what is needed to decode.
