# Issue-13 Proposal: Gate A+ 최종 마감 — 재감사 잔여 결함 보수

Status: Phase 1 proposal — APPROVE is out of scope for this PR.

See docs/issue-13/reports/risk-management/survey.md for current-state findings.

## Context

This is the risk-management rulebook's third gate-A+ remediation round: issue-1 (methodology) → issue-7 (plugin-set enforcement) → issue-10 (gate-A+ remediation round 1, landed the canon migration to core's gate-lib) → issue-13 (this round), closing what a fresh 2026-08-01 re-audit found still open after issue-10's remediation landed. The issue names four numbered requirements plus two "공통 선행 조건" that must already be landed in core before this work starts. The survey confirms both preconditions (core #75, on-the-record #182) are landed in `tokenmaxxxer-core`. This proposal addresses the issue's four requirements against that landed baseline.

## 1. 공통 항목: core #75의 확정 가드/규칙 적용

The survey (§A.4) found all four of this repo's gate scripts source `gate-lib.sh` identically and with two divergences from the now-canonical shape documented in `core/hooks/lib/gate-lib.sh`'s header:

- No `||` fallback guard on the source line (exact pattern `compliance-check.sh` now statically FAILs, per survey §A.2).
- Primary variable name `CORE_PLUGIN_ROOT`, which is not what spawn.py actually injects (`CLAUDE_PLUGIN_ROOT_CORE`, confirmed set in the live environment per survey §A). Today each gate falls through to its `$CLAUDE_PLUGIN_ROOT/../core` fallback rather than reading the injected value directly.

Proposed change, applied identically to all four files:

- `erm-verdict-methodology/hooks/erm-order-gate.sh:11`
- `risk-register-methodology/hooks/register-fields-gate.sh:15`
- `phase1-proposal-norms/hooks/proposal-shape-gate.sh:17`
- `phase2-record-norms/hooks/record-shape-gate.sh:31`

Replace the current line:

```
. "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh"
```

with the exact canon idiom from core/gate-lib.sh's header (substituting each gate's own script name for `<gate-name>.sh`):

```
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "<gate-name>.sh: cannot source gate-lib.sh" >&2; exit 2; }
```

This closes both divergences at once: it reads the actually-injected `CLAUDE_PLUGIN_ROOT_CORE` first, falls back to a same-repo relative resolution only if that variable is unset, and fails closed (exit 2) if the source itself fails — satisfying `compliance-check.sh`'s `|| ` line-adjacency check.

`gate_bash_write_targets` migration: the survey (§A.4) found no hand-rolled Bash write-target scanning logic in any of the four gate scripts (`grep` for `Bash`, `write.target`, `target.*path` across all four returned nothing). None of these four gates process the `Bash` tool at all — their `hooks.json` matchers are scoped to `Write|Edit|MultiEdit` only. No migration to `gate_lib.gate_bash_write_targets` is applicable here; this sub-item of core #75 has nothing to close in this repo. This is noted so the closure record does not silently skip an item that was checked and found not applicable, rather than simply omitted.

## 2. hooks.json matcher와 코드의 도구 커버리지 완전 정합

The survey (§B) found all four gate scripts' Python payload already branches on `NotebookEdit` and calls `gate_lib.gate_reconstruct_write` with NotebookEdit-handling logic, but all four `hooks.json` files scope their matcher to `Write|Edit|MultiEdit`, so that code path can never fire — a dead branch the matcher never routes to.

Proposed change: add `NotebookEdit` to the matcher in all four files, so matcher and code agree:

- `erm-verdict-methodology/hooks/hooks.json`
- `risk-register-methodology/hooks/hooks.json`
- `phase1-proposal-norms/hooks/hooks.json`
- `phase2-record-norms/hooks/hooks.json`

Change `"matcher": "Write|Edit|MultiEdit"` to `"matcher": "Write|Edit|MultiEdit|NotebookEdit"` in each.

