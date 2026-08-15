---
axis: appetite-tolerance-threshold
rule_count_floor: 10
---

# Risk appetite / tolerance threshold setting

## Decision rules

1. When setting `risk-appetite-threshold` for a register entry, derive
   it from the entity-level appetite statement decomposed for that
   risk's category/objective — do not set a category threshold
   independently of the entity-level appetite statement; tolerance is
   appetite broken down per category/objective, not a second, freestanding
   number.
   source: https://www.wolterskluwer.com/en/expert-insights/risk-appetite-and-risk-tolerance-whats-the-difference
2. When a risk's objective is strategic/business-model-level (e.g.
   market entry), express its threshold in appetite terms (broad,
   qualitative risk-acceptance posture); when the objective is
   operational/day-to-day, express its threshold in tolerance terms
   (a measurable variation band in the objective's own units) — using
   an appetite-style qualitative band for an operational threshold makes
   it unmeasurable against the register's numeric residual score.
   source: https://www.fieldguide.io/resource-articles/what-is-risk-tolerance
3. When multiple risk categories interact (e.g. financial + regulatory
   on the same initiative), set the combined threshold from a portfolio
   view of how the categories cascade, not from summing each category's
   independent threshold — independent per-category thresholds miss
   cascade effects between categories.
   source: https://quantivate.com/developing-risk-appetite-and-tolerances/
4. Removal: when a category-level tolerance threshold was set without
   ever tracing back to an entity-level appetite statement, do not
   carry it forward into the next register cycle — retire it and
   re-derive from the current appetite statement, since an
   un-traceable threshold cannot be checked for staleness against
   subsequent appetite changes.
   source: https://www.wolterskluwer.com/en/expert-insights/risk-appetite-and-risk-tolerance-whats-the-difference
5. When a category's threshold is bound by an external regulatory or
   contractual limit (a specific clause, control ID, or numeric cap in
   a named framework), cite that exact clause/control ID on the
   threshold entry instead of stating only the entity-level appetite
   band it was decomposed from — a threshold traceable only to a
   generic appetite band cannot be checked against the specific
   external requirement that actually constrains it when that
   requirement changes.
