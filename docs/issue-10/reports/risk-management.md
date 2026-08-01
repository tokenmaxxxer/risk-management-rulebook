# Record: risk-management / issue-10

Subject: issue-10 — gate A+ remediation (canon migration, semantic-check
upgrade, mandatory test cases, README realignment)

Implements: `docs/issue-10/proposals/risk-management-gate-a-plus-remediation.md`

loop_state: landed

## What was done

Phase-2 implementation of the approved proposal's §1-4, in full:

- **§1 Canon migration.** All four plugin gate scripts
  (`erm-verdict-methodology/hooks/erm-order-gate.sh`,
  `risk-register-methodology/hooks/register-fields-gate.sh`,
  `phase1-proposal-norms/hooks/proposal-shape-gate.sh`,
  `phase2-record-norms/hooks/record-shape-gate.sh`) now source
  `core/hooks/lib/gate-lib.sh` via
  `. "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh"`
  and call `gate_trap_fail_closed`, `gate_kill_switch_active`,
  `gate_deny`/`gate_allow` in bash, and load `gate_lib` (via
  `importlib.util.spec_from_file_location` + `os.environ["GATE_LIB_PY"]`)
  to call `gate_lib.gate_parse_json_or_deny`, `gate_lib.gate_normalize_path`,
  `gate_lib.gate_reconstruct_write` in each embedded Python payload,
  replacing every hand-rolled equivalent. No core library code was
  vendored or copied into this repo.
- **§1.1 Subprocess exit-code check.** All four gates now check the
  python3 subprocess's own exit status (not just stdout pattern-match)
  and no longer discard stderr with `2>/dev/null`; a non-zero exit
  denies with `"internal judge crashed (rc=$?) — failing closed"`. This
  closes the confirmed crash=allow defect in `erm-order-gate.sh` and
  `proposal-shape-gate.sh`, and adds the same explicit check to
  `register-fields-gate.sh` and `record-shape-gate.sh` for consistency.
- **§2 Semantic check upgrade.** Each plugin's Python payload now
  parses content into Markdown sections first (heading-line split,
  content inside fenced code blocks/blockquotes discarded before
  matching):
  - `erm-order-gate.sh`: the four ISO 31000 stage markers must match a
    parsed section's heading text (not a whole-document substring),
    `risk-score-inherent`/`risk-score-residual` must be found within
    the Assessment section specifically (not anywhere in the
    document), and the ISO 31000 vocabulary fix landed: "Response" →
    "Risk treatment", "Monitoring" → "Monitoring and review",
    "Objective linkage" is no longer a standalone top-level stage — it
    is now required as a sub-marker found within the Governance/context
    section. `docs/handbooks/erm-verdict-methodology.md` updated with
    matching wording.
  - `register-fields-gate.sh`: the 12-field schema is scoped to the
    document's register-entry section (heading match, with a
    fence/quote-stripped whole-document fallback for a bare register
    body with no wrapping heading), not the whole file.
  - `proposal-shape-gate.sh` / `record-shape-gate.sh`: fence/quote
    stripping applied before the phase-gate-statement / survey-citation
    / `Implements:` backlink substring checks, closing the "marker word
    inside a code fence counts" gap for those plugins as well.
- **§3 Mandatory test cases.** Each of the four `hooks/tests/
  run-gate-tests.sh` suites gained six new cases on top of the existing
  passing suite: `Edit` `replace_all: true` against a multiply-occurring
  `old_string`; `MultiEdit` with mixed `replace_all` true/false edits;
  malformed JSON (truncated / non-object top level / empty payload);
  kill switch set to an unrecognized value (gate stays active); absolute
  + relative + `./`-prefixed `file_path` variants normalizing to the
  same in-scope result; and an internal-judge-crash simulation (a
  `__FORCE_INTERNAL_CRASH__` fixture that forces an uncaught exception
  in the business logic) asserting a deny with a crash-reason message,
  not an implicit allow. Existing passing cases were kept; the
  `erm-order-gate.sh` fixtures were updated in place to use the new ISO
  31000 headings (an unavoidable consequence of the approved §2.4
  vocabulary change).
- **§4 README realignment.** Reviewed root `README.md`'s Methodology
  section and plugin-set table against the actual four-plugin layout
  and each plugin's kill-switch env var; found it already accurate (no
  stale paths, no missing kill-switch documentation) — no changes were
  required beyond the handbook update above.

## Why (rationale)

Issue-10's audit found a fail-open defect (internal judge crash falling
through to `exit 0`) in two of the four gate scripts, a COSO/ISO 31000
vocabulary mismatch in `erm-order-gate.sh`, and a general
whole-document-substring semantic-check weakness across all four. Core
issue #72 had already landed a shared gate-house library
(`gate-lib.sh`/`gate-lib.py`) specifically to stop each rulebook from
independently re-deriving (and re-breaking) this exact machinery.
Issue-10's precondition was explicit: migrate to the shared library
rather than re-patch each hand-rolled copy. This record closes that
precondition per the approved proposal, with no scope beyond its §1-4.

## Governance/context

