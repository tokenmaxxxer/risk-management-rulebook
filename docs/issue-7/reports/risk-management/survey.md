# Current-state survey — issue-7 (risk-management enforcement gap)

Subject: issue-7. Phase 1 only (survey step of the phase-1 proposal
package). Sequential reads (Bash/Read/find), not parallel WebSearch — noted
honestly, see scout-brief.md for the same disclosure on the scout step.

## 1. What exists today in this repo's `risk-management` plugin

- `risk-management/.claude-plugin/plugin.json` — manifest only (name,
  description, author).
- `risk-management/hooks/hooks.json` — wires a single `SessionStart` hook
  (`directive.sh`). No `PreToolUse` hook is registered anywhere in this
  rulebook's own tree.
- `risk-management/hooks/directive.sh` — a thin stub that sources
  `core/hooks/lib/role-directive.sh` and calls `core_role_directive` with
  this role's `--decides` / `--use-when` / `--produces` / `--write-scope`
  / `--hand-off` / `--record-path` strings. The `--produces` value already
  names the two adopted standards in prose: *"ERM verdict (COSO ERM
  5-component judgment), risk register entry (ISO 31000 schema — see
  README), mitigation owner"* — but this is a **single string emitted at
  SessionStart**, not a directive with stages/judgment-criteria/
  prohibitions, and nothing checks that a session actually followed it.
- `risk-management/hooks/record-fields.json` — a config file (not a
  script) read by core's generic record-fields gate. It lists the full
  12-field `risk-register-entry` schema plus `erm-verdict` and
  `mitigation-owner` as `required_fields`, and `record_path_suffix:
  "/reports/risk-management.md"`. `RECORD_FIELDS_TERMINAL_STATES` is `[]`
  (no terminal-state distinction adopted).

This is the full contents of the plugin's own tree — there is no gate
script, no test directory, and no agents/checklists directory under
`risk-management/`.

## 2. Where the adopted methodology/norms live (prior maturation issue)

- **Issue #5** (`docs/issue-1/proposals/risk-management-methodology.md`,
  merged as `1d7ffa2`): the phase-1 proposal. Adopts **COSO ERM (2017)
  5-component structure** to govern the *shape* of the `erm-verdict`
  (governance/context → objective linkage → assessment → response →
  monitoring) and **ISO 31000's process + risk-register minimum field
  set** to govern the *risk-register-entry* artifact. Section (d)
  ("Plugin reflection plan") lists exactly what phase 2 was to change:
  `record-fields.json`'s `required_fields`, `directive.sh`'s `--produces`
  string, and a new README "Methodology" section — explicitly **"No new
  gate script"**, reasoning that core's generic record-fields gate
  already reads `required_fields` and expanding the list is config-only.
- `docs/issue-1/reports/risk-management/current-state-survey.md` and
  `docs/issue-1/reports/risk-management/scout-brief.md` — the phase-1
  survey and 4-angle parallel WebSearch scout brief backing that proposal
  (COSO ERM, ISO 31000 register fields, risk appetite/heat-map practice,
  register ownership — sources cited inline in scout-brief.md).
- **Issue #6** (commit `e4fa0d1`, "Reflect approved risk-management
  methodology norms into plugin (phase 2)"): the phase-2 delivery. Per
  `git show e4fa0d1 --stat`, this is exactly the plan from issue-1(d):
  `record-fields.json` grew from a 3-field flat list to the full 12-field
  schema, `directive.sh`'s `--produces` line was updated to name COSO
  ERM/ISO 31000 explicitly, and `README.md` gained the "Methodology"
  section (adopted-standard prose, required-record-schema table,
  out-of-scope note) reproduced verbatim in the current README read
  above.

