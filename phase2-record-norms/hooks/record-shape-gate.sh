#!/usr/bin/env bash
# PreToolUse gate for phase2-record-norms.
#
# Structure (fail-closed trap, dependency/root-discovery checks, scope
# regex, resulting-content reconstruction, kill switch) is adapted BY
# STRUCTURE ONLY — no script body copied — from the sibling gates cited
# in docs/issue-2/proposals/core-canon-reference-conversion.md's citation
# convention:
#   - pricing-rulebook/pricing/hooks/methodology-gate.sh
#   - implementation-rulebook/coding/hooks/coding-progress-gate.sh
# Those files are not present in this repo checkout; cited by path only.
#
# Scope of this gate (proposal docs/issue-7/proposals/
# risk-management-plugin-enforcement.md §2.4): a phase-2 record
# (docs/issue-<n>/reports/<role>.md) must contain an "Implements:"
# backlink line pointing at a docs/issue-<n>/proposals/*.md path with
# the SAME issue number as the record's own path.
#
# Deliberate scope limit (proposal §2.4, open item 3): this gate does
# NOT verify that an Approve marker exists before the write. A
# PreToolUse hook has no GitHub API access, so that check cannot be
# performed reliably from a local script; the proposal explicitly
# scopes this gate down to the backlink-only check and leaves the
# Approve-gate responsibility with the human-followed role-handoff
# contract process (contract v3 s19), not a script. This is a stated
# limit, not a silently dropped requirement.

set -u

__fc() {
  local ec=$?
  if [[ "$ec" != "0" && "$ec" != "2" ]]; then
    echo "DENY::phase2-record-norms gate crashed unexpectedly (exit $ec) - failing closed" >&2
    exit 2
  fi
  exit "$ec"
}
trap __fc EXIT

# Kill switch, checked first.
if [[ "${PHASE2_RECORD_NORMS_GATE_OFF:-}" == "1" ]]; then
  exit 0
fi

# Dependency checks.
if ! command -v python3 >/dev/null 2>&1; then
  echo "DENY::python3 not found - failing closed" >&2
  exit 2
fi
if ! command -v git >/dev/null 2>&1; then
  echo "DENY::git not found - failing closed" >&2
  exit 2
fi

# Root discovery.
ROOT="${CLAUDE_PROJECT_DIR:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [[ -z "$ROOT" || ! -d "$ROOT" ]]; then
  echo "DENY::could not determine project root - failing closed" >&2
  exit 2
fi

PAYLOAD="$(cat)"

RESULT="$(ROOT="$ROOT" PAYLOAD="$PAYLOAD" python3 <<'PYEOF'
import json
import os
import re
import sys

root = os.environ["ROOT"]
raw_payload = os.environ["PAYLOAD"]

try:
    payload = json.loads(raw_payload)
except Exception:
    print("DENY::malformed PreToolUse JSON payload - failing closed")
    sys.exit(0)

tool_name = payload.get("tool_name")
tool_input = payload.get("tool_input") or {}
file_path = tool_input.get("file_path")

if not tool_name or not file_path:
    print("DENY::missing tool_name or file_path in payload - failing closed")
    sys.exit(0)

# Normalize file_path to a repo-relative path for scoping.
rel_path = file_path
if os.path.isabs(rel_path):
    try:
        rel_path = os.path.relpath(rel_path, root)
    except Exception:
        print("DENY::could not resolve file_path relative to project root - failing closed")
        sys.exit(0)
rel_path = rel_path.replace(os.sep, "/")

SCOPE_RE = re.compile(r"^docs/issue-[0-9]+/reports/[a-z-]+\.md$")
m = SCOPE_RE.match(rel_path)
if not m:
    print("ALLOW::out of scope for phase2-record-norms gate")
    sys.exit(0)

# Extract this record's own issue number.
own_issue_m = re.match(r"^docs/issue-([0-9]+)/reports/[a-z-]+\.md$", rel_path)
own_issue = own_issue_m.group(1)

# Reconstruct resulting content per tool type.
abs_path = file_path if os.path.isabs(file_path) else os.path.join(root, file_path)

def read_existing():
    try:
        with open(abs_path, "r", encoding="utf-8") as f:
            return f.read()
    except Exception:
        return None

content = None

if tool_name == "Write":
    content = tool_input.get("content")
    if content is None:
        print("DENY::Write tool_input missing content - failing closed")
        sys.exit(0)

elif tool_name == "Edit":
    old_string = tool_input.get("old_string")
    new_string = tool_input.get("new_string")
    if old_string is None or new_string is None:
        print("DENY::Edit tool_input missing old_string/new_string - failing closed")
        sys.exit(0)
    existing = read_existing()
    if existing is None:
        print("DENY::could not read existing file for Edit reconstruction - failing closed")
        sys.exit(0)
    if old_string not in existing:
        print("DENY::Edit old_string not found in existing file - failing closed")
        sys.exit(0)
    content = existing.replace(old_string, new_string, 1)

elif tool_name == "MultiEdit":
    edits = tool_input.get("edits")
    if not edits:
        print("DENY::MultiEdit tool_input missing edits - failing closed")
        sys.exit(0)
    existing = read_existing()
    if existing is None:
        print("DENY::could not read existing file for MultiEdit reconstruction - failing closed")
        sys.exit(0)
    content = existing
    for edit in edits:
        old_string = edit.get("old_string")
        new_string = edit.get("new_string")
        if old_string is None or new_string is None:
            print("DENY::MultiEdit edit entry missing old_string/new_string - failing closed")
            sys.exit(0)
        if old_string not in content:
            print("DENY::MultiEdit old_string not found in reconstructed content - failing closed")
            sys.exit(0)
        content = content.replace(old_string, new_string, 1)

else:
    print("ALLOW::tool_name not Write/Edit/MultiEdit")
    sys.exit(0)

# Business logic: find "Implements:" backlink line.
implements_re = re.compile(r"^Implements:\s*(.+)$", re.MULTILINE)
match = implements_re.search(content)
if not match:
    print("DENY::no \"Implements:\" backlink line found - phase-2 record must cite the phase-1 proposal it implements")
    sys.exit(0)

target = match.group(1).strip()
proposal_re = re.compile(r"docs/issue-([0-9]+)/proposals/[^\s]+\.md")
pm = proposal_re.search(target)
if not pm:
    print(f"DENY::\"Implements:\" backlink does not reference a docs/issue-<n>/proposals/*.md path (got: {target})")
    sys.exit(0)

target_issue = pm.group(1)
if target_issue != own_issue:
    print(f"DENY::\"Implements:\" backlink issue number ({target_issue}) does not match record's own issue number ({own_issue})")
    sys.exit(0)

print("ALLOW::Implements backlink present and issue numbers match")
PYEOF
)"

STATUS="${RESULT%%::*}"
REASON="${RESULT#*::}"

if [[ "$STATUS" == "ALLOW" ]]; then
  exit 0
elif [[ "$STATUS" == "DENY" ]]; then
  echo "$REASON" >&2
  exit 2
else
  echo "DENY::gate produced unrecognized output - failing closed" >&2
  exit 2
fi
