# Proposal: risk-management gate A+ remediation

Subject: issue-10

Status: Phase 1 proposal — for review only. **APPROVE is out of scope for
this PR; phase 2 (remediation implementation) opens only after an
`approvers.md` account approves per contract v3 s19.** This document
proposes; it contains no `src/`/`test/` implementation.

See `docs/issue-10/reports/risk-management/survey.md` for current-state
findings (four gate scripts read against the issue and against core's
landed gate-house standard).

## 0. What this fixes and why fail-open is the priority

The issue's audit graded the repo B- on two confirmed defects plus a
general semantic-check gap:

1. `erm-order-gate.sh`'s internal (Python) judge, on an uncaught
   exception, produces an empty subprocess result that the surrounding
   bash falls through to `exit 0` on — a **crash allows the write**.
   Survey §1 traces the identical bug into `proposal-shape-gate.sh`.
2. `erm-order-gate.sh` claims ISO 31000:2018 but checks for headings
   that read as COSO ERM vocabulary, not ISO 31000 clause names.
3. Semantic checks are whole-document substring/regex, so a mention of
   a required word anywhere in the file — including inside a code
   fence or an unrelated sentence — can satisfy a check meant to assert
   real methodology structure.

Core issue #72 landed `core/hooks/lib/gate-lib.sh` (+`gate-lib.py`) and
`docs/handbooks/gate-house-standard.md` specifically because these are
not isolated bugs — the 43-repo audit behind #72 found the same defect
*classes* independently re-derived everywhere, including in core's own
canon. Issue-10's precondition is explicit: **reference that shared
library, do not reimplement it.** This proposal is a migration plus a
semantic-check upgrade, not a redesign.

## 1. Canon migration (all four plugins)

Each of `erm-verdict-methodology`, `risk-register-methodology`,
`phase1-proposal-norms`, `phase2-record-norms`'s gate scripts sources
`gate-lib.sh` and loads `gate-lib.py`, replacing the hand-rolled
equivalent:

| Hand-rolled today | Replaced by |
|---|---|
| `__fc()`/`trap __fc EXIT` (4 near-identical copies) | `gate_trap_fail_closed` |
| kill-switch string check (4 copies, "1"-only) | `gate_kill_switch_active` |
| ad hoc `echo ... >&2; exit 2` / `exit 0` | `gate_deny "<plugin>" "<reason>"` / `gate_allow` |
| `try: json.load(...) except: print("DENY::...")` (4 copies) | `gate_lib.gate_parse_json_or_deny` |
| `os.path.isabs` + `os.path.relpath`/`startswith` (4 copies, 2 idioms) | `gate_lib.gate_normalize_path` |
| `existing.replace(old, new, 1)`, ignores `replace_all`, no `NotebookEdit` (4 copies) | `gate_lib.gate_reconstruct_write` |

Concretely: each gate script's bash preamble becomes

```bash
. "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh"
gate_trap_fail_closed
set -uo pipefail
gate_kill_switch_active "${PLUGIN_OFF_VAR:-}" || { trap - EXIT; exit 0; }
```

and each embedded Python payload imports `gate_lib` via the
`GATE_LIB_PY` env var `gate-lib.sh` exports (usage shown in the lib's
own header comment) and calls `gate_lib.gate_parse_json_or_deny`,
`gate_lib.gate_normalize_path`, `gate_lib.gate_reconstruct_write` in
place of the hand-rolled equivalents. This mechanically closes defects
4-6 from the survey (`replace_all`/`NotebookEdit`, kill-switch spelling,
path normalization) across all four plugins at once, because it deletes
the four independently-buggy re-derivations rather than patching each.

**This also fixes defect 1 (crash = allow) as a side effect**, not a
special case: `gate_trap_fail_closed`'s EXIT trap remaps *any* non-0/2
exit to 2, and `gate_parse_json_or_deny` runs inside the same Python
process the gate's business logic runs in — an uncaught exception
there propagates as a non-zero Python exit, which the outer
`gate_deny`/subprocess-call convention (below) must check, closing the
suppressed-stderr + unchecked-exit-status hole directly.

### 1.1 Subprocess exit-code check (the specific line that caused defect 1)

The migration additionally requires every gate's bash-to-Python call
site to check the subprocess's own exit status, not just parse its
stdout — `gate-lib.sh` centralizes the trap/kill-switch/deny primitives
but each gate still owns its own `python3 ... | read result` line, and
today's stderr-discarding redirect is exactly what let a crash's
non-zero exit disappear silently. The fix:

```bash
if ! result="$(printf '%s' "$payload" | python3 "$PYSCRIPT" "$PROJECT_DIR")"; then
  gate_deny "<plugin>" "internal judge crashed (rc=$?) — failing closed"
fi
```

