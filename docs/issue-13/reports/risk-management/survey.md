# Issue-13 Survey: Gate A+ 재감사 잔여 결함 현황 (risk-management)

Scope: current-state findings only, no recommendations. This is the third gate-A+ remediation round for the risk-management rulebook set (issue-1 methodology → issue-7 plugin-set enforcement → issue-10 gate-A+ remediation round 1, which landed the canon migration to core's gate-lib → issue-13, this round, closing the 2026-08-01 re-audit's remaining defects). Covers the four plugins under this repo: `erm-verdict-methodology`, `risk-register-methodology`, `phase1-proposal-norms`, `phase2-record-norms`.

## A. Core preconditions (issue-75, issue-182) landed state

Both preconditions named in the issue body as "공통 선행 조건" are confirmed landed in the core plugin:

- **core #75** (gate-lib source guard + compliance-check detection + gate_bash_write_targets py parity): confirmed landed via `git -C <core> log --oneline -5` showing commit `52bdc15 "gate-lib source guard + gate_bash_write_targets py parity (issue-75)"`.
- **on-the-record #182** (CLAUDE_PLUGIN_ROOT_CORE injection by spawn.py): confirmed via the current session's environment — `env | grep -i core` shows `CLAUDE_PLUGIN_ROOT_CORE=/home/jwjung/.claude/plugins/marketplaces/tokenmaxxxer/runs/rulebooks/tokenmaxxxer-core/core` is set. No `CORE_PLUGIN_ROOT` variable is present in the environment.

### A.1 Canon source-guard shape (core/hooks/lib/gate-lib.sh header, lines ~1-20)

The core library's own header comment now specifies the required source-line idiom for any gate that sources it:

```
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "<gate-name>.sh: cannot source gate-lib.sh" >&2; exit 2; }
```

The comment states the rationale explicitly: an unguarded source that fails when core is unreachable runs no code — including no `gate_*` function definitions — after which every documented `gate_kill_switch_active ... || { exit 0; }` call site reads the resulting "command not found" (exit 127) as the kill switch being off, silently allowing everything. The guard is required to fail closed (exit 2) instead.

### A.2 core/hooks/tests/compliance-check.sh detection (lines ~51-59)

`compliance-check.sh` now statically FAILs any gate script matching `gate-lib\.sh"$` (sources gate-lib.sh with the source statement ending right after the closing quote) unless the same line also matches `gate-lib\.sh"[[:space:]]*\|\|` (an `||` immediately follows). Reason string emitted: "sources gate-lib.sh with no || guard on the same line — fail-open when core is unreachable (missing CLAUDE_PLUGIN_ROOT_CORE)".

### A.3 core/hooks/lib/gate-lib.py — gate_bash_write_targets (line 159)

`gate_bash_write_targets(command)` now exists in `core/hooks/lib/gate-lib.py`, documented as "Python mirror of gate-lib.sh's gate_bash_write_targets (issue-75)" — a Bash-command write-target scanner available for any gate that needs to inspect Bash tool invocations for file-write targets.

### A.4 This repo's four gate scripts against the above canon

Read directly (all four, current state on `issue-13/risk-management` branch):

| File | Source line (verbatim) |
|---|---|
| `erm-verdict-methodology/hooks/erm-order-gate.sh:11` | `. "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh"` |
| `risk-register-methodology/hooks/register-fields-gate.sh:15` | `. "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh"` |
| `phase1-proposal-norms/hooks/proposal-shape-gate.sh:17` | `. "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh"` |
| `phase2-record-norms/hooks/record-shape-gate.sh:31` | `. "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh"` |

All four are byte-identical in shape and both differ from the confirmed canon in two independent ways:

