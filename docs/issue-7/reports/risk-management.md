# Record: risk-management / issue-7

Subject: issue-7 — 플러그인 심화: 채택 방법론을 강제 장치로 직접 구현

Implements: `docs/issue-7/proposals/risk-management-plugin-enforcement.md`

loop_state: landed

## What was done

Phase-2 반영: 승인된 proposal
(`docs/issue-7/proposals/risk-management-plugin-enforcement.md`)의 §0
플러그인 목록(4개) 전부를 실구현했다 — `erm-verdict-methodology`,
`risk-register-methodology`, `phase1-proposal-norms`,
`phase2-record-norms`. 각 플러그인은 자기완결(`plugin.json` +
`hooks/hooks.json` + 게이트 스크립트 + `hooks/tests/run-gate-tests.sh` +
`docs/handbooks/<name>/methodology.md` + directive fragment)이고,
`.claude-plugin/marketplace.json`에 독립 등록했다. `risk-management/hooks/
directive.sh`는 네 플러그인의 directive fragment를 source·concatenate하는
조합 방식으로 재구성했고(§0.4), `README.md`의 Methodology 절을 COSO ERM
오표기 정정 + 플러그인 세트 표로 갱신했다. 상세는 "반영 내역" 절 참고.

## Why (rationale)

Issue #7의 요구는 "채택 방법론이 directive 한 줄과 문서로만 남았다"는
문제였고, 승인자 코멘트(요구 정정)는 단일 게이트/디렉티브 심화가 아니라
"룰북당 여러 개" 플러그인 세트로 체계화할 것을 명시했다. Phase-1
proposal(§0.1, §0.2)이 이미 이 근거를 기획서 안에 확정했으므로, phase-2는
그 설계를 그대로 실행에 옮기는 작업이다 — 새 방법론 판단이나 범위 확장
없이, proposal이 명시한 4개 플러그인·게이트·테스트·핸드북·조합 메커니즘을
구현만 했다.

## Governance/context

이슈-7 phase-1 승인 (2026-07-31, JiwonJung94, `APPROVE
issue-7/risk-management`). 판단 대상 리스크: phase-2 구현이 승인된
proposal 범위를 벗어나 core canon을 복사하거나, proposal이 명시한 4개
플러그인 경계를 흐리거나, 게이트가 fail-open으로 동작할 위험.

## Objective linkage

이 역할의 채택 방법론(ISO 31000:2018 process clauses + risk-register
schema)과 두 phase-norm(기획서/산출물 규범)을 기계적으로 강제하는 목적—
issue #7의 `decides`/`use_when`과 직접 연결(전사 리스크 노출 판단이
directive 문언에만 의존하지 않고 게이트로 실제 검증됨).

## Assessment (erm-verdict)

- `risk-score-inherent`: medium — 4개 플러그인·4개 게이트 스크립트·4개
  테스트 스위트를 병렬 구현하는 규모이므로, 스크립트 골격 불일치나
  fail-open 버그가 발생할 표면적이 issue-1의 config-only 반영보다 넓음.
- `existing-controls`: 4개 플러그인 모두 동일한 fail-closed 트랩(`trap
  __fc EXIT`) + kill-switch-first + scope-regex-early-allow 골격을
  공유하도록 계약을 고정한 뒤 병렬 구현했고, 각 플러그인이 자체
  `hooks/tests/run-gate-tests.sh`로 allow/deny/malformed-JSON/Edit-mismatch/
  kill-switch 케이스를 실제 서브프로세스로 검증했다(§3, "반영 내역"
  절의 결과 표 참고). 모든 스크립트가 canon 스크립트 본문을 복사하지
  않고 경로로만 인용한다(§5, canon-reference-only).
- `risk-score-residual`: low — 4개 플러그인 전부 테스트 그린 상태로
  머지되었고, 각 게이트는 자기 scope regex 밖 쓰기에 대해 즉시 allow하여
  다른 플러그인·core 게이트와 충돌하지 않는다.
- `risk-appetite-threshold`: low 이하만 허용 (fail-open 버그, canon 복사,
  플러그인 경계 붕괴는 unacceptable).

## Response

Response tier: accept (risk-score-residual이 threshold 이내). Mitigation
owner: JiwonJung94. Mitigation plan: "반영 내역" 절에 명시된 대로 4개
플러그인 범위를 proposal §0 목록으로 엄격히 제한했고, open item 2건(§Open
items 2, 3)은 phase-2에서 확정하지 않고 다음 이슈로 이월했다.

## Monitoring

Review-date: 2026-09-15. 트리거: (a) core가 실제로
`core_role_directive`/`marketplace.json` cross-plugin dependency
메커니즘을 공개해 open item 1·2가 확정되는 경우, (b) 이 플러그인 세트의
게이트가 실제 세션에서 fail-open으로 동작하는 사례가 발견되는 경우.

## risk-register-entry

| Field | Value |
|---|---|
| `risk-id` | issue-7-phase2-plugin-scope |
| `risk-description` | phase-2 구현이 승인된 proposal의 4-플러그인 경계를 벗어나거나(예: 로직을 하나로 병합), core/pricing-rulebook/implementation-rulebook의 스크립트 본문을 복사하거나, 게이트가 fail-open으로 동작할 위험 |
| `risk-category` | operational |
| `likelihood` | low |
| `impact` | medium |
| `risk-score-inherent` | low-medium |
| `existing-controls` | 4개 플러그인 모두 동일한 fail-closed/kill-switch/scope-regex 골격을 공유하도록 사전에 계약을 고정(§0.4의 조합 메커니즘과 별개로, 게이트 골격 자체는 proposal §2 서술을 그대로 따름); 각자 독립 `run-gate-tests.sh`로 실제 서브프로세스 검증 완료 |
| `risk-score-residual` | low |
| `risk-appetite-threshold` | low 이하만 허용 (fail-open, canon 복사, 플러그인 경계 붕괴는 불허용) |
| `mitigation-owner` | JiwonJung94 |
| `mitigation-plan` | 4개 플러그인 구현을 proposal §0 목록으로 한정, 각자 자체 테스트로 검증, open item 1·2·3·4는 phase-2에서 확정하지 않고 이월 |
| `review-date` | 2026-09-15 |

