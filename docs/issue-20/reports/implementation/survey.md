# Current-state survey — issue-20

Scope: what already exists in this rulebook that the realized marketplace
spec `roles/specs/risk-management.spec.json` needs to be layered onto.
This is a scout/current-state pass, not the proposal itself.

## The spec (verbatim facts used below)

- `required_fields`: `risk_id` (ref), `description` (string), `likelihood`
  (enum: low/medium/high), `impact` (enum: low/medium/high), `treatment`
  (string), `owner` (ref).
- `reference_resolution.rule`: `owner` must resolve to a real person/role,
  `risk_id` to a real registered risk-register entry — no orphan refs
  (issue-515 invariant 2). `checked_by`:
  `on-the-record/hooks/role-spec-reference-guard.sh`.
- `recomputation.rule`: every registered `risk_id` needs a treatment/owner
  pair before a terminal `loop_state`. `checked_by`: `TBD (follow-up —
  issue-521 out-of-scope note)`.
- `write_scope`: `docs/issue-<n>/reports/risk-management.md`.
- `loop_state`: progress `[registering, treating]`, terminal `[landed]`,
  refusal `[treatment-undeclared]`, error `[risk-unreachable]`.

## What this rulebook already has

Two facet plugins govern this role's PRODUCES (README.md, "Plugin set
(issue-7)" table):

- `erm-verdict-methodology` — ISO 31000:2018 process-clause shape
  (`## Governance/context` → `## Assessment` → `## Risk treatment` →
  `## Monitoring and review`), gated by `hooks/erm-order-gate.sh`.
- `risk-register-methodology` — ISO 31000 12-field register schema
  (`risk-id`, `risk-description`, `risk-category`, `likelihood`, `impact`,
  `risk-score-inherent`, `existing-controls`, `risk-score-residual`,
  `risk-appetite-threshold`, `mitigation-owner`, `mitigation-plan`,
  `review-date`), gated by `hooks/register-fields-gate.sh` and declared
  again (presence-only) in `risk-management/hooks/record-fields.json`.

`risk-management/hooks/directive.sh` is a point-in-time inlined copy of
both fragments' text (issue-171 reshape note in the file's own header
comment: the checker's stub form allows only one `core_role_directive`
call line, so the fragments are no longer live-sourced at runtime) —
editing the fragments alone does not change what a session sees; both
need editing to stay in sync, matching how issue-7's plugin-set was
originally composed.

## Field-by-field gap check

Grepped `docs/` and `README.md` case-insensitively for each spec field
name, literally as spelled in the spec:

| spec field | already present? | where | gap |
|---|---|---|---|
| `risk_id` (underscore) | **no** | only `risk-id` (hyphen) exists everywhere (record-fields.json, both gates, both handbooks, `README.md`'s 12-field table) | grep for the literal spec spelling `risk_id` finds nothing — a real gap even though the hyphenated rulebook field already covers the same concept |
| `description` | yes | substring of `risk-description` (12-field table, both fragments, both gates) | none |
| `likelihood` | yes | used verbatim as a field name throughout (both facets) | value shape differs: spec makes it an enum (`low/medium/high`); this rulebook's doctrine (`docs/handbooks/risk-register-methodology.md`, "Why fields stay qualitative-or-numeric free text") deliberately keeps it free text, reasoned from a repo-wide scale search that found no canon-wide matrix (issue-7 round-2, open item 5) |
| `impact` | yes | same as `likelihood` | same free-text-vs-enum gap as `likelihood` |
| `treatment` | yes | already present as prose ("risk treatment", ISO 31000 §6.5 clause name, the `## Risk treatment` heading, "treatment action(s)" in the 12-field table's `mitigation-plan` row) | the rulebook's *field* for this concept is named `mitigation-plan`, not `treatment` — the spec's field name and the rulebook's field name diverge even though the grep already passes on the word "treatment" appearing elsewhere |
| `owner` | yes | substring of `mitigation-owner` | none |

Net: one literal-spelling gap (`risk_id`), one field-name mapping to state
explicitly (`treatment` → `mitigation-plan`), and one value-shape tension
to resolve in the proposal's Rationale (`likelihood`/`impact` enum vs. the
rulebook's deliberate free-text convention).

## `loop_state` vocabulary — current state

`risk-management/hooks/record-fields.json`'s `RECORD_FIELDS_TERMINAL_STATES`
is `[]` — empty. No `docs/specs/record-fields-terminal-states.json` exists
in this repo (checked: `find . -iname record-fields-terminal-states.json`,
no hit). Every existing phase-2 record under `docs/issue-*/reports/
risk-management.md` uses `loop_state: landed` ad hoc (issue-1, issue-7,
issue-10, issue-13's reports), with no declared vocabulary backing that
choice — `docs/issue-2/reports/implementation/current-state-survey.md`
line 119 independently confirms: "no role that has a genuine loop_state
difference from other roles" existed as of issue-2. This rulebook
currently inherits whatever generic default core's canon carries; the
spec's five-state set (`landed`, `registering`, `risk-unreachable`,
`treating`, `treatment-undeclared`) is role-specific vocabulary core's
generic default cannot know about.

## Sibling precedent (api-design-rulebook, issue-17)

`api-design-rulebook`'s issue-17 (same shape of task — aligning a rulebook
to its own realized `api-design.spec.json`) is directly comparable and
already landed as a proposal at
`docs/issue-17/proposals/api-design.md` in that sibling repo. Its pattern,
reused here:

- Field names with no natural gate-worthy home (there: `verdict`;
  reference-resolution/recomputation fields spec assigns elsewhere: there,
  `spectral_ruleset_id`) get doctrine-only mentions, not new gates — the
  spec's own `checked_by`/`TBD` fields already assign that responsibility
  outside this rulebook.
- The five-state `loop_state` vocabulary is pinned via a new
  `docs/specs/record-fields-terminal-states.json`, keyed by the role name,
  in the same nested `{progress, terminal, refusal, error}` shape the spec
  itself uses (not a flat list) — matching how `content-design-rulebook`
  and `api-design-rulebook` both already do this.
- No existing gate, PRODUCES facet, or handbook section gets deleted;
  spec fields attach as additive doctrine and (where already gate-enforced
  under a different literal name) an explicit field-name-mapping note.

That precedent's reference-resolution/recomputation deferral reasoning
(a `PreToolUse` hook has no GitHub/on-the-record API access to verify a
cross-repo reference or a recomputation event) applies unchanged to this
spec's identical `checked_by: on-the-record/hooks/role-
spec-reference-guard.sh` and `checked_by: TBD (follow-up)` lines.

## Gates: do any need behavior changes?

`hooks/erm-order-gate.sh` and `hooks/register-fields-gate.sh` already
enforce presence for every concept the spec's six fields name (via their
hyphenated rulebook equivalents) except the literal spelling `risk_id`,
which is a doctrine/grep gap, not an enforcement gap — no gate currently
fails to catch a record missing an `owner`/`treatment`/`likelihood`/
`impact`/`description`/`risk_id`-equivalent value. Changing gate
*enforcement* to require the enum `low/medium/high` for `likelihood`/
`impact` would be a behavior change to existing methodology (the
deliberately free-text convention), not an additive strengthening —
flagged for the proposal's Rationale to decide explicitly rather than
silently drop or silently apply.
