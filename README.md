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
(approved issue-1) and mechanically enforced as a **plugin set** per
`docs/issue-7/proposals/risk-management-plugin-enforcement.md` (approved
issue-7): a two-standard pairing, not a single framework, each standard
now owned by its own independent, self-contained plugin rather than
embedded in `risk-management/` directly.

- **ISO 31000:2018 process clauses (6.3-6.6)** — owned by the
  `erm-verdict-methodology` plugin — govern the shape of the ERM verdict
  itself: the judgment must be traceable through governance/context →
  objective linkage → assessment → response → monitoring, so
  `erm-verdict` cannot be a bare accept/reject; it must show which
  objective is at risk and what response tier follows. (Earlier drafts
  of this rulebook mislabeled this five-stage per-document process as
  "COSO ERM 5-component structure" — COSO ERM 2017's actual five
  components describe an entity-level framework, not a single verdict
  document's section order; corrected in the issue-7 proposal's round-2
  revision.)
- **ISO 31000's risk register minimum field set** — owned by the
  `risk-register-methodology` plugin — governs the risk-register-entry
  artifact: the concrete, auditable record.

Both are enterprise/organizational-scope standards, matching this role's
`decides`/`use_when` above (broader than project-risk tools like PMBOK's
risk register) — see the proposals for full rationale and sources.

### Plugin set (issue-7)

Four sibling plugins compose into this role's phase-1 and phase-2 norms
(`risk-management/hooks/directive.sh` sources and concatenates their
directive fragments; each plugin independently registers its own
`PreToolUse` gate, additive to core's generic record-fields gate):

| Plugin | Methodology owned | Gate | Kill switch |
|---|---|---|---|
| `erm-verdict-methodology` | ISO 31000:2018 process-clause shape for `erm-verdict` | `hooks/erm-order-gate.sh` | `ERM_VERDICT_METHODOLOGY_GATE_OFF=1` |
| `risk-register-methodology` | ISO 31000 12-field register schema | `hooks/register-fields-gate.sh` | `RISK_REGISTER_METHODOLOGY_GATE_OFF=1` |
| `phase1-proposal-norms` (role-agnostic) | 기획서(phase-1) proposal writing norm | `hooks/proposal-shape-gate.sh` | `PHASE1_PROPOSAL_NORMS_GATE_OFF=1` |
| `phase2-record-norms` (role-agnostic) | 산출물(phase-2) record writing norm | `hooks/record-shape-gate.sh` | `PHASE2_RECORD_NORMS_GATE_OFF=1` |

Each plugin ships its own `.claude-plugin/plugin.json`, `hooks/hooks.json`,
and `hooks/tests/run-gate-tests.sh`; its handbook lives at repo-root
`docs/handbooks/<name>.md` per this repo's docs-layout convention. Each
plugin is registered independently in `.claude-plugin/marketplace.json`. See
`docs/issue-7/proposals/risk-management-plugin-enforcement.md` for the
full design and `docs/issue-7/reports/risk-management.md` for the phase-2
implementation record.

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

#### Spec field mapping (issue #20)

The realized marketplace `roles/specs/risk-management.spec.json`'s six
required deliverable fields map onto this schema:
`risk_id`↔`risk-id`, `description`↔`risk-description`,
`likelihood`↔`likelihood`, `impact`↔`impact`,
`treatment`↔`mitigation-plan`, `owner`↔`mitigation-owner`. `low`/`medium`/
`high` values for `likelihood`/`impact` satisfy both this rulebook's
free-text gate and the spec's stricter `enum` typing; other qualitative
or numeric values remain valid here but would not satisfy the spec's
typing. See `docs/issue-20/proposals/implementation.md` for full
reasoning.

#### `loop_state` vocabulary (issue #20)

Pinning `loop_state` to the spec's five-state set (`landed`,
`registering`, `risk-unreachable`, `treating`, `treatment-undeclared`)
via a repo-local `docs/specs/record-fields-terminal-states.json` was
attempted and reverted: core's `record-fields-gate.sh` accepts only its
own fixed contract §2 kind list (`coding-record`, `feasibility-record`,
`ops-record`, `product-record`, `qa-record`, `reflect-record`,
`review-record`, `ux-design-record`, `verify-record`) as override keys
and denies **every** record write in the repo — not just
risk-management's — the moment the file contains an unrecognized kind
key such as `risk-management`. This rulebook's role does not map to any
of those kinds, so the override file cannot express this vocabulary
without breaking record-writing repo-wide; see
`docs/issue-20/reports/implementation.md` for the reproduction.

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
