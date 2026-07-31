#!/usr/bin/env bash
# Directive fragment for erm-verdict-methodology.
# Sourced and concatenated by risk-management/hooks/directive.sh
# (integration step owned by the risk-management role plugin, not this
# plugin — see docs/issue-7/proposals/risk-management-plugin-enforcement.md
# §0.4). This file is self-contained: it defines one function and takes
# no dependency on any other plugin's files.

erm_verdict_methodology_fragment() {
  cat <<'EOF'
## erm-verdict shape: ISO 31000:2018 process clauses (6.3-6.6)

An `erm-verdict` document must show its work as a five-stage process
(each stage a `##`-level Markdown heading, in this order):

1. Governance/context (`## Governance/context`, ISO 31000 §6.3) — state
   which objective(s) the risk attaches to and under what risk-appetite
   policy the verdict will be judged. Prohibition: do not open directly
   with a likelihood/impact number before this stage is stated — a
   verdict that starts at "risk score: 12" with no objective named is a
   bare accept/reject, not a process.

2. Objective linkage (`## Objective linkage`, ISO 31000 §6.3, criteria
   sub-clause) — name the specific business objective(s) at risk and
   how; risk criteria must be set relative to objectives, not stated in
   the abstract. Judgment criterion: the objective named must be a
   scoped goal (revenue, uptime, regulatory standing, etc.), not a
   restatement of the risk itself.

3. Assessment (`## Assessment`, ISO 31000 §6.4: identification,
   analysis, evaluation) — likelihood, impact, inherent score, existing
   controls, residual score, appetite threshold. Prohibition: inherent
   and residual must be two distinct numbers/ratings, each labeled
   separately (`risk-score-inherent`, `risk-score-residual`) — a single
   "current risk level" collapses the two, a known anti-pattern. No
   canon-wide likelihood/impact matrix or numeric scale exists
   elsewhere in this repo, so qualitative or numeric ratings both
   satisfy this stage; nothing here mandates a fixed scale.

4. Response (`## Response`, ISO 31000 §6.5, risk treatment) — state the
   response tier that follows from residual-vs-appetite (accept /
   mitigate / transfer / avoid) and name the mitigation owner and plan.
   Judgment criterion: the response tier must be consistent with the
   residual-vs-appetite comparison — a judgment call for the author,
   since the automated gate checks only presence and ordering, not
   tier-consistency.

5. Monitoring (`## Monitoring`, ISO 31000 §6.6, monitoring and review)
   — state the review/due date and what would trigger re-assessment
   before that date. Prohibition: "review-date: TBD" or an equivalent
   non-committal placeholder does not satisfy this stage.

Each stage maps 1:1 to a grep-able marker (the `##` heading named
above). A PreToolUse gate enforces marker presence, left-to-right
order, and inherent/residual distinctness on writes to
`docs/issue-<n>/(proposals/*risk-management*|reports/risk-management).md`;
it does not and cannot judge whether an objective is well-chosen or a
mitigation plan is sound — that judgment stays with the author.
EOF
}
