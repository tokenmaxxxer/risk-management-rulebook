# erm-verdict-methodology

Source: `docs/issue-7/proposals/risk-management-plugin-enforcement.md`
§1.1 (directive fragment content) and §2.1 (gate design) — this handbook
restates the reasoning that section leaves compressed in directive prose.

## Why ISO 31000:2018 process clauses, not COSO ERM

An earlier draft of this plugin's design labeled the five-stage
`erm-verdict` shape (governance/context → objective linkage →
assessment → response → monitoring) as "COSO ERM (2017)". A domain
review caught that this was wrong: COSO ERM 2017's five components are
*Governance & Culture*, *Strategy & Objective-Setting*, *Performance*,
*Review & Revision*, and *Information, Communication & Reporting* —
these describe how an entire organization runs risk management as a
capability, not the section order of one verdict document.

What the gate actually checks is a **per-document process**: establish
context and the objective it serves, assess likelihood/impact/
inherent-vs-residual, decide and own a response, set a review trigger.
That is exactly the shape of ISO 31000:2018's process clauses:

- **6.3** Scope, context, and criteria (folds in objective linkage,
  since ISO 31000 requires risk criteria to be set relative to
  objectives, not stated in the abstract)
- **6.4** Risk assessment (identification, analysis, evaluation)
- **6.5** Risk treatment
- **6.6** Monitoring and review

Re-authoring the five stages to fit COSO's real components instead
(adding a distinct "Information, Communication & Reporting" stage,
merging assessment+response under one "Performance" component) would
change what the gate checks more than a labeling fix warrants. ISO
31000 was also already the source `risk-register-methodology`'s field
schema was reasoned from, so both facet plugins now trace to the same
standard while governing two different things — per-document process
shape (this plugin) versus a record's minimum field schema (the sibling
plugin) — the same content-vs-process-shape separation the proposal
draws between the phase-norm plugins, applied within the methodology
plugins too.

## Why inherent and residual must be two distinct values

Collapsing inherent and residual risk into a single "current risk
level" is a known anti-pattern (see `docs/issue-7/reports/risk-
management/scout-brief.md`): it erases the very thing a verdict is
supposed to show — how much a control actually reduced exposure. A
verdict that states one number cannot demonstrate that controls did
anything, and cannot be checked against an appetite threshold in a
meaningful way (appetite compares against *residual*, not raw
exposure). The gate therefore requires both `risk-score-inherent` and
`risk-score-residual` to be present as separately labeled values that
are not equal.

## The marker convention the gate checks

Updated per `docs/issue-10/proposals/risk-management-gate-a-plus-
remediation.md` §2.4: the two headings that read as COSO-flavored
vocabulary while the plugin claims ISO 31000 are corrected, and the
check is now section-boundary-aware rather than a whole-document
substring search (fenced code blocks and blockquotes no longer count).

Four top-level ISO 31000 process stages map 1:1 to a Markdown heading,
matched against a parsed section's heading text (not a raw substring
search) and checked for presence plus left-to-right document order
(position comparison only — no semantic judgment of content quality):

1. `## Governance/context` — ISO 31000 §6.3
2. `## Assessment` — ISO 31000 §6.4
3. `## Risk treatment` — ISO 31000 §6.5 (previously "Response" —
   corrected; "Response" is not an ISO 31000 clause name)
4. `## Monitoring and review` — ISO 31000 §6.6 (previously
   "Monitoring" — corrected to the full clause name)

`Objective linkage` is **no longer a standalone top-level stage**. ISO
31000 requires risk criteria to be set relative to objectives as part
of §6.3, not as a separate document section, so it is now required as
a sub-marker found *within* the Governance/context section (its own
heading through the next heading of equal-or-higher level) — either as
a nested heading or a labeled line inside that section — rather than
appearing anywhere in the document.

`risk-score-inherent` and `risk-score-residual` are likewise scoped:
both must be found within the Assessment section specifically, not
merely anywhere in the file.

This convention is stated explicitly here (and in the directive
fragment sourced by `risk-management/hooks/directive.sh`) so the gate
script and the human/session author are working from the same
contract — the gate cannot judge whether an objective is well-chosen or
a mitigation plan is sound, only that the required stages exist, in
the right section, in order, with inherent and residual kept distinct.

## Gate A+ final closure (issue-13)

Per `docs/issue-13/proposals/risk-management-gate-a-plus-final-closure.md`
(approved): `hooks/erm-order-gate.sh` now sources `gate-lib.sh` via the
canon idiom — `${CLAUDE_PLUGIN_ROOT_CORE:-...}` first, a same-repo
relative fallback second, and a `|| exit 2` fail-closed guard on the
source line itself, so a missing/broken core checkout denies rather than
silently falling through. `hooks.json`'s matcher now includes
`NotebookEdit` alongside `Write|Edit|MultiEdit`, matching the
`gate_reconstruct_write` code path the gate script already exercised for
that tool but that the matcher previously never routed to.
`hooks/tests/run-gate-tests.sh` adds a case asserting exit 2 when
`CLAUDE_PLUGIN_ROOT_CORE` points at a nonexistent path, proving the
source-guard fails closed dynamically rather than only by static
`compliance-check.sh` inspection.

## No scratch file: env-var handoff instead of mktemp (issue-16)

Per `docs/issue-16/proposals/erm-order-gate-mktemp-fix.md` (approved),
`hooks/erm-order-gate.sh` no longer writes its embedded Python judge to
a `mktemp` scratch file before running it. Under a sandboxed session
where the platform tmp dir sits outside the writable set, that write
was denied and the gate's fail-closed trap denied every erm-verdict
write regardless of content — the same bug class
product-discovery-rulebook#54 fixed for its own gate.

The fix follows that same house pattern: the JSON payload and resolved
project root are exported as `GATE_PAYLOAD` / `GATE_PROJECT_DIR` env
vars, and the Python source is piped straight into `python3` via a
`<<'PYEOF' ... PYEOF` heredoc on the invocation's own stdin — no
scratch file is created or cleaned up. The judge reads
`os.environ["GATE_PROJECT_DIR"]` and `os.environ["GATE_PAYLOAD"]` in
place of `sys.argv[1]` and `sys.stdin.read()`; routing the payload
through the environment instead of stdin is what frees stdin for the
heredoc, avoiding the collision the previous scratch-file workaround
existed to route around. `hooks/tests/run-gate-tests.sh` adds a
regression case that shadows `mktemp` on `PATH` with an
always-failing marker binary scoped to the gate subprocess, asserting
both that the gate still ALLOWs a valid payload and that the marker
file the shadow binary would touch is never created.

## Test-env resolution convention (issue-23)

Per `docs/issue-23/proposals/implementation.md`, `hooks/tests/run-gate-tests.sh`
now resolves core via `hooks/tests/lib/resolve-core.sh` before running any
case, per the canonical convention at `tokenmaxxxer/on-the-record`
`docs/specs/test-env-resolution.md` (issue #551): `CLAUDE_PLUGIN_ROOT_CORE`
if set and resolvable, else a sibling core checkout, else SKIP (exit 75,
explicit stderr message) instead of running cases that would fail
misleadingly on a plain checkout. The gate's own fail-closed case (a bad
`CLAUDE_PLUGIN_ROOT_CORE` path) is unchanged.