So the adopted norm is fully documented in prose and reflected as a
**config list of field names** — but per issue-1(d) point 4 ("No new gate
script... expanding the field list is a config-only change under the
existing mechanism"), no role-specific enforcement script exists. The
"existing mechanism" is core's generic record-fields gate, which (per its
naming and role in `hooks.json`'s comment in the risk-management README:
*"the trailer/record-fields/handbook-trigger gates are registered by
core, not here"*) checks presence of `required_fields` keys somewhere in
the record text — a flat, generic key-presence check with no knowledge of
COSO's 5-component *ordering* requirement, no distinction between
inherent/residual scoring being genuinely computed vs. merely mentioned,
and no state-tracking for any multi-step ordering the methodology
implies.

## 3. The hook-machine rigor bar: implementation-rulebook and pricing-rulebook

Issue #7 names `implementation-rulebook`'s hook machine as the bar
("hook 머신 400줄+") and separately points at
`pricing-rulebook/pricing/hooks/methodology-gate.sh` as the pattern to
mirror for a *methodology* gate specifically (as opposed to
implementation-rulebook's *progress*-gate, which is a different kind of
enforcement). Both live outside this repo, at
`/home/jwjung/tokenmaxxxer/rulebooks/implementation-rulebook` and
`/home/jwjung/tokenmaxxxer/rulebooks/pricing-rulebook` respectively (read
for this survey, not vendored — see canon-reference discipline below).

### 3a. `implementation-rulebook/coding/hooks/coding-progress-gate.sh` (~179 lines)

A `PreToolUse` gate matching `Bash` commands containing `git commit`.
Structure worth mirroring:

1. **Fail-closed trap at top**: `trap __fc EXIT` installed as the very
   first statement, before `set`/`source`, so any abnormal termination
   (unbound var, failed source) is remapped to exit 2 (deny) rather than
   silently allowing (a `PreToolUse` hook treats any non-2 exit as
   non-blocking / fail-open).
2. **Dependency checks fail closed**: `command -v python3` /
   `command -v git` missing => deny with an explicit reason, never
   "assume it's fine."
3. **Root discovery** via `CLAUDE_PROJECT_DIR` (plausibility-checked) or
   `git rev-parse --show-toplevel`, denying if neither resolves.
4. **JSON payload parsed in an embedded `python3` heredoc**, itself
   wrapped in `try/except` with a second fail-closed layer
   (`_fc_sys.exit(2)` on any internal error) — two independent fail-closed
   layers (bash trap + python except).
5. **Scope check first**: exits 0 immediately for tool calls / commands
   that are not the gate's business (not a `git commit`, no attributable
   subject) — the gate only judges what it is actually the gate for.
6. **State read from another role's record**: reads
   `docs/issue-<n>/reports/verify.md`, parses inline `finding:` blocks by
   regex (severity/addressed_to/id fields), and requires the *committing*
   role's own record (`coding.md`) to carry a `resolved_findings` entry
   naming the finder + a sha **and** the finder's own record to show
   `loop_state: cleared` before allowing the commit — i.e. ordering is
   enforced by reading state out of two records' text, not a separate
   state file.
7. Exercised by `implementation-rulebook/tests/run-gate-tests.sh`, which
   spins up a throwaway `git init` repo per case, pipes a synthetic
   `PreToolUse` JSON payload into the gate script as a real subprocess,
   and asserts the exit code maps to allow/deny — no mocking of the gate
   internals.

### 3b. `pricing-rulebook/pricing/hooks/methodology-gate.sh` (~230 lines) — the direct analog for a "produces" gate

This is the more directly relevant precedent for risk-management, since
its job is exactly what issue #7 asks for: verify a **methodology's
required elements are present in a proposal/record write**, not a
commit-ordering gate. Structure:

