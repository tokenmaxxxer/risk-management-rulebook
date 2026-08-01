# Record: risk-management / issue-13

Subject: issue-13 — Gate A+ final closure (source guard fix, matcher/code
coverage parity, missing-core + Edit-deny test coverage, green-suite and
compliance-check record)

Implements: `docs/issue-13/proposals/risk-management-gate-a-plus-final-closure.md`

loop_state: landed

## What was done

Phase-2 implementation of the approved proposal's items 1-4 (approver
comment: "APPROVE issue-13/risk-management", no caveats, including the
recommended NotebookEdit matcher addition in item 2):

- **Item 1 — source guard fix (all 4 gate scripts).** Replaced the
  `gate-lib.sh` source line in each of:
  - `erm-verdict-methodology/hooks/erm-order-gate.sh:11`
  - `risk-register-methodology/hooks/register-fields-gate.sh:15`
  - `phase1-proposal-norms/hooks/proposal-shape-gate.sh:17`
  - `phase2-record-norms/hooks/record-shape-gate.sh:31`

  from `. "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh"`
  to the canon idiom taken directly from `core/hooks/lib/gate-lib.sh`'s
  header comment (verified against a local core checkout):

  ```
  . "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "<gate-name>.sh: cannot source gate-lib.sh" >&2; exit 2; }
  ```

  with `<gate-name>.sh` substituted per file. This reads the
  actually-injected `CLAUDE_PLUGIN_ROOT_CORE` env var first (rather than
  the never-injected `CORE_PLUGIN_ROOT`), falls back to a same-repo
  relative resolution only if unset, and fails closed (exit 2) if the
  source itself fails. Re-confirmed the `gate_bash_write_targets`
  migration sub-item has nothing to close here: none of the four gate
  scripts hand-roll Bash write-target scanning or process the `Bash`
  tool at all.

- **Item 2 — matcher/code coverage parity (all 4 hooks.json).** Changed
  `"matcher": "Write|Edit|MultiEdit"` to
  `"matcher": "Write|Edit|MultiEdit|NotebookEdit"` in:
  - `erm-verdict-methodology/hooks/hooks.json`
  - `risk-register-methodology/hooks/hooks.json`
  - `phase1-proposal-norms/hooks/hooks.json`
  - `phase2-record-norms/hooks/hooks.json`

  per the proposal's recommendation: each gate's Python payload already
  branches on `NotebookEdit` and calls `gate_lib.gate_reconstruct_write`
  with NotebookEdit-handling logic, so the matcher gap was a dead
  branch the matcher never routed to.

