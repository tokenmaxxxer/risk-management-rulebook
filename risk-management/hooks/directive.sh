#!/usr/bin/env bash
# SessionStart: risk-management's role directive.
# Shared trap/kill-switch/heredoc boilerplate now lives in core's
# core_role_directive (core issue #66); this stub supplies only the
# role-specific payload.
source "${CLAUDE_PLUGIN_ROOT}/../core/hooks/lib/role-directive.sh"

core_role_directive \
  --role "risk-management" \
  --kill-switch-var "RISK_MANAGEMENT_CYCLE_OFF" \
  --decides "전사 리스크 노출이 허용 범위인가" \
  --use-when "재무/운영/전략 리스크가 걸릴 때 (feasibility보다 넓은 범위)" \
  --produces "ERM verdict (COSO ERM 5-component judgment), risk register entry (ISO 31000 schema — see README), mitigation owner" \
  --write-scope "[]" \
  --hand-off "개별 법규 컴플라이언스 세부는 → legal-compliance" \
  --record-path "docs/issue-<n>/reports/risk-management.md"
