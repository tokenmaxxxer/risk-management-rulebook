# Scout Brief — issue-1 (risk-management domain methodology)

Mode: parallel WebSearch, 4 angles, 1 round (sweep only; judge point 1 showed
strong convergence across all four searches, no decision-relevant new
information expected from further deepening → stopped, saturation rule).

## Category must-bes (converged across sources)

- A named, published risk assessment **methodology** (not ad hoc judgment):
  COSO ERM 2017's 5 components / 20 principles, or ISO 31000's iterative
  process (establish context → identify → analyze → evaluate → treat →
  monitor/review, with communication/consultation throughout).
- **Risk appetite** stated and overlaid on scoring, not scoring done in a
  vacuum — GARP, MetricStream both flag appetite-disconnected scoring as a
  known failure mode.
- **Likelihood x impact** scoring producing a risk score, visualized as a
  heat map for prioritization.
- **Inherent vs. residual risk** scored separately — the gap between them is
  what shows whether controls actually work (SureCloud, Rocketlane).
- Risk register as the canonical artifact, with a stable minimum field set:
  risk ID, description, category, likelihood, impact, risk score, owner,
  existing controls, mitigation/treatment plan, status, review/due date
  (SureCloud, Rocketlane, Optial, TrustCloud all converge on this set).
- **Named owner** for both the risk overall and each mitigation action —
  "risks without a clearly accountable person rarely move forward"
  (SureCloud).

## Performance axes strong sources compete on

1. Whether appetite is a decorative statement vs. actually overlaid on the
   scoring/heat map (weak practice states appetite once and never revisits
   it against live scores).
2. Whether inherent/residual are tracked as two distinct numbers vs. one
   post-hoc "current risk level" (the two-number version is what exposes
   whether a control is real).
3. Depth of ownership: risk owner only, vs. risk owner + per-action owner +
   due date + review cadence (the latter is what "best practice" sources
   treat as maturity signal, not baseline).

## Adopt / skip

- **Adopt**: COSO ERM's 5-component structure for the *proposal's* section
  scaffolding (governance/context, objective-linkage, assessment
  methodology, response, monitoring) — it maps cleanly onto "what a
  phase-1 proposal must justify" and is the most widely cited enterprise
  (vs. project-only) framework, matching this role's `use_when` (재무/운영/전략
  리스크, broader than feasibility).
- **Adopt**: ISO 31000's process steps + risk register minimum field set for
  the *phase-2 deliverable's* required components — it's the more
  operational, artifact-focused of the two standards and pairs naturally
  with COSO's governance framing (COSO = why/how you govern risk; ISO 31000
  = the concrete process and register that produces evidence).
- **Adopt**: inherent/residual dual scoring — cheap to require, closes a
  known failure mode (single fake "current level" number).
- **Skip**: quantitative/actuarial risk modeling (VaR, Monte Carlo) — no
  source treated this as baseline; it's a specialized technique layered on
  top of the qualitative likelihood x impact process for specific risk
  types, not something every ERM verdict needs.
- **Skip**: reproducing full heat-map visual tooling — this role produces
  text/markdown records, not a dashboard; the heat-map *logic* (appetite
  threshold triggers a response tier) is adopted, the visualization is not.

## Gap line (current repo state vs. field must-bes)

Current `record-fields.json` requires only `erm-verdict`,
`risk-register-entry`, `mitigation-owner` — three fields, one register
entry, one owner. Field must-bes not yet present: explicit
likelihood/impact/risk-score fields, inherent-vs-residual distinction,
existing-controls field, review/due-date field, and any stated risk-appetite
threshold the verdict is judged against. Directive.sh's `produces` line
("ERM verdict, risk register entry, mitigation owner") already gestures at
COSO/ISO vocabulary but the plugin does not yet enforce or even name a
methodology — this is the gap phase 2 closes.

## Sources

- https://erm.ncsu.edu/resource-center/cosos-erm-framework/
- https://sprinto.com/blog/coso-erm/
- https://www.smartsheet.com/content/iso-31000-templates
- https://lumiformapp.com/templates/iso-31000-risk-register-template_35592
- https://www.garp.org/risk-intelligence/culture-governance/how-to-develop-an-enterprise-risk-rating-approach
- https://www.metricstream.com/learn/risk-heat-map.html
- https://www.surecloud.com/resource-hub/risk-registers-guide
- https://www.rocketlane.com/blogs/risk-register-template