- **Item 3a — missing-core dynamic test case (all 4 suites).** Added one
  new mandatory test case to each of:
  - `erm-verdict-methodology/hooks/tests/run-gate-tests.sh`
  - `risk-register-methodology/hooks/tests/run-gate-tests.sh`
  - `phase1-proposal-norms/hooks/tests/run-gate-tests.sh`
  - `phase2-record-norms/hooks/tests/run-gate-tests.sh`

  Each case invokes the gate with `CLAUDE_PLUGIN_ROOT_CORE` set to a
  nonexistent directory (`/nonexistent-core-$$`) against an
  otherwise-valid, in-scope payload matching that suite's own existing
  valid-payload fixtures, and asserts exit code 2 — directly exercising
  the item-1 `||` guard as an executed test, not just a static
  convention. Each case follows its own suite's existing
  helper/env-injection idiom (`run_case`'s `env_extra` argument where
  the harness supports it; inline `env`/`VAR=val` subprocess invocation
  matching the file's existing kill-switch-test pattern otherwise).

- **Item 3b — Edit-reconstruction-denies case (phase1-proposal-norms
  only).** Added one new test case to
  `phase1-proposal-norms/hooks/tests/run-gate-tests.sh`: an `Edit`
  against an initially-compliant proposal file whose
  `old_string`/`new_string` pair removes the
  "Status: Phase 1 proposal — APPROVE is out of scope for this PR."
  line, expecting deny (exit 2). Scoped to phase1-proposal-norms only,
  per the proposal's explicit scoping — the issue text names the
  phase1 suite by name as the concrete defect; extending the same case
  shape to the other three suites was flagged in the proposal as
  optional hardening, not a named defect, and was left out of scope
  here.

- **Item 4 — README/manifest re-verification.** Re-verified the
  proposal's phase-2 caveat that item 1/2's edits could introduce fresh
  README staleness even though the pre-change state was clean: grepped
  root `README.md` for any literal `Write|Edit|MultiEdit` matcher
  string. No match was found — `README.md` does not quote the matcher
  string literally anywhere, so no edit was required. Item 4 remains
  closed as "no remediation needed, verified clean" for both the
  pre-change and post-change state.

## Why (rationale)

Issue-13 is the third gate-A+ remediation round on this rulebook, closing
what a fresh 2026-08-01 re-audit found still open after issue-10's
remediation landed: two divergences from the core canon source idiom
(missing `||` fail-closed guard, wrong primary env var name), a dead
NotebookEdit code branch unreachable through the hooks.json matcher, and
a gap where the fail-closed `||` guard and phase1's Edit-deny path were
proven only by static inspection/convention rather than an executed
test. Both preconditions named by the issue (core #75, on-the-record
#182) were confirmed already landed in `tokenmaxxxer-core` per the
survey, so this round addresses only the four numbered requirements
against that landed baseline — no broader scope.

## Governance/context

Issue-13 phase-1 proposal approved 2026-08-01 (comment "APPROVE
issue-13/risk-management", per contract v3 §19, no caveats — including
the proposal's own recommendation on item 2's NotebookEdit matcher
addition, which is therefore not an open judgment call). Risk under
judgment: a gate that silently mis-resolves its own library source
(wrong env var, no fail-closed fallback) can fall through to a stale
fallback path or, worse, allow a write while claiming compliance;
closing this is a prerequisite for treating any of the four gates'
future test-suite green runs as trustworthy evidence.

### Objective linkage

Closes the third and (per the issue) final round of gate-A+ remediation
findings on this rulebook's four gate scripts before further phase-1/
phase-2 risk-management work is judged by gates carrying these
divergences.

## Assessment

Verified by direct execution, not inspection alone.

risk-score-inherent: high
risk-score-residual: low

### Test suite run results

All four `hooks/tests/run-gate-tests.sh` suites were run (with
`CLAUDE_PLUGIN_ROOT_CORE` pointed at a local `tokenmaxxxer-core`
checkout so the item-1 source line resolves correctly) and are green,
including each suite's new item-3a case and phase1's item-3b case:

```
erm-verdict-methodology:    Summary: 22 passed, 0 failed
risk-register-methodology:  === summary: 24 passed, 0 failed ===
phase1-proposal-norms:      Summary: 19 passed, 0 failed
phase2-record-norms:        === phase2-record-norms gate tests: 18 passed, 0 failed ===
```

### compliance-check.sh run result

`core/hooks/tests/compliance-check.sh` was run against each of the four
plugins' `hooks/` directories:

```
##### erm-verdict-methodology #####
compliance-check: ok — erm-verdict-methodology/hooks/erm-order-gate.sh
exit: 0
##### risk-register-methodology #####
compliance-check: ok — risk-register-methodology/hooks/register-fields-gate.sh
exit: 0
##### phase1-proposal-norms #####
compliance-check: ok — phase1-proposal-norms/hooks/proposal-shape-gate.sh
exit: 0
##### phase2-record-norms #####
compliance-check: ok — phase2-record-norms/hooks/record-shape-gate.sh
exit: 0
```

All four passed with exit code 0 and no FAIL reasons emitted — the two
static rules the proposal named (the `||`-guard adjacency check and the
`.replace(...)`-without-`gate_reconstruct_write` rule) both pass on the
post-item-1 source lines.

## Risk treatment

Response tier: mitigate — completed. Mitigation owner: JiwonJung94. All
four numbered items landed and verified per the Assessment section
above; no deferred items remain from this proposal's scope.

## Monitoring and review

Review-date: 2026-09-01.

Trigger: `compliance-check.sh` run against this rulebook's `hooks/`
finding any remaining hand-rolled source guard, missing `||` fallback,
or matcher/code coverage mismatch (none found at landing time, verified
above).

## Open findings

None outstanding against this proposal's items 1-4. The proposal's
secondary/optional note (that the Edit-reconstruction-denies gap named
in item 3b "may exist to a lesser degree" in the other three suites) was
explicitly scoped out of this round's required work by the proposal
itself and is not treated as an open finding here — it is noted for a
future round's judgment, consistent with the proposal's own framing.

## risk-register-entry

risk-id: issue-13-gate-a-plus-final-closure
risk-description: Four risk-management plugin gates sourced gate-lib.sh with a wrong primary env var name and no fail-closed `||` guard, one hooks.json matcher gap left a NotebookEdit-handling code branch permanently unreachable, and the fail-closed guard plus phase1's Edit-deny path were unproven by any executed test
risk-category: operational
likelihood: medium
impact: high
risk-score-inherent: high
existing-controls: canon source-guard idiom applied to all four gate scripts (item 1); hooks.json matcher/code parity closed via NotebookEdit addition (item 2); missing-core dynamic test case added to all four suites and Edit-reconstruction-denies case added to phase1-proposal-norms (item 3a/3b); full suite green plus compliance-check.sh PASS on all four plugins, recorded here (item 3c); README/manifest re-verified clean post-edit (item 4)
risk-score-residual: low
risk-appetite-threshold: low or below only
mitigation-owner: JiwonJung94
mitigation-plan: Landed in full per items 1-4 of the approved proposal; monitored going forward via compliance-check.sh and the per-plugin test suites on any future change to these four gate scripts
review-date: 2026-09-01
status: mitigated/closed — items 1-4 all landed and verified 2026-08-01
