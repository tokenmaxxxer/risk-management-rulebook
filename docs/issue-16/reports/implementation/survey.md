# Survey: issue #16 — erm-order-gate.sh bare mktemp false-deny

## Current state of `erm-verdict-methodology/hooks/erm-order-gate.sh`

Lines 25-193 of the file do the following:

- **Lines 25-28**: resolve `PROJECT_DIR` from `CLAUDE_PROJECT_DIR`, falling back to `git rev-parse --show-toplevel`, denying via `gate_deny` if neither works.
- **Line 30**: `payload="$(cat 2>/dev/null || true)"` — captures the PreToolUse JSON payload from stdin into a shell variable.
- **Lines 27-30 (comment above the mktemp)**: the file's own comment already documents *why* the code does not just pipe a heredoc straight into `python3`: "a heredoc attached to a command consumes that command's stdin, which would otherwise clobber the piped-in $payload before python ever sees it." This is the load-bearing constraint the fix must respect.
- **Line 31**: `PYSCRIPT="$(mktemp)"` — allocates a scratch file in the platform tmp dir.
- **Lines 32-186**: `cat > "$PYSCRIPT" <<'PYEOF' ... PYEOF` — writes the inline Python judge (~155 lines) into that scratch file. The judge loads `gate-lib.py` via `importlib`, reads `project_dir` from `sys.argv[1]`, reads the raw payload from `sys.stdin.read()`, parses it via `gate_lib.gate_parse_json_or_deny`, and applies ISO 31000 ordering/vocabulary checks, emitting `ALLOW::ok` or `DENY::<reason>`.
- **Line 188**: `result="$(printf '%s' "$payload" | python3 "$PYSCRIPT" "$PROJECT_DIR")"` — invokes python3 against the scratch file, feeding `$payload` on stdin and `$PROJECT_DIR` as `argv[1]`. On nonzero exit, cleans up (`rm -f "$PYSCRIPT"`, line 190) and fails closed via `gate_deny "erm-order-gate" "internal judge crashed ..."`.
- **Line 193**: `rm -f "$PYSCRIPT"` — cleans up the scratch file on the success path.
- Remaining lines: parse `verdict`/`reason` out of `result`, and deny if `verdict = DENY`.

## Root cause

Under a sandboxed Claude Code role session, if the platform tmp directory used by `mktemp` (line 31) is outside the session's writable set, the `mktemp` call itself is denied/fails. Because the script runs under `gate_trap_fail_closed` (set up near the top of the file), any unexpected failure — including a denied `mktemp` — triggers the fail-closed trap, which denies the operation. The result: every erm-verdict write is denied regardless of its actual content, whenever the sandbox denies scratch-file writes to platform tmp. This is unrelated to whether the payload itself is valid.

## Repo-wide mktemp grep

Command run from repo root: `grep -rn "mktemp" --include=*.sh .`

Findings, categorized:

- **Runtime gate mktemp (in scope for this issue)**:
  - `erm-verdict-methodology/hooks/erm-order-gate.sh:31` — `PYSCRIPT="$(mktemp)"` — the only runtime gate mktemp found anywhere in the repo.
- **Test harness mktemp (out of scope — throwaway scratch files for test infrastructure, not gate runtime)**:
  - `phase1-proposal-norms/hooks/tests/run-gate-tests.sh` (line 12, plus header comment)
  - `erm-verdict-methodology/hooks/tests/run-gate-tests.sh` (lines 42, 52, 87, 104, 122, 130, 148, 166, 170, 174, 180, 189, 213, 242, 256, 258, 260, 264, 268, 270, 276, 282 — throwaway git repo dir, per-case payload files, stderr capture files)
  - `risk-register-methodology/hooks/tests/run-gate-tests.sh` (lines 16, 51, 52, 181, 182, 237, 268 — throwaway repo dir, stdout/stderr capture files)
  - `phase2-record-norms/hooks/tests/run-gate-tests.sh` (line 18, 34 — throwaway repo dir, stderr capture file)

No other `*/hooks/*.sh` runtime script (outside `*/hooks/tests/*.sh`) uses `mktemp`. `erm-order-gate.sh` is confirmed as the sole runtime gate mktemp user in this repo.

## Scout-directive skip record

**Pure bugfix — skip condition satisfied.** No design decision is open: the fix pattern (swap `PYSCRIPT="$(mktemp)"` + heredoc-to-file for payload/project-root passed via environment variables into a `python3 <<'PYEOF' ... PYEOF` heredoc read on stdin), the target file (`erm-verdict-methodology/hooks/erm-order-gate.sh`), and the acceptance criteria (no mktemp in gate runtime path; all existing tests unchanged; new regression test proving the gate no longer depends on mktemp) are all fully specified by issue #16 itself. This qualifies for the scout-directive's "pure bugfix" skip condition on further design exploration.

## Existing test harness

`erm-verdict-methodology/hooks/tests/run-gate-tests.sh` (292 lines) is the regression suite this fix must not break, and the location where the new mktemp-shadow regression test (phase 2) will be added. Structure:

- `SCRIPT_DIR`/`GATE` resolve the path to `erm-order-gate.sh` under test.
- `PASS`/`FAIL` counters accumulate across cases.
- A `FULL_DOC` fixture (lines ~18-37) is a valid ISO-31000-ordered erm-verdict document used as the baseline "should ALLOW" payload across many cases.
- `setup_repo()` (~line 32) creates a throwaway git repo via `mktemp -d`, initializes it, and creates `docs/issue-7/proposals`.
- `run_case name expected_exit expected_stderr_substr payload_file [env_extra]` (~line 47 onward) is the core assertion helper: it runs `bash "$GATE" < "$payload"`, optionally prefixed with `env $env_extra` to inject extra environment variables for that one invocation, captures stdout/stderr/exit code, and compares against expectations, incrementing `PASS`/`FAIL`.
- A `make_payload` helper (referenced by call sites e.g. line 104, 122, etc.) builds synthetic PreToolUse JSON payloads for `Write` tool calls against a target file with given content.
- Individual test cases construct a payload file (often via `p="$(mktemp)"` — test-local scratch, out of scope per above) and invoke `run_case` with expectations covering: full valid doc (ALLOW), out-of-order sections (DENY), missing doc sections (DENY), missing objective linkage (DENY), identical inherent/residual scores (DENY), non-erm-verdict target files (ALLOW/skip), malformed JSON (DENY), forced internal crash sentinel (DENY, fail-closed), path variants (repo-relative, `./`-prefixed), and kill-switch behavior.
- The `env_extra` parameter on `run_case` is the existing mechanism by which a case-specific environment variable (e.g. a `PATH` override) can be injected for a single gate invocation — this is the mechanism the phase-2 mktemp-shadow regression test is expected to reuse.
