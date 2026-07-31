# Issue #2 — Phase 2 Implementation Record

Subject: issue-2

loop_state: blocked

## Why

Core landed a single canon for warrant-hunter (core issue #63), the three
role-agnostic gates (core issue #66), and shared directive boilerplate
(`core/hooks/lib/role-directive.sh`). This role's local copies of all of
these were duplicates the issue asked converted to references, per the
approved proposal `docs/issue-2/proposals/core-canon-reference-conversion.md`
(approved via `APPROVE issue-2/implementation`, contract v3 s19
single-account mode).

Upstream basis: proposal at
`docs/issue-2/proposals/core-canon-reference-conversion.md` and survey at
`docs/issue-2/reports/implementation/current-state-survey.md`, both committed
at `f84d54b`/`88f03af` on this branch.

## What Was Done

1. Deleted `risk-management/agents/warrant-hunter.md`. Replaced with a
   one-line reference in `README.md`'s Layout section pointing at core's
   `warrant/` plugin (core issue #63).
2. Deleted `risk-management/hooks/trailer-gate.sh` and
   `risk-management/hooks/handbook-trigger-gate.sh`, and removed their
   `PreToolUse` (Bash matcher) entries from `risk-management/hooks/hooks.json`.
3. Deleted `risk-management/hooks/record-fields-gate.sh` and its `PreToolUse`
   (Write|Edit|MultiEdit|NotebookEdit matcher) entry from `hooks.json`.
   Migrated its role-specific config (required fields
   `erm-verdict`/`risk-register-entry`/`mitigation-owner`, record path suffix
   `/reports/risk-management.md`) into a new
   `risk-management/hooks/record-fields.json`, including an explicit (empty)
   `RECORD_FIELDS_TERMINAL_STATES` array per item 4 — this repo currently has
   no terminal `loop_state` divergence from the sibling default, declared
   explicitly rather than left implicit.
4. Replaced `risk-management/hooks/directive.sh` with a thin stub that
   sources `core/hooks/lib/role-directive.sh` and calls `core_role_directive`
   with only this role's payload (decides/use_when/produces/write_scope/
   hand-off/kill-switch var/record path). `hooks.json`'s `SessionStart` entry
   is unchanged.
5. `hooks.json` after conversion carries only the `SessionStart` entry; all
   `PreToolUse` wiring for the three gates is removed, per the issue (core's
   own registration, core issue #66, supersedes it).

### Item 5 — stub-check verification

`core/hooks/tests/stub-check.sh` does not exist in this checkout: there is no
`core/` directory, submodule, or additional remote in this repo (confirmed at
phase-1 survey and reconfirmed now — `git branch -a` still shows only `main`
and `issue-2/implementation`, no core canon is checked out as a dependency at
execution time). The check could not be run. This mirrors phase-1 finding
open-item 3 exactly: it remains unresolved, not resolved by this batch.

**Consequence:** `directive.sh`'s `source
"${CLAUDE_PLUGIN_ROOT}/../core/hooks/lib/role-directive.sh"` path and the
`core_role_directive` call's flag surface are written to the target shape
specified in the approved proposal, but are unverified against the real core
function signature (phase-1 open item 1) and against stub-check.sh (this
item). Until core canon is present as an actual dependency at runtime, this
stub will fail at `source` time.

## Loop State Detail

Blocked — core canon (`core/` checkout, `core_role_directive` signature,
`core/hooks/tests/stub-check.sh`) is not present as a dependency in this
repo, so item 5's verification and the two signature-confirmation open items
cannot be closed from this checkout. All local-side edits scoped to the
approved proposal are otherwise complete.

## Next Steps

Once core canon is checked out as a dependency: confirm
`core_role_directive`'s real call signature, run
`core/hooks/tests/stub-check.sh` against `risk-management/hooks/directive.sh`,
and record pass/fail here.

## Resolution Path

Tracked as open findings below; closes when core canon becomes available to
this repo and phase-2 verification can actually run.

## Open Findings

1. Exact call signature of `core_role_directive` — not confirmable without a
   core checkout.
2. Whether core's record-fields gate reads `record-fields.json` in this exact
   shape or a different per-role config surface — `record-fields.json`'s
   field names are this role's best-effort target shape per the proposal,
   not confirmed against core's actual implementation.
3. Location/existence of `core/hooks/tests/stub-check.sh` — still not present
   in any checkout available to this role; item 5's pass/fail cannot be
   recorded until it is.