- Same fail-closed trap + dependency checks + root discovery as 3a.
- **Path scoping via regex against the write surface**:
  `PROPOSAL_RE = r'^docs/issue-[0-9]+/proposals/.*pricing.*\.md$'` and
  `RECORD_RE = r'^docs/issue-[0-9]+/reports/pricing\.md$'` — exits 0
  (not this gate's business) for any other write.
- **Resulting-content reconstruction for `Write`/`Edit`/`MultiEdit`**:
  for `Write`, uses `tool_input.content` directly; for `Edit`, applies
  `old_string`→`new_string` against the current on-disk text; for
  `MultiEdit`, applies the edit list in order. If the resulting text can't
  be determined (e.g. an `Edit` whose `old_string` doesn't match), it
  **denies** rather than guessing — "the gate cannot judge a write it
  cannot parse."
- **Six required-element checks**, each a `has_any(...)` substring/regex
  test against the lower-cased resulting text (method named or an
  explicit early-exit path; family named when conjoint language appears;
  inputs-needed stated; a gate-check result cited; any numeric verdict
  carrying a label; a residual/"cannot answer" list) — every missing
  element is named individually in the deny message, with a pointer back
  to the source norms doc (`docs/issue-1/proposals/methodology-norms.md`).
- **No separate state-tracking file** for pricing, because the pricing
  methodology has no ordering constraint across writes — each write is
  judged on its own content. `docs/handbooks/pricing/methodology.md`
  documents the *reasoning* behind each mechanical check, kept separate
  from the gate script itself (checklist doc vs. enforcement script).
- Kill switch: `PRICING_METHODOLOGY_GATE_OFF=1` env var, checked before
  any other logic runs.

### 3c. Canon-reference discipline (constraint already established in this repo, issues #3/#4)

`docs/issue-2/proposals/core-canon-reference-conversion.md` and commit
`b9d3f64` ("Convert local warrant-hunter/gate copies to core canon
references") already established the pattern this issue's proposal must
follow: when a script's authoritative home is `core/hooks/` (or another
rulebook's own plugin tree, in risk-management's case
`implementation-rulebook`/`pricing-rulebook` are peer rulebooks, not
canon core — see below), a role's own rulebook references it by path
resolved against that plugin's install root rather than vendoring a
second copy. `core/hooks/tests/stub-check.sh` mechanically enforces this
for `core/hooks/`-manifest scripts. `implementation-rulebook` and
`pricing-rulebook` are **not** core canon — they are sibling role
rulebooks in the same marketplace family — so risk-management cannot
literally "reference" their gate scripts via a canon install-root path;
the correct discipline (confirmed by reading both, not copying) is:
**adapt their structure/pattern into a new, risk-management-owned gate
script**, citing both source files by path in the new script's comments,
never pasting their bash/python bodies verbatim. `core/hooks/` itself
(`role-directive.sh`, the generic `record-fields-gate.sh` the risk-
management plugin already depends on) remains referenced, never copied,
per existing discipline.

## 4. The gap

| Dimension | Current risk-management state | Hook-machine bar (implementation-rulebook / pricing-rulebook) |
|---|---|---|
| Directive depth | One `--produces` string naming two standards in prose, emitted once at SessionStart | Structured stages/judgment-criteria/prohibitions per phase, executable-level per facet (implementation-rulebook's `directive.sh` builds four multi-paragraph blocks: YOU_DECIDE/USE_WHEN/PRODUCES/HAND_OFF, each enumerating concrete rules, not summary lines) |
| Methodology gate | None — generic core record-fields gate only checks flat key-presence of `required_fields`, no knowledge of COSO 5-component ordering, no inherent-vs-residual distinction beyond field presence | A role-owned `PreToolUse` gate scoped to the role's own write surfaces, reconstructing resulting content and checking semantic elements (methodology named, per-element presence, labeled numbers), fail-closed throughout |
| Ordering/state tracking | None (`RECORD_FIELDS_TERMINAL_STATES: []`) | implementation-rulebook's progress gate enforces "resolve before proceed" ordering by reading `loop_state`/`resolved_findings` out of two records; pricing's methodology has no ordering need so it has none — risk-management's own methodology (COSO's governance→objective-linkage→assessment→response→monitoring *shape*, and any adopt-before-cite ordering) needs its own judgment call in the proposal about whether state-tracking is warranted |
| Gate tests | None | `implementation-rulebook/tests/run-gate-tests.sh` — real-subprocess, synthetic-JSON-payload, throwaway-git-repo test harness per gate |
| Agents/checklists | None (README references core's `warrant-hunter`, not risk-management-specific) | `pricing-rulebook/docs/handbooks/pricing/methodology.md` — a worked checklist document separate from (and cited by) the gate script |

This gap — "adopted methodology lives only as a directive one-liner and a
field-name list, with no machine enforcement of ordering, per-element
semantics, or judgment criteria" — is exactly the problem statement in
issue #7, and is what the accompanying proposal
(`docs/issue-7/proposals/risk-management-plugin-enforcement.md`) addresses
for phase 2.