removing the stderr-discarding redirect (crash output should reach the
transcript, not be discarded) and branching on the subprocess's actual
exit status instead of only pattern-matching its stdout. Applies to
`erm-order-gate.sh` and `proposal-shape-gate.sh` (survey §1's two
confirmed instances); `register-fields-gate.sh` and
`record-shape-gate.sh` already fail closed on empty output but gain the
same explicit rc-check for consistency and because `gate_lib`-raised
exceptions inside their Python payload should also surface a crash
reason, not just "gate produced no result."

## 2. Semantic check upgrade: substring → section/adjacency/structure

Replace whole-document substring/regex marker checks with a
markdown-structure-aware pass, shared logic added to each plugin's own
Python payload (small enough that a shared `gate_lib.py` addition is
not warranted — this is methodology-specific business logic, not a
cross-cutting shape `gate-lib` should own):

1. **Parse into sections first.** Split the content on heading lines,
   discarding anything inside a fenced code block or blockquote before
   matching — a marker word inside a fence or quote no longer counts.
   This closes the "word mention passes" gap directly.
2. **Require markers as section headings, not substrings.** A stage
   marker must match a parsed section's heading text (exact or
   whitespace-normalized), not a raw string search anywhere in the
   document.
3. **Adjacency, not just document-order.** `erm-order-gate.sh` today
   checks stage *order* via index comparison, which this proposal
   keeps, but adds: each required field (e.g. the inherent/residual
   risk-score labels) must be found **within the section it belongs
   to** (its own heading through the next heading of equal-or-higher
   level), not anywhere in the document. `register-fields-gate.sh`'s
   12-field schema similarly scopes each field lookup to its dedicated
   register-entry section, not the whole file.
4. **ISO 31000 vocabulary fix.** `erm-order-gate.sh`'s required stage
   headings change:

   | Current heading (COSO-flavored) | Replacement heading (ISO 31000:2018 clause-aligned) |
   |---|---|
   | "Governance/context" | kept as-is — 6.3 Scope, context, criteria |
   | "Objective linkage" | retained as a sub-marker under the 6.3 section, no longer a standalone top-level stage name checked in isolation |
   | "Assessment" | kept as-is — 6.4 Risk assessment: identification/analysis/evaluation |
   | "Response" | renamed "Risk treatment" — 6.5's actual ISO 31000 term |
   | "Monitoring" | renamed "Monitoring and review" — 6.6's actual clause name |

   This is a business-logic change (what the gate requires), reviewed
   and approved as part of this proposal, not a canon-lib change.
   `docs/handbooks/erm-verdict-methodology.md` gets the matching
   wording update in phase 2.

## 3. Mandatory test cases

