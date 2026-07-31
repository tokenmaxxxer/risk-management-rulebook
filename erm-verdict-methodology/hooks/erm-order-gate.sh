#!/usr/bin/env bash
# PreToolUse gate: erm-verdict-methodology.
# Enforces ISO 31000:2018 process-clause ordering (6.3/6.4/6.5/6.6) on
# erm-verdict facet documents. Structure adapted (cited by path, no
# script body copied) from pricing-rulebook/pricing/hooks/methodology-gate.sh
# and implementation-rulebook/coding/hooks/coding-progress-gate.sh.
set -u
__fc() { local ec=$?; if [ "$ec" != 0 ] && [ "$ec" != 2 ]; then exit 2; fi; }
trap __fc EXIT

# Kill switch — checked first, before any other logic.
if [ "${ERM_VERDICT_METHODOLOGY_GATE_OFF:-}" = "1" ]; then
  exit 0
fi

command -v python3 >/dev/null 2>&1 || { echo "erm-order-gate: python3 required" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "erm-order-gate: git required" >&2; exit 2; }

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$PROJECT_DIR" ]; then
  PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "erm-order-gate: cannot determine project root" >&2; exit 2; }
fi

payload="$(cat)"

# Extract tool_name, file_path, and reconstruct resulting content via python3.
# The python source is written to a temp file first (rather than fed via a
# heredoc directly on the python3 invocation) because a heredoc attached to
# a command consumes that command's stdin, which would otherwise clobber
# the piped-in $payload before python ever sees it.
PYSCRIPT="$(mktemp)"
cat > "$PYSCRIPT" <<'PYEOF'
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
SCOPE = re.compile(r"^docs/issue-[0-9]+/(proposals/.*risk-management.*|reports/risk-management)\.md$")
rel = file_path
if os.path.isabs(rel):
    try:
        rel = os.path.relpath(rel, project_dir)
    except Exception:
        pass
if not SCOPE.match(rel):
    print("ALLOW::out of scope")
    sys.exit(0)

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

STAGES = [
    "## Governance/context",
    "## Objective linkage",
    "## Assessment",
    "## Response",
    "## Monitoring",
]
positions = []
for s in STAGES:
    idx = content.find(s)
    if idx == -1:
        print(f"DENY::missing required stage marker: {s}")
        sys.exit(0)
    positions.append((s, idx))

for i in range(1, len(positions)):
    if positions[i][1] < positions[i-1][1]:
        print(f"DENY::stage markers out of order: {positions[i][0]} appears before {positions[i-1][0]}")
        sys.exit(0)

inherent = re.search(r"risk-score-inherent[:\s]+([^\n]+)", content)
residual = re.search(r"risk-score-residual[:\s]+([^\n]+)", content)
if not inherent:
    print("DENY::missing risk-score-inherent label")
    sys.exit(0)
if not residual:
    print("DENY::missing risk-score-residual label")
    sys.exit(0)
if inherent.group(1).strip() == residual.group(1).strip():
    print("DENY::risk-score-inherent and risk-score-residual share the same value — must be distinct")
    sys.exit(0)

print("ALLOW::ok")
PYEOF

result="$(printf '%s' "$payload" | python3 "$PYSCRIPT" "$PROJECT_DIR" 2>/dev/null)"
rm -f "$PYSCRIPT"

verdict="${result%%::*}"
reason="${result#*::}"

if [ "$verdict" = "DENY" ]; then
  echo "erm-order-gate: $reason" >&2
  exit 2
fi
exit 0
