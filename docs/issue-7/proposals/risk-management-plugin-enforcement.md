# Proposal: risk-management methodology enforcement (hook-machine level)

Subject: issue-7

Status: Phase 1 proposal — for review only. **APPROVE is out of scope for
this PR; phase 2 (enforcement implementation) opens only after an
`approvers.md` account approves per contract v3 s19.** This document
proposes; it contains no `src/`/`test/` implementation.

See `docs/issue-7/reports/risk-management/survey.md` for current-state
findings and `docs/issue-7/reports/risk-management/scout-brief.md` for the
hook-machine pattern sweep this proposal adapts from.

**Canon-reference-only, restated up front**: nothing below vendors a copy
of `core/hooks/*`, `implementation-rulebook/coding/hooks/*`, or
`pricing-rulebook/pricing/hooks/*`. Every mechanism proposed is a new
file owned by this rulebook, whose comments cite the sibling files it
adapted structure from by path — never their literal script bodies.
`core/hooks/lib/role-directive.sh` and core's generic record-fields gate
remain referenced through the existing plugin-root mechanism, unchanged.

## 1. Deepened directive design

Today `risk-management/hooks/directive.sh` calls `core_role_directive`
with five flat strings (`--decides`, `--use-when`, `--produces`,
`--write-scope`, `--hand-off`), the `--produces` value being one
sentence naming COSO ERM/ISO 31000 in passing. Per issue #7 point 1, this
must become **facet-level, executable directives** — mirroring how
`implementation-rulebook/coding/hooks/directive.sh` builds four
multi-paragraph shell variables (`YOU_DECIDE`, `USE_WHEN`, `PRODUCES`,
`HAND_OFF`), each enumerating concrete stages/criteria/prohibitions
rather than a summary line, structurally adapted (not copied) to
risk-management's own two facets:

### Facet A — ERM verdict (COSO ERM 5-component shape)

Proposed `PRODUCES` content, structured as **stages with judgment
criteria and explicit prohibitions**, one line each so the phase-2 gate
(section 2) can check for their markers mechanically:

1. **Governance/context** stage — state which objective(s) the risk
   attaches to and under what risk-appetite policy the verdict will be
   judged. *Prohibition*: no verdict may open directly with a
   likelihood/impact number before this stage is stated — an
   `erm-verdict` that starts at "risk score: 12" with no objective named
   is a bare accept/reject, which issue-1's proposal explicitly rejects.
2. **Objective linkage** stage — name which specific business
   objective(s) are at risk and how (COSO's defining feature vs. a
   standalone risk-only framework). *Judgment criterion*: the objective
   named must be one recognizable as a scoped goal (revenue, uptime,
   regulatory standing, etc.), not a restatement of the risk itself.
3. **Assessment** stage — likelihood, impact, inherent score, existing
   controls, residual score, appetite threshold (the ISO 31000 register
   fields already required by `record-fields.json`, cross-linked here so
   the directive text and the config agree). *Prohibition*: inherent and
   residual must be two distinct numbers/ratings — a single "current risk
   level" collapses the two and is the specific failure mode issue-1's
   scout-brief flagged as a known anti-pattern.
4. **Response** stage — state the response tier that follows from
   residual-vs-appetite (accept / mitigate / transfer / avoid, standard
   ISO 31000 vocabulary) and name the mitigation owner + plan.
   *Judgment criterion*: the response tier stated must be consistent with
   the residual-vs-appetite comparison (e.g. residual > appetite cannot
   pair with "accept" silently — a mismatch is a proposal-time judgment
   call the directive should name explicitly, even if the phase-2 gate
   only checks presence, not the tier-consistency judgment itself, per
   the "what a machine check can verify" line drawn in section 2).
5. **Monitoring** stage — state the review/due date and what would
   trigger re-assessment before that date. *Prohibition*: "review-date:
   TBD" or equivalent non-committal placeholder does not satisfy this
   stage.

### Facet B — risk-register-entry (ISO 31000 schema)

