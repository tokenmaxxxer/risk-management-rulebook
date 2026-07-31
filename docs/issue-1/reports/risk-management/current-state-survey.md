# Issue #1 — Current-State Survey (Phase 1)

Subject: issue-1, role risk-management, branch `issue-1/risk-management`, as
of commit `b9d3f64`.

## What exists today

- `risk-management/hooks/directive.sh` — thin stub over core's
  `core_role_directive` (converted in issue-2/#4). Role payload: `decides`
  = 전사 리스크 노출이 허용 범위인가; `use_when` = 재무/운영/전략 리스크가 걸릴 때; `produces` =
  "ERM verdict, risk register entry, mitigation owner"; `write_scope` = [];
  `hand-off` → legal-compliance; record path
  `docs/issue-<n>/reports/risk-management.md`.
- `risk-management/hooks/record-fields.json` — gate config read by core's
  record-fields gate: `required_fields` = `["erm-verdict",
  "risk-register-entry", "mitigation-owner"]`, `record_path_suffix` =
  `/reports/risk-management.md`, `RECORD_FIELDS_TERMINAL_STATES` = `[]`
  (empty — no terminal loop-state distinction declared).
- No `risk-management/hooks/*-gate.sh` files remain locally (deleted, now
  core-owned per issue-2/#4) — this role has no local gate logic to modify,
  only the directive payload and the record-fields config.
- `README.md` documents the same fields; no separate "methodology" section
  exists anywhere in the repo.
- No prior phase-1 proposal exists for this role (issue-2's proposal was a
  different subject: core-canon reference conversion, not domain
  methodology).

## Gaps relative to this issue's ask

1. **No named methodology.** `produces` says "ERM verdict, risk register
   entry, mitigation owner" but nowhere does the rulebook say ERM under
   *which* framework, or what a "risk register entry" must contain beyond
   its own label.
2. **`required_fields` is a flat 3-item list**, not a schema — no
   likelihood/impact/score fields, no inherent-vs-residual distinction, no
   controls or review-date field. See scout-brief.md gap line.
3. **No phase-1 proposal-writing standard exists yet** for this role — this
   issue is itself the first phase-1 proposal ever written for
   risk-management, so there is no prior-proposal precedent to preserve or
   conflict with (unlike issue-2, which converted existing local copies).
4. **No gate gap**: the record-fields gate mechanism is core-owned and
   already reads this role's config generically; adding new required fields
   is a config-only change (`record-fields.json` + `directive.sh`'s
   `produces` line), not a new gate.

## Write surfaces this proposal must address

- `risk-management/hooks/record-fields.json` (`required_fields`,
  `RECORD_FIELDS_TERMINAL_STATES`) — phase-2 target for methodology-derived
  field additions.
- `risk-management/hooks/directive.sh` (`--produces`, possibly a new
  `--methodology`-shaped flag if `core_role_directive` supports one — not
  confirmed, flagged open item) — phase-2 target for stating the adopted
  methodology in the directive payload itself.
- `README.md` — phase-2 target for documenting the methodology and field
  schema for humans.
- No new gate script needed; core's record-fields gate already enforces
  whatever `required_fields` lists.

## Open items to confirm before phase 2 executes

1. Whether `core_role_directive` (core issue #66/#4's stub) accepts an
   additional flag for stating methodology/framework name, or whether that
   information only belongs in README.md prose — not visible without a core
   checkout in this repo.
2. Whether `RECORD_FIELDS_TERMINAL_STATES` is the right surface for a
   risk-appetite threshold check, or whether that becomes a new field
   inside `required_fields` instead — core's actual gate semantics for this
   key are not visible locally (same gap issue-2's survey flagged).