1. **No `||` guard.** Each line ends `gate-lib.sh"` with nothing following on the same statement — exactly the pattern `compliance-check.sh` now FAILs on (per A.2).
2. **Var name.** Each line reads `CORE_PLUGIN_ROOT` as the primary variable, with `$CLAUDE_PLUGIN_ROOT/../core` as fallback. The environment in this session (per A above) sets `CLAUDE_PLUGIN_ROOT_CORE` (issue-182's injected name), not `CORE_PLUGIN_ROOT`. Since `CORE_PLUGIN_ROOT` is unset, each gate falls through to its `$CLAUDE_PLUGIN_ROOT/../core` fallback rather than reading the value spawn.py actually injects.

A grep of all four `hooks/*-gate.sh` files for `Bash`, `write.target`, or `target.*path` patterns returned no matches — none of the four gates hand-roll a Bash write-target scan today, so there is no existing hand-rolled logic in this repo that duplicates `gate_bash_write_targets`.

## B. NotebookEdit dead branch (all four plugins)

`grep -n NotebookEdit */hooks/*-gate.sh` shows all four gate scripts' Python payload logic branch on `tool_name in ("Write", "Edit", "MultiEdit", "NotebookEdit")` and call `gate_lib.gate_reconstruct_write(tool_name, ...)`, which itself contains NotebookEdit-handling logic.

However, all four `hooks/hooks.json` files declare:

```
"matcher": "Write|Edit|MultiEdit"
```

— confirmed identical across `erm-verdict-methodology/hooks/hooks.json`, `phase1-proposal-norms/hooks/hooks.json`, `phase2-record-norms/hooks/hooks.json`, `risk-register-methodology/hooks/hooks.json`. None include `NotebookEdit`. Consequently the `NotebookEdit` branch inside each gate script's Python payload can never execute under normal hook dispatch — the matcher never routes a NotebookEdit tool call to the gate. This is a matcher/code coverage mismatch: the code path exists and is written to handle a tool the hook is never invoked for.

## C. phase1-proposal-norms test suite: Edit-reconstruction-denies coverage gap

Read directly: `phase1-proposal-norms/hooks/tests/run-gate-tests.sh`.

- Line ~100 (Case 6): "deny: Edit old_string not found" — an Edit whose `old_string` does not exist in the target file, expecting deny (exit 2). This exercises the "old_string not found" error path only, not content-shape denial after a successful reconstruction.
- The mandatory-test-case block (issue-10 §3, 6 per plugin) includes an Edit with `replace_all: true` (Case 1) and a MultiEdit with mixed `replace_all` true/false edits (Case 2). Both of these are constructed against content (`DUP_CONTENT`, `MULTI_CONTENT`) that already contains the phase-gate statement and survey citation, and both are asserted to ALLOW (exit 0).

No case in this file exercises: an Edit whose `old_string`/`new_string` substitution succeeds (old_string is found and replaced) and the resulting reconstructed content fails the phase-gate-statement or survey-citation shape check, expecting deny (exit 2). All current Edit-path test coverage is either (a) a deny on failure-to-find `old_string`, or (b) an allow on a still-compliant reconstruction. The path where a successful Edit reconstruction produces non-compliant content and gets denied is untested.

## D. Missing-core dynamic test case (all four suites)

Searched all four `hooks/tests/run-gate-tests.sh` files. None contain a test case that points `CLAUDE_PLUGIN_ROOT_CORE` (or `CORE_PLUGIN_ROOT`, per the var actually read — see A.4) at a nonexistent path and asserts the gate fails closed (exit 2) rather than allowing. No dynamic (execution-based) regression test exists in any of the four suites proving that a missing/unreachable core causes a deny; the fail-closed behavior described in core's gate-lib.sh header (A.1) is currently enforced only by the static `compliance-check.sh` FAIL rule (A.2), not reproduced by an executed test in this repo.

## E. README / manifest — old role names, ghost files

Every backtick-quoted file path in `README.md` was checked and resolves to a real file: `hooks/erm-order-gate.sh`, `hooks/hooks.json`, `hooks/proposal-shape-gate.sh`, `hooks/record-shape-gate.sh`, `hooks/register-fields-gate.sh`, `hooks/tests/run-gate-tests.sh`, and all referenced `plugin.json`/`marketplace.json` paths.

`.claude-plugin/marketplace.json`'s five plugin entries each point at a `./<dir>` source that matches one of the five actual plugin directories present in the repo.

A grep for `legacy|deprecated|old_role|risk-mgmt\b|COSO` across `*.md`/`*.json`/`*.sh` in the repo found no residual stale references. The one `COSO` mention in `README.md` is an intentional historical-correction note (already-fixed language from a prior round), not a residual defect.

Current-state result: the issue's fourth item ("README·manifest에 옛 역할명·유령 파일 잔재 0") holds against the repository as it stands at the time of this survey.
