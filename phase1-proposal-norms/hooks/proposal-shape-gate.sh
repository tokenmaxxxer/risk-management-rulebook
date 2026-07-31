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
set -u
__fc() { local ec=$?; if [ "$ec" != 0 ] && [ "$ec" != 2 ]; then exit 2; fi; }
trap __fc EXIT

# Kill switch — checked first, before any other logic.
if [ "${PHASE1_PROPOSAL_NORMS_GATE_OFF:-}" = "1" ]; then
  exit 0
fi

command -v python3 >/dev/null 2>&1 || { echo "proposal-shape-gate: python3 required" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "proposal-shape-gate: git required" >&2; exit 2; }

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$PROJECT_DIR" ]; then
  PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "proposal-shape-gate: cannot determine project root" >&2; exit 2; }
fi

payload="$(cat)"

# The python program is captured into a variable (not fed via a heredoc
# directly on the python3 invocation) so that stdin remains free to
# carry the JSON payload itself — a heredoc attached straight to the
# command consumes stdin for the program text, which would starve
# sys.stdin.read() of the payload entirely.
PYPROG="$(cat <<'PYEOF'
import json, sys, os
project_dir = sys.argv[1]
try:
    data = json.load(sys.stdin)
except Exception:
    print("DENY::malformed JSON payload")
    sys.exit(0)

tool_name = data.get("tool_name", "")
tool_input = data.get("tool_input", {}) or {}
file_path = tool_input.get("file_path", "")
if not file_path:
    print("ALLOW::no file_path")
    sys.exit(0)

import re
# Role-agnostic scope: any docs/issue-<n>/proposals/*.md, no role-name restriction.
SCOPE = re.compile(r"^docs/issue-[0-9]+/proposals/.*\.md$")
rel = file_path
if os.path.isabs(rel):
    try:
        rel = os.path.relpath(rel, project_dir)
    except Exception:
        pass
if not SCOPE.match(rel):
    print("ALLOW::out of scope")
    sys.exit(0)

# Issue number this proposal file belongs to, for the survey-citation check.
issue_match = re.match(r"^docs/issue-([0-9]+)/proposals/.*\.md$", rel)
issue_num = issue_match.group(1) if issue_match else None

abs_path = file_path if os.path.isabs(file_path) else os.path.join(project_dir, file_path)

def read_existing():
    try:
        with open(abs_path, "r", encoding="utf-8") as f:
            return f.read()
    except Exception:
        return None

if tool_name == "Write":
    content = tool_input.get("content", "")
elif tool_name == "Edit":
    old = tool_input.get("old_string", "")
    new = tool_input.get("new_string", "")
    existing = read_existing()
    if existing is None:
        print("DENY::cannot read existing file for Edit reconstruction")
        sys.exit(0)
    if old not in existing:
        print("DENY::old_string not found in existing file")
        sys.exit(0)
    content = existing.replace(old, new, 1)
elif tool_name == "MultiEdit":
    existing = read_existing()
    if existing is None:
        print("DENY::cannot read existing file for MultiEdit reconstruction")
        sys.exit(0)
    content = existing
    for e in tool_input.get("edits", []):
        old = e.get("old_string", "")
        new = e.get("new_string", "")
        if old not in content:
            print("DENY::old_string not found during MultiEdit reconstruction")
            sys.exit(0)
        content = content.replace(old, new, 1)
else:
    print("ALLOW::tool not in scope")
    sys.exit(0)

# Phase-gate statement marker: tolerant substring checks for the two
# required phrases, checked independently so the deny message names
# exactly which half is missing. "Phase 1 proposal" and "APPROVE is out
# of scope" are the exact phrases this repo's proposals use (see
# docs/issue-7/proposals/risk-management-plugin-enforcement.md's own
# Status line); case-sensitive substring match, not a loose regex, to
# keep the check verbatim-checkable per §1.3.
has_phase_gate = "Phase 1 proposal" in content
has_approve_out_of_scope = "APPROVE is out of scope" in content

if not has_phase_gate and not has_approve_out_of_scope:
    print("DENY::missing phase-gate statement (both 'Phase 1 proposal' and 'APPROVE is out of scope' phrases absent)")
    sys.exit(0)
if not has_phase_gate:
    print("DENY::missing phase-gate statement ('Phase 1 proposal' phrase absent)")
    sys.exit(0)
if not has_approve_out_of_scope:
    print("DENY::missing phase-gate statement ('APPROVE is out of scope' phrase absent)")
    sys.exit(0)

# Survey/current-state citation: a path-shaped string under the same
# issue's docs/issue-<n>/reports/ tree. Citation-exists check only, not
# content verification, per §2.3's explicitly named limit.
if issue_num is not None:
    survey_re = re.compile(r"docs/issue-" + re.escape(issue_num) + r"/reports/")
else:
    survey_re = re.compile(r"docs/issue-[0-9]+/reports/")

if not survey_re.search(content):
    print("DENY::missing survey/current-state citation (no docs/issue-" + str(issue_num) + "/reports/ path found)")
    sys.exit(0)

print("ALLOW::ok")
PYEOF
)"

result="$(printf '%s' "$payload" | python3 -c "$PYPROG" "$PROJECT_DIR" 2>/dev/null)"

verdict="${result%%::*}"
reason="${result#*::}"

if [ "$verdict" = "DENY" ]; then
  echo "proposal-shape-gate: $reason" >&2
  exit 2
fi
exit 0