Per issue-10 item 3, each of the four plugins' `hooks/tests/
run-gate-tests.sh` gains, in addition to its existing passing cases:

1. **`Edit` with `replace_all: true`** against a multiply-occurring
   `old_string` — asserts the reconstructed content used for judgment
   reflects all occurrences replaced, not just the first.
2. **`MultiEdit`** with a mix of `replace_all: true`/`false` edits in
   one call — asserts each edit's own flag is honored independently.
3. **Malformed JSON** (truncated, non-object top level, empty payload)
   — asserts deny, not an unhandled exception.
4. **Kill switch set to an unrecognized value** (e.g. a typo) — asserts
   the gate stays **active** (deny path still reachable), matching
   `gate_kill_switch_active`'s convention.
5. **Absolute `file_path`** matching the same scope a relative-path
   fixture already matches, plus a `./`-prefixed variant — asserts
   `gate_normalize_path` resolves both to the same in-scope result.
6. **Internal-judge-crash simulation** (issue-10-specific, beyond the
   core standard's six): a fixture that forces the embedded Python
   payload to raise (e.g. malformed but JSON-valid input that the
   business logic mishandles) — asserts the gate denies with a
   crash-reason message, not an implicit allow. This is the direct
   regression test for defect 1.

Cases 1-5 are the core gate-house standard's mandatory six minus the
Bash-tool-write case, which does not apply here — none of the four
gates match on `Bash` tool writes, and nothing in the issue asks for
that surface to be added; scope stays as today (`Write`/`Edit`/
`MultiEdit`). Case 6 is added on top for the issue's specific fail-open
finding. All cases run per-plugin (4 plugins x 6 cases = 24 new cases
across the suite), plus a compliance check
(`core/hooks/tests/compliance-check.sh`, if present in the checkout at
phase-2 time; otherwise a manual equivalent grep for the hand-rolled
patterns table in survey §1-6) confirming zero hand-rolled kill-switch/
reconstruction idioms remain. Full suite green is the phase-2 delivery
condition per issue item 3.

## 4. README realignment

Phase-2 scope, deferred per survey §7: diff `README.md`'s Methodology
section and any file/path listing against the four-plugin reality
(`erm-verdict-methodology/`, `risk-register-methodology/`,
`phase1-proposal-norms/`, `phase2-record-norms/`, plus `risk-management/
hooks/directive.sh`'s fragment-concatenation), remove any path that no
longer exists, and document each plugin's actual kill switch. No design
decision here — mechanical diff-and-correct against the phase-2 code as
landed.

## 5. Non-goals (explicitly out of scope for this remediation)

- No new plugin, no new methodology, no scope expansion beyond the
  issue's four named defect classes plus the vocabulary/README fixes.
- No change to `phase2-record-norms`'s deliberate Approve-marker scope
  limit (survey/issue-7 proposal §2.4 open item 3) — unrelated to this
  issue.
- Bash-tool write-target scanning adoption — not requested, no current
  gate matches on `Bash`-tool writes, and issue-10 does not ask for
  that surface; noted as a future item only if a later issue asks for
  it.

## 6. Risk (erm-verdict, methodology dogfood on this proposal itself)

## Governance/context

This proposal is reviewed under the same ISO 31000:2018 process-clause
verdict this repo's own `erm-verdict-methodology` plugin enforces on
phase-2 records, applied here to the remediation decision itself.

## Objective linkage

Closes the B- audit gate on issue-10's exact findings before any
further phase-1/phase-2 work in this repo is gated by the currently
fail-open script.

## Assessment

Prose summary: the fail-open gate on a methodology-enforcement plugin
means every phase-2 record written since issue-7 landed could have
bypassed the ISO 31000 structure check on any crash-triggering input,
silently. The shell-level fail-closed EXIT trap already catches
shell-level crashes in all four scripts; only the Python-subprocess-
result path was uncontrolled. Migration to gate-lib.sh/gate-lib.py plus
the explicit rc-check (§1.1) closes the specific line, and mandatory
test case 6 (§3) regression-tests it going forward.

risk-score-inherent: high
risk-score-residual: low-medium

## Response

Response tier: mitigate (proceed to phase-2 implementation of §1-4 on
approval). Mitigation owner: JiwonJung94. Mitigation plan: this
proposal's §1-4, implemented and test-verified per §3 before phase-2
record closes.

## Monitoring

Review-date: 2026-09-01 (before the issue-7 monitoring review-date of
2026-09-15, so this remediation is verified landed first). Trigger:
`compliance-check.sh` (or manual equivalent) run against this
rulebook's `hooks/` finds any remaining hand-rolled kill-switch or
`.replace(old, new[, 1])` reconstruction pattern.

## risk-register-entry

risk-id: issue-10-gate-a-plus-remediation
risk-description: Four risk-management plugin gates (erm-verdict-methodology, risk-register-methodology, phase1-proposal-norms, phase2-record-norms) each hand-rolled the fail-closed/kill-switch/path-normalize/reconstruct machinery core issue #72 later centralized, and two of the four fall through to an implicit exit 0 (allow) when their embedded Python judge crashes; erm-order-gate.sh also checks COSO-flavored heading names while claiming ISO 31000
risk-category: operational
likelihood: medium
impact: high
existing-controls: shell-level fail-closed EXIT trap present in all four scripts; kill-switch-first ordering present; per-plugin test suites green at issue-7 landing (but did not cover crash/replace_all/kill-switch-unrecognized-value/absolute-path cases)
risk-appetite-threshold: low or below only (a methodology-enforcement gate that can silently allow on crash is unacceptable at this repo's risk appetite)
mitigation-owner: JiwonJung94
mitigation-plan: Migrate all four gates to core canon gate-lib.sh/gate-lib.py (§1), add explicit subprocess-rc-check on the two vulnerable call sites (§1.1), upgrade semantic checks to section/adjacency-scoped matching and fix the ISO 31000 vocabulary (§2), add the mandatory six-plus-one test cases per plugin (§3), realign README (§4) — all in phase 2 on approval
review-date: 2026-09-01

Field reference table (same values as above, for readability):

| Field | Value |
|---|---|
| `risk-id` | issue-10-gate-a-plus-remediation |
| `risk-category` | operational |
| `likelihood` | medium |
| `impact` | high |
| `risk-score-inherent` | high |
| `risk-score-residual` | low-medium |
| `mitigation-owner` | JiwonJung94 |
| `review-date` | 2026-09-01 |
