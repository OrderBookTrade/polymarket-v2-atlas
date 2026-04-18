# polymarket-v2-atlas

A working map of Polymarket V2 — for developers, market-makers and auditors
who need to understand the live system from the inside out. Grown from real
transactions, not marketing material.

## Layout

```
polymarket-v2-atlas/
├── entries/                       # hand-decoded real transactions (the anchor)
│   └── 0001-ctfexchangev2-mint/
├── contracts/
│   ├── upstream/                  # git submodules (Polymarket source of truth)
│   │   ├── ctf-exchange-v2/
│   │   ├── uma-ctf-adapter/
│   │   └── neg-risk-ctf-adapter/
│   └── snapshots/                 # Polygonscan verified source, pinned to a block
│       ├── pUSD/
│       ├── CollateralOnramp/
│       ├── PermissionedRamp/
│       └── Vault/
├── registry/
│   └── contracts.json             # addresses · roles · ABIs · dependency graph
├── annotations/
│   ├── v1-to-v2-diff.md           # what changed for integrators
│   ├── trust-boundaries.md        # who owns what, and what crosses the line
│   └── integration-gotchas.md     # things that stopped me >30 s, with citations
└── decoder/                       # week 2+ — programmatic decoder
```

## How the pieces relate

- **`entries/`** is the trunk. Every other directory grows out of it.
  A claim anywhere else in the repo should cite an entry (or be marked as a
  gap, see below).
- **`contracts/upstream/`** gives you canonical solc-compilable source. Use
  this for ABIs, struct layouts, type hashes.
- **`contracts/snapshots/`** gives you bytecode-faithful source pinned to a
  block, so we can detect upgrades/drift on the proxies Polymarket owns.
- **`registry/contracts.json`** is the machine-readable index. Every
  contract the atlas touches lands here. It's the handshake between decoded
  entries and the future decoder.
- **`annotations/`** is the human-readable commentary layer. Each file is
  *downstream* of observations — items land in an annotation *from* an
  entry's "Gotcha list" or "Trust boundaries crossed" section, not the
  other way around.
- **`decoder/`** is deferred. See [`decoder/README.md`](./decoder/README.md)
  for when it gets built and why.

## Entries

| # | Title | Flow types covered |
|---|---|---|
| [0001](./entries/0001-ctfexchangev2-mint/README.md) | CTFExchangeV2 · MINT match — full tx decode | MINT |

## Conventions

- **One entry = one tx** unless a broader topic (e.g. an invariant, a flow
  family) needs two complementary samples.
- Every claim is checkable. Each entry section ends with "How I found this"
  — the exact command / file / UI path that produced the finding.
- Raw RPC artifacts live alongside each entry under `artifacts/` so the
  decode is reproducible when third-party explorers go stale.
- Gaps are tracked in `registry/contracts.json` under `"gaps"` and
  surfaced in-context inside each annotation. We don't paper over
  unknowns.

## Working with submodules

```sh
# first clone
git clone --recurse-submodules <this-repo>

# if you already cloned without --recurse-submodules
git submodule update --init --recursive

# pull upstream changes
git submodule update --remote --merge
```

Upstream submodules are pinned to specific commits — bumping them is a
deliberate change, not passive drift. When bumping, re-run entry-level
decodes on a recent tx to confirm nothing behavioral has shifted.

## Not in scope

- Business positioning / roadmap.
- Anything about signature design beyond what is needed to decode.
- "How to build a market maker on Polymarket" — the atlas gives you the
  primitives; strategy is elsewhere.
