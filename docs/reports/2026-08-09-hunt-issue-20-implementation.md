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
