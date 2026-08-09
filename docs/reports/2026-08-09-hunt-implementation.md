---
proposal: docs/issue-23/proposals/implementation.md
---

# Hunt record — implementation

## before-landing — stance 0: assume the gate/change just made is bypassable — find the bypass

Verdict: FINDING — resolve_core accepts any non-empty gate-lib.sh with no validation of content, and the production gate script sourcing that file is not fail-closed against missing functions: a stale/incompatible core resolved this way makes proposal-shape-gate.sh silently ALLOW (exit 0) payloads it should DENY (exit 2).
Kind: composition
Seed: git diff cdf4629..HEAD -- phase1-proposal-norms/hooks/tests phase2-record-norms/hooks/tests erm-verdict-methodology/hooks/tests risk-register-methodology/hooks/tests docs/handbooks (resolve-core.sh addition + run-gate-tests.sh wiring)
cap_seconds: 120
tier: default
diff_stat_lines: ~90 (4x resolve-core.sh new files + run-gate-tests.sh wiring + 4x handbook doc additions)
started_at: 2026-08-09T00:00:00Z
ended_at: 2026-08-09T00:20:00Z

### Reproduce
```
REPO=/home/jwjung/.tokenmaxxxer/work/risk-management-rulebook-issue-23-implementation
mkdir -p "$REPO/core/hooks/lib"
printf '# totally bogus core, not the real gate-lib\n' > "$REPO/core/hooks/lib/gate-lib.sh"
unset CLAUDE_PLUGIN_ROOT_CORE
export CLAUDE_PLUGIN_ROOT_CORE="$REPO/core"
printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"docs/issue-9/proposals/foo.md","content":"no gate stuff at all"}}' \
  | bash "$REPO/phase1-proposal-norms/hooks/proposal-shape-gate.sh"; echo "EXIT=$?"
rm -rf "$REPO/core"
```
(Equivalently: run `bash phase1-proposal-norms/hooks/tests/run-gate-tests.sh` with the same bogus `$REPO/core/hooks/lib/gate-lib.sh` present as a sibling candidate and `CLAUDE_PLUGIN_ROOT_CORE` unset — `resolve_core` picks it up via the sibling-candidate path exactly the same way.)

### Observed
`resolve_core` returns exit 0 and resolves to `$REPO/core` purely because `hooks/lib/gate-lib.sh` is non-empty (`[ -s ... ]`), with zero check that it defines the functions the gate depends on (`gate_trap_fail_closed`, `gate_kill_switch_active`, etc.). Sourcing that bogus file inside `proposal-shape-gate.sh` succeeds (a comment-only file sources cleanly, so the script's `|| exit 2` guard on the `.` never fires). The script then continues past `command not found` errors for the missing functions (only `set -u` is active, not `set -e`) and falls through to its default ALLOW path.

Running the full harness with this bogus core in place and `CLAUDE_PLUGIN_ROOT_CORE` unset (so `resolve_core` falls through to the sibling candidate) produces:
```
FAIL: deny: phase-gate statement missing (expected exit 2, got 0; output: .../proposal-shape-gate.sh: line 18: gate_trap_fail_closed: command not found
.../proposal-shape-gate.sh: line 21: gate_kill_switch_active: command not found)
...
Summary: 9 passed, 10 failed
```
Every case that should DENY (exit 2) instead returns exit 0 (ALLOW) once the sourced gate-lib.sh is broken/incompatible — i.e. the gate fails OPEN, not closed, against a corrupt/incompatible core dependency. The test harness happens to catch this as FAIL because it asserts exact exit codes, but the underlying production gate script itself has no fail-closed guard past the initial `.` sourcing step — so any real-world scenario that lands resolve_core (or the direct `CLAUDE_PLUGIN_ROOT_CORE` sourcing path it mirrors) on a non-empty-but-stale/incompatible gate-lib.sh (partial checkout, version skew between plugin and core, a differently-shaped file that happens to satisfy `-s`) turns every deny case into a silent allow in production, where there is no test harness comparing exit codes to catch it.

### Expected
Either `resolve_core` should validate that the candidate's `gate-lib.sh` actually defines the required functions (not just that it's non-empty) before accepting it, or `proposal-shape-gate.sh` (and its siblings) should fail closed if any expected `gate_*` function is undefined after sourcing — currently a bogus/incompatible-but-non-empty gate-lib.sh silently converts every DENY case into ALLOW.
