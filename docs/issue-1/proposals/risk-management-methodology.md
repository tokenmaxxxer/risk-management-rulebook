# Proposal: risk-management rulebook methodology norms

Subject: issue-1

Status: Phase 1 proposal — for review only. **APPROVE is out of scope for
this PR; phase 2 (plugin enforcement) opens only after an approvers.md
account approves per contract v3 s19.**

See `docs/issue-1/reports/risk-management/current-state-survey.md` for
current-state findings and
`docs/issue-1/reports/risk-management/scout-brief.md` for the domain sweep
this proposal is based on.

## Scouting

Ran: 4 parallel WebSearch angles (COSO ERM, ISO 31000 register fields, risk
appetite/heat-map methodology, risk register ownership/tracking practice),
1 sweep round. Judge point 1 showed strong cross-source convergence, so no
further deepening round was run (saturation rule). See scout-brief.md for
full findings, adopt/skip reasoning, and sources.

## (a) Phase-1 proposal norm

**Methodology**: this document itself is the template. Every future
phase-1 proposal for `risk-management` must:

1. Run (or explicitly skip-with-reason, per scout-directive) a domain
   scouting pass before proposing, and cite sources for any claimed
   industry practice — no unsourced "best practice" assertions.
2. State a **current-state survey** first (what exists, what's missing) —
   proposals may not invent gaps without checking the actual repo state.
3. State the adopted methodology **by name** with a one-line reason it fits
   this role's `decides`/`use_when` (전사 리스크 노출이 허용 범위인가 /
   재무·운영·전략 리스크, broader than feasibility — this is an enterprise-scope
   role, which is the logical reason COSO ERM and ISO 31000, both
   enterprise/organizational standards rather than project-risk tools, are
   the right fit and e.g. a project-risk-only framework would not be).
4. List required record fields as a concrete schema (field name + what it
   captures), not prose.
5. State a plugin reflection plan: which files change, which don't, and
   why (config vs. gate vs. directive payload) — mirrors this proposal's
   own "Plugin reflection plan" section below.

**Required sections** (in order): Scouting, Summary, Adopted methodology +
rationale, Required record schema, Plugin reflection plan, Open items.

## (b) Phase-2 deliverable norm

**Methodology, adopted**: a two-standard pairing, not a single framework.

- **COSO ERM (2017), 5-component structure** governs the *shape of the ERM
  verdict itself* — the judgment must be traceable through
  governance/context → objective linkage → assessment → response →
  monitoring, i.e. an `erm-verdict` cannot be a bare accept/reject; it must
  show which objective is at risk and what response tier follows.
- **ISO 31000's process + risk register minimum field set** governs the
  *risk-register-entry artifact* — the concrete, auditable record.

Both are enterprise/organizational-scope standards (not project-only tools
like a PMBOK risk register), matching this role's stated scope
(`decides`/`use_when`) as surveyed above — that is the logical reason this
pairing was chosen over alternatives, not an arbitrary pick from the field.

### Required record schema (risk-register-entry)

Per scout-brief's converged must-bes, each `risk-register-entry` must
carry, at minimum:

| Field | Captures |
|---|---|
| `risk-id` | stable identifier for cross-reference across records |
| `risk-description` | what could happen, in plain language |
| `risk-category` | e.g. strategic/operational/financial/regulatory |
| `likelihood` | qualitative or numeric likelihood rating |
| `impact` | qualitative or numeric impact rating |
| `risk-score-inherent` | likelihood x impact, before controls |
| `existing-controls` | controls currently in place, if any |
| `risk-score-residual` | likelihood x impact, after existing controls |
| `risk-appetite-threshold` | the appetite level the residual score is judged against |
| `mitigation-owner` | named accountable person (already required) |
| `mitigation-plan` | the treatment action(s) |
| `review-date` | next scheduled re-assessment |

`erm-verdict` and `mitigation-owner` remain required top-level fields as
today; the table above is the *expansion* of `risk-register-entry` from an
opaque blob into a schema.

## (c) Rationale for each adoption

