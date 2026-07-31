# Issue #2 — Current-State Survey (Phase 1)

Subject: issue-2

Scope: `risk-management-rulebook` repo, branch `issue-2/implementation`, as of
commit `f84d54b` (issue-170 skeleton seed). This is a phase-1 research
artifact only; no files are changed by this survey.

## Repo inventory

```
.claude-plugin/marketplace.json
README.md
docs/specs/approvers.md
risk-management/.claude-plugin/plugin.json
risk-management/agents/warrant-hunter.md
risk-management/hooks/directive.sh
risk-management/hooks/handbook-trigger-gate.sh
risk-management/hooks/hooks.json
risk-management/hooks/record-fields-gate.sh
risk-management/hooks/trailer-gate.sh
```

There is no visible `core` canon checkout in this repo (no submodule, no
`core/` directory, no additional remotes beyond `origin`; `git branch -a`
shows only `main` and `issue-2/implementation`; `git log --all` shows a
single commit). The issue body (core issue #63, #66) is the only available
description of core canon shape:

- `warrant/` plugin in core (core issue #63): size-proportional budget +
  miss-streak + instrumentation, superseding role-local warrant-hunter copies.
- `core/hooks/`: three role-agnostic gates — trailer, record-fields,
  handbook-trigger (core issue #66), with `CLAUDE_ROLE` injection and hook
  registration done on the core side.
- `core/hooks/lib/role-directive.sh`'s `core_role_directive` function:
  shared directive boilerplate that each role's `directive.sh` is expected to
  call, supplying only role-specific fields.

Since core canon isn't checked out locally, the proposal below specifies the
target shape (what a stub should assume/call) based on the issue text, and
flags where the actual core function signature must be confirmed before
phase 2 executes edits.

## Item-by-item findings

### 1. warrant-hunter local copy

`risk-management/agents/warrant-hunter.md` (23 lines) is a full local
markdown agent definition: mandate text, decision boundary quoted directly
from this role's `decides` field, a stance-rotation skeleton note, and a
scope/hand-off section. It explicitly says "adapted from
implementation-rulebook's `agents/warrant-hunter.md`" — i.e. it is itself a
role-to-role copy, and per the issue is now further superseded by the core
`warrant/` plugin (core issue #63, size-proportional budget + miss-streak +
instrumentation). Nothing in this file is risk-management-specific except:
- the decision boundary line: `전사 리스크 노출이 허용 범위인가`
- the hand-off line: `개별 법규 컴플라이언스 세부는 → legal-compliance`

Both of those already live verbatim in `README.md` and `directive.sh` — the
role's canonical `decides`/`hand-off` fields — so nothing here is uniquely
carried only by this file.

### 2. Gate copies (trailer / record-fields / handbook-trigger)

All three live under `risk-management/hooks/` and are wired via
`risk-management/hooks/hooks.json` (`SessionStart` + two `PreToolUse`
matchers referencing `${CLAUDE_PLUGIN_ROOT}/hooks/*.sh`):

- `trailer-gate.sh` — its own header says "this file's logic is
  role-agnostic," adapted from implementation-rulebook with only the role
  name substituted (`RISK_MANAGEMENT_CYCLE_OFF`, `risk-management: refused`
  strings). Enforces the `Subject: issue-<n>` commit trailer per contract v3.
  No risk-management-specific behavior.
- `record-fields-gate.sh` — role-agnostic gate *mechanism*, but its
  `REQUIRED_FIELDS = ["erm-verdict", "risk-register-entry",
  "mitigation-owner"]` and the `RECORD_SUFFIX` target path
  (`docs/issue-<n>/reports/risk-management.md`) are genuinely role-specific
  — derived from this role's own `produces` field (per issue-170), not
  copied from another role.
- `handbook-trigger-gate.sh` — role-agnostic mechanism, currently a
  placeholder (`exit 0 # placeholder verdict — TODO before this repo is
  treated as load-bearing`); no role-specific logic present yet at all.

Per the issue, core issue #66 lands these three gates in `core/hooks/` with
`CLAUDE_ROLE` injection and hook registration on the core side, meaning the
local copies plus this role's `hooks.json` `PreToolUse` wiring for them
become redundant once core registers its own hooks.

### 3. directive.sh — duplicated vs. stubbed

`risk-management/hooks/directive.sh` is a full standalone script: its own
trap/kill-switch boilerplate (lines 4-8, structurally identical pattern to
the gates' `__fc` trap idiom but written out locally, not sourced), and a
heredoc with the full directive text. Per the issue, common boilerplate
should live in `core/hooks/lib/role-directive.sh`'s `core_role_directive`
function, and this role's `directive.sh` should become a thin stub that
sources that shared function and supplies only the role-specific payload.

Role-specific content actually present in the heredoc that must be preserved
verbatim in the stub's role-specific block:
- `YOU DECIDE: 전사 리스크 노출이 허용 범위인가`
- `USE_WHEN: 재무/운영/전략 리스크가 걸릴 때 (feasibility보다 넓은 범위)`
- `PRODUCES (required record fields): ERM verdict, risk register entry, mitigation owner`
- `WRITE_SCOPE: []`
- `HAND-OFF: 개별 법규 컴플라이언스 세부는 → legal-compliance`
- kill-switch env var name `RISK_MANAGEMENT_CYCLE_OFF` and the `CLAUDE_ROLE
  = risk-management` gate check (role identity, cannot be shared).
- the `RECORD:` line pointing at
  `docs/issue-<n>/reports/risk-management.md` phase-gated per contract v3
  s19.

The generic prose ("BOUNDARY CASE: if the work in front of you drifts
outside...") and the trap/kill-switch shell idiom itself are boilerplate
candidates for `core_role_directive`, not role-specific.

### 4. Role-specific terminal-state / RECORD_FIELDS config

The issue calls out `RECORD_FIELDS_TERMINAL_STATES` as the mechanism for any
role that has a genuine "loop_state" difference from other roles. No such
config exists yet in this repo — `record-fields-gate.sh` has no terminal-
states handling at all, only the required-produces-fields check. This is a
gap relative to the issue's item 4, not a duplicate to remove: item 4 is
additive (introduce the config), not subtractive.

### 5. `core/hooks/tests/stub-check.sh`

Not present in this repo (would live in core, not here) and not discoverable
locally — there is no core checkout, submodule, or reference to this path
anywhere in the current tree. Confirming pass/fail against it is a phase-2
action once core canon is actually available as a dependency; phase 1 can
only flag that the check target doesn't exist yet in this checkout.

## What is genuinely role-specific to `risk-management` (must be preserved)

- `decides`: `전사 리스크 노출이 허용 범위인가`
- `use_when`: `재무/운영/전략 리스크가 걸릴 때 (feasibility보다 넓은 범위)`
- `produces` / required record fields: ERM verdict, risk register entry,
  mitigation owner (i.e. `erm-verdict`, `risk-register-entry`,
  `mitigation-owner` in `record-fields-gate.sh`)
- `write_scope`: `[]`
- `hand-off`: `개별 법규 컴플라이언스 세부는 → legal-compliance`
- role identity gate: `CLAUDE_ROLE = risk-management`, kill switch
  `RISK_MANAGEMENT_CYCLE_OFF`
- record target path: `docs/issue-<n>/reports/risk-management.md`
- plugin metadata (`plugin.json`, `marketplace.json`) — role name,
  description, authorship — untouched by this issue, not a canon-duplicate
  concern.

## What is duplicated/local and targeted for removal or stubbing

| Item | File(s) | Disposition |
|---|---|---|
| warrant-hunter copy | `risk-management/agents/warrant-hunter.md` | delete; replaced by reference to core `warrant/` plugin |
| trailer gate copy | `risk-management/hooks/trailer-gate.sh` + its `hooks.json` PreToolUse(Bash) entry | delete; superseded by core `core/hooks/` registration |
| record-fields gate copy | `risk-management/hooks/record-fields-gate.sh` + its `hooks.json` PreToolUse(Write\|Edit\|MultiEdit) entry | delete mechanism; role-specific field list/config must migrate to whatever role-config surface core's version reads (e.g. a `RECORD_FIELDS_TERMINAL_STATES`/required-fields config file) |
| handbook-trigger gate copy | `risk-management/hooks/handbook-trigger-gate.sh` + its `hooks.json` PreToolUse(Bash) entry | delete; superseded by core `core/hooks/` registration (was only a placeholder anyway) |
| directive.sh boilerplate | `risk-management/hooks/directive.sh` | replace with thin stub: source `core/hooks/lib/role-directive.sh`, call `core_role_directive` with role-specific args, keep `SessionStart` wiring in `hooks.json` unchanged |

## Open items to confirm before phase 2 executes

1. Exact call signature of `core_role_directive` (positional args vs. env
   vars) — not visible from this repo; must be read from the actual core
   checkout when phase 2 begins.
2. Whether core's record-fields gate takes required-fields as a
   `CLAUDE_ROLE`-keyed lookup it owns, or still expects a per-role config
   file/env var in this repo — determines exactly what (if anything) stays
   in `risk-management/hooks/` after item 2's gate copies are deleted.
3. Location/existence of `core/hooks/tests/stub-check.sh` to run for item 5's
   verification record.