## mitigation-owner

JiwonJung94

## 반영 내역 (upstream basis: docs/issue-7/proposals/risk-management-plugin-enforcement.md)

승인된 proposal §0 플러그인 목록 4건 전부, 그리고 §0.4의 조합 메커니즘을
적용했다.

1. **`erm-verdict-methodology/`** (신규 플러그인, proposal §0 row 1,
   §1.1, §2.1, §4) — `.claude-plugin/plugin.json`, `hooks/hooks.json`
   (PreToolUse: Write|Edit|MultiEdit), `hooks/erm-order-gate.sh` (ISO
   31000 §6.3-6.6 5단계 마커 순서·inherent/residual 구분 검사, kill
   switch `ERM_VERDICT_METHODOLOGY_GATE_OFF=1`), `hooks/tests/
   run-gate-tests.sh` (12 cases, 전부 통과), `docs/handbooks/
   erm-verdict-methodology/methodology.md`, `hooks/directive-fragment.sh`.
2. **`risk-register-methodology/`** (신규 플러그인, proposal §0 row 2,
   §1.2, §2.2, §4) — 동일 구조, `hooks/register-fields-gate.sh`
   (12필드 존재 + risk-category 허용값 + mitigation-owner/review-date
   placeholder 거부, kill switch `RISK_REGISTER_METHODOLOGY_GATE_OFF=1`),
   테스트 13 cases 전부 통과.
3. **`phase1-proposal-norms/`** (신규 플러그인, proposal §0 row 3,
   §1.3 phase1 절반, §2.3, §4, role-agnostic) —
   `hooks/proposal-shape-gate.sh` (phase-gate 문구 + survey 인용 경로
   존재 검사, kill switch `PHASE1_PROPOSAL_NORMS_GATE_OFF=1`), 테스트
   8 cases 전부 통과.
4. **`phase2-record-norms/`** (신규 플러그인, proposal §0 row 4, §1.3
   phase2 절반, §2.4, §4, role-agnostic) —
   `hooks/record-shape-gate.sh` ("Implements:" 백링크 검사, 동일
   issue 번호 일치 확인, Approve-marker 검증은 proposal §2.4의 open item
   그대로 스코프 밖으로 명시, kill switch `PHASE2_RECORD_NORMS_GATE_OFF=1`),
   테스트 8 cases 전부 통과.
5. **`risk-management/hooks/directive.sh`** — proposal §0.4대로 재구성:
   더 이상 단일 `--produces` 문자열에 방법론을 직접 기술하지 않고, 네
   플러그인의 `hooks/directive-fragment.sh`를 source해 함수 호출
   결과를 concatenate한 문자열을 `--produces`로 전달한다.
6. **`.claude-plugin/marketplace.json`** — 4개 플러그인 엔트리 신규
   등록 (`source`: 각 플러그인 디렉토리, 기존 `risk-management` 엔트리는
   그대로 유지).
7. **`README.md`** — Methodology 절을 "COSO ERM 5-component" 오표기에서
   ISO 31000:2018 process clauses(6.3-6.6)로 정정하고(이슈-7 proposal
   round-2 revision의 재귀속 근거를 그대로 인용), 플러그인 세트 표
   신설.
8. 캐논 참조만·복사 금지 준수: 4개 게이트 스크립트 헤더 주석 모두
   `pricing-rulebook/pricing/hooks/methodology-gate.sh`,
   `implementation-rulebook/coding/hooks/coding-progress-gate.sh`를
   경로로만 인용 — 본문 미복사 (proposal §5).
9. 상태 추적 파일 신설 없음 — proposal §2절 "State tracking" 판단대로,
   `erm-order-gate.sh`의 순서 검사는 단일 문서 내 position-비교만
   필요해 cross-write 상태 파일이 불필요하다.
10. 신규 agent 없음 — proposal §4 판단(반복 다단계 절차가 발견되지
    않음)을 phase-2에서도 유지.

## Open findings (이월, 미확정 — proposal의 Open items 그대로 승계)

1. `core_role_directive`가 fragment-concatenation 방식의 `--produces`
   인자를 실제로 받는지, 혹은 다른 조합 메커니즘이 필요한지 — core
   checkout이 이 레포에 없어 확인 불가 (issue-1 open item 1과 동일
   계열의 gap).
2. 플러그인 간 의존성(예: `risk-management`가 4개 플러그인에 의존한다는
   선언) 표기 메커니즘 — `plugin.json` 필드인지 README 컨벤션인지 이
   레포에 선례가 없어 미확정. 현재는 marketplace.json 공동 등록만으로
   구성.
3. `phase2-record-norms`의 Approve-marker 검증 가능 여부 — PreToolUse
   훅이 GitHub API 접근이 없어, 현재는 backlink 존재만 검사하고 Approve
   순서는 human-process 책임으로 남김 (proposal §2.4 그대로).
4. inherent-vs-residual "값이 실제로 다른가" 검사를 same-value-string
   비교를 넘어 더 정교하게 시도할지 여부 — 미결정 (proposal open item
   4 승계).