Proposed directive content: the 12-field schema already in
`record-fields.json`/README, restated in the directive itself as
**per-field judgment criteria**, not just a name list — e.g.
`risk-category` must be one of the four named categories
(strategic/operational/financial/regulatory) or an explicitly justified
addition, not free text; `mitigation-owner` must be a named person/role,
not "TBD" or a team name with no individual accountable (mirrors
scout-brief's "risks without a clearly accountable person rarely move
forward" finding).

### Executable-level statement (what "executable-level per facet" means here)

Each stage/field above is written so it maps 1:1 to a **grep-able marker**
in the resulting document text (a heading, a labeled line, or a
recognizable phrase) — this is the property the phase-2 gate depends on;
a directive written as free prose with no stable markers cannot be
mechanically checked. The directive text itself should state the marker
convention (e.g. `## Governance/context`, `## Objective linkage`, etc. as
section headings in the `erm-verdict` write) so the gate and the human
author are reading the same contract.

## 2. Methodology gate design

New file: `risk-management/hooks/methodology-gate.sh`, registered as a
`PreToolUse` hook (`Write|Edit|MultiEdit`) in
`risk-management/hooks/hooks.json`, additive to (never replacing) core's
existing generic record-fields gate — same relationship
`pricing-rulebook/pricing/hooks/methodology-gate.sh`'s own header comment
states for its role ("on top of, never instead of, the core canon
record-fields-gate.sh's generic §20 fields").

Structure, adapted from `pricing-rulebook/pricing/hooks/methodology-
gate.sh` and `implementation-rulebook/coding/hooks/coding-progress-
gate.sh` (both cited by path in the new script's own header comment, not
copied):

1. **Fail-closed trap at top**, before any `set`/`source`, identical
   idiom to both source scripts (`trap __fc EXIT` mapping any
   non-0/non-2 exit to 2).
2. **Dependency + root-discovery checks**, fail closed exactly as both
   source scripts do (`python3`/`git` presence, `CLAUDE_PROJECT_DIR` or
   `git rev-parse --show-toplevel`).
3. **Scope regex**, targeting this role's own write surfaces:
   - `^docs/issue-[0-9]+/proposals/.*risk-management.*\.md$` (phase-1
     proposals)
   - `^docs/issue-[0-9]+/reports/risk-management\.md$` (phase-2 record,
     matching `record_path_suffix` in `record-fields.json`)
   Any other write exits 0 immediately (not this gate's business).
4. **Resulting-content reconstruction** for Write/Edit/MultiEdit,
   denying rather than guessing when the new text can't be determined —
   identical approach to `methodology-gate.sh` L129-159.
5. **Per-element checks**, each individually named in the deny message
   and traceable to the directive/README norm it enforces:
   - Facet A stage markers present (governance/context, objective
     linkage, assessment, response, monitoring — see section 1) *in that
     order* within the `erm-verdict` content. Order matters here (COSO's
     defining property is traceability through the sequence), so the
     check is not just "all five headings present" but "each later
     heading's first occurrence comes after the earlier one's" — a
     structural check a regex + position-comparison can do without any
     semantic judgment of content quality.
   - Inherent and residual scores both present **and distinct fields**
     (not the same value reused) — checked by requiring both
     `risk-score-inherent` and `risk-score-residual` labels appear with
     values, mirroring the "labeled numbers" check pattern in pricing's
     gate (`has_digits and not labeled` => missing), adapted to require
     two separate labeled numbers rather than one.
   - All 12 `risk-register-entry` fields from `record-fields.json`
     present as labeled lines (this partially overlaps core's generic
     record-fields gate; the overlap is intentional defense-in-depth,
     matching the "additive, never instead of" relationship stated
     above — the new gate additionally checks the COSO *ordering*
     property core's generic gate cannot know about).
   - `mitigation-owner` is not a placeholder token (`TBD`, `unassigned`,
     empty) — same "named owner" judgment scout-brief flagged.
   - `review-date` is not a placeholder token.
6. **Kill switch**: `RISK_MANAGEMENT_METHODOLOGY_GATE_OFF=1`, checked
   before any other logic, matching the per-hook kill-switch convention
   `PRICING_METHODOLOGY_GATE_OFF` establishes (distinct from the
   directive's own `RISK_MANAGEMENT_CYCLE_OFF`, since a `SessionStart`
   directive and a `PreToolUse` gate are independently switchable
   mechanisms in the sibling rulebooks surveyed).

### State tracking — open judgment call, not silently adopted or dropped

Section 1's ordering requirement (governance/context before assessment,
etc.) is a **single-document, position-based** check, not a
cross-write/cross-record ordering — it needs no persistent state file,
unlike implementation-rulebook's cross-record `resolved_findings` +
`loop_state` mechanism (survey.md §3a point 6). Scout-brief's review of
issue-1's adopted methodology found no explicit "investigate → establish
evidence → adopt" multi-step approval flow analogous to what issue #7's
problem statement gestures at generically ("방법론상 순서 제약이 있으면...상태
추적으로 강제") — COSO/ISO 31000 as adopted here describe a document's
internal shape, not a multi-session approval sequence. **Recommendation**:
do not add a state-tracking file in phase 2 unless phase-2 investigation
of `core_role_directive`'s actual behavior (open item 1 from issue-1's
proposal, still unresolved per survey.md) surfaces a genuine multi-step
ordering requirement this proposal missed. If phase 2 finds one, it
should use the same "read `loop_state`-equivalent text out of the record
itself" approach implementation-rulebook uses, rather than inventing a
separate state file format, for consistency with the sibling pattern.

## 3. Gate test plan

New file: `risk-management/hooks/tests/run-gate-tests.sh` (or
repo-root `tests/` if the phase-2 session confirms that's the
convention this repo's board-gate/other gates expect — flagged as an
open item; `implementation-rulebook` keeps its harness at
`<rulebook-root>/tests/run-gate-tests.sh`, a sibling to the role
directories, which is the pattern to mirror by default), using the same
real-subprocess / synthetic-JSON-payload / throwaway-`git init`-repo
harness as `implementation-rulebook/tests/run-gate-tests.sh`.

Positive (allow) cases:
- Full, correctly-ordered `erm-verdict` with all five stage markers in
  order + all 12 register fields present, named owner, real review date
  → allow.
- A write to a path the gate's scope regex doesn't match (e.g.
  `docs/issue-7/reports/qa.md`) → allow (gate is not this write's
  business — mirrors `run-gate-tests.sh`'s `foreign-path` case).
- An `Edit` whose `old_string` is found and content reconstruction
  succeeds, resulting text satisfies all checks → allow.

Negative (deny) cases:
- Stage markers present but out of order (e.g. "Response" heading occurs
  before "Assessment") → deny naming the ordering violation specifically.
- Missing one specific stage marker (test each of the five separately, to
  confirm the deny message names the *specific* missing stage, not a
  generic "incomplete" message) → deny.
- `risk-score-inherent` and `risk-score-residual` both present with the
  identical value string reused (a proxy for "not actually distinct") →
  deny (or: flagged as a docs-only recommendation if a machine check
  cannot reliably distinguish "genuinely recomputed same number by
  coincidence" from "copy-pasted" — this distinction is called out
  explicitly as a limit of what this gate can verify, matching how
  pricing's gate only checks presence-and-labeling, not correctness of
  the number itself).
- `mitigation-owner: TBD` (placeholder token) → deny.
- Empty/near-empty write to the record path → deny (generic empty case,
  mirrors `record-fields-gate.sh`'s own `record-empty` test in
  implementation-rulebook's harness, run here for the new role-owned
  gate too).
- Malformed/unparseable JSON payload on stdin → deny (fail-closed
  internal-error path), mirroring both source gates' `except Exception`
  fail-closed branch.
- `Edit` whose `old_string` doesn't match current file content (content
  reconstruction fails) → deny, not silently skip.
- Kill switch set (`RISK_MANAGEMENT_METHODOLOGY_GATE_OFF=1`) → allow
  regardless of content (confirms the switch actually short-circuits).

## 4. Agents/checklists

- New handbook doc: `docs/handbooks/risk-management/methodology.md` (or
  `risk-management/docs/handbooks/...` — exact placement an open item for
  phase 2 depending on whether this repo's doc-placement convention
  differs from `pricing-rulebook`'s `docs/handbooks/pricing/
  methodology.md`), separating the *reasoning* behind each mechanical
  check (why ordering matters, why inherent/residual must be distinct,
  why a named owner matters — largely restating scout-brief's converged
  findings) from the gate script itself, mirroring the pricing precedent.
- **No new agent proposed.** Issue #7 point 4 makes agents/checklists
  conditional ("방법론이 요구하는 반복 절차가 있으면") — no repeating
  multi-step procedure was found in the adopted COSO/ISO 31000 norms
  beyond the single-document stage ordering already covered by the gate
  (section 2) and the handbook checklist above; inventing an agent for a
  procedure the methodology doesn't actually call for would be scope the
  proposal should not add. If phase-2 investigation of `core`'s
  `warrant-hunter` cadence (referenced in this repo's README as provided
  by core, not local) surfaces a risk-management-specific hunt cadence
  need, that is a separate, later proposal.

## 5. Canon reference discipline (explicit statement)

This proposal recommends **canon reference only** throughout: the new
`methodology-gate.sh` cites (by path, in its header comment)
`pricing-rulebook/pricing/hooks/methodology-gate.sh` and
`implementation-rulebook/coding/hooks/coding-progress-gate.sh` as the
patterns its structure was adapted from, and continues to reference
`core/hooks/lib/role-directive.sh` and core's generic record-fields gate
through the existing plugin-root mechanism — no script body from any of
these is copied into this rulebook's tree. Phase 2 must carry this same
citation discipline into the actual gate script's comments, following
`docs/issue-2/proposals/core-canon-reference-conversion.md`'s established
precedent.

## Open items to confirm before phase 2 executes

1. Whether `core_role_directive`'s actual signature accepts multi-section
   payloads the way `implementation-rulebook/coding/hooks/directive.sh`
   passes four pre-built strings, or whether risk-management's directive
   needs restructuring to match core's real call signature (same class of
   gap issue-1's own open item 1 flagged and left unresolved).
2. Exact test-harness location (`risk-management/hooks/tests/` vs.
   repo-root `tests/`) — depends on whether this repo already has other
   role gates with an established tests-directory convention to match
   (none currently exist in this repo per survey.md §1, so phase 2 should
   check whether a repo-wide convention exists before picking a location,
   rather than this proposal guessing).
3. Whether the inherent-vs-residual "genuinely distinct number" check
   (section 3, negative case 3) is worth attempting mechanically at all,
   or should be left as a handbook-documented human-judgment item outside
   gate scope — flagged rather than pre-decided, since over-claiming what
   a text-presence gate can verify would repeat the exact overclaiming
   failure mode pricing's own methodology guards against in its own
   domain.

All of the above (new gate script, hooks.json registration, gate tests,
handbook doc, directive.sh restructuring) begin only after an
`approvers.md`-listed account posts `APPROVE issue-7/risk-management`
(single-account mode) or a PR review Approve (two-account mode), per
contract v3 s19.
