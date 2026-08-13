---
axis: aggregation-consolidation
rule_count_floor: 10
---

# Risk aggregation / consolidation (removal-heavy axis)

## Decision rules

1. When combining scores across positively correlated risks (same root
   cause or shared dependency), do not sum their individual scores
   linearly — correlated risks concentrate rather than add
   independently, so a linear sum overstates diversification benefit
   that does not exist between them.
   source: https://www.britannica.com/money/concentration-risk-management
2. When a single counterparty, vendor, or asset class underlies several
   register entries, flag the set as a concentration risk and record
   the combined exposure as its own entry rather than leaving the
   concentration implicit across scattered individual entries — an
   implicit concentration is invisible to a reviewer scanning individual
   scores.
   source: https://www.britannica.com/money/concentration-risk-management
3. Removal: when two register entries describe the same underlying
   exposure from different angles (duplicate root cause, same trigger,
   same mitigation owner), merge them into one entry and delete the
   duplicate rather than tracking both — duplicate entries double-count
   the same exposure in any portfolio-level rollup.
   source: https://fastercapital.com/content/Risk-Aggregation-Data--How-to-Aggregate-and-Consolidate-Your-Risk-Data-across-Different-Sources-and-Dimensions.html
4. Removal: when a register entry's mitigation is complete, its
   residual score has been at the lowest band for multiple consecutive
   review cycles, and no recurrence trigger is credible, retire the
   entry (mark closed, remove from the active register view) instead of
   leaving stale near-zero entries in the active set — stale entries
   dilute a reviewer's attention on the risks that still matter.
   source: https://fastercapital.com/content/Risk-Aggregation-Data--How-to-Aggregate-and-Consolidate-Your-Risk-Data-across-Different-Sources-and-Dimensions.html
