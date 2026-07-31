# Record: risk-management / issue-1

Subject: issue-1 — 룰북 성숙화: risk-management 도메인 방법론 조사 기반
제안서·산출물 규범 수립

loop_state: landed

## What was done

Phase-2 반영: 승인된 proposal
(`docs/issue-1/proposals/risk-management-methodology.md`, upstream basis)의
"Plugin reflection plan" (d)항 중 phase-2 실행 대상 3건
(`risk-management/hooks/record-fields.json`,
`risk-management/hooks/directive.sh`, `README.md`)을 적용 완료. 상세는
"반영 내역" 절 참고.

## Why (rationale)

Phase-1에서 조사·채택한 COSO ERM + ISO 31000 방법론 규범을 실제 게이트
설정과 directive 문언, 문서에 반영해 이 룰북이 조사 근거 없는 감이 아니라
확정된 방법론을 강제하도록 하기 위함 (issue-1 목적).

## erm-verdict

허용 범위 내. Phase 2 반영은 승인된 proposal
(`docs/issue-1/proposals/risk-management-methodology.md`) 범위를 벗어나지
않으며, 플러그인 설정값(required_fields, --produces 문자열)과 README 문서
갱신에 한정된다 — 실행 로직(게이트 스크립트) 신설이나 core canon 복사가
없으므로 전사 리스크 노출 없음. Governance/context: 이슈-1 phase-1 승인
(2026-07-31, JiwonJung94, `APPROVE issue-1/risk-management`). Objective
linkage: 이 역할의 산출물 규범을 조사 근거로 확정하는 목적 달성. Response
tier: 없음 (조치 불요, 완료 처리).

## risk-register-entry

| Field | Value |
|---|---|
| `risk-id` | issue-1-phase2-scope-creep |
| `risk-description` | phase-2 반영 작업이 승인된 proposal 범위를 넘어 core canon을 복사하거나 새 게이트 로직을 만들 위험 |
| `risk-category` | operational |
| `likelihood` | low |
| `impact` | medium |
| `risk-score-inherent` | low-medium |
| `existing-controls` | proposal의 "Plugin reflection plan"이 변경 대상 파일과 각 변경의 근거를 사전에 명시함; core의 record-fields 게이트가 `required_fields`를 제네릭하게 읽으므로 신규 게이트 스크립트 불필요 |
| `risk-score-residual` | low |
| `risk-appetite-threshold` | low 이하만 허용 (신규 게이트 로직·core 복사 없음) |
| `mitigation-owner` | JiwonJung94 |
| `mitigation-plan` | 실제 반영을 proposal (d)항 목록 3건(record-fields.json, directive.sh, README.md)으로 한정하고, open item 2건(core 게이트 시맨틱, RECORD_FIELDS_TERMINAL_STATES)은 미확정 상태로 남겨 후속 이슈에서 확인 |
| `review-date` | 2026-08-31 |

## mitigation-owner

JiwonJung94

## 반영 내역 (upstream basis: docs/issue-1/proposals/risk-management-methodology.md)

승인된 proposal (a)~(d) 항 중 phase-2 실행 대상(플러그인 반영)만 적용:

1. `risk-management/hooks/record-fields.json` — `required_fields`를
   기존 3필드 flat list에서 proposal (b)항 스키마 12필드로 확장
   (`risk-id`, `risk-description`, `risk-category`, `likelihood`,
   `impact`, `risk-score-inherent`, `existing-controls`,
   `risk-score-residual`, `risk-appetite-threshold`, `mitigation-owner`,
   `mitigation-plan`, `review-date`, `erm-verdict`). 기존
   `risk-register-entry` 단일 필드는 이 스키마로 대체됨 (proposal
   (b)항: "an opaque blob into a schema").
2. `risk-management/hooks/directive.sh` — `--produces` 값을 채택 방법론
   (COSO ERM 5-component, ISO 31000 스키마)을 명시하도록 갱신.
3. `README.md` — "Methodology" 섹션 신설: COSO ERM + ISO 31000 페어링,
   근거 요약, 레지스터 스키마 표, 범위 제외 항목(정량 모델링,
   히트맵 툴링) 명시.
4. 신규 게이트 스크립트 없음 — core의 record-fields 게이트가
   `required_fields`를 제네릭하게 읽으므로 설정값 확장만으로 충분
   (proposal (d)-4).
5. `RECORD_FIELDS_TERMINAL_STATES`는 `[]` 유지 — proposal이 flagged한
   open item 3 (risk-appetite-exception terminal state)은 core 게이트
   시맨틱 확인 전까지 결정하지 않음.

## Open findings (이월, 미확정)

1. `core_role_directive`가 별도의 methodology-naming 인자를 받는지,
   아니면 `--produces` 문자열과 README 산문에만 존재하는지 — core
   checkout 없이는 확인 불가.
2. core의 record-fields 게이트가 `required_fields`를 flat
   key-presence 체크로 검증하는지, nested/typed 스키마를 지원하는지 —
   이번 12필드 확장이 1:1로 매핑되는지 여부를 결정함.
3. `RECORD_FIELDS_TERMINAL_STATES`에 "risk-appetite-exception" terminal
   state를 추가할지 — core 게이트 시맨틱 확인 후 별도 이슈로 처리.
