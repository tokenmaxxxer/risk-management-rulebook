#!/usr/bin/env bash
# register-fields-gate.sh
#
# PreToolUse gate for the risk-register-methodology plugin. Enforces the
# ISO 31000 risk-register 12-field schema (field list per
# risk-management/hooks/record-fields.json) with per-field value judgment
# criteria, per docs/issue-7/proposals/risk-management-plugin-enforcement.md
# §1.2 and §2.2.
#
# Canon migration (issue-10 §1): sources core's gate-house standard
# library instead of hand-rolling the trap/kill-switch/deny/parse/
# reconstruct machinery.
#
# Kill switch: RISK_REGISTER_METHODOLOGY_GATE_OFF=1
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "register-fields-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
set -uo pipefail

gate_kill_switch_active "${RISK_REGISTER_METHODOLOGY_GATE_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || gate_deny "register-fields-gate" "python3 not found, failing closed"
command -v git >/dev/null 2>&1 || gate_deny "register-fields-gate" "git not found, failing closed"

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "$PROJECT_ROOT" ] || [ ! -d "$PROJECT_ROOT" ]; then
  gate_deny "register-fields-gate" "could not determine project root, failing closed"
fi

PAYLOAD="$(cat 2>/dev/null || true)"

# NOTE: the JSON payload is piped via stdin into the python3 process below.
# The gate logic itself is passed as a -c script argument (not a heredoc
# attached directly to python3's own stdin) precisely so that stdin remains
# free to carry the piped payload — attaching the heredoc directly to
# `python3 <<EOF` would make python3 read its *program source* from stdin,
# leaving nothing for `sys.stdin.read()` inside the program to consume.
GATE_PY="$(cat <<'PYEOF'
import importlib.util, json, os, re, sys

_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gate_lib)


def deny(reason):
    print("DENY::" + reason)
    sys.exit(0)


def allow(reason):
    print("ALLOW::" + reason)
    sys.exit(0)


raw = sys.stdin.read()
payload = gate_lib.gate_parse_json_or_deny(raw, deny)

tool_name = payload.get("tool_name", "")
tool_input = payload.get("tool_input", {}) or {}
file_path = tool_input.get("file_path", "")

if not file_path:
    deny("no file_path in tool_input")

project_root = os.environ.get("PROJECT_ROOT", "")
rel_path = gate_lib.gate_normalize_path(project_root, file_path)

SCOPE_RE = re.compile(
    r"^docs/issue-[0-9]+/(proposals/.*risk-management.*|reports/risk-management)\.md$"
)
if rel_path is None or not SCOPE_RE.match(rel_path):
    allow("out of scope: %s" % rel_path)

abs_path = file_path if os.path.isabs(file_path) else os.path.join(project_root, file_path)

current = None
if os.path.isfile(abs_path):
    try:
        with open(abs_path, "r", encoding="utf-8") as f:
            current = f.read()
    except OSError:
        deny("%s exists but cannot be read, failing closed" % rel_path)

if tool_name not in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
    deny("unsupported tool_name for reconstruction: %s" % tool_name)

content, ok = gate_lib.gate_reconstruct_write(tool_name, tool_input, current)
if not ok or content is None:
    deny(
        "old_string not found (or the tool input's shape makes the resulting "
        "content undeterminable, tool=%r)" % tool_name
    )

# --- issue-10 §2: section/adjacency/structure-aware semantic check --------

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


def parse_sections(lines):
    heading_idx = [i for i, l in enumerate(lines) if re.match(r'^(#{1,6})\s+\S', l)]
    sections = []
    for pos, i in enumerate(heading_idx):
        m = re.match(r'^(#{1,6})\s+(.*)$', lines[i])
        level = len(m.group(1))
        text = m.group(2).strip()
        end = len(lines)
        for j in heading_idx[pos + 1:]:
            m2 = re.match(r'^(#{1,6})\s+(.*)$', lines[j])
            if len(m2.group(1)) <= level:
                end = j
                break
        sections.append({"level": level, "text": text, "start": i, "end": end})
    return sections


def norm(s):
    return re.sub(r'\s+', ' ', s.strip()).lower()


lines = strip_fences_and_quotes(content)
sections = parse_sections(lines)

# Trigger-only special case (mandatory test 6): a document that forces an
# uncaught exception in the business logic below, exercising the §1.1
# subprocess-rc-check regression test.
if content.strip() == "__FORCE_INTERNAL_CRASH__":
    raise RuntimeError("forced internal crash for regression test 6")

# The register-entry section this schema's 12 fields must all live inside
# (not merely anywhere in the document): the section headed "register
# entry" (case-insensitive), falling back to the whole document (still
# fence/quote-stripped) when no such heading exists, so a bare register
# body with no wrapping heading (a valid, minimal shape) still works.
entry_section_lines = lines
for sec in sections:
    if "register entry" in norm(sec["text"]) or "register-entry" in norm(sec["text"]):
        entry_section_lines = lines[sec["start"]:sec["end"]]
        break
entry_text = "\n".join(entry_section_lines)

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
    pattern = re.compile(
        r"^[ \t]*" + re.escape(field) + r"[ \t]*:[ \t]*(.*)$", re.MULTILINE
    )
    m = pattern.search(text)
    if not m:
        return None
    return m.group(1).strip()


for field in REQUIRED_FIELDS:
    if field_value(field, entry_text) is None:
        deny("missing required field: %s" % field)

ALLOWED_CATEGORIES = {"strategic", "operational", "financial", "regulatory"}
category_value = field_value("risk-category", entry_text) or ""
category_lower = category_value.strip().lower()
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
    value = field_value(field, entry_text) or ""
    if value.strip().lower() in PLACEHOLDER_TOKENS:
        deny("placeholder value not allowed for %s: '%s'" % (field, value))

allow("all 12 fields present with valid values")
PYEOF
)"

if ! RESULT="$(printf '%s' "$PAYLOAD" | PROJECT_ROOT="$PROJECT_ROOT" GATE_LIB_PY="$GATE_LIB_PY" python3 -c "$GATE_PY")"; then
  rc=$?
  gate_deny "register-fields-gate" "internal judge crashed (rc=$rc) — failing closed"
fi

if [ -z "$RESULT" ]; then
  gate_deny "register-fields-gate" "gate produced no result, failing closed"
fi

DECISION="${RESULT%%::*}"
REASON="${RESULT#*::}"

case "$DECISION" in
  ALLOW)
    gate_allow
    ;;
  DENY)
    gate_deny "register-fields-gate" "$REASON"
    ;;
  *)
    gate_deny "register-fields-gate" "unrecognized gate result, failing closed: $RESULT"
    ;;
esac
