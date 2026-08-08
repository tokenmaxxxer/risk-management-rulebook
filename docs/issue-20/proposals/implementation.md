---
status: proposed
files:
  - README.md
  - risk-management/hooks/directive.sh
  - erm-verdict-methodology/hooks/directive-fragment.sh
  - risk-register-methodology/hooks/directive-fragment.sh
  - docs/specs/record-fields-terminal-states.json
---

Status: Phase 1 proposal for issue #20. APPROVE is out of scope for this
document — it proposes; it does not implement.

## Request

Layer the realized marketplace `risk-management.spec.json`'s six required
deliverable fields (`risk_id`, `description`, `likelihood`, `impact`,
`treatment`, `owner`) and its `loop_state` vocabulary (`landed`,
`registering`, `risk-unreachable`, `treating`, `treatment-undeclared`)
onto this rulebook's methodology docs and hooks — strengthening the two
existing PRODUCES facets (`erm-verdict-methodology`,
`risk-register-methodology`), never deleting or replacing their content.
Per `docs/issue-20/reports/implementation/survey.md`.

## Constraints

- Every one of the six spec field names must appear (grep -i, substring
  match) in `docs/` or `README.md` after phase 2 (acceptance check 1) —
  the survey found five already do via their hyphenated rulebook
  equivalents (`risk-id`→wait, no: `risk-id` does **not** match the
  literal spec spelling `risk_id`; `risk-description` matches
  `description`; `likelihood`/`impact` match verbatim; `mitigation-owner`
  matches `owner`; "treatment" already appears in prose even though the
  rulebook's field for that concept is named `mitigation-plan`). Only
  `risk_id` (the underscore spelling) is a genuine grep gap.
- The rulebook's `loop_state` vocabulary must match the spec's five-state
  set exactly, no stale or extra states (acceptance check 2) — currently
  unpinned (`RECORD_FIELDS_TERMINAL_STATES: []`, no
  `docs/specs/record-fields-terminal-states.json`).
- `risk_id`'s and `owner`'s reference-resolution, and the treatment/owner
  recomputation-before-terminal rule, are each explicitly assigned
  elsewhere by the spec itself (`on-the-record/hooks/role-spec-
  reference-guard.sh`, and a stated `TBD` follow-up respectively) — this
  rulebook adopts the vocabulary and field-presence expectation only; it
  does not re-implement resolution or recomputation enforcement that
  belongs to another system.
- No methodology content gets deleted: both existing PRODUCES facets
  (erm-verdict five-stage ISO 31000 shape, the 12-field register schema)
  stay exactly as documented; the spec's fields attach to them via
  doctrine, they don't replace any existing field, heading, or gate
  check.
- `risk-management/hooks/directive.sh` is a point-in-time inlined copy of
  both sibling fragments (issue-171 reshape note), not a live source —
  any text change made to a fragment must be mirrored into `directive.sh`
  in the same commit or the SessionStart-visible text drifts from the
  fragment source.

## Rationale

**`risk_id` (spelling gap) → doctrine-only mapping note, no field
rename.** Considered renaming the rulebook's `risk-id` field to the
spec's `risk_id` spelling everywhere (gates, record-fields.json, both
handbooks) to close the grep gap structurally. Rejected: every existing
gate (`register-fields-gate.sh`'s regex-driven `field_value()` lookups,
`record-fields.json`'s presence list) is written against the hyphenated
spelling, and this repo's own Markdown convention uses hyphenated
`field-name: value` lines throughout (12-field table, both directive
fragments) — a rename would touch every gate and every historical
record's expected shape for a purely cosmetic spelling difference the
spec itself doesn't require (the spec's field `type` is `ref`; it says
nothing about a mandatory hyphen-vs-underscore literal spelling in the
*rulebook's own* records). A short doctrine note stating the mapping
(`risk_id` (spec) ↔ `risk-id` (this rulebook's field)) closes the grep
gap without a rename's blast radius.

**`treatment` (name gap) → doctrine-only mapping note, no field
rename.** Considered renaming `mitigation-plan` to `treatment` throughout
for the same literal-alignment reason. Rejected for the same reason as
`risk_id`: `mitigation-plan` is the field name every existing gate
enforces (`register-fields-gate.sh`'s `REQUIRED_FIELDS` list,
`erm-order-gate.sh`'s Response-stage prose, `record-fields.json`), and the
grep acceptance check already passes today via the word "treatment"
appearing in surrounding prose (the ISO 31000 §6.5 clause name, the `##
Risk treatment` heading, the 12-field table's own description text) —
there is no acceptance-check gap to close by renaming, only a
same-concept-different-label gap worth stating explicitly so a reader
mapping the spec to this rulebook doesn't have to infer it.

**`likelihood`/`impact` enum (low/medium/high) → doctrine note only, gate
enforcement stays free-text.** Considered tightening
`register-fields-gate.sh` and `erm-order-gate.sh` to reject any
`likelihood`/`impact` value outside `{low, medium, high}`, matching the
spec's `enum` type exactly. Rejected: this rulebook's free-text
convention for these two fields is not an oversight — it's a stated,
reasoned decision (`docs/handbooks/risk-register-methodology.md`, "Why
fields stay qualitative-or-numeric free text": a repo-wide search across
`core/`, `implementation-rulebook/`, `pricing-rulebook/` found no
canon-wide likelihood/impact scale, so this plugin declined to invent one
unilaterally). Issue #20 itself says to strengthen existing content,
never delete it — silently narrowing an already-landed, explicitly
reasoned free-text convention down to a three-value enum in the same
proposal that claims to only be adding vocabulary would contradict that
instruction, not honor it. The doctrine note instead states plainly that
`low`/`medium`/`high` values satisfy both the spec's enum and this
rulebook's existing free-text gate (a subset relationship, not a
conflict), while non-enum qualitative/numeric values continue to satisfy
this rulebook's own gate without satisfying the spec's stricter typing —
naming that gap explicitly rather than silently resolving it, per the
acceptance criteria's "empty state" instruction (a field with no clean
single home gets its tension stated, not silently dropped or silently
forced).

**`loop_state` vocabulary → new `docs/specs/record-fields-terminal-
states.json`, following `api-design-rulebook`'s issue-17 precedent.**
Considered leaving `loop_state` unpinned (inheriting core canon's generic
default) since this repo currently has no override file. Rejected: the
spec's five-state set is role-specific vocabulary a generic default
cannot express, and the override mechanism — a per-repo
`docs/specs/record-fields-terminal-states.json`, keyed by role/kind name
— already exists precisely for this case (confirmed live in
`content-design-rulebook` and `api-design-rulebook`, both using the same
nested `{progress, terminal, refusal, error}` shape the spec itself
uses, not a flat list). Also considered writing the vocabulary into
`risk-management/hooks/record-fields.json`'s own
`RECORD_FIELDS_TERMINAL_STATES` array instead of a new top-level file.
Rejected: that field is currently an empty flat array with no declared
consumer contract in this repo distinguishing progress/terminal/refusal/
error, whereas the dedicated `docs/specs/` file already has a working,
canon-recognized shape in two sibling repos — reusing the proven
mechanism over inventing a second one in a role-local file avoids two
loop_state sources of truth disagreeing later. Note (warrant-hunt,
after-proposal, stance 3, `docs/reports/2026-08-09-hunt-issue-20-
implementation.md`): no hook script in this repo — including every file
in this proposal's own frozen write set — reads `loop_state`,
`docs/specs/`, or a `{progress, terminal, refusal, error}` shape; the
consumer is core canon's generic record-fields gate, vendored outside
this repo, not anything local. This file is doctrine-only from this
repo's own perspective, matching the same gap in `content-design-
rulebook` and `api-design-rulebook`'s identical files — stated here
explicitly rather than left implicit, per the hunt finding.

## What will be done

1. `docs/specs/record-fields-terminal-states.json` (new file): add the
   `risk-management` kind's `loop_state` override, matching the spec's
   set exactly:
   `{"risk-management": {"progress": ["registering", "treating"],
   "terminal": ["landed"], "refusal": ["treatment-undeclared"], "error":
   ["risk-unreachable"]}}`.
2. `risk-register-methodology/hooks/directive-fragment.sh`: add a short
   paragraph after the existing 12-field bullet list mapping the spec's
   field names onto this rulebook's field names — `risk_id`↔`risk-id`,
   `description`↔`risk-description`, `treatment`↔`mitigation-plan`,
   `owner`↔`mitigation-owner` — and stating that `low`/`medium`/`high`
   values for `likelihood`/`impact` satisfy both this rulebook's existing
   free-text gate and the spec's stricter enum, while other qualitative/
   numeric values remain valid here but would not satisfy the spec's
   typing (the explicit "empty state" statement for the enum tension).
   Note `risk_id`/`owner` reference-resolution is checked by
   `on-the-record/hooks/role-spec-reference-guard.sh`, not this
   rulebook, and the treatment/owner-before-terminal recomputation rule
   is the spec's own stated `TBD` follow-up.
3. `erm-verdict-methodology/hooks/directive-fragment.sh`: add one
   sentence to the existing "Response" stage paragraph cross-referencing
   that the spec's `treatment` field maps to this stage's
   `mitigation-plan`/`mitigation-owner` content, so the mapping is
   visible from both facets, not only the register one.
4. `risk-management/hooks/directive.sh`: re-inline the updated composed
   text from both fragments (per the file's own "point-in-time inlined
   copy" convention — this is a mechanical re-generation of the existing
   single `core_role_directive` call's payload string, not new prose).
5. `README.md`: add the same spec-field-mapping note to the "Required
   record schema (risk-register-entry)" section (short paragraph after
   the existing 12-field table), and add a short "`loop_state`
   vocabulary" note pointing at the new
   `docs/specs/record-fields-terminal-states.json` file.

## Out of scope

- Renaming any existing field (`risk-id`, `mitigation-plan`,
  `mitigation-owner`, etc.) to match the spec's literal spelling —
  doctrine mapping notes close the grep/readability gap without the
  blast radius of touching every gate and historical record shape.
- Tightening `register-fields-gate.sh` or `erm-order-gate.sh` to reject
  non-enum `likelihood`/`impact` values — this rulebook's free-text
  convention is a prior, reasoned decision this issue does not ask to be
  revisited, and issue #20 explicitly says to strengthen, never delete,
  existing methodology.
- Building a `risk_id`/`owner` reference-resolution gate in this repo —
  the spec assigns that to `on-the-record/hooks/role-spec-
  reference-guard.sh`.
- Building the treatment/owner-before-terminal recomputation mechanism —
  the spec marks its `checked_by` as `TBD (follow-up)` itself.
- Any change to `phase1-proposal-norms` or `phase2-record-norms` (the two
  role-agnostic process-shape plugins) — none of the six spec fields or
  the loop_state vocabulary is a process-shape concern.

## How you'll know it worked

- `grep -ri 'risk_id\|description\|likelihood\|impact\|treatment\|owner' docs/ README.md`
  returns at least one hit per field name (acceptance check 1) — `risk_id`
  specifically needs the new doctrine note; the other five already pass
  today and stay passing.
- The only `loop_state` vocabulary present in
  `docs/specs/record-fields-terminal-states.json` for the
  `risk-management` kind is exactly `{landed, registering,
  risk-unreachable, treating, treatment-undeclared}` — no stale or extra
  states (acceptance check 2).
- `bash erm-verdict-methodology/hooks/tests/run-gate-tests.sh`,
  `bash risk-register-methodology/hooks/tests/run-gate-tests.sh`,
  `bash phase1-proposal-norms/hooks/tests/run-gate-tests.sh`, and
  `bash phase2-record-norms/hooks/tests/run-gate-tests.sh` (this
  rulebook's test suite — no top-level `pytest`/`tests/*.sh` exists, so
  per-plugin `hooks/tests/run-gate-tests.sh` is the suite) all still pass
  unchanged, since no gate script's logic is touched by this proposal
  (acceptance check 3).
- Manual review confirms `risk_id`/`owner` reference-resolution and the
  treatment/owner recomputation rule are each documented as
  deferred-elsewhere, with the reasoning stated in this proposal's
  Rationale section, and the `likelihood`/`impact` enum-vs-free-text
  tension is stated explicitly rather than silently resolved or dropped
  (acceptance check's "empty state" requirement).
