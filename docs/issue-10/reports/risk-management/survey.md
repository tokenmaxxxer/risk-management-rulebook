# Survey: risk-management gate A+ remediation — issue-10

Subject: issue-10, current-state findings for
`docs/issue-10/proposals/risk-management-gate-a-plus-remediation.md`.

## Scope

Four self-contained plugins landed under issue-7
(`erm-verdict-methodology`, `risk-register-methodology`,
`phase1-proposal-norms`, `phase2-record-norms`), each with its own
PreToolUse gate script. This survey reads all four gate scripts plus
`README.md` against the issue-10 audit findings and the core gate-house
standard (core issue #72, landed).

## Core canon available for reference (not reimplementation)

`core/hooks/lib/gate-lib.sh` (+ sibling `gate-lib.py`) and
`docs/handbooks/gate-house-standard.md` are landed in core and provide,
per the handbook: `gate_trap_fail_closed`, `gate_kill_switch_active`,
`gate_deny`/`gate_allow` (bash); `gate_parse_json_or_deny`,
`gate_normalize_path`, `gate_reconstruct_write` (Python, honors
per-edit `replace_all` and reconstructs `NotebookEdit`); and
`gate_bash_write_targets` (bash, token-scan for Bash-tool writes). The
handbook also names a mandatory six-case test harness shape and a
`compliance-check.sh` detector for exactly the defect classes issue-10
flags.

## Confirmed defects, per gate script

### 1. Internal-judge-crash = fail-open (issue's headline finding)

`erm-verdict-methodology/hooks/erm-order-gate.sh:134` and
`phase1-proposal-norms/hooks/proposal-shape-gate.sh:145` both do:

```
result="$(printf '%s' "$payload" | python3 "$PYSCRIPT" ... 2>/dev/null)"
...
if [ "$verdict" = "DENY" ]; then ...; fi
exit 0
```

Neither checks the python3 subprocess's own exit code. If the embedded
Python payload raises an uncaught exception (a bug in the section-
adjacency/structure logic itself, not a payload-shape problem already
guarded by the outer `try/except` around `json.load`), python3 exits
non-zero, `result` is empty, `verdict` is `""` (not `"DENY"`), and
execution falls through to the unconditional `exit 0` at the bottom —
**allow**. This is exactly the audit's "erm-order 내부 판정기 크래시=allow"
finding, and it recurs identically in `phase1-proposal-norms`'s gate.

By contrast, `risk-register-methodology/hooks/register-fields-gate.sh:207-210`
and `phase2-record-norms/hooks/record-shape-gate.sh` (no `2>/dev/null`,
Python heredoc runs without a discarding redirect, `if [ -z "$RESULT" ]`
checked, unrecognized `$DECISION` treated as deny) already fail closed on
an empty/crashed result — these two are not vulnerable to this bug, but
they don't use `gate_trap_fail_closed`/`gate_parse_json_or_deny` either,
so they duplicate (imperfectly) what the canon lib centralizes.

### 2. COSO vocabulary markers inside a gate that asserts ISO 31000

`erm-order-gate.sh:99-105`:

```python
STAGES = [
    "## Governance/context",
    "## Objective linkage",
    "## Assessment",
    "## Response",
    "## Monitoring",
]
```

`docs/handbooks/erm-verdict-methodology.md` and the plugin's own header
comment claim ISO 31000:2018 process clauses (6.3-6.6). "Objective
linkage" and "Response" are COSO ERM 2017 component-adjacent vocabulary
(Strategy & Objective-Setting; the COSO "Review & Revision"/"Performance"
naming lineage), not ISO 31000 clause names (6.4 Risk assessment covers
identification/analysis/evaluation; 6.5 Risk treatment is the ISO term
for what this gate calls "Response"). The gate's own `## Objective
linkage` / `## Response` heading names contradict the methodology label
it enforces — a document could satisfy the gate's headings while still
reading as COSO-flavored, undermining the ISO 31000 claim the gate
exists to check.

### 3. Semantic checks are substring/regex, not section/adjacency/structure

All four gates check presence via `content.find(marker)` /
`re.search(field_pattern)` against the **whole document string**, with
no enforcement that:
- a marker actually starts a Markdown section (vs. appearing mid-
  sentence, in a quote, or inside a code fence);
- a required field's value sits under the section it semantically
  belongs to (e.g. `risk-score-inherent` could appear anywhere in the
  document and still satisfy `register-fields-gate.sh`'s
  `field_value()` regex);
- adjacent/related markers are structurally adjacent, not just present
  in file order (`erm-order-gate.sh` does check *order* via `content.find`
  index comparison, which is a partial structural check, but no
  section-boundary check — a marker inside a fenced code block or
  blockquote still counts).

This is exactly the "부분문자열 통과" gap issue-10 §2 names.

### 4. `Edit`/`MultiEdit`/`replace_all` reconstruction

All four gates reconstruct `Edit`/`MultiEdit` via
`existing.replace(old, new, 1)`, ignoring the real `Edit`/`MultiEdit`
call's own `replace_all` field entirely — this is core issue #72's bug
class 2, confirmed present in identical form across all four rulebook
gates (each independently re-derived the same wrong idiom, per the
gate-house-standard handbook's premise that the 43-repo audit found
repeated, not isolated, defects). None handle `NotebookEdit`.

### 5. Kill switch

All four use `[ "$X" = "1" ]` / `[[ "$X" == "1" ]]` — only the literal
string `"1"` disables; every other value (including `true`/`yes`/`on`)
stays active. This differs from `gate_kill_switch_active`'s canon
convention (recognizes `1`/`true`/`yes`/`on` case-insensitively as the
only disabling set) but does not reproduce core's pre-#72
unrecognized-value-disables bug — these four gates already fail toward
"stay active" on anything but `"1"`. Still non-compliant with the now-
canonical function signature/behavior, and `compliance-check.sh` would
likely flag the hand-rolled `*_OFF` read (per the handbook's detector
description) regardless of which direction the bug runs.

### 6. Path normalization

Each gate hand-rolls `os.path.isabs(...)` +
`os.path.relpath(file_path, project_dir)` (or a `startswith` check in
`register-fields-gate.sh`), not the canon `gate_normalize_path`. Not
independently confirmed broken by inspection, but per the gate-house
standard's premise (six repo-wide defect *classes*, not isolated bugs)
and the issue's explicit ask ("절대경로 정규화"), this is exactly the
shape `gate_normalize_path` exists to replace — a self-derived
normalizer is the risk surface even where today's fixture set happens
to pass.

### 7. README

Not yet compared line-by-line against the four-plugin reality in this
survey (deferred to phase-2 remediation per issue's item 4); flagged
here only as confirmed in-scope from the issue text.

## Gap line

The four gates already have: fail-closed traps on unexpected exit
(`__fc`/trap EXIT, correctly wired for shell-level crashes), kill-switch-
first ordering, per-plugin test suites (all green as of issue-7 landing),
and canon-reference-only header comments (no script body copied). What
they lack, matching the core gate-house standard point for point: (a)
canon `gate-lib.sh`/`gate-lib.py` sourcing (all four hand-roll every
function the lib now centralizes); (b) `replace_all`/`NotebookEdit`-
honoring reconstruction; (c) subprocess-exit-code-checked fail-closed on
Python-level crashes (2 of 4 gates only); (d) section/adjacency-aware
semantic checks in place of whole-document substring/regex; (e) the
ISO 31000-only vocabulary fix in `erm-order-gate.sh`'s `STAGES` list.

## Sources

- `erm-verdict-methodology/hooks/erm-order-gate.sh` (this repo)
- `risk-register-methodology/hooks/register-fields-gate.sh` (this repo)
- `phase1-proposal-norms/hooks/proposal-shape-gate.sh` (this repo)
- `phase2-record-norms/hooks/record-shape-gate.sh` (this repo)
- `docs/issue-7/reports/risk-management.md` (this repo, prior landing record)
- core `hooks/lib/gate-lib.sh`, `docs/handbooks/gate-house-standard.md`
  (core issue #72, landed; read from local core reference checkout)

## Scout: skipped

Skip condition: core's gate-house standard (issue #72, landed) already
fixes the exact defect classes issue-10 names and hands down a concrete
API (`gate_*` functions) and mandatory test-case shape — there is no
open design decision left for this rulebook to make beyond migrating to
that canon and upgrading the semantic-check granularity issue-10 asks
for, both of which are spec-fixed, not exploratory. No product-shaped
field-scan is applicable.
