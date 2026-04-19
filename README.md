# polymarket-v2-atlas

A working map of Polymarket V2 — for developers, market-makers and auditors
who need to understand the live system from the inside out. Grown from real
transactions, not marketing material.

## Layout

```text
polymarket-v2-atlas/
├── entries/                       # hand-decoded real transactions (the anchor)
│   └── 0001-ctfexchangev2-mint/
├── lib/                           # git submodules (Polymarket source of truth)
│   ├── ctf-exchange-v2/           # core exchange logic
│   ├── uma-ctf-adapter/           # optimistic oracle resolution
│   ├── neg-risk-ctf-adapter/      # mutually exclusive multi-outcome markets
│   └── forge-std/                 # foundry standard library for scripting
├── registry/
│   └── contracts.json             # addresses · roles · ABIs · dependency graph
├── script/                        # executable Foundry scripts for live interaction
│   ├── BaseScript.s.sol           # environment preparation & fork setup
│   ├── ctf/                       # conditional tokens scripts
│   └── pusd/                      # collateral scripts
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
- **`lib/`** gives you canonical solc-compilable source directly from Polymarket's upstream. Use
  this for ABIs, struct layouts, type hashes, and scripting dependencies.
- **`registry/contracts.json`** is the machine-readable index. Every
  contract the atlas touches lands here. It's the handshake between decoded
  entries and the future decoder.
- **`script/`** connects the static atlas to the live chain through Foundry. These executable scripts validate behaviors against real network state.
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

## Foundry Environment & Submodules

This atlas is configured as a fully operational Foundry workspace to test live interactions.

```sh
# 1. First clone (with all upstream contracts mapped into lib/)
git clone --recurse-submodules <this-repo>

# 2. If you already cloned without --recurse-submodules:
git submodule update --init --recursive

# 3. Environment configuration
cp .env.example .env
# Fill in your PRVATE_KEY and POLYGON_RPC_URL

# 4. Run scripts
forge build
forge script script/pusd/PUSDScript.s.sol --rpc-url $POLYGON_RPC_URL
```

Upstream submodules are pinned to specific commits — bumping them is a
deliberate change, not passive drift. When bumping, re-run entry-level
decodes on a recent tx to confirm nothing behavioral has shifted.

## Not in scope

- Business positioning / roadmap.
- Anything about signature design beyond what is needed to decode.
- "How to build a market maker on Polymarket" — the atlas gives you the
  primitives; strategy is elsewhere.
