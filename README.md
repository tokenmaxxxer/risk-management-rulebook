# risk-management-rulebook

Rulebook for the `risk-management` role (contract v3 role-handoff protocol), split off
per `docs/issue-160/proposals/role-taxonomy.md`'s round-3 promotion and
generated as skeleton scaffolding by issue-170.

- **decides**: 전사 리스크 노출이 허용 범위인가
- **use_when**: 재무/운영/전략 리스크가 걸릴 때 (feasibility보다 넓은 범위)
- **produces**: ERM verdict, risk register entry, mitigation owner
- **write_scope**: []
- **hand-off**: 개별 법규 컴플라이언스 세부는 → legal-compliance

## Methodology

Adopted per `docs/issue-1/proposals/risk-management-methodology.md`
(approved issue-1): a two-standard pairing, not a single framework.

- **COSO ERM (2017), 5-component structure** governs the shape of the ERM
  verdict itself — the judgment must be traceable through
  governance/context → objective linkage → assessment → response →
  monitoring, so `erm-verdict` cannot be a bare accept/reject; it must show
  which objective is at risk and what response tier follows.
- **ISO 31000's process + risk register minimum field set** governs the
  risk-register-entry artifact — the concrete, auditable record.

Both are enterprise/organizational-scope standards, matching this role's
`decides`/`use_when` above (broader than project-risk tools like PMBOK's
risk register) — see the proposal for full rationale and sources.

### Required record schema (risk-register-entry)

| Field | Captures |
|---|---|
| `risk-id` | stable identifier for cross-reference across records |
| `risk-description` | what could happen, in plain language |
| `risk-category` | e.g. strategic/operational/financial/regulatory |
| `likelihood` | qualitative or numeric likelihood rating |
| `impact` | qualitative or numeric impact rating |
| `risk-score-inherent` | likelihood x impact, before controls |
| `existing-controls` | controls currently in place, if any |
| `risk-score-residual` | likelihood x impact, after existing controls |
| `risk-appetite-threshold` | the appetite level the residual score is judged against |
| `mitigation-owner` | named accountable person |
| `mitigation-plan` | the treatment action(s) |
| `review-date` | next scheduled re-assessment |

`erm-verdict` remains a required top-level field alongside this schema.
Out of scope: quantitative/actuarial modeling (VaR, Monte Carlo) and
heat-map visualization tooling — see the proposal's rationale section for
why.

## Install

```
claude plugin marketplace add tokenmaxxxer/risk-management-rulebook
claude plugin install risk-management
```

## Layout

- `risk-management/.claude-plugin/plugin.json` — plugin manifest
- `risk-management/hooks/hooks.json` — SessionStart wiring (directive.sh only; the
  trailer/record-fields/handbook-trigger gates are registered by core, not here —
  core issue #66)
- `risk-management/hooks/directive.sh` — thin stub sourcing core's
  `core_role_directive` (core issue #66) with this role's own payload
- `risk-management/hooks/record-fields.json` — this role's required-field set and
  record path, read by core's record-fields gate per `CLAUDE_ROLE`
- warrant-hunter agent — provided by core's `warrant/` plugin (core issue #63);
  no local copy in this rulebook
- `docs/specs/approvers.md` — Approve-authority allowlist (see below)

This is scaffolding, not a finished rulebook: fill in doctrine detail,
handoff enforcement, and any role-specific progress gate before treating
it as load-bearing.
