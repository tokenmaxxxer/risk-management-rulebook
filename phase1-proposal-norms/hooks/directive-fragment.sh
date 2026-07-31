#!/usr/bin/env bash
# Directive fragment: phase1-proposal-norms.
# Sourced by any role's hooks/directive.sh (SessionStart) as one of the
# fragments concatenated into that role's phase-1 --produces string, per
# docs/issue-7/proposals/risk-management-plugin-enforcement.md §0.4/§1.3.
# Self-contained, generic across roles — the only role-specific text is
# the illustrative example in the last line, which names no fixed role.

phase1_proposal_norms_fragment() {
  cat <<'EOF'
phase1-proposal-norms:
- Survey-before-proposal ordering: a current-state survey (or
  equivalent existing-state investigation) must exist under this
  issue's docs/issue-<n>/reports/ tree, and the proposal document must
  cite it by path, before the proposal itself is written. This is
  contract v3 s19's rigor floor — a proposal may not invent gaps or
  findings without checking what the repo's actual current state is;
  citing a survey that does not exist, or writing the proposal before
  the survey is drafted, does not satisfy this requirement.
- Explicit phase-gate statement: every phase-1 proposal document must
  carry a verbatim-checkable statement that (a) identifies itself as a
  "Phase 1 proposal" and (b) states that "APPROVE is out of scope" for
  the review this document is submitted under (or the plugin's declared
  equivalent phrasing). This keeps APPROVE decisions unambiguous —
  string-equality gated per the role-handoff contract v3 — and prevents
  a phase-1 document from being read or approved as if it were a
  phase-2 implementation record.
- Canon-reference-only prohibition: a proposal must not vendor a copy of
  another plugin's or rulebook's script body, directive text, or gate
  logic. Where a proposal adapts structure from an existing mechanism
  (e.g. a sibling rulebook's gate script), it must cite that source by
  path in a comment or footnote, never copy the source text itself.
- Example (illustrative only, not role-specific): a risk-management
  phase-1 proposal must cite docs/issue-<n>/reports/risk-management/
  survey.md and carry a "Status: Phase 1 proposal ... APPROVE is out of
  scope" line — the same shape applies verbatim to any other role's
  phase-1 proposal under its own issue/report path.
EOF
}
