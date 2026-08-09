# Current-state survey — issue #23

## Scope of the write set
This repo has exactly 4 gate-test scripts, all bash, one per plugin:
- `phase1-proposal-norms/hooks/tests/run-gate-tests.sh`
- `phase2-record-norms/hooks/tests/run-gate-tests.sh`
- `erm-verdict-methodology/hooks/tests/run-gate-tests.sh`
- `risk-register-methodology/hooks/tests/run-gate-tests.sh`

Each invokes its plugin's gate script (e.g. `proposal-shape-gate.sh`) as a
subprocess. Each gate script sources core's `hooks/lib/gate-lib.sh` via:

```
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "... cannot source gate-lib.sh" >&2; exit 2; }
```

No plugin ships a local `hooks/lib/gate-lib.sh` (confirmed: no such file
exists anywhere under this repo). So the fallback path only works when
`CLAUDE_PLUGIN_ROOT_CORE` is set and points at a real core checkout
(the spawn-session env) — outside spawn, sourcing fails and the gate
exits 2 with "cannot source gate-lib.sh" on stderr.

## Reproduced failure
Ran `phase1-proposal-norms/hooks/tests/run-gate-tests.sh` with
`CLAUDE_PLUGIN_ROOT_CORE` unset (plain checkout): 9 of 19 cases FAIL —
every case expecting exit 0 fails with exit 2 and the "cannot source
gate-lib.sh" message, indistinguishable in the runner's own summary line
from a genuine gate regression. Two cases that expect exit 2 by design
(missing-CLAUDE_PLUGIN_ROOT_CORE test, and one that happens to also hit
the source failure) pass by coincidence, not by verifying real gate
logic. This is exactly the ambiguity issue #551 / the convention doc
describes. The other 3 test scripts share the identical sourcing
pattern and are expected to fail the same way (not independently run,
same code path).

## The canonical convention (on-the-record, issue #551)
Fetched verbatim from `tokenmaxxxer/on-the-record`
`docs/specs/test-env-resolution.md` (this repo has no local copy of the
doc or its reference module — this is the first adoption in a rulebook
repo; `gh search code resolve_core --owner tokenmaxxxer` found no prior
adopter to pattern-match against).

Resolution order: (1) `$CLAUDE_PLUGIN_ROOT_CORE` if it contains a
non-empty `hooks/lib/gate-lib.sh`; (2) first caller-supplied sibling
candidate containing the same; (3) otherwise SKIP — print
`SKIP: core plugin unreachable — unverifiable outside spawn env` to
stderr, exit `75` (`EX_TEMPFAIL`), distinct from the gate's own 0/1/2.
No network fallback is part of the canonical contract.

Reference implementation is a Python module + CLI
(`gates/test_env_resolve.py`, `python3 -m gates.test_env_resolve
<candidates...>`) with two documented adoption shapes: pytest (`import`
+ fixture) and **bash test runner** — invoke the module as a CLI and
branch on exit code (0 = resolved path on stdout, 75 = skip the whole
run).

This repo has no Python test infrastructure and no vendored copy of
`gates/`; the 4 consumers here are exactly the "bash test runner" shape
the doc names. There is no `gates/test_skip_gate.py`-style exception
here — every one of the 4 scripts does depend on core's `gate-lib.sh`
being resolvable, so the convention applies to all 4, not a subset.

## What "adopt" requires per script
Each `run-gate-tests.sh` currently assumes core is reachable and never
checks. To adopt the convention, each script must, before running any
cases: resolve core using the canonical order, and if unresolved, print
the SKIP message and exit 75 instead of running cases that would
misleadingly fail. Cases that exercise the gate's own fail-closed
behavior when `CLAUDE_PLUGIN_ROOT_CORE` points at a bad path (case 7 in
`phase1-proposal-norms`'s runner) are a *gate-defect* check, not an
env-resolution check — they must keep running unchanged once core is
otherwise resolved, per the issue's "do not weaken any assertion that
runs when core IS reachable" requirement.

## Design decision this survey exposes
No Python interpreter dependency currently exists in these bash-only
test scripts. Two live options for how to run the resolution order:
shell out to `python3 -m gates.test_env_resolve` (requires vendoring the
`gates` package into this repo), or replicate the same 3-step order as
a small bash function local to each script (~15 lines, referencing the
convention doc by comment/grep-able string per the issue's acceptance
check). This decision is carried into the proposal's Rationale section,
not decided here.
