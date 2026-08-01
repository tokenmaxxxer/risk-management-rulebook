#!/usr/bin/env bash
# PreToolUse gate: phase1-proposal-norms.
# Enforces the 기획서(phase-1) proposal writing norm on
# docs/issue-<n>/proposals/**.md documents, role-agnostic (no role-name
# restriction in the scope regex — this plugin composes into any role's
# phase-1 norm, per docs/issue-7/proposals/risk-management-plugin-
# enforcement.md §0.2). Structure adapted (cited by path, no script body
# copied) from pricing-rulebook/pricing/hooks/methodology-gate.sh and
# implementation-rulebook/coding/hooks/coding-progress-gate.sh, per the
# citation convention in docs/issue-2/proposals/core-canon-reference-
# conversion.md (source files not present in this repo checkout; cited
# by path only).
#
# Canon migration (issue-10 §1): sources core's gate-house standard
# library instead of hand-rolling the trap/kill-switch/deny/parse/
# reconstruct machinery.
. "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh"
gate_trap_fail_closed
set -uo pipefail

gate_kill_switch_active "${PHASE1_PROPOSAL_NORMS_GATE_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || gate_deny "proposal-shape-gate" "python3 required"
command -v git >/dev/null 2>&1 || gate_deny "proposal-shape-gate" "git required"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$PROJECT_DIR" ]; then
  PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)" || gate_deny "proposal-shape-gate" "cannot determine project root"
fi

payload="$(cat 2>/dev/null || true)"

# The python program is captured into a variable (not fed via a heredoc
# directly on the python3 invocation) so that stdin remains free to
# carry the JSON payload itself — a heredoc attached straight to the
# command consumes stdin for the program text, which would starve
# sys.stdin.read() of the payload entirely.
PYPROG="$(cat <<'PYEOF'
import importlib.util, json, os, re, sys

project_dir = sys.argv[1]

_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gate_lib)


def deny(msg):
    print("DENY::" + msg)
    sys.exit(0)


raw = sys.stdin.read()
data = gate_lib.gate_parse_json_or_deny(raw, deny)

tool_name = data.get("tool_name", "")
tool_input = data.get("tool_input", {}) or {}
file_path = tool_input.get("file_path", "")
if not file_path:
    print("ALLOW::no file_path")
    sys.exit(0)

# Role-agnostic scope: any docs/issue-<n>/proposals/*.md, no role-name restriction.
SCOPE = re.compile(r"^docs/issue-[0-9]+/proposals/.*\.md$")
rel = gate_lib.gate_normalize_path(project_dir, file_path)
if rel is None or not SCOPE.match(rel):
    print("ALLOW::out of scope")
    sys.exit(0)

# Issue number this proposal file belongs to, for the survey-citation check.
issue_match = re.match(r"^docs/issue-([0-9]+)/proposals/.*\.md$", rel)
issue_num = issue_match.group(1) if issue_match else None

abs_path = file_path if os.path.isabs(file_path) else os.path.join(project_dir, file_path)

current = None
if os.path.isfile(abs_path):
    try:
        with open(abs_path, "r", encoding="utf-8") as f:
            current = f.read()
    except OSError:
        deny("existing file cannot be read; failing closed")

if tool_name not in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
    print("ALLOW::tool not in scope")
    sys.exit(0)

content, ok = gate_lib.gate_reconstruct_write(tool_name, tool_input, current)
if not ok or content is None:
    deny(
        "old_string not found (or the tool input's shape makes the "
        "resulting content undeterminable, tool=%r)" % tool_name
    )

# Trigger-only special case (mandatory test 6): forces an uncaught
# exception in the business logic below.
if content.strip() == "__FORCE_INTERNAL_CRASH__":
    raise RuntimeError("forced internal crash for regression test 6")


def strip_fences_and_quotes(text):
    lines = text.splitlines()
    out = []
    in_fence = False
    for l in lines:
        if re.match(r'^\s*(```|~~~)', l):
            in_fence = not in_fence
            out.append("")
            continue
        if in_fence:
            out.append("")
            continue
        if re.match(r'^\s*>', l):
            out.append("")
            continue
        out.append(l)
    return out


checked_text = "\n".join(strip_fences_and_quotes(content))

# Phase-gate statement marker: tolerant substring checks for the two
# required phrases (outside fences/quotes now), checked independently so
# the deny message names exactly which half is missing. "Phase 1
# proposal" and "APPROVE is out of scope" are the exact phrases this
# repo's proposals use (see docs/issue-7/proposals/risk-management-
# plugin-enforcement.md's own Status line); case-sensitive substring
# match, not a loose regex, to keep the check verbatim-checkable.
has_phase_gate = "Phase 1 proposal" in checked_text
has_approve_out_of_scope = "APPROVE is out of scope" in checked_text

if not has_phase_gate and not has_approve_out_of_scope:
    deny("missing phase-gate statement (both 'Phase 1 proposal' and 'APPROVE is out of scope' phrases absent)")
if not has_phase_gate:
    deny("missing phase-gate statement ('Phase 1 proposal' phrase absent)")
if not has_approve_out_of_scope:
    deny("missing phase-gate statement ('APPROVE is out of scope' phrase absent)")

# Survey/current-state citation: a path-shaped string under the same
# issue's docs/issue-<n>/reports/ tree. Citation-exists check only, not
# content verification.
if issue_num is not None:
    survey_re = re.compile(r"docs/issue-" + re.escape(issue_num) + r"/reports/")
else:
    survey_re = re.compile(r"docs/issue-[0-9]+/reports/")

if not survey_re.search(checked_text):
    deny("missing survey/current-state citation (no docs/issue-" + str(issue_num) + "/reports/ path found)")

print("ALLOW::ok")
PYEOF
)"

if ! result="$(printf '%s' "$payload" | python3 -c "$PYPROG" "$PROJECT_DIR")"; then
  rc=$?
  gate_deny "proposal-shape-gate" "internal judge crashed (rc=$rc) — failing closed"
fi

verdict="${result%%::*}"
reason="${result#*::}"

if [ "$verdict" = "DENY" ]; then
  gate_deny "proposal-shape-gate" "$reason"
fi
gate_allow
