---
axis: monitoring-review-cadence
rule_count_floor: 10
---

# Monitoring / review cadence selection

## Decision rules

1. When a register entry's residual score is High or Critical, set
   `review-date` to a monthly cadence; Medium to quarterly; Low to
   annual — as the default baseline before velocity adjustment (rule 2).
   source: https://sbnsoftware.com/blog/how-often-should-risk-assessments-be-reviewed-and-updated/
2. When a risk's velocity is high (it can materialize and start
   affecting objectives within days/weeks of a trigger event) shorten
   the baseline cadence from rule 1 by at least one tier (e.g. quarterly
   -> monthly) even if its score alone would not require it — cadence
   must track velocity in addition to score, not score alone.
   source: https://www.wolterskluwer.com/en/expert-insights/what-is-risk-velocity-and-should-you-track-it
3. When a material risk event occurs (a trigger condition fires, a
   control fails, a related risk's score changes), review that entry
   immediately regardless of its scheduled `review-date` — cadence is a
   ceiling on review interval, not a floor that defers an event-driven
   review.
   source: https://sbnsoftware.com/blog/how-often-should-risk-assessments-be-reviewed-and-updated/
4. Removal: when a Low-score, low-velocity entry has been reviewed on
   an unchanged cadence for multiple cycles with no score movement and
   no active mitigation-plan progress expected, drop its review
   frequency to the longest tier (annual/biennial) rather than
   continuing a shorter legacy cadence set when its score was higher —
   do not carry forward a review frequency the entry's current risk
   profile no longer justifies.
   source: https://sbnsoftware.com/blog/how-often-should-risk-assessments-be-reviewed-and-updated/
5. When a mitigation control is marked complete, trigger an immediate
   residual-risk re-score and re-derive the review cadence from that
   fresh residual score — do not let the entry keep the cadence set
   from its pre-mitigation (inherent) score, since the whole point of
   the completed control was to change the risk the entry represents.
