# risk-register-methodology handbook

Source: `docs/issue-7/proposals/risk-management-plugin-enforcement.md` §1.2
(directive fragment content) and §2.2 (gate business logic). This plugin
owns the ISO 31000 risk-register 12-field schema for the `risk-register-entry`
facet — a distinct concern from `erm-verdict-methodology`'s per-document
process shape (see the proposal's §0.1 "content vs. process-shape"
separation).

## The 12-field schema

`risk-id`, `risk-description`, `risk-category`, `likelihood`, `impact`,
`risk-score-inherent`, `existing-controls`, `risk-score-residual`,
`risk-appetite-threshold`, `mitigation-owner`, `mitigation-plan`,
`review-date` — the same field set already declared in
`risk-management/hooks/record-fields.json`. That file's generic gate checks
presence only; this plugin's gate (`hooks/register-fields-gate.sh`) is
intentional defense-in-depth on top of it, adding per-field **value**
judgment criteria the generic gate cannot express.

## Why inherent-vs-residual dual scoring matters

Scoring risk once, after controls, collapses the very thing a register is
supposed to expose: whether existing controls are doing anything.
Requiring `risk-score-inherent` and `risk-score-residual` as two distinct
labeled fields (never the same line reused) mirrors the field's own
best-practice literature — a single post-hoc "current risk level" number is
a known anti-pattern that hides ineffective controls behind a
plausible-looking score. This is a presence-and-distinctness check only;
this plugin does not judge whether the two numbers are *correctly* related
to each other, which stays a human judgment call.

## Why mitigation-owner and review-date reject placeholder tokens

`docs/issue-1/reports/risk-management/scout-brief.md` names this directly:
"risks without a clearly accountable person rarely move forward." A
register entry with `mitigation-owner: TBD` or `review-date: unassigned`
looks complete to a presence-only check but has not actually assigned
accountability or a monitoring trigger — exactly the accountability gap
the scout brief flags as a convergent failure mode across sources. The gate
therefore denies the literal placeholder tokens `""` (empty), `tbd`,
`unassigned`, and `n/a` (case-insensitive, trimmed) for these two fields
specifically. This is a mechanical check, not semantic verification — it
catches known placeholder strings, not "is this a real, identifiable
person." A bare team name (e.g. "Platform Team") is explicitly out of
scope for this check per the proposal §1.2; only the literal placeholder
tokens above are caught.

## The risk-category allowed-values + justification convention

`risk-category` must be one of four named categories — `strategic`,
`operational`, `financial`, `regulatory` (case-insensitive) — or carry an
explicit justification marker. This plugin's documented convention: the
field's value line must contain the literal substring `(justified:`
somewhere after the category text, e.g.:

```
risk-category: reputational (justified: brand-facing incident with direct revenue exposure)
```

Any category value not in the allowed set and without this marker is
denied, naming the offending value in the deny message. This keeps the
schema from silently admitting arbitrary free text while still allowing a
genuinely novel category when an author is willing to state why the four
named ones don't fit.

## Why fields stay qualitative-or-numeric free text

Per the proposal's round-2 revision (open item 5): no canon-wide
likelihood/impact matrix, numeric scoring scale, or appetite-scale
convention exists anywhere else in this repo (`core/`,
`implementation-rulebook/`, `pricing-rulebook/` were all searched, no hit).
`likelihood`, `impact`, `risk-score-inherent`, `risk-score-residual`, and
`risk-appetite-threshold` therefore stay free text — qualitative ("medium",
"high") or numeric, either satisfies this plugin's gate — rather than this
plugin inventing a scale no other canon source mandates. If a future issue
establishes a repo-wide risk-scoring scale, this gate's checks (currently
presence-and-value-category only, no value-range validation) would need
revisiting to adopt or explicitly decline it.
