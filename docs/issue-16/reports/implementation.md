---
code_under_review: erm-verdict-methodology/hooks/erm-order-gate.sh, erm-verdict-methodology/hooks/tests/run-gate-tests.sh
loop_state: phase-2-complete
---

# Implementation record — issue-16

Proposal: `docs/issue-16/proposals/erm-order-gate-mktemp-fix.md` (approved via PR #17).

## What was done

1. Removed `PYSCRIPT="$(mktemp)"` and the `cat > "$PYSCRIPT" <<'PYEOF'` file redirection from `erm-order-gate.sh`; the heredoc now feeds `python3` directly on its own invocation.
2. Payload and project root are now handed to the judge via `export GATE_PAYLOAD="$payload"` / `export GATE_PROJECT_DIR="$PROJECT_DIR"` instead of stdin/argv, removing the stdin contention that previously forced the scratch-file workaround.
3. In the embedded Python judge: `project_dir = os.environ["GATE_PROJECT_DIR"]` (was `sys.argv[1]`), `raw = os.environ["GATE_PAYLOAD"]` (was `sys.stdin.read()`).
4. Removed the `rm -f "$PYSCRIPT"` cleanup calls (nothing to clean up — no scratch file is ever created).
5. Replaced the stale comment describing the old mktemp-then-stdin-heredoc workaround with one describing the env-var handoff.
6. Added a regression test to `run-gate-tests.sh` (case 8, product-discovery-rulebook#54 style): shadows `mktemp` on `PATH` with an always-failing marker binary scoped to the gate subprocess (via `run_case`'s `env_extra` param), asserts the gate still ALLOWs a valid payload, and separately asserts the marker file the shadow `mktemp` would touch is never created.

## Why

Per issue #16: the bare `mktemp` at the old line 31 writes the inline Python judge to a scratch file before running it. Under a sandboxed Claude Code role session where the platform tmp dir is outside the writable set, that write is denied, the gate's fail-closed trap fires, and every erm-verdict write is denied regardless of content. The fix (per the approved proposal) eliminates the scratch file entirely by routing the payload/root through environment variables so the heredoc can feed `python3` directly without a stdin collision — the same pattern product-discovery-rulebook#54 established for its own gate.

## Concrete upstream basis

- Issue #16 (this repo), citing product-discovery-rulebook#54 as the house pattern already applied to km-cross-index and content-design gates on 2026-08-06.
- `docs/issue-16/proposals/erm-order-gate-mktemp-fix.md` (approved phase-1 proposal, PR #17) — `## What will be done` §1-6, followed without deviation.
- `docs/issue-16/reports/implementation/survey.md` (phase-1 current-state survey).

## Verification performed (this session, both directions)

- Post-fix: full `run-gate-tests.sh` suite — **24 passed, 0 failed** (23 pre-existing cases + new case 8, split into two PASS lines: the ALLOW assertion and the no-marker-file assertion).
- Pre-fix (regression-test proves the bug): `git stash push -- erm-verdict-methodology/hooks/erm-order-gate.sh` (reverting only the gate script, keeping the new test), reran the suite — **22 passed, 2 failed**. The two failures were exactly the new case 8's two assertions:
  - `FAIL: allow: gate survives mktemp shadowed with always-failing marker (exit=2 expected=0 ... 'erm-order-gate: refused — internal judge crashed (rc=0) — failing closed')`
  - `FAIL: mktemp shadow marker was created — gate still invokes mktemp`
  This confirms the test fails against the pre-fix script (fail-closed denial, exactly the bug the issue describes) and passes after the fix, with no side effects on the other 22 cases. `git stash pop` restored the fix afterward.
- `grep -rn mktemp erm-verdict-methodology/hooks/erm-order-gate.sh` — no output (empty grep, confirmed via exit code 1).
- Injection-safety probe of the new `GATE_PAYLOAD`/`GATE_PROJECT_DIR` env-var transport, run against a throwaway scratch repo (outside the real issue tree) via a driver script (`/tmp/.../scratchpad/probe.py`, discarded after use) feeding payloads containing `$(...)` command substitution, backticks, a `PYEOF` heredoc-delimiter collision, and an inline `os.system(...)` call as document content:
  - All four payloads: gate exited 0 (ALLOW, content treated as opaque text — no execution), stdout/stderr empty, and the would-be marker file was never created for any of the four. Observed output:
    ```
    === cmd-subst ===
    exit=0 stdout='' stderr=''
    marker created: False
    === backticks ===
    exit=0 stdout='' stderr=''
    marker created: False
    === pyeof-collision ===
    exit=0 stdout='' stderr=''
    marker created: False
    === os-system-inline ===
    exit=0 stdout='' stderr=''
    marker created: False
    ```
  Confirms the env-var transport does not create a code-execution seam: the payload is read as a plain string (`os.environ["GATE_PAYLOAD"]`) into a Python variable, never passed through a shell or `eval`, so shell metacharacters and Python-looking text in document content have no special effect.

## What did not work

None — the approach from the approved proposal applied cleanly on the first attempt; no edit was written then undone, and no expected behavior failed to hold.

## Rationale for deviations

None — implementation followed the approved proposal's `## What will be done` (§1-6) without deviation.

## Doc-placement ladder (completed items)

- `docs/handbooks/erm-verdict-methodology.md` — added a section documenting the env-var handoff mechanism (mechanically required by `handbook-trigger-gate.sh` since `hooks/tests/run-gate-tests.sh`, an operational test-harness script, changed in this unit of work; `docs/` is always writable regardless of the proposal's frozen write set).
- No new env var, config key, dependency, or migration introduced by this change beyond the handbook update above.
- No library-or-format choice or public-signature/wire-format change beyond what the proposal's own `## Rationale` already recorded — no new `docs/issue-16/decisions/` entry; this is a plumbing fix, not a new architectural decision.
- No standalone benchmark/investigation report — the pre/post regression-suite counts and the injection-probe output are recorded inline above (`## Verification performed`), which is this record's designated home for such observations.

## Hunt cadence

Per contract v3 s22 (this is a headless, single-shot session — no later turn for an async completion notification to land in), the before-landing warrant-hunter dispatch is skipped: dispatching a background hunter and ending the turn without consuming its result would violate the higher-priority headless rule (s22 overrides the warrant-directive's dispatch instruction in this situation). Recorded here as the mandatory skip note; no hunt ran this session.

## Open findings

None open.

## Open finding resolution path

Not applicable — no open findings.

## Next steps

None — proposal's `## What will be done` is fully implemented, both verification directions are confirmed, and the record is closing at `loop_state: phase-2-complete`. Remaining work is the human PR review/merge decision on PR #17 (this branch).
