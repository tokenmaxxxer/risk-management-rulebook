---
proposal: docs/issue-20/proposals/implementation.md
---

# Hunt record — issue-20-implementation

## after-proposal — stance 3: assume the rule as written cannot hold — find the state nothing maintains

Verdict: FINDING — proposal designates docs/specs/record-fields-terminal-states.json as the loop_state authority, but no hook in this repo's own frozen write set (or elsewhere in-tree) reads loop_state, docs/specs/, or a terminal/progress/refusal/error shape at all — the file would be state nothing in this repo maintains or consumes.
Kind: design-error
Seed: docs/issue-20/proposals/implementation.md lines 112-140 ("What will be done" item 1, new docs/specs/record-fields-terminal-states.json); compared against risk-management/hooks/directive.sh, erm-verdict-methodology/hooks/directive-fragment.sh, risk-register-methodology/hooks/directive-fragment.sh (the proposal's own frozen write set)
cap_seconds: 120
tier: default
diff_stat_lines: 2 new untracked files under docs/issue-20/ (proposal + survey), no code diff
started_at: 2026-08-09T05:50:46+09:00
ended_at: 2026-08-09T05:53:30+09:00

### Reproduce
```
cd /home/jwjung/.tokenmaxxxer/work/risk-management-rulebook-issue-20-implementation
grep -n "loop_state\|specs/\|terminal" risk-management/hooks/directive.sh erm-verdict-methodology/hooks/directive-fragment.sh risk-register-methodology/hooks/directive-fragment.sh
# -> no output, no match in any of the three planned-to-be-touched hook scripts
find . -path ./.git -prune -o -iname "*.sh" -print | xargs grep -l "loop_state\|docs/specs/record-fields" 2>/dev/null
# -> no output anywhere in the repo
```

### Observed
Zero matches: none of the shell hooks this proposal plans to touch (or any other hook in the repo) reads `loop_state`, `docs/specs/`, or the `{progress, terminal, refusal, error}` shape the proposal says the new file will use. The proposal justifies the new file by pointing to "canon core" and sibling repos (`content-design-rulebook`, `api-design-rulebook`) as the mechanism that reads this per-repo override — but that consuming mechanism is not present in this repo's own tree, so the new file's loop_state override would be inert here: any hook enforcement of loop_state vocabulary this proposal implies is state nothing in this repo currently maintains.

### Expected
Either the proposal should identify the actual in-repo (or vendored-canon) code path that reads `docs/specs/record-fields-terminal-states.json` before naming it as the target, or it should state explicitly that the file is doctrine-only with no live consumer in this repo (the same gap it used to disqualify writing into `RECORD_FIELDS_TERMINAL_STATES`).

## before-landing — stance 3: assume the rule as written cannot hold — find the state nothing maintains

Verdict: FINDING — directive text asserts risk_id/owner reference-resolution is "checked elsewhere (`on-the-record/hooks/role-spec-reference-guard.sh`)", but neither an `on-the-record` plugin nor that script exists anywhere in this repo (nor does `roles/specs/risk-management.spec.json`, the spec file the mapping is supposedly derived from).
Kind: design-error
Seed: git diff main -- risk-register-methodology/hooks/directive-fragment.sh erm-verdict-methodology/hooks/directive-fragment.sh risk-management/hooks/directive.sh README.md
cap_seconds: 120
tier: default
diff_stat_lines: ~90 (4 files changed)
started_at: 2026-08-09T00:00:00Z
ended_at: 2026-08-09T00:03:00Z

### Reproduce
```
find . -iname "role-spec-reference-guard.sh"
find . -iname "*on-the-record*"
find . -iname "risk-management.spec.json"
```

### Observed
All three commands return empty — no such directory, script, or spec file exists in the repository at all. Yet both `risk-register-methodology/hooks/directive-fragment.sh` and the inlined copy in `risk-management/hooks/directive.sh` state as authoritative doctrine: "`risk_id`/`owner` reference-resolution is checked elsewhere (`on-the-record/hooks/role-spec-reference-guard.sh`), not by this plugin's gate" — presenting a real, currently-enforced check that in fact does not exist anywhere the repo (or its stated marketplace realization) can be inspected. The doctrine's coverage claim ("reference-resolution IS checked, just not here") has no maintaining code; nothing enforces `risk_id`/`owner` reference-resolution at all, silently, for any document that satisfies this rulebook's gate.

### Expected
Either the referenced script/plugin should exist and actually perform the claimed check, or the directive text should not assert coverage by a named, non-existent enforcement point — it should state the gap honestly (as the sibling `loop_state` deviation note in README.md does) rather than implying a check exists that nothing in this repo maintains.
