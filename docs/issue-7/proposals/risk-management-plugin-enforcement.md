# Proposal: risk-management methodology enforcement as a plugin set

Subject: issue-7

Status: Phase 1 proposal — for review only. **APPROVE is out of scope for
this PR; phase 2 (enforcement implementation) opens only after an
`approvers.md` account approves per contract v3 s19.** This document
proposes; it contains no `src/`/`test/` implementation.

See `docs/issue-7/reports/risk-management/survey.md` for current-state
findings and `docs/issue-7/reports/risk-management/scout-brief.md` for the
hook-machine pattern sweep this proposal adapts from.

**Revision note (this version)**: an approver's `요구 정정` comment on the
open PR rejected a single deepened directive + one gate script as the
shape of this proposal. The required shape is a **plugin set**: each
adopted methodology becomes its own **independent, self-contained
plugin** (directive/gate/agent/tests as applicable — the `core`
`freelunch`/`scout` plugins are the reference bar for completeness), the
phase-1 (기획서) and phase-2 (산출물) norms are each **composed from
plugin combinations** rather than embedded directly in the
`risk-management` role plugin, and the proposal must carry an explicit
**plugin list** (name, methodology owned, components, how they combine).
Section 0 below is that list; sections 1-5 restate the prior gate/
directive/test design as the *contents* of the plugins the list names,
not as loose files inside `risk-management/`.

**Canon-reference-only, restated up front**: nothing below vendors a copy
of `core/hooks/*`, `implementation-rulebook/coding/hooks/*`, or
`pricing-rulebook/pricing/hooks/*`. Every mechanism proposed is a new
file owned by the plugin that declares it, whose comments cite the
sibling files it adapted structure from by path — never their literal
script bodies. `core/hooks/lib/role-directive.sh` and core's generic
record-fields gate remain referenced through the existing plugin-root
mechanism, unchanged.

## 0. Plugin list (the design's body)

Four new plugins, each a sibling of `risk-management/` and `core/` at
marketplace root, each with its own `.claude-plugin/plugin.json` and
`marketplace.json` entry. `risk-management/` itself stops carrying
methodology logic directly and instead declares these plugins as its
composition — see 0.4.

| Plugin | Methodology owned | Components | Registers as |
|---|---|---|---|
| `erm-verdict-methodology` | COSO ERM (2017) 5-component shape for the `erm-verdict` facet | directive fragment (facet A stages, §1.1), `hooks/erm-order-gate.sh` (PreToolUse, §2.1), `hooks/tests/run-gate-tests.sh` (§3), `docs/handbooks/erm-verdict-methodology/methodology.md` (§4) | independent plugin in `.claude-plugin/marketplace.json` |
| `risk-register-methodology` | ISO 31000 risk-register 12-field schema for the `risk-register-entry` facet | directive fragment (facet B fields, §1.2), `hooks/register-fields-gate.sh` (PreToolUse, §2.2), `hooks/tests/run-gate-tests.sh` (§3), `docs/handbooks/risk-register-methodology/methodology.md` (§4) | independent plugin in `.claude-plugin/marketplace.json` |
| `phase1-proposal-norms` | The 기획서(phase-1) writing norm this and every prior risk-management proposal has followed by convention only (survey-before-proposal ordering, canon-reference discipline, explicit "APPROVE out of scope" phase gate statement) — generalized so it composes, not risk-management-specific prose | directive fragment consumed by any role's `hooks/directive.sh` at `SessionStart` (composable snippet, not a role-owned file), `hooks/proposal-shape-gate.sh` (PreToolUse on `docs/issue-*/proposals/**`, checks the phase-gate statement and survey-reference marker are present) | independent plugin; **composed into** `risk-management`'s phase-1 norm (0.4) |
| `phase2-record-norms` | The 산출물(phase-2) record writing norm (record path = `reports/<role>.md`, waits for Approve, cites the phase-1 proposal it implements) | directive fragment consumed at `SessionStart`, `hooks/record-shape-gate.sh` (PreToolUse on `docs/issue-*/reports/<role>.md`, checks an implements-proposal backlink and that the write postdates an Approve marker) | independent plugin; **composed into** `risk-management`'s phase-2 norm (0.4) |

### 0.1 Why four, not one

