#!/usr/bin/env bash
# directive-fragment.sh
#
# Directive fragment owned by risk-register-methodology, per
# docs/issue-7/proposals/risk-management-plugin-enforcement.md §1.2 and
# §0.4 (fragment-concatenation composition). This file is self-contained:
# it defines risk_register_methodology_fragment() and does nothing else.
# It is meant to be sourced by risk-management/hooks/directive.sh as a
# separate integration step this plugin does not perform itself.

risk_register_methodology_fragment() {
  cat <<'EOF'
### risk-register-methodology — ISO 31000 risk-register schema

Every risk-register-entry facet document must carry all 12 fields as
labeled lines (`field-name: value`), each satisfying a per-field judgment
criterion, not just presence:

- `risk-id`, `risk-description`: identify and describe the risk.
- `risk-category`: one of `strategic`, `operational`, `financial`,
  `regulatory` (case-insensitive), or a free-text value carrying an
  explicit justification marker `(justified: ...)` in the same line — bare
  free text with no marker is rejected.
- `likelihood`, `impact`: qualitative or numeric; no canon-wide scale
  exists in this repo, so no fixed scale is mandated.
- `risk-score-inherent`, `risk-score-residual`: two distinct labeled
  values, never the same line reused — collapsing to a single post-hoc
  "current risk level" number hides whether existing controls work.
- `existing-controls`: what is actually in place today, distinct from the
  mitigation plan (which is what will be added/changed).
- `risk-appetite-threshold`: the threshold the residual score is judged
  against.
- `mitigation-owner`: a named accountable person/role. Placeholder tokens
  (empty, `TBD`, `unassigned`, `N/A`, case-insensitive) are rejected —
  "risks without a clearly accountable person rarely move forward"
  (scout-brief.md finding). A bare team name is not mechanically caught by
  this check; that remains a human judgment call.
- `mitigation-plan`: the concrete action(s) that will change the residual
  score.
- `review-date`: a real date or trigger; the same placeholder-token
  rejection as `mitigation-owner` applies.

Enforced by `hooks/register-fields-gate.sh` (kill switch:
`RISK_REGISTER_METHODOLOGY_GATE_OFF=1`). See
`docs/handbooks/risk-register-methodology.md` (repo root) for full
reasoning.
EOF
}
