#!/usr/bin/env bash
# register-fields-gate.sh
#
# PreToolUse gate for the risk-register-methodology plugin. Enforces the
# ISO 31000 risk-register 12-field schema (field list per
# risk-management/hooks/record-fields.json) with per-field value judgment
# criteria, per docs/issue-7/proposals/risk-management-plugin-enforcement.md
# §1.2 and §2.2.
#
# Structural skeleton (fail-closed trap, dependency + root-discovery checks,
# scope regex, resulting-content reconstruction, kill switch) is adapted BY
# PATH ONLY — no script body copied — from:
#   pricing-rulebook/pricing/hooks/methodology-gate.sh
#   implementation-rulebook/coding/hooks/coding-progress-gate.sh
# (neither file is present in this repo checkout; citation convention per
# docs/issue-2/proposals/core-canon-reference-conversion.md).
#
# Kill switch: RISK_REGISTER_METHODOLOGY_GATE_OFF=1

set -u

__fc() {
  local ec=$?
  if [ "$ec" -ne 0 ] && [ "$ec" -ne 2 ]; then
    echo "register-fields-gate: fail-closed on unexpected exit ($ec)" >&2
    exit 2
  fi
  exit "$ec"
}
trap __fc EXIT

# --- kill switch, checked first -------------------------------------------
if [ "${RISK_REGISTER_METHODOLOGY_GATE_OFF:-0}" = "1" ]; then
  exit 0
fi

# --- dependency checks ------------------------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
  echo "register-fields-gate: python3 not found, failing closed" >&2
  exit 2
fi
if ! command -v git >/dev/null 2>&1; then
  echo "register-fields-gate: git not found, failing closed" >&2
  exit 2
fi

# --- project root discovery -------------------------------------------------
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "$PROJECT_ROOT" ] || [ ! -d "$PROJECT_ROOT" ]; then
  echo "register-fields-gate: could not determine project root, failing closed" >&2
  exit 2
fi

# --- read PreToolUse payload from stdin -------------------------------------
PAYLOAD="$(cat)"
if [ -z "$PAYLOAD" ]; then
  echo "register-fields-gate: empty payload, failing closed" >&2
  exit 2
fi

# NOTE: the JSON payload is piped via stdin into the python3 process below.
# The gate logic itself is passed as a -c script argument (not a heredoc
# attached directly to python3's own stdin) precisely so that stdin remains
# free to carry the piped payload — attaching the heredoc directly to
# `python3 <<EOF` would make python3 read its *program source* from stdin,
# leaving nothing for `sys.stdin.read()` inside the program to consume.
GATE_PY="$(cat <<'PYEOF'
import json
import os
import re
import sys

def deny(reason):
    print("DENY::" + reason)
    sys.exit(0)

def allow(reason):
    print("ALLOW::" + reason)
    sys.exit(0)

raw = sys.stdin.read()
try:
    payload = json.loads(raw)
except Exception as e:
    deny("malformed JSON payload: %s" % e)

tool_name = payload.get("tool_name", "")
tool_input = payload.get("tool_input", {}) or {}
file_path = tool_input.get("file_path", "")

if not file_path:
    deny("no file_path in tool_input")

project_root = os.environ.get("PROJECT_ROOT", "")
rel_path = file_path
if project_root and file_path.startswith(project_root):
    rel_path = os.path.relpath(file_path, project_root)
rel_path = rel_path.lstrip("./")

SCOPE_RE = re.compile(
    r"^docs/issue-[0-9]+/(proposals/.*risk-management.*|reports/risk-management)\.md$"
)
if not SCOPE_RE.match(rel_path):
    allow("out of scope: %s" % rel_path)

# --- reconstruct resulting content ------------------------------------------
def read_existing(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    except Exception:
        return None

if tool_name == "Write":
    content = tool_input.get("content")
    if content is None:
        deny("Write tool_input missing content, cannot reconstruct")

elif tool_name == "Edit":
    existing = read_existing(file_path)
    old_string = tool_input.get("old_string")
    new_string = tool_input.get("new_string")
    if existing is None:
        deny("could not read existing file for Edit reconstruction: %s" % rel_path)
    if old_string is None or new_string is None:
        deny("Edit tool_input missing old_string/new_string")
    if old_string not in existing:
        deny("Edit old_string not found in existing file, cannot reconstruct")
    content = existing.replace(old_string, new_string, 1)

elif tool_name == "MultiEdit":
    existing = read_existing(file_path)
    if existing is None:
        deny("could not read existing file for MultiEdit reconstruction: %s" % rel_path)
    edits = tool_input.get("edits", [])
    content = existing
    for i, e in enumerate(edits):
        old_string = e.get("old_string")
        new_string = e.get("new_string")
        if old_string is None or new_string is None:
            deny("MultiEdit edit #%d missing old_string/new_string" % i)
        if old_string not in content:
            deny("MultiEdit edit #%d old_string not found, cannot reconstruct" % i)
        content = content.replace(old_string, new_string, 1)

else:
    deny("unsupported tool_name for reconstruction: %s" % tool_name)

# --- business logic: 12-field schema, per-field judgment criteria ----------
REQUIRED_FIELDS = [
    "risk-id",
    "risk-description",
    "risk-category",
    "likelihood",
    "impact",
    "risk-score-inherent",
    "existing-controls",
    "risk-score-residual",
    "risk-appetite-threshold",
    "mitigation-owner",
    "mitigation-plan",
    "review-date",
]

def field_value(field, text):
    # label pattern: "field-name: value" or "field-name:value" at start of a line
    pattern = re.compile(
        r"^[ \t]*" + re.escape(field) + r"[ \t]*:[ \t]*(.*)$", re.MULTILINE
    )
    m = pattern.search(text)
    if not m:
        return None
    return m.group(1).strip()

for field in REQUIRED_FIELDS:
    if field_value(field, content) is None:
        deny("missing required field: %s" % field)

ALLOWED_CATEGORIES = {"strategic", "operational", "financial", "regulatory"}
category_value = field_value("risk-category", content) or ""
category_lower = category_value.strip().lower()
# justification convention: value followed by "(justified: ...)" anywhere in the line
has_justification = "(justified:" in category_lower
bare_category = re.split(r"\(justified:", category_lower, maxsplit=1)[0].strip()
if bare_category not in ALLOWED_CATEGORIES and not has_justification:
    deny(
        "invalid risk-category value '%s': must be one of %s, or the value "
        "must carry an explicit justification marker '(justified: ...)'"
        % (category_value, ", ".join(sorted(ALLOWED_CATEGORIES)))
    )

PLACEHOLDER_TOKENS = {"", "tbd", "unassigned", "n/a"}
for field in ("mitigation-owner", "review-date"):
    value = field_value(field, content) or ""
    if value.strip().lower() in PLACEHOLDER_TOKENS:
        deny("placeholder value not allowed for %s: '%s'" % (field, value))

allow("all 12 fields present with valid values")
PYEOF
)"

RESULT="$(printf '%s' "$PAYLOAD" | PROJECT_ROOT="$PROJECT_ROOT" python3 -c "$GATE_PY")"

if [ -z "$RESULT" ]; then
  echo "register-fields-gate: gate produced no result, failing closed" >&2
  exit 2
fi

DECISION="${RESULT%%::*}"
REASON="${RESULT#*::}"

case "$DECISION" in
  ALLOW)
    exit 0
    ;;
  DENY)
    echo "register-fields-gate: DENY: $REASON" >&2
    exit 2
    ;;
  *)
    echo "register-fields-gate: unrecognized gate result, failing closed: $RESULT" >&2
    exit 2
    ;;
esac