- **COSO ERM over a narrower risk-only standard**: COSO explicitly frames
  risk in terms of strategy/objective linkage, which matches this role's
  `decides` line (허용 범위 판단 is an objective-linkage question, not a
  standalone risk score) — see scout-brief.
- **ISO 31000 for the register over inventing a bespoke field set**: the
  minimum-field convergence across four independent industry sources
  (SureCloud, Rocketlane, Optial, TrustCloud, all in scout-brief) means this
  is not one vendor's opinion; adopting it avoids the role inventing a
  weaker ad hoc register.
- **Inherent vs. residual dual scoring**: adopted because every strong
  source treats a single "current risk level" number as a known failure
  mode that hides whether controls are real — cheap to require, closes a
  real gap.
- **Appetite threshold as an explicit field, not prose**: GARP and
  MetricStream (scout-brief) both flag appetite stated once and never
  checked against live scores as the standard failure mode; making it a
  field forces every verdict to show the check happened.
- **Skip quantitative/actuarial modeling (VaR, Monte Carlo)**: no source
  treated this as baseline practice for a general ERM verdict; it's a
  specialized addition for specific risk types, out of scope for this
  role's general-purpose record.
- **Skip heat-map visualization tooling**: this role produces
  markdown/text records, not a dashboard; the heat-map's *decision logic*
  (score vs. appetite triggers a response tier) is captured via the
  `risk-score-residual` + `risk-appetite-threshold` fields instead.

## (d) Plugin reflection plan

Concrete, phase-2-only (no files change in this PR):

1. **`risk-management/hooks/record-fields.json`**: expand `required_fields`
   from the current 3-item flat list to include the schema fields above
   (`risk-id`, `risk-description`, `risk-category`, `likelihood`, `impact`,
   `risk-score-inherent`, `existing-controls`, `risk-score-residual`,
   `risk-appetite-threshold`, `mitigation-plan`, `review-date`), alongside
   the existing `erm-verdict` and `mitigation-owner`. Exact key naming to
   be finalized against whatever validation shape core's record-fields gate
   actually expects (see open item 2 below) — this proposal fixes the
   *field set*, not necessarily the exact JSON key strings if core's gate
   requires a different shape (e.g. nested schema vs. flat list).
2. **`risk-management/hooks/directive.sh`**: update the `--produces` value
   to name the methodology explicitly, e.g. "ERM verdict (COSO ERM
   5-component judgment), risk register entry (ISO 31000 schema — see
   README), mitigation owner" — so the directive text itself states which
   standards are in force, not just field names.
3. **`README.md`**: add a "Methodology" section documenting the COSO
   ERM + ISO 31000 pairing, the rationale above (condensed), and the full
   register schema table, so a human reading the repo sees the same norm
   the gate enforces.
4. **No new gate script**: core's record-fields gate (core issue #66,
   referenced via issue-2/#4) already reads `required_fields` generically;
   expanding the field list is a config-only change under the existing
   mechanism, not new gate logic.
5. **`RECORD_FIELDS_TERMINAL_STATES`**: left `[]` unless phase-2
   investigation of core's actual gate semantics shows this role needs a
   terminal loop-state distinction (e.g. "risk accepted with standing
   appetite exception" vs. "risk closed") — not decided here; flagged as
   open item.

## Open items to confirm before phase 2 executes

1. Whether `core_role_directive`'s actual signature accepts a distinct
   methodology-naming argument or whether that only lives in the
   `--produces` string and README prose (not visible without a core
   checkout in this repo — same class of gap issue-2's survey flagged).
2. Whether core's record-fields gate validates `required_fields` as a flat
   key-presence check (current 3-field shape suggests yes) or supports
   nested/typed schemas — determines whether the 12-field table above maps
   1:1 onto `required_fields` entries or needs restructuring.
3. Whether `RECORD_FIELDS_TERMINAL_STATES` should carry a
   "risk-appetite-exception" terminal state — deferred to phase 2 once
   core's gate semantics for this key are confirmed.

All of the above (record-fields.json edits, directive.sh edits, README
edits) begin only after an `approvers.md`-listed account posts `APPROVE
issue-1/risk-management` (single-account mode) or a PR review Approve
(two-account mode), per contract v3 s19.
