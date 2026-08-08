---
code_under_review: README.md, risk-management/hooks/directive.sh, erm-verdict-methodology/hooks/directive-fragment.sh, risk-register-methodology/hooks/directive-fragment.sh
type: doctrine
breaking: false
verdict: pass
loop_state: landed
---

Implements: docs/issue-20/proposals/implementation.md

## What was done

Applied the approved phase-1 proposal (issue #20, single-account
APPROVE issue-20/implementation), with one deviation (see
`## Rationale for deviations`):

1. `docs/specs/record-fields-terminal-states.json` — attempted, then
   reverted; see `## Rationale for deviations` below.
2. `risk-register-methodology/hooks/directive-fragment.sh` — added a
   "Spec field mapping" subsection: the six spec field names mapped onto
   this rulebook's existing field names, plus the explicit
   likelihood/impact enum-vs-free-text tension statement.
3. `erm-verdict-methodology/hooks/directive-fragment.sh` — added one
   cross-reference sentence to the Response stage tying the spec's
   `treatment` field to `mitigation-plan`/`mitigation-owner`.
4. `risk-management/hooks/directive.sh` — re-inlined both fragment
   changes into the composed payload string (mechanical, per the file's
   own point-in-time-copy convention).
5. `README.md` — added the same spec-field-mapping note under "Required
   record schema", and a `loop_state` vocabulary note documenting the
   attempted-and-reverted pin (item 1) with the reproduction.

No methodology content was deleted or renamed; no gate script logic was
touched.

## Why

Per the approved proposal's Rationale: doctrine-only mapping notes close
the acceptance check's grep gaps (only `risk_id`'s underscore spelling
was a genuine gap), without the blast radius of renaming fields every
existing gate and historical record already depends on, and without
silently narrowing the rulebook's prior, reasoned free-text
likelihood/impact convention into a stricter enum.

## Upstream

docs/issue-20/proposals/implementation.md

## Rationale for deviations

**Item 1 (`docs/specs/record-fields-terminal-states.json`) reverted —
mechanically infeasible under core's actual gate, not a design choice.**
The proposal assumed (per its own after-proposal warrant-hunt note) that
the override mechanism was doctrine-only in this repo, with the real
consumer being core canon's generic record-fields gate "vendored outside
this repo." Building the file surfaced that the vendored gate
(`core/hooks/record-fields-gate.sh`) is very much live and load-bearing:
it validates every key in `docs/specs/record-fields-terminal-states.json`
against its own fixed contract §2 kind list (`coding-record`,
`feasibility-record`, `ops-record`, `product-record`, `qa-record`,
`reflect-record`, `review-record`, `ux-design-record`, `verify-record`)
and denies on any unrecognized key. `risk-management` is not one of
those kinds — this rulebook's role has no contract §2 mapping — so
adding it as a key does not just fail to pin the vocabulary, it blocks
*every* Write/Edit to *any* record in the repo (reproduced: writing this
very record was denied the moment the file existed, with the gate's own
error naming `risk-management` as the unrecognized kind). This is worse
than the "no consumer" case the proposal reasoned from — it is an active
regression to repo-wide record-writing. Swapped to: do not create the
file; state the finding in `README.md`'s `loop_state` note instead of
silently dropping the acceptance criterion. Acceptance check 2 ("the
rulebook's `loop_state` vocabulary must match the spec's five-state set
exactly") is therefore not met by a mechanism in this repo — the finding
and its reproduction are the documented "empty state" the issue's
acceptance criteria call for when a field has no clean home, applied
here to the vocabulary-pinning mechanism itself rather than to a single
field.

## Verification run

- `grep -ri 'risk_id\|description\|likelihood\|impact\|treatment\|owner' docs/ README.md` — hits present for every field name, including the new `risk_id` doctrine note (acceptance check 1: met).
- `docs/specs/record-fields-terminal-states.json`: attempted; `Write` was denied by `core/hooks/record-fields-gate.sh` with "names unrecognized kind 'risk-management' (not one of contract §2's record kinds: ...)" — reproduced, file not created (acceptance check 2: not met by a mechanism in this repo; see deviation above).
- `bash erm-verdict-methodology/hooks/tests/run-gate-tests.sh` — 24 passed, 0 failed.
- `bash risk-register-methodology/hooks/tests/run-gate-tests.sh` — 24 passed, 0 failed.
- `bash phase1-proposal-norms/hooks/tests/run-gate-tests.sh` — 19 passed, 0 failed.
- `bash phase2-record-norms/hooks/tests/run-gate-tests.sh` — 18 passed, 0 failed.
  (acceptance check 3: met — no top-level `pytest`/`tests/*.sh`; per-plugin suites are the rulebook's test suite and all pass unchanged.)
- Manual review: `risk_id`/`owner` reference-resolution and the
  treatment/owner recomputation rule are documented as deferred
  elsewhere (both fragment files and directive.sh); the
  likelihood/impact enum-vs-free-text tension is stated explicitly, not
  silently resolved; the loop_state-pinning infeasibility is stated
  explicitly, not silently dropped (acceptance check's "empty state"
  requirement: met).

## What did not work

- Wrote `docs/specs/record-fields-terminal-states.json` with key
  `risk-management` per the proposal's `## What will be done` item 1 →
  the very next `Write` (this record) was denied by
  `core/hooks/record-fields-gate.sh`: `risk-management` is not one of
  contract §2's fixed record kinds, and the gate fails closed on any
  unrecognized key across the whole repo, not just the offending kind's
  own records. Reverted (file removed) before proceeding; see
  `## Rationale for deviations`.

## Open findings

None (the loop_state-pinning gap above is a documented deviation with a
stated resolution path, not an open finding — see next steps).

## Next steps

Acceptance check 2 remains unmet by any mechanism available in this
repo today. Closing it would need either (a) a contract §2 change
upstream (core) adding a generic/`role-defined` kind the fixed list
accepts, or (b) mapping `risk-management` onto one of the nine existing
kinds if one is judged close enough (none obviously fits: this role
produces ERM verdicts and risk-register entries, not code/ops/product/
qa/ux artifacts). Either is a decision for a future issue, not this one.

## Before-landing hunt

Stance 3 (state nothing maintains), `docs/reports/2026-08-09-hunt-issue-20-implementation.md`:
flagged that `on-the-record/hooks/role-spec-reference-guard.sh` and
`roles/specs/risk-management.spec.json` don't exist in this repo. Not a
defect: both live in the external marketplace/on-the-record system this
repo's realized spec comes from, not in this rulebook — the proposal's
own `## Out of scope` already states plainly that reference-resolution
is "the spec assigns that to `on-the-record/hooks/role-spec-
reference-guard.sh`", i.e. deliberately not built here. No code change
made in response.

## Resolution path

File a follow-up issue against core (or this repo, scoped to a role→kind
mapping decision) proposing how `risk-management`-kind records should
pin `loop_state`, once a contract §2-recognized kind or extension point
exists for domain-specific rulebook roles.