Rationale and judgment call flagged for the approver: the issue's item 2 asks for matcher/code coverage to fully agree ("완전 정합"), and core's `gate_reconstruct_write` already treats `NotebookEdit` as a supported case rather than an unimplemented stub. Since these plugins' scoped paths (`docs/issue-N/proposals|reports/*.md`) are markdown files, a NotebookEdit invocation against them would be an edge case (editing a markdown file as if it were a single-cell notebook) rather than a common path — but leaving fully-implemented gate code permanently unreachable is precisely the "dead branch" defect the issue names, and the alternative (deleting the NotebookEdit-handling code from the gate scripts as unreachable) would mean re-implementing it later if this plugin set is ever extended to cover `.ipynb` targets. Recommendation is to close the matcher gap (add NotebookEdit) rather than delete the code, but this is presented as a recommendation, not a unilateral decision, since it changes each gate's live tool coverage.

## 3. missing-core 케이스 포함 전 스위트 배송 상태 green + compliance-check 통과 record 기록

Two additions, scoped as follows:

**3a. Missing-core dynamic test case — all four suites.** The survey (§D) found no suite currently exercises the fail-closed behavior dynamically; it is currently proven only by core's static `compliance-check.sh` rule, not by an executed test in this repo. Add one new mandatory test case to each of:

- `erm-verdict-methodology/hooks/tests/run-gate-tests.sh`
- `risk-register-methodology/hooks/tests/run-gate-tests.sh`
- `phase1-proposal-norms/hooks/tests/run-gate-tests.sh`
- `phase2-record-norms/hooks/tests/run-gate-tests.sh`

The case: invoke the gate with `CLAUDE_PLUGIN_ROOT_CORE` set to a nonexistent directory path (e.g. `/nonexistent-core-$$`), with any otherwise-valid tool-call payload, and assert exit code 2. This directly exercises the `||` guard added under item 1 above and proves it is wired into each of the four gates, not merely documented as a convention.

**3b. Edit-reconstruction-denies case — phase1-proposal-norms (primary), noted as optional elsewhere.** The survey (§C) found `phase1-proposal-norms/hooks/tests/run-gate-tests.sh` has an Edit-deny case only for "old_string not found" (line ~100) and Edit/MultiEdit allow cases only for still-compliant reconstructions; no case proves a successful Edit reconstruction that produces non-compliant content is denied. Add one new test case to `phase1-proposal-norms/hooks/tests/run-gate-tests.sh`: an Edit against an initially-compliant proposal file whose `old_string`/`new_string` pair removes the "Status: Phase 1 proposal" line (or the survey-citation line), expecting deny (exit 2). This is the case the issue text names explicitly ("phase1 스위트 Edit 케이스 부재").

The same category of gap (Edit-reconstruction-denies-on-shape-failure) may exist to a lesser degree in the other three suites (`erm-verdict-methodology`, `risk-register-methodology`, `phase2-record-norms`), since none of the survey excerpts read for §C were checked against those three suites' full Edit coverage. This is flagged as a secondary/optional item for the approver's judgment — the issue text scopes the concrete defect to "phase1 스위트" by name, so 3b's required scope is phase1-proposal-norms only; extending the same case shape to the other three suites is optional hardening, not a named defect.

**3c. Green suite + compliance-check record.** Once 1, 2, 3a, and 3b land, all four `run-gate-tests.sh` suites should be run to green, and `core/hooks/tests/compliance-check.sh` should be run against all four gate scripts and pass (no FAIL reasons emitted, per the two rules in survey §A.2 and the `.replace(...)`-without-`gate_reconstruct_write` rule). Recording that passing run is a phase-2 record concern, not a phase-1 proposal concern — this proposal specifies what will be changed and what will be tested, not the record of the resulting passing run.

## 4. README·manifest 옛 역할명·유령 파일 잔재 0

The survey (§E) found this item already holds against the repository's current state: every backtick-quoted path in `README.md` resolves to a real file, every `marketplace.json` plugin entry points at a real directory, and no stale role-name or deprecated-term residue was found. No remediation is proposed for this item — it is proposed for closure as "no remediation needed, verified clean."

One caveat carried forward for phase 2: item 1's `hooks.json` guard edits and item 2's matcher-string edits touch files that `README.md` may reference by content-adjacent description (not by the literal changed lines, but by describing gate behavior). Phase 2 implementation should re-verify README/manifest accuracy after those edits land, since a hooks.json matcher change is exactly the kind of edit that can introduce fresh staleness even when the pre-change state was clean.

## Scope note

This is a phase-1 proposal only. No code file has been touched in producing this document. APPROVE is out of scope for this PR; phase 2 (implementation) opens only on human Approve, per contract v3 §19.
