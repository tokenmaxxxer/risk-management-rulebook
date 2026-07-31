# Scout brief — issue-7 (hook-machine enforcement pattern sweep)

Mode: **sequential** tool calls (Bash `find`/Read, one target at a time),
not parallel — unlike issue-1's 4-angle parallel WebSearch scout, this
sweep is over local repo/sibling-rulebook files already on disk, so it was
run as a short sequential batch of reads rather than fanned-out searches.
No web search was needed for this step; the "domain" here is other
rulebooks' hook mechanisms, not external industry practice (that scouting
already happened in issue-1's scout-brief.md and is not re-run here).

## Angles swept (in order)

1. This repo's own `risk-management/` plugin tree (`find` + read all 4
   files) — confirmed no gate script, no tests dir, matches survey.md.
2. `implementation-rulebook`'s `coding/hooks/` directory — read
   `coding-progress-gate.sh` (progress/ordering gate) and `directive.sh`
   (structured multi-section directive).
3. `implementation-rulebook/tests/run-gate-tests.sh` — the gate-test
   harness pattern (synthetic PreToolUse JSON piped into the real script
   in a throwaway git repo, exit-code asserted).
4. `pricing-rulebook`'s `pricing/hooks/methodology-gate.sh` and
   `docs/handbooks/pricing/methodology.md` — the closest direct analog to
   what issue #7 asks for (a *methodology* gate, not a *progress* gate).
5. `docs/issue-2/proposals/core-canon-reference-conversion.md` (this
   repo) — canon-reference-only discipline already established for
   issues #3/#4, to confirm the constraint applies the same way to
   sibling-rulebook patterns (it does, with a documented distinction: see
   survey.md §3c).

## Must-haves for a hook-machine-level gate (converged across 1–4)

- **Fail-closed trap at top of file**, before any `set`/`source` line, so
  any abnormal exit maps to deny (exit 2), not silent allow. Source:
  `implementation-rulebook/coding/hooks/coding-progress-gate.sh` L1-10,
  `pricing-rulebook/pricing/hooks/methodology-gate.sh` L1-2 (identical
  trap idiom in both — this is a shared house style, adopt verbatim as
  *pattern*, cite both, do not copy the literal script).
- **Dependency and root-discovery checks fail closed** (missing
  `python3`/`git`, unresolvable project root => deny with a stated
  reason). Source: both gate scripts, same section (~L28-40 each).
- **Scope check first**: exit 0 immediately for any tool call/path that
  isn't the gate's business, so the gate never blocks unrelated writes.
  Source: `methodology-gate.sh` L106-119 (regex against
  `docs/issue-<n>/proposals/*pricing*.md` and
  `docs/issue-<n>/reports/pricing.md`).
- **Resulting-content reconstruction for Write/Edit/MultiEdit**, denying
  (not guessing) when the new text can't be determined from the tool
  input. Source: `methodology-gate.sh` L129-159.
- **Per-element semantic checks with individually named misses** in the
  deny message, each traceable to a specific clause in the adopted norms
  doc. Source: `methodology-gate.sh` L163-218, citing
  `docs/issue-1/proposals/methodology-norms.md` by name in its own deny
  string.
- **Kill switch env var**, checked before any other logic.
  Source: `methodology-gate.sh` L25-28 (`PRICING_METHODOLOGY_GATE_OFF`);
  risk-management already has a `RISK_MANAGEMENT_CYCLE_OFF` var for its
  directive — a new gate needs its own analogous switch
  (e.g. `RISK_MANAGEMENT_METHODOLOGY_GATE_OFF`), following the same
  per-hook (not per-role) convention pricing uses.
- **Real-subprocess test harness**: synthetic PreToolUse JSON piped into
  the actual script inside a disposable `git init` temp repo, asserting
  exit code 0/2/other maps to allow/deny/error. Source:
  `implementation-rulebook/tests/run-gate-tests.sh` (all cases).

## Patterns to adopt vs. skip for risk-management specifically

**Adopt:**
- The methodology-gate.sh shape wholesale (fail-closed trap, scope regex,
  content-reconstruction, per-element checks, kill switch) — it is the
  closer analog since risk-management's need ("required produces elements
  present") is the same shape as pricing's, not implementation's
  cross-record ordering need.
- A companion handbook doc (like `docs/handbooks/pricing/methodology.md`)
  separating the *reasoning* per check from the gate script itself.

**Adopt with adaptation (risk-management is not identical to pricing):**
- Pricing's methodology has no ordering constraint, so it has no
  state-tracking. Risk-management's COSO ERM adoption states the
  `erm-verdict` must be *traceable through* governance/context →
  objective-linkage → assessment → response → monitoring — this is a
  **shape-of-a-single-document** ordering (sections must appear, in a
  meaningful order, within one verdict), not a **cross-write/cross-record**
  ordering like implementation's "resolve verify's finding before your
  next commit." The proposal below treats this as a same-document
  section-presence-and-order check, not a persistent state file, unless
  a genuinely multi-step approval flow is identified (see proposal open
  items).

**Skip:**
- implementation's cross-record `resolved_findings` + `loop_state:
  cleared` state-tracking mechanism itself — no analog in risk-
  management's adopted methodology found in issue-1's proposal; forcing
  it in would invent a requirement the methodology doesn't actually ask
  for. Flagged as an open item in the proposal rather than silently
  adopted or silently dropped.
- Copying either gate script's literal bash/python body — canon-reference
  discipline (issues #3/#4, `docs/issue-2/proposals/core-canon-reference-
  conversion.md`) extends by analogy to sibling-rulebook patterns: cite
  by path, adapt structure, never vendor.

## Gap line (restated from survey.md §4, for this brief's purposes)

Risk-management has zero `PreToolUse` gates, zero tests, and zero
agents/checklists today; the target shape is one role-owned methodology
gate (mirroring `methodology-gate.sh`), one gate-test file (mirroring
`run-gate-tests.sh`), and one methodology handbook doc (mirroring
`docs/handbooks/pricing/methodology.md`) — no new core-level script, per
issue-1(d)'s already-recorded reasoning that core's generic record-fields
gate stays as the first-layer check and a role-owned gate is an
*additive* second layer, matching how `methodology-gate.sh`'s own header
comment describes itself ("on top of, never instead of, the core canon
record-fields-gate.sh's generic §20 fields").

## Sources (all file paths, no web search this round)

- `/home/jwjung/.tokenmaxxxer/work/risk-management-rulebook-issue-7-risk-management/risk-management/hooks/*`
- `/home/jwjung/tokenmaxxxer/rulebooks/implementation-rulebook/coding/hooks/coding-progress-gate.sh`
- `/home/jwjung/tokenmaxxxer/rulebooks/implementation-rulebook/coding/hooks/directive.sh`
- `/home/jwjung/tokenmaxxxer/rulebooks/implementation-rulebook/tests/run-gate-tests.sh`
- `/home/jwjung/tokenmaxxxer/rulebooks/pricing-rulebook/pricing/hooks/methodology-gate.sh`
- `/home/jwjung/tokenmaxxxer/rulebooks/pricing-rulebook/docs/handbooks/pricing/methodology.md`
- `docs/issue-2/proposals/core-canon-reference-conversion.md` (this repo)
- `docs/issue-1/proposals/risk-management-methodology.md`,
  `docs/issue-1/reports/risk-management/scout-brief.md` (this repo, prior
  maturation issue)
