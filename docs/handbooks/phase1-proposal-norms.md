# phase1-proposal-norms methodology

Source: `docs/issue-7/proposals/risk-management-plugin-enforcement.md`
§1.3 (phase1 half) and §0.2. This plugin generalizes a norm that every
prior risk-management phase-1 proposal already followed by convention —
`docs/issue-1/proposals/risk-management-methodology.md` and this
repo's own `docs/issue-7/proposals/risk-management-plugin-enforcement.md`
both open with a "Status: Phase 1 proposal ... APPROVE is out of scope"
line and cite a survey document before proposing anything — into a
role-agnostic, mechanically enforced rule rather than risk-management-
specific prose. Nothing here is risk-management content; it governs
process shape only, per §0.2's content-vs-process-shape distinction.

## Survey-before-proposal ordering

Contract v3 s19 sets a rigor floor: a proposal may not invent gaps,
findings, or current-state claims without first checking what the repo
actually contains. The mechanical proxy for "the survey was checked" is
a citation — a `docs/issue-<n>/reports/` path string appearing in the
proposal's own text, under the same issue number the proposal itself
belongs to. This is deliberately a citation-exists check, not a
content-verification check: the gate can confirm a survey path was
named, not that its findings were actually read or honored. That
narrower claim is stated explicitly rather than overclaimed, matching
the same limit the parent proposal names for `phase2-record-norms`'
backlink check.

## Explicit phase-gate statement requirement

The role-handoff contract (v3) gates APPROVE decisions on string
equality — a reviewing account must be able to tell, without
interpretation, whether a document is a phase-1 proposal (open for
comment, not for APPROVE) or a phase-2 record (implementation, subject
to APPROVE). Requiring two specific, literal phrases — identifying the
document as a "Phase 1 proposal" and stating "APPROVE is out of scope"
— keeps that determination unambiguous and machine-checkable, rather
than relying on a human to infer phase from surrounding prose. The gate
denies naming which of the two phrases is missing, so an author fixing
a rejected write knows exactly what to add rather than guessing.

## Canon-reference-only prohibition

Per the parent proposal's canon-reference-only discipline (also stated
in `docs/issue-2/proposals/core-canon-reference-conversion.md`), a
phase-1 proposal may adapt structure from an existing sibling
mechanism but must cite it by path in a comment, never copy the
source's literal script or prose body into the new document. This
keeps rulebooks from silently diverging vendored copies of shared
mechanisms over time.

## Role-agnostic by design

Unlike `erm-verdict-methodology` and `risk-register-methodology` (which
govern ISO 31000 content specific to risk-management), this plugin's
scope regex (`^docs/issue-[0-9]+/proposals/.*\.md$`) names no role and
its directive fragment's prose names no role beyond one illustrative
example. Any role's `hooks/directive.sh` can source and concatenate
this plugin's fragment into its own phase-1 `--produces` string,
exactly as `risk-management` does per the parent proposal's §0.4.

## Gate A+ final closure (issue-13)

Per `docs/issue-13/proposals/risk-management-gate-a-plus-final-closure.md`
(approved): `hooks/proposal-shape-gate.sh` now sources `gate-lib.sh` via
the canon idiom (`CLAUDE_PLUGIN_ROOT_CORE` first, relative fallback
second, `|| exit 2` fail-closed on the source line). `hooks.json`'s
matcher gained `NotebookEdit` for matcher/code parity with the gate's
existing `gate_reconstruct_write` handling. `hooks/tests/run-gate-tests.sh`
gained two new cases: a missing-`CLAUDE_PLUGIN_ROOT_CORE` deny-2 case
(dynamic proof of the fail-closed guard), and an Edit-reconstruction
case where an Edit whose old/new string pair strips the required
"Phase 1 proposal" status line is denied — closing the previously-absent
Edit-deny-on-shape-failure coverage this plugin's suite lacked.
