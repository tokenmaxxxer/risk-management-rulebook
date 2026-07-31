# Proposal: Convert risk-management rulebook to reference core canon

Subject: issue-2

Status: Phase 1 proposal — for review only. See survey at
`docs/issue-2/reports/implementation/current-state-survey.md` for full
findings this proposal is based on.

## Scouting

Skipped: this is an internal repo-hygiene refactor (deduplicating role-local
copies against an already-landed internal core canon per core issues #63/#66).
There is no external market/product/competitive angle to scout.

## Summary

Core has landed a single canon for: the warrant-hunter agent (core `warrant/`
plugin, core issue #63), the three role-agnostic gates (core `core/hooks/`,
core issue #66), and shared directive boilerplate
(`core/hooks/lib/role-directive.sh`'s `core_role_directive`). This repo's
`risk-management` role still carries full local copies of all of these. The
issue asks for one batch of five changes converting local copies into thin
references, while preserving what's genuinely specific to `risk-management`.

## Item 1 — remove local warrant-hunter copy

**Delete:** `risk-management/agents/warrant-hunter.md` in full (its own
header already admits it's "adapted from implementation-rulebook's
`agents/warrant-hunter.md`" — a role-to-role copy, now superseded by core's
`warrant/` plugin with size-proportional budget + miss-streak +
instrumentation).

**Replace with:** a one-line reference in `README.md`'s Layout section,
e.g.:

```
- warrant-hunter agent — provided by core's `warrant/` plugin (core issue #63); no local copy in this rulebook.
```

**Preserve:** nothing needs to move into a stub file, because the two lines
of role-specific content in the old file (`decides`:
`전사 리스크 노출이 허용 범위인가`, `hand-off`:
`개별 법규 컴플라이언스 세부는 → legal-compliance`) already live verbatim
in `README.md` and in `directive.sh`'s role-specific block (see item 3). No
information is lost by deleting the file outright.

## Item 2 — remove gate copies, drop their hook registration

**Delete:**
- `risk-management/hooks/trailer-gate.sh` (its own header says "this file's
  logic is role-agnostic" — pure copy, only strings substituted)
- `risk-management/hooks/handbook-trigger-gate.sh` (currently only a
  placeholder `exit 0` — no role logic to lose)
- the corresponding two `PreToolUse` (Bash matcher) hook entries in
  `risk-management/hooks/hooks.json` that reference these two scripts

**Also delete the mechanism, but migrate the config:**
- `risk-management/hooks/record-fields-gate.sh` deleted, and its
  `PreToolUse` (Write|Edit|MultiEdit matcher) entry in `hooks.json` removed —
  BUT its `REQUIRED_FIELDS = ["erm-verdict", "risk-register-entry",
  "mitigation-owner"]` and target-path suffix
  (`docs/issue-<n>/reports/risk-management.md`) are genuinely
  role-specific (derived from this role's own `produces`, per issue-170) and
  must not simply vanish. Per the issue's item 4, this config should move to
  an explicit `RECORD_FIELDS_TERMINAL_STATES`-style config that core's
  version of the gate reads per-`CLAUDE_ROLE`. Concretely: add a small
  role-config file (exact surface TBD by core's actual gate implementation —
  flagged as an open item in the survey) carrying:
  - required fields: `erm-verdict`, `risk-register-entry`,
    `mitigation-owner`
  - record path suffix: `/reports/risk-management.md`
  - any terminal `loop_state` set specific to this role (none currently
    defined in this repo — if risk-management's ERM loop has terminal
    states distinct from other roles, they must be enumerated here rather
    than assumed to be the sibling default)

**hooks.json after:** only the `SessionStart` entry (directive.sh, see item
3) remains under this role's `hooks.json`; the two `PreToolUse` matcher
blocks are removed entirely since core's own hook registration (core issue
#66, `CLAUDE_ROLE` injection) supersedes them.

## Item 3 — stub directive.sh

**Replace** the current 31-line `risk-management/hooks/directive.sh` (which
inlines its own trap/kill-switch boilerplate and the full directive heredoc)
with a thin stub of this shape:

```bash
#!/usr/bin/env bash
# SessionStart: risk-management's role directive.
# Delegates shared boilerplate to core; supplies only role-specific payload.
source "${CLAUDE_PLUGIN_ROOT}/../core/hooks/lib/role-directive.sh"

core_role_directive \
  --role "risk-management" \
  --kill-switch-var "RISK_MANAGEMENT_CYCLE_OFF" \
  --decides "전사 리스크 노출이 허용 범위인가" \
  --use-when "재무/운영/전략 리스크가 걸릴 때 (feasibility보다 넓은 범위)" \
  --produces "ERM verdict, risk register entry, mitigation owner" \
  --write-scope "[]" \
  --hand-off "개별 법규 컴플라이언스 세부는 → legal-compliance" \
  --record-path "docs/issue-<n>/reports/risk-management.md"
```

Exact flag/arg names depend on `core_role_directive`'s real signature (not
visible from this checkout — flagged as open item 1 in the survey); the
above is the target shape, to be confirmed against the actual core function
before phase 2 edits land.

**Preserve verbatim (role-specific, must appear in the stub's arguments,
not deleted):**
- `전사 리스크 노출이 허용 범위인가` (decides)
- `재무/운영/전략 리스크가 걸릴 때 (feasibility보다 넓은 범위)` (use_when)
- `ERM verdict, risk register entry, mitigation owner` (produces)
- `[]` (write_scope)
- `개별 법규 컴플라이언스 세부는 → legal-compliance` (hand-off)
- `RISK_MANAGEMENT_CYCLE_OFF` (kill switch var name) and the
  `CLAUDE_ROLE = risk-management` identity check
- `docs/issue-<n>/reports/risk-management.md` record path, phase-gated per
  contract v3 s19

**Move to core (no longer duplicated locally):** the trap/kill-switch shell
idiom, the generic "BOUNDARY CASE" prose, and the heredoc formatting —
these become `core_role_directive`'s job.

## Item 4 — explicit RECORD_FIELDS_TERMINAL_STATES preservation

Covered concretely under item 2 above: risk-management's required-fields
set (`erm-verdict`, `risk-register-entry`, `mitigation-owner`) and record
path move into an explicit per-role config rather than being deleted along
with the gate script. Current repo has no terminal `loop_state` divergence
to declare yet (`record-fields-gate.sh` today has no terminal-state
handling at all); if phase-2 investigation of core's actual gate reveals
risk-management needs a distinct terminal-state set, it must be declared
explicitly in this config, not left to inherit a sibling role's default.

## Item 5 — stub-check verification record

`core/hooks/tests/stub-check.sh` does not exist in this checkout (no core
canon is checked out locally in this repo — see survey). This is a phase-2
action: once core canon is available as a dependency at execution time, run
the check against the converted `directive.sh` stub and record pass/fail in
this role's phase-2 record (`docs/issue-2/reports/implementation.md`, not
created by this phase-1 task).

## Ordering constraint (from the issue)

This conversion must complete before this repo's rulebook-maturation issue
phase 2 begins — noting for the record, not an action item here.

## Explicitly out of scope for this proposal (phase 2, gated on approval)

- Actually deleting `risk-management/agents/warrant-hunter.md`,
  `risk-management/hooks/trailer-gate.sh`,
  `risk-management/hooks/handbook-trigger-gate.sh`,
  `risk-management/hooks/record-fields-gate.sh`.
- Actually rewriting `risk-management/hooks/directive.sh` or
  `risk-management/hooks/hooks.json`.
- Creating any new role-config file for required-fields/terminal-states.
- Running `core/hooks/tests/stub-check.sh`.

All of the above begin only after an `approvers.md`-listed account posts
`APPROVE issue-2/implementation` (single-account mode) or a PR review
Approve (two-account mode), per contract v3 s19.
