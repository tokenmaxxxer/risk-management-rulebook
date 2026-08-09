---
status: proposed
files:
  - phase1-proposal-norms/hooks/tests/lib/resolve-core.sh
  - phase1-proposal-norms/hooks/tests/run-gate-tests.sh
  - phase2-record-norms/hooks/tests/lib/resolve-core.sh
  - phase2-record-norms/hooks/tests/run-gate-tests.sh
  - erm-verdict-methodology/hooks/tests/lib/resolve-core.sh
  - erm-verdict-methodology/hooks/tests/run-gate-tests.sh
  - risk-register-methodology/hooks/tests/lib/resolve-core.sh
  - risk-register-methodology/hooks/tests/run-gate-tests.sh
---

Status: Phase 1 proposal — APPROVE is out of scope for this PR.

See docs/issue-23/reports/implementation/survey.md for current-state
findings.

## Request
Adopt the canonical test-env resolution convention
(`tokenmaxxxer/on-the-record` `docs/specs/test-env-resolution.md`,
issue #551) in this repo's 4 gate-test scripts, so that on a plain
checkout without `CLAUDE_PLUGIN_ROOT_CORE` set, each script SKIPs with
the convention's explicit message and exit `75` instead of failing
misleadingly on most cases. Assertions that already run correctly when
core IS reachable must not be weakened.

## Constraints
- Must use the convention's exact resolution order and SKIP contract
  (message text, exit code 75) — not a repo-specific variant.
- Must not weaken the one case per runner that intentionally verifies
  the *gate's own* fail-closed behavior when `CLAUDE_PLUGIN_ROOT_CORE`
  points at a bad path — that is a gate-defect check, not an
  env-resolution check, and stays unchanged.
- Scripts must reference the convention doc (acceptance check: grep for
  `test-env-resolution`).
- No network fallback (per the doc, out of the canonical contract).

## Rationale
Two ways to run the resolution order inside these bash-only runners:

1. **Vendor `gates/test_env_resolve.py` and shell out to
   `python3 -m gates.test_env_resolve <candidates>`.** Rejected: it pulls
   a whole Python package (`gates/`) into a repo that currently has zero
   Python test infrastructure, for one function's worth of logic, and
   ties every future edit of the resolver to keeping two repos' copies
   in sync — the doc itself says adopting the convention is "separate
   work per repo," not "vendor the reference impl verbatim."
2. **Replicate the same 3-step order as a small bash function, one per
   plugin, referencing the convention doc.** Chosen: matches the "bash
   test runner" adoption shape the doc documents (branch on exit code),
   keeps each plugin self-contained (existing repo convention — no
   shared top-level `hooks/` — see the 4 independent `run-gate-tests.sh`
   under separate plugin dirs), and needs no new dependency for what is
   ~15 lines of shell.

`hooks/tests/lib/resolve-core.sh` is a new small file per plugin (not a
single shared repo-root file) to match this repo's existing per-plugin
self-containment — each plugin's `hooks/tests/` already stands alone.

## What will be done
For each of the 4 plugins, add `hooks/tests/lib/resolve-core.sh`
implementing the convention's resolution order in bash:
1. `$CLAUDE_PLUGIN_ROOT_CORE` if set and
   `$CLAUDE_PLUGIN_ROOT_CORE/hooks/lib/gate-lib.sh` exists and is
   non-empty.
2. Else the first sibling candidate (`../core`,
   `../../tokenmaxxxer-core/core`) containing the same non-empty file.
3. Else print `SKIP: core plugin unreachable — unverifiable outside
   spawn env` to stderr and exit `75`.

Each file's header comment cites `docs/specs/test-env-resolution.md`
(issue #551) by name, satisfying the grep-for-`test-env-resolution`
acceptance check.

Each `run-gate-tests.sh` sources its sibling `lib/resolve-core.sh` at
the top, calls the resolver before any `run_case` calls, and on a
non-zero/skip result prints the SKIP message and exits 75 immediately —
no cases run, no PASS/FAIL summary is printed for that run. On a
resolved core, `CLAUDE_PLUGIN_ROOT_CORE` is exported to the resolved
path (matching current behavior when it was already set) and every
existing case runs unchanged, including the CLAUDE_PLUGIN_ROOT_CORE
bad-path fail-closed case.

## Out of scope
- Changing `gate-lib.sh` or any gate script's own sourcing line.
- Adding Python or vendoring `gates/` into this repo.
- Any rulebook repo other than this one (per the convention doc, each
  repo's adoption is separate, tracked in its own issue/PR).
- Any REAL gate defect the survey did not surface — if the build phase
  finds one, it is recorded as a finding, not silently masked with SKIP.

## How you'll know it worked
- On a plain checkout (`unset CLAUDE_PLUGIN_ROOT_CORE`, no sibling core
  checkout present), each of the 4 `run-gate-tests.sh` exits `75` and
  prints the SKIP message — zero misleading FAIL lines.
- With `CLAUDE_PLUGIN_ROOT_CORE` set to a real core checkout (the spawn
  env this repo already runs under), all cases pass exactly as they do
  today — same PASS/FAIL counts as the current `main`.
- `grep -rl test-env-resolution */hooks/tests` returns all 4 plugins.
