#!/usr/bin/env bash
# SessionStart: risk-management's role directive.
# Shared trap/kill-switch/heredoc boilerplate now lives in core's
# core_role_directive (core issue #66); this stub supplies only the
# role-specific payload.
#
# Per docs/issue-7/proposals/risk-management-plugin-enforcement.md §0.4,
# risk-management no longer embeds methodology/phase-norm prose directly:
# the --produces payload is composed from four sibling plugins' directive
# fragments (phase-norm fragment + the two methodology fragments), phase
# determined by which fragment is sourced. CLAUDE_PLUGIN_ROOT for a
# plugin is its own root, so sibling plugins are reached via
# "${CLAUDE_PLUGIN_ROOT}/../<plugin-name>".
source "${CLAUDE_PLUGIN_ROOT}/../core/hooks/lib/role-directive.sh"
source "${CLAUDE_PLUGIN_ROOT}/../erm-verdict-methodology/hooks/directive-fragment.sh"
source "${CLAUDE_PLUGIN_ROOT}/../risk-register-methodology/hooks/directive-fragment.sh"

# Phase is not mechanically detectable inside SessionStart (no reliable
# phase-1-vs-phase-2 signal at session boot); both phase-norm fragments
# compose in, matching how the role's directive text has always been one
# combined block regardless of phase — see open item 1 in the proposal
# for the open question of whether core_role_directive's real signature
# could instead accept phase as a selector.
source "${CLAUDE_PLUGIN_ROOT}/../phase1-proposal-norms/hooks/directive-fragment.sh"
source "${CLAUDE_PLUGIN_ROOT}/../phase2-record-norms/hooks/directive-fragment.sh"

PRODUCES="$(cat <<EOF
ERM verdict (ISO 31000:2018 process-clause shape — see
erm-verdict-methodology), risk register entry (ISO 31000 12-field schema
— see risk-register-methodology), mitigation owner.

$(phase1_proposal_norms_fragment)

$(phase2_record_norms_fragment)

$(erm_verdict_methodology_fragment)

$(risk_register_methodology_fragment)
EOF
)"

core_role_directive \
  --role "risk-management" \
  --kill-switch-var "RISK_MANAGEMENT_CYCLE_OFF" \
  --decides "전사 리스크 노출이 허용 범위인가" \
  --use-when "재무/운영/전략 리스크가 걸릴 때 (feasibility보다 넓은 범위)" \
  --produces "$PRODUCES" \
  --write-scope "[]" \
  --hand-off "개별 법규 컴플라이언스 세부는 → legal-compliance" \
  --record-path "docs/issue-<n>/reports/risk-management.md"
