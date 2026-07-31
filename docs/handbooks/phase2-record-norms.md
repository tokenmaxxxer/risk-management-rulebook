# phase2-record-norms methodology

Source: `docs/issue-7/proposals/risk-management-plugin-enforcement.md`
§0.2, §1.3 (phase2 half), §2.4.

## Why phase-2 records must backlink their implemented proposal

A phase-2 record (a `docs/issue-<n>/reports/<role>.md` 산출물) is the
output of a role acting on a phase-1 proposal that an approver already
signed off on. The role-handoff contract (contract v3 s19) defines that
handoff explicitly: phase 1 (기획서) proposes, an approver approves, and
only then does phase 2 (산출물) execute against what was approved. If a
phase-2 record does not say which proposal it implements, that link is
invisible to anyone reading the record later — there is no way to trace
the record back to the approved scope it was supposed to execute, and
no way to tell whether the record drifted from what was actually
approved. An "Implements:" backlink line, naming the exact proposal
file (matched by issue number), is the minimal marker that keeps this
traceability intact without requiring a separate index or database.

This is why the gate (`hooks/record-shape-gate.sh`) denies a write with
no such backlink, or a backlink pointing at a proposal under a
different issue number than the record itself: a mismatched issue
number is at least as broken a handoff as a missing backlink, since it
points the trace at the wrong proposal entirely.

## Deliberate scope limit: no Approve-marker verification

Proposal §2.4 raises, and leaves open, whether this gate could also
verify that an Approve marker exists before the phase-2 write happens.
This plugin does not attempt that. A `PreToolUse` hook runs as a local
script with no GitHub API access — it cannot query issue or PR state to
confirm an approver actually posted an Approve comment. Proposal §2.4's
own reasoning (open item 3) is followed here: unless some other
mechanism in `core/` already writes a local Approve-state marker this
gate could read (not found in this repo's `core/` tree as of the
proposal), the Approve-gate responsibility stays with the human process
described in the role-handoff contract, not a script. This plugin
states that limit explicitly, both in the gate script's header comment
and in its directive fragment, rather than silently dropping the
requirement or pretending a backlink-presence check also proves an
Approve marker exists.

## Role-agnostic composition

Per proposal §0.2, this plugin governs *process shape* (when a write is
allowed to happen, what it must reference), not *content* (what an
ERM verdict or risk-register entry must contain). Process-shape norms
are reusable by any role that produces phase-2 records under
`docs/issue-<n>/reports/<role>.md`, so this plugin names no specific
role or methodology anywhere in its gate, tests, or directive fragment.
It composes into `risk-management`'s phase-2 norm today (per proposal
§0.4), and is available to any future rulebook's phase-2 norm the same
way, via directive-fragment concatenation and independent
`PreToolUse` hook registration — the same composition mechanism
`core`'s own `freelunch`/`scout` plugins already use.
