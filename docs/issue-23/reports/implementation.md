---
kind: coding-record
code_under_review: phase1-proposal-norms/hooks/tests/lib/resolve-core.sh, phase1-proposal-norms/hooks/tests/run-gate-tests.sh, phase2-record-norms/hooks/tests/lib/resolve-core.sh, phase2-record-norms/hooks/tests/run-gate-tests.sh, erm-verdict-methodology/hooks/tests/lib/resolve-core.sh, erm-verdict-methodology/hooks/tests/run-gate-tests.sh, risk-register-methodology/hooks/tests/lib/resolve-core.sh, risk-register-methodology/hooks/tests/run-gate-tests.sh, docs/handbooks/phase1-proposal-norms.md, docs/handbooks/phase2-record-norms.md, docs/handbooks/erm-verdict-methodology.md, docs/handbooks/risk-register-methodology.md
type: feature
breaking: false
verdict: pass
loop_state: landed
---

# Implementation record — issue #23

## What was done
Adopted the canonical test-env resolution convention
(`tokenmaxxxer/on-the-record` `docs/specs/test-env-resolution.md`,
issue #551) in this repo's 4 gate-test scripts, per
`docs/issue-23/proposals/implementation.md`:

- Added `hooks/tests/lib/resolve-core.sh` to each of
  `phase1-proposal-norms`, `phase2-record-norms`,
  `erm-verdict-methodology`, `risk-register-methodology` — a
  `resolve_core()` bash function implementing the convention's
  3-step order (env var -> sibling candidate -> SKIP, exit 75,
  explicit stderr message), header comment citing
  `docs/specs/test-env-resolution.md` by name.
- Each plugin's `hooks/tests/run-gate-tests.sh` now sources
  `lib/resolve-core.sh`, resolves core before any `run_case` call, and
  exits 75 immediately (no PASS/FAIL summary) when unresolved.
  `CLAUDE_PLUGIN_ROOT_CORE` is exported to the resolved path on
  success, matching prior behavior when it was already set.
- Documented the adoption in each of the 4 plugin handbooks under
  `docs/handbooks/` (operational-surface commit requirement).

Doc-placement ladder — completed items:
- [x] `docs/handbooks/phase1-proposal-norms.md` — new "Test-env
  resolution convention (issue-23)" section
- [x] `docs/handbooks/phase2-record-norms.md` — same
- [x] `docs/handbooks/erm-verdict-methodology.md` — same
- [x] `docs/handbooks/risk-register-methodology.md` — same
- [x] No new dependency, env var, or migration introduced — no
  `.env.example` / manifest change needed

## Why
Per the issue: these 4 gate-test scripts assume the spawn env
(`CLAUDE_PLUGIN_ROOT_CORE` set, or a reachable core clone) and, outside
it, every case that expects exit 0 fails with exit 2 ("cannot source
gate-lib.sh") — indistinguishable in the runner's own summary from a
genuine gate regression. Adopting the on-the-record convention removes
that ambiguity: outside the spawn env the runner now SKIPs explicitly
instead of producing misleading FAIL lines.

## Upstream basis
Basis: `docs/issue-23/proposals/implementation.md` (approved via issue
comment "APPROVE issue-23/implementation" from `JiwonJung94`, listed in
`docs/specs/approvers.md`). Current-state findings:
`docs/issue-23/reports/implementation/survey.md`.

## Verification performed
Ran all 4 `run-gate-tests.sh` twice each, in this session, as the
single confirmation run:
- With `CLAUDE_PLUGIN_ROOT_CORE` unset and no sibling core checkout
  reachable (`env -u CLAUDE_PLUGIN_ROOT_CORE bash <script>`): all 4
  exit 75 and print `SKIP: core plugin unreachable — unverifiable
  outside spawn env` to stderr, no case runs.
- With the spawn env's `CLAUDE_PLUGIN_ROOT_CORE` set (this session's
  actual env): all 4 runners pass with the same counts as before this
  change — `phase1-proposal-norms` 19/19, `phase2-record-norms` 18/18,
  `erm-verdict-methodology` 24/24, `risk-register-methodology` 24/24 —
  including each runner's own `CLAUDE_PLUGIN_ROOT_CORE`-bad-path
  fail-closed case (unweakened).
- `grep -rl test-env-resolution */hooks/tests` returns all 4 plugins'
  new `lib/resolve-core.sh` files.

No real gate defect surfaced during this build; nothing was masked
with SKIP.

## What did not work
None.

## Hunt
`docs/reports/2026-08-09-hunt-implementation.md` — before-landing dispatch,
stance 0. Finding: a bogus/incompatible-but-non-empty
`hooks/lib/gate-lib.sh` resolved via `CLAUDE_PLUGIN_ROOT_CORE` (or
`resolve_core`'s sibling-candidate path) sources without error but is
missing the `gate_*` functions the gate scripts call, and those gate
scripts have no fail-closed guard past the `.` sourcing line (only
`set -u`, not `set -e`) — so a stale/incompatible core silently turns
every DENY case into ALLOW.

resolved_findings:
- ref: docs/reports/2026-08-09-hunt-implementation.md
  disposition: out-of-scope
  reason: the root cause is `proposal-shape-gate.sh` (and its 3
    siblings) lacking a fail-closed guard past their own `.` sourcing
    line — the same gap exists on `main` today, unchanged by this
    build. This proposal's write set explicitly excludes "changing
    gate-lib.sh or any gate script's own sourcing line" (## Out of
    scope). `resolve_core`'s `-s` check does not weaken anything: the
    prior code path (`${CLAUDE_PLUGIN_ROOT_CORE:-fallback}/hooks/lib/gate-lib.sh`,
    sourced directly by each gate script) had zero content validation
    either, so this is a pre-existing production gate defect the
    survey did not surface, not a regression introduced by adopting
    the test-env resolution convention. Filed for follow-up as a
    separate issue rather than fixed here (out of this proposal's
    frozen write set).

## Open findings
One, filed for follow-up (not blocking this delivery — see
`resolved_findings` above): gate scripts across all 4 plugins fail
open, not closed, when their sourced `gate-lib.sh` is present but
incompatible/stale (missing expected functions). Resolution path: a
new issue proposing a fail-closed guard in each gate script (e.g.
`command -v gate_trap_fail_closed >/dev/null || exit 2` immediately
after the `.` sourcing line, or `set -e` scoped to the sourcing
block), scoped separately from this issue's write set.