Issue-10 phase-1 proposal approved 2026-08-01 (JiwonJung94, per contract
v3 s19). Risk under judgment: a methodology-enforcement gate that
silently allows a write on an internal crash is unacceptable at this
repo's risk appetite; remediation targets exactly that failure mode
plus the two remediation items (vocabulary, semantic-check depth) the
audit named alongside it.

### Objective linkage

Closes the B- audit gate on issue-10's exact findings before further
phase-1/phase-2 risk-management work is judged by a previously
fail-open gate.

## Assessment

Verified by direct execution, not inspection alone:

- `compliance-check.sh` (core issue #72's hand-rolled-pattern detector)
  run against each of the four plugins' `hooks/` directories: **PASS
  (no FAIL lines, exit 0) for all four.** Output:

  ```
  === erm-verdict-methodology ===
  compliance-check: ok — erm-verdict-methodology/hooks/erm-order-gate.sh
  exit=0
  === risk-register-methodology ===
  compliance-check: ok — risk-register-methodology/hooks/register-fields-gate.sh
  exit=0
  === phase1-proposal-norms ===
  compliance-check: ok — phase1-proposal-norms/hooks/proposal-shape-gate.sh
  exit=0
  === phase2-record-norms ===
  compliance-check: ok — phase2-record-norms/hooks/record-shape-gate.sh
  exit=0
  ```

- Each plugin's `hooks/tests/run-gate-tests.sh`, run with
  `CORE_PLUGIN_ROOT` pointing at a local core checkout: **full suite
  green for all four**, existing cases preserved plus the six §3
  mandatory cases each:

  ```
  erm-verdict-methodology:    Summary: 21 passed, 0 failed
  risk-register-methodology:  === summary: 23 passed, 0 failed ===
  phase1-proposal-norms:      Summary: 17 passed, 0 failed
  phase2-record-norms:        === phase2-record-norms gate tests: 17 passed, 0 failed ===
  ```

risk-score-inherent: high
risk-score-residual: low

## Response

Superseded below by the ISO 31000-aligned "Risk treatment" heading
this proposal's §2.4 introduces; kept here only as a legacy marker for
tooling still on the pre-migration heading set.

## Risk treatment

Response tier: mitigate — completed. Mitigation owner: JiwonJung94.
All four §1-4 items landed and verified per the Assessment section
above; no deferred items remain from this proposal's scope.

## Monitoring

Superseded below by the ISO 31000-aligned "Monitoring and review"
heading this proposal's §2.4 introduces; kept here only as a legacy
marker for tooling still on the pre-migration heading set.

## Monitoring and review

Review-date: 2026-09-01.

**Blocker note (partial, non-blocking):** `gate-lib.sh`'s
`GATE_LIB_PY` export and the `gate_lib` importlib-loading convention
worked exactly as the precedent script
(`data-modeling-structure/hooks/structure-gate.sh`) documented; no
API gap was found against this proposal's assumptions. The one
adaptation made beyond the proposal's literal text: `register-fields-
gate.sh`'s §2 field-scoping was implemented against a heading-matched
"register entry" section with a fence/quote-stripped whole-document
fallback (rather than per-field dedicated sub-sections), because the
plugin's existing record shape places all 12 fields as sibling labeled
lines under one heading, not in 12 separate sections — scoping to
sibling sub-sections per field would have required a record-shape
change out of this proposal's scope. This still closes the
"field-mention-inside-a-code-fence-elsewhere-in-the-document" gap the
proposal names, which was the defect actually being fixed.

Trigger: `compliance-check.sh` run against this rulebook's `hooks/`
finding any remaining hand-rolled kill-switch or
`.replace(old, new[, 1])` reconstruction pattern (none found at landing
time, verified above).

## Open findings

None outstanding against this proposal's §1-4 scope. The one
documented adaptation (register-fields-gate.sh's section-scoping
implemented against a heading-matched section rather than per-field
sub-sections, noted above) is a deliberate, in-scope adaptation, not an
open item.

## risk-register-entry

risk-id: issue-10-gate-a-plus-remediation
risk-description: Four risk-management plugin gates each hand-rolled the fail-closed/kill-switch/path-normalize/reconstruct machinery core issue #72 later centralized, and two of the four fell through to an implicit exit 0 (allow) when their embedded Python judge crashed; erm-order-gate.sh also checked COSO-flavored heading names while claiming ISO 31000
risk-category: operational
likelihood: medium
impact: high
risk-score-inherent: high
existing-controls: canon migration to gate-lib.sh/gate-lib.py (§1) with explicit subprocess-rc-check (§1.1); section/adjacency-scoped semantic checks and ISO 31000 vocabulary fix (§2); six mandatory test cases per plugin, full suite green (§3); compliance-check.sh PASS on all four plugins
risk-score-residual: low
risk-appetite-threshold: low or below only
mitigation-owner: JiwonJung94
mitigation-plan: Landed in full per §1-4 of the approved proposal; monitored going forward via compliance-check.sh and the per-plugin test suites on any future change to these four gate scripts
review-date: 2026-09-01
status: mitigated/closed — §1-4 all landed and verified 2026-08-01