Issue #7's own enumeration ("directive 심화", "방법론 게이트", "게이트
테스트", "에이전트/체크리스트") describes *facets of one bundle*, which is
exactly the shape the approver's comment rejected — it named "룰북당 여러
개" (multiple plugins per rulebook) explicitly, and separated 기획서 norms
from 산출물 norms as their own composable units, not sub-sections of a
single methodology doc. Splitting `erm-verdict-methodology` from
`risk-register-methodology` follows the same logic already present in the
adopted norm itself (issue-1's proposal treats COSO-shape and ISO-schema
as two distinct standards governing two distinct facets — see
survey.md §2); one plugin per methodology keeps that boundary at the
plugin level instead of collapsing it back into one script with two
concerns.

### 0.2 Why `phase1-proposal-norms` / `phase2-record-norms` are separate from the two methodology plugins

The two methodology plugins govern *content* (what an `erm-verdict` or a
`risk-register-entry` must contain). The two phase-norm plugins govern
*process shape* (when a write is allowed to happen, what it must
reference) — a distinction issue #7's own instructions draw explicitly
("기획서(phase 1) 규범과 산출물(phase 2) 규범도 각각을 플러그인 조합으로").
Keeping them separate also makes them reusable by future rulebooks other
than risk-management, which content-methodology plugins are not (COSO/
ISO 31000 are risk-management-specific; the phase-gate shape is not).

### 0.3 Self-containment per plugin

Each plugin above ships its own `.claude-plugin/plugin.json`, its own
`hooks/hooks.json` wiring only its own hook(s), its own `hooks/tests/`
directory with allow/deny cases scoped to that plugin's gate only, and
its own `docs/handbooks/<plugin-name>/methodology.md`. No plugin reads
another proposed-plugin's internal files directly — cross-plugin
composition happens only through the combination mechanism in 0.4
(directive-fragment concatenation + independently-registered PreToolUse
hooks, both mechanisms `core`'s own `freelunch`/`scout` plugins already
use to compose into a session without collapsing into one file).

### 0.4 Combination into `risk-management`'s phase-1 and phase-2 norms

`risk-management/hooks/directive.sh` is restructured (still the role's
own file — it does not move) to **source and concatenate** directive
fragments from all four plugins, replacing today's single flat
`--produces` string:

```
--produces = phase1-proposal-norms.fragment
           + erm-verdict-methodology.fragment
           + risk-register-methodology.fragment
```

for phase-1 sessions, and

```
--produces = phase2-record-norms.fragment
           + erm-verdict-methodology.fragment
           + risk-register-methodology.fragment
```

for phase-2 sessions — the methodology fragments are shared across both
phases (COSO/ISO 31000 content requirements don't change by phase); the
phase-norm fragment swaps. This *is* the "어떤 플러그인들이 조합되어 그
규범이 성립하는지" the approver's comment requires be the design's body:
phase-1 norm = `phase1-proposal-norms` ∘ `erm-verdict-methodology` ∘
`risk-register-methodology`; phase-2 norm = `phase2-record-norms` ∘
`erm-verdict-methodology` ∘ `risk-register-methodology`. Enforcement
composes the same way at the gate level: `risk-management/hooks/
hooks.json` registers no gate of its own; the four plugins' own
`PreToolUse` hooks each independently fire (scoped by their own path
regexes, §2) when `risk-management`'s write surfaces are touched, giving
the same net coverage the single `methodology-gate.sh` in the prior
version of this proposal provided, now as four independently-owned,
independently-testable gates rather than one file mixing four concerns.
`marketplace.json` gains four new entries (one per plugin); `risk-
management`'s own manifest gains a `dependencies`-style note (exact
mechanism — plugin.json field vs. README-documented convention — is an
open item, §Open items, since no existing plugin in this repo currently
declares a cross-plugin dependency to precedent from).

## 1. Directive fragments (owned by the plugins that declare them)

Today `risk-management/hooks/directive.sh` calls `core_role_directive`
with five flat strings, the `--produces` value being one sentence naming
COSO ERM/ISO 31000 in passing. Per issue #7 point 1 and the approver's
plugin-set requirement, this becomes **facet-level, executable directive
fragments**, each owned by its methodology plugin (not embedded in
`risk-management/`) and concatenated per 0.4 — mirroring how
`implementation-rulebook/coding/hooks/directive.sh` builds multi-
paragraph blocks enumerating concrete stages/criteria/prohibitions
rather than a summary line.

