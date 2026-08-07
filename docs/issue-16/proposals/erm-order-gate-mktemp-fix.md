---
status: proposed
files:
  - erm-verdict-methodology/hooks/erm-order-gate.sh
  - erm-verdict-methodology/hooks/tests/run-gate-tests.sh
---
## Request

`erm-order-gate.sh` writes its inline Python judge to a scratch file via a bare `mktemp` (line 31) before invoking it. Under a sandboxed Claude Code role session where the platform tmp directory is outside the writable set, that `mktemp` write is denied, the gate's fail-closed trap fires, and every erm-verdict write is denied regardless of what is actually being written. Fix the gate to stop depending on a writable scratch file at runtime.

## Constraints

- Must preserve the exact current behavior/output contract: `ALLOW::`/`DENY::` verdict lines, the existing `gate_deny`/`gate_allow` call sites, and all exit codes must be unchanged.
- All existing test cases in `erm-verdict-methodology/hooks/tests/run-gate-tests.sh` must still pass unchanged, per the issue's acceptance criteria.
- No `mktemp` may remain anywhere in the gate's runtime path (i.e., in `erm-order-gate.sh` itself).
- Must not introduce a new dependency (no new binaries, no new Python packages).

## Rationale

**Chosen approach:** pass the JSON payload and the resolved project root into the Python judge via environment variables (`GATE_PAYLOAD`, `GATE_PROJECT_DIR`), and pipe the Python source itself directly to `python3` as a heredoc on stdin — eliminating the scratch file entirely. The file's own existing comment (lines 27-30) already correctly identifies why a direct heredoc wasn't used previously: a heredoc attached to a command consumes that command's stdin, so if the heredoc is the invocation's stdin, `$payload` can no longer also be piped in on stdin. Routing the payload through an environment variable instead of stdin removes the contention: the heredoc supplies the Python source (as it always effectively has, just previously staged through a file), and the judge reads `os.environ["GATE_PAYLOAD"]` in place of `sys.stdin.read()`, and `os.environ["GATE_PROJECT_DIR"]` in place of `sys.argv[1]`. No filesystem write is required anywhere in the runtime path.

**Rejected alternative (a): keep `mktemp` but pre-create the scratch file under a `CLAUDE_PROJECT_DIR`-relative path instead of the platform tmp dir.** Rejected because this still requires a filesystem write, and a sandbox that denies writes to arbitrary locations may deny writes inside the project tree just as readily depending on policy — it does not eliminate the failure class, only relocates it, and it introduces a new risk: if cleanup (`rm -f`) is itself skipped or denied under the same sandboxing failure, a stray file is left inside the repository working tree, which is worse than a stray file in platform tmp.

**Rejected alternative (b): inline the whole judge as a single-line `python3 -c "$(cat <<...)"` string.** Rejected because the judge is ~155 lines of Python containing embedded regexes and JSON-adjacent string literals; folding it into a single command-line string via `-c` risks shell quoting/escaping errors around those literals, degrades readability and diff-ability of the judge source, and for scripts of this size risks bumping against practical `ARG_MAX`/readability limits for no benefit over a stdin heredoc, which has neither of these problems.

## What will be done

1. In `erm-order-gate.sh`, remove `PYSCRIPT="$(mktemp)"` (line 31) and the `cat > "$PYSCRIPT" <<'PYEOF' ... PYEOF` redirection (lines 32/186) — the heredoc stays as a heredoc, but its target becomes `python3` directly instead of a file.
2. Before the heredoc, `export GATE_PAYLOAD="$payload"` and `export GATE_PROJECT_DIR="$PROJECT_DIR"` (replacing the current `printf '%s' "$payload" | python3 "$PYSCRIPT" "$PROJECT_DIR"` invocation at line 188 with `result="$(python3 <<'PYEOF' ... PYEOF\n)"`, with the heredoc body itself unchanged except for its two read sites).
3. Inside the Python judge source: replace `project_dir = sys.argv[1]` with `project_dir = os.environ["GATE_PROJECT_DIR"]`, and replace `raw = sys.stdin.read()` with `raw = os.environ["GATE_PAYLOAD"]`.
4. Remove the now-obsolete `rm -f "$PYSCRIPT"` cleanup calls (lines 190, 193) — nothing to clean up once there is no scratch file.
5. Update the stale comment above the old `mktemp` line (lines 27-30) to describe the new mechanism (env-var handoff avoids the stdin-heredoc collision) instead of the scratch-file workaround it currently justifies.
6. Add a regression test to `erm-verdict-methodology/hooks/tests/run-gate-tests.sh`, in the product-discovery-rulebook#54 style: a test case that shadows `mktemp` on `PATH` with a tiny always-failing marker binary placed first in `PATH` for that one gate subprocess invocation, using the existing `env_extra` parameter of `run_case` (e.g. `env_extra="PATH=<marker-dir>:$PATH"`), asserting the gate still ALLOWs a valid payload even though `mktemp` fails. This test is expected to fail against the current (pre-fix) script — because the current script's fail-closed trap denies when `mktemp` fails — and to pass once the fix lands, since the fixed gate no longer invokes `mktemp` at all.

## Out of scope

- No changes to any other gate or plugin in the repo. The survey (`docs/issue-16/reports/implementation/survey.md`) confirmed via repo-wide grep that `erm-order-gate.sh` line 31 is the only runtime gate `mktemp` in this repository — all other `mktemp` hits live under `*/hooks/tests/*.sh` test harnesses, which are out of scope by the issue's own framing.
- No changes to `gate-lib.sh` or to other plugins' test harnesses.
- No changes to the ISO 31000 ordering/vocabulary logic itself — this is a plumbing fix only, not a behavior change to what the judge decides.

## How you'll know it worked

- The existing `erm-verdict-methodology/hooks/tests/run-gate-tests.sh` suite passes unchanged (same pass count, same case behavior) after the fix.
- The new mktemp-shadow regression test fails against the current script (pre-fix) and passes after the fix is applied.
- `grep -rn mktemp erm-verdict-methodology/hooks/erm-order-gate.sh` returns no output.