### 1.1 `erm-verdict-methodology` directive fragment — COSO ERM 5-component shape

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
   controls, residual score, appetite threshold. *Prohibition*: inherent
   and residual must be two distinct numbers/ratings — a single "current
   risk level" collapses the two, a known anti-pattern per scout-brief.
4. **Response** stage — state the response tier that follows from
   residual-vs-appetite (accept / mitigate / transfer / avoid) and name
   the mitigation owner + plan. *Judgment criterion*: the response tier
   must be consistent with the residual-vs-appetite comparison (a
   proposal-time judgment call the directive names explicitly, even
   though the gate — §2.1 — only checks presence and ordering, not
   tier-consistency itself).
5. **Monitoring** stage — state the review/due date and what would
   trigger re-assessment before that date. *Prohibition*: "review-date:
   TBD" or equivalent non-committal placeholder does not satisfy this
   stage.

Each stage maps 1:1 to a grep-able marker (`## Governance/context`, etc.
as section headings) — the fragment states this marker convention
explicitly so the plugin's own gate (§2.1) and the human author read the
same contract.

### 1.2 `risk-register-methodology` directive fragment — ISO 31000 schema

The 12-field schema already in `record-fields.json`/README, restated as
**per-field judgment criteria**, not just a name list — e.g.
`risk-category` must be one of the four named categories
(strategic/operational/financial/regulatory) or an explicitly justified
addition, not free text; `mitigation-owner` must be a named person/role,
not "TBD" or a team name with no individual accountable (mirrors
scout-brief's "risks without a clearly accountable person rarely move
forward" finding).

### 1.3 `phase1-proposal-norms` / `phase2-record-norms` directive fragments

`phase1-proposal-norms`: state the survey-before-proposal ordering
(current-state survey must exist and be cited before a proposal is
written — contract v3 s19's rigor floor), the explicit phase-gate
statement requirement ("Status: Phase 1 proposal... APPROVE is out of
scope" or equivalent, verbatim-checkable per §2.3), and the canon-
reference-only prohibition (no vendored copies of sibling
rulebooks'/core's script bodies).

`phase2-record-norms`: state that a phase-2 write must cite the phase-1
proposal it implements (an "Implements:" backlink line naming the
proposal file), and must not occur before an Approve marker exists
(checked by the gate reading the issue/PR state — §2.4 flags this as an
open item on exactly what "checked" can mean for a script with no GitHub
API access from a `PreToolUse` hook).

## 2. Methodology and phase-norm gates (one per plugin, not one merged script)

Each gate below is a separate file owned by its plugin, each
independently registered as a `PreToolUse` hook (`Write|Edit|MultiEdit`)
in that plugin's own `hooks/hooks.json`, additive to (never replacing)
core's existing generic record-fields gate. All four share the same
structural skeleton, adapted (cited by path, not copied) from
`pricing-rulebook/pricing/hooks/methodology-gate.sh` and
`implementation-rulebook/coding/hooks/coding-progress-gate.sh`:

1. **Fail-closed trap at top**, before any `set`/`source`, identical
   idiom to both source scripts (`trap __fc EXIT` mapping any
   non-0/non-2 exit to 2).
2. **Dependency + root-discovery checks**, fail closed exactly as both
   source scripts do (`python3`/`git` presence, `CLAUDE_PROJECT_DIR` or
   `git rev-parse --show-toplevel`).
3. **Scope regex, own write surface only** (see per-gate scoping below).
   Any other write exits 0 immediately — this is what lets four gates
   coexist without one shadowing another's business.
4. **Resulting-content reconstruction** for Write/Edit/MultiEdit,
   denying rather than guessing when the new text can't be determined.
5. **Kill switch**, one env var per plugin (below), checked before any
   other logic — distinct switches so each plugin is independently
   disableable, matching the per-hook kill-switch convention
   `PRICING_METHODOLOGY_GATE_OFF` establishes.

### 2.1 `erm-verdict-methodology/hooks/erm-order-gate.sh`

- Scope: `^docs/issue-[0-9]+/(proposals/.*risk-management.*|reports/risk-management)\.md$`.
- Checks: the five stage markers from §1.1 present **in order** (each
  later heading's first occurrence comes after the earlier one's —
  regex + position-comparison, no semantic judgment of content quality);
  `risk-score-inherent` and `risk-score-residual` both present as
  separately-labeled values (not the same label reused).
- Kill switch: `ERM_VERDICT_METHODOLOGY_GATE_OFF=1`.

### 2.2 `risk-register-methodology/hooks/register-fields-gate.sh`

- Scope: same regex as 2.1 (both facets can appear in the same document,
  per the existing `erm-verdict` + `risk-register-entry` combined record
  shape — the two gates run independently on the same write, each
  checking only its own facet, which is the intended "additive,
  never-instead-of" relationship, now applied gate-to-gate as well as
  gate-to-core).
- Checks: all 12 `risk-register-entry` fields present as labeled lines
  (intentional defense-in-depth overlap with core's generic record-
  fields gate — this gate additionally enforces field-value judgment
  criteria from §1.2 the generic gate cannot know, e.g. `risk-category`
  must be one of the four named categories); `mitigation-owner` and
  `review-date` are not placeholder tokens (`TBD`, `unassigned`, empty).
- Kill switch: `RISK_REGISTER_METHODOLOGY_GATE_OFF=1`.

### 2.3 `phase1-proposal-norms/hooks/proposal-shape-gate.sh`

- Scope: `^docs/issue-[0-9]+/proposals/.*\.md$` (role-agnostic — this
  plugin composes into any role's phase-1 norm, not risk-management-only,
  per 0.2).
- Checks: a phase-gate statement marker is present (regex for
  "Phase 1 proposal" + "APPROVE is out of scope" or the plugin's declared
  equivalent phrasing); a reference to a survey/current-state file under
  the same `docs/issue-<n>/reports/` tree is present (a path-shaped
  string, not content verification — the gate can check a citation
  exists, not that it was actually read, an explicitly named limit).
- Kill switch: `PHASE1_PROPOSAL_NORMS_GATE_OFF=1`.

### 2.4 `phase2-record-norms/hooks/record-shape-gate.sh`

- Scope: `^docs/issue-[0-9]+/reports/[a-z-]+\.md$` (role-agnostic).
- Checks: an "Implements:" backlink to a `docs/issue-<n>/proposals/*.md`
  path is present in the resulting text.
- **Open item, not silently adopted**: whether this gate can or should
  also verify an Approve marker exists before allowing the write. A
  `PreToolUse` hook has no GitHub API access in general; if `core`
  exposes an Approve-state file/marker some other mechanism already
  writes (unconfirmed — not found in this repo's `core/` tree during this
  survey), this gate could read that; otherwise this check is scoped
  down to "record cites what it implements" only, and the Approve-gate
  responsibility stays with the human contract-following process
  described in the role-handoff contract, not a script. Phase 2 must
  confirm which before implementing this file.
- Kill switch: `PHASE2_RECORD_NORMS_GATE_OFF=1`.

### State tracking — still not adopted, restated per-plugin

Section 1.1's ordering requirement is a single-document, position-based
check (owned entirely by `erm-verdict-methodology`'s own gate, §2.1), not
a cross-write/cross-record ordering — it needs no persistent state file,
unlike implementation-rulebook's cross-record `resolved_findings` +
`loop_state` mechanism. No other facet or phase-norm plugin above has an
ordering requirement that spans multiple writes or multiple records.
**Recommendation unchanged from the prior version of this proposal**: no
state-tracking file in phase 2 unless phase-2 investigation surfaces a
genuine multi-step ordering requirement this proposal missed.

## 3. Gate test plan (one `hooks/tests/run-gate-tests.sh` per plugin)

Each plugin ships its own test file, scoped to its own gate only,
mirroring `implementation-rulebook/tests/run-gate-tests.sh`'s real-
subprocess / synthetic-JSON-payload / throwaway-`git init`-repo harness.
Location: `<plugin-name>/hooks/tests/run-gate-tests.sh` per plugin (each
plugin is self-contained per 0.3 — no shared repo-root `tests/` directory
across plugins, since that would recreate the single-merged-file problem
at the test layer instead of the gate layer).

`erm-verdict-methodology` cases:
- Allow: five stage markers present and correctly ordered, inherent/
  residual both labeled and distinct.
- Deny: markers out of order (named specifically in the deny message);
  one specific stage marker missing (tested once per stage, five cases,
  each deny message naming the specific missing stage); inherent/
  residual sharing the same labeled value.
- Foreign-path allow: write outside the scope regex → allow.
- Malformed JSON payload → deny (fail-closed).
- `Edit` whose `old_string` doesn't match → deny.
- Kill switch set → allow regardless of content.

`risk-register-methodology` cases:
- Allow: all 12 fields present, `risk-category` a named category, owner
  and review-date real values.
- Deny: one field missing (tested per field or a representative subset);
  `mitigation-owner: TBD`; `risk-category` a non-listed free-text value
  with no justification.
- Same foreign-path/malformed-JSON/Edit-mismatch/kill-switch cases as
  above, scoped to this gate.

`phase1-proposal-norms` cases:
- Allow: phase-gate statement + survey citation both present.
- Deny: phase-gate statement missing; survey citation missing.
- Same generic fail-closed cases as above.

`phase2-record-norms` cases:
- Allow: "Implements:" backlink present.
- Deny: backlink missing.
- Same generic fail-closed cases as above.

## 4. Handbooks (one per plugin)

- `erm-verdict-methodology/docs/handbooks/erm-verdict-methodology/methodology.md`
  — reasoning behind ordering, inherent/residual distinctness.
- `risk-register-methodology/docs/handbooks/risk-register-methodology/methodology.md`
  — reasoning behind the 12-field schema and per-field criteria.
- `phase1-proposal-norms/docs/handbooks/phase1-proposal-norms/methodology.md`
  and `phase2-record-norms/docs/handbooks/phase2-record-norms/methodology.md`
  — reasoning behind the phase-gate/backlink requirements, generalized
  across roles (not risk-management-specific prose, per 0.2).

**No new agent proposed**, unchanged from the prior version of this
proposal: no repeating multi-step procedure was found in the adopted
COSO/ISO 31000 norms beyond the single-document stage ordering already
covered by `erm-verdict-methodology`'s gate and handbook. If phase-2
investigation of `core`'s `warrant-hunter` cadence surfaces a risk-
management-specific hunt cadence need, that is a separate, later
proposal.

## 5. Canon reference discipline (explicit statement, unchanged)

Every gate script above cites (by path, in its own header comment) the
sibling-rulebook file its structure was adapted from —
`pricing-rulebook/pricing/hooks/methodology-gate.sh` and
`implementation-rulebook/coding/hooks/coding-progress-gate.sh` — and
continues to reference `core/hooks/lib/role-directive.sh` and core's
generic record-fields gate through the existing plugin-root mechanism.
No script body from any of these is copied into any new plugin's tree.
Phase 2 must carry this same citation discipline into every one of the
four plugins' gate scripts, following
`docs/issue-2/proposals/core-canon-reference-conversion.md`'s established
precedent.

## Open items to confirm before phase 2 executes

1. Whether `core_role_directive`'s actual signature accepts the
   fragment-concatenation composition described in 0.4, or whether
   `risk-management/hooks/directive.sh` needs a different composition
   mechanism to match core's real call signature (same class of gap
   issue-1's own open item 1 flagged and left unresolved).
2. Exact cross-plugin dependency declaration mechanism (`plugin.json`
   field vs. README-documented convention) — no existing plugin in this
   repo currently declares one, so phase 2 must either establish the
   convention or find that `marketplace.json`-level co-registration is
   sufficient without a formal dependency field.
3. Whether `phase2-record-norms`' Approve-marker check (§2.4) is
   implementable at all from a `PreToolUse` hook with no GitHub API
   access, or must stay scoped to the backlink-only check — flagged
   rather than pre-decided, to avoid over-claiming what a local script
   can verify about a GitHub-side state.
4. Whether the inherent-vs-residual "genuinely distinct number" check is
   worth attempting mechanically at all beyond same-value-string
   detection, or should be documented as a human-judgment item outside
   gate scope (same open item as the prior version of this proposal,
   carried forward unresolved).

All of the above (four new plugins, their gate scripts, hooks.json
registrations, gate tests, handbooks, `risk-management/hooks/
directive.sh` restructuring into fragment composition per 0.4) begin
only after an `approvers.md`-listed account posts
`APPROVE issue-7/risk-management` (single-account mode) or a PR review
Approve (two-account mode), per contract v3 s19.
