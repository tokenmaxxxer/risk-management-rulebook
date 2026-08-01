#!/usr/bin/env bash
# PreToolUse gate: erm-verdict-methodology.
# Enforces ISO 31000:2018 process-clause ordering (6.3/6.4/6.5/6.6) on
# erm-verdict facet documents. Structure adapted (cited by path, no
# script body copied) from pricing-rulebook/pricing/hooks/methodology-gate.sh
# and implementation-rulebook/coding/hooks/coding-progress-gate.sh.
#
# Canon migration (issue-10 §1): sources core's gate-house standard
# library instead of hand-rolling the trap/kill-switch/deny/parse/
# reconstruct machinery.
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "erm-order-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
set -uo pipefail

gate_kill_switch_active "${ERM_VERDICT_METHODOLOGY_GATE_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || gate_deny "erm-order-gate" "python3 required"
command -v git >/dev/null 2>&1 || gate_deny "erm-order-gate" "git required"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$PROJECT_DIR" ]; then
  PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)" || gate_deny "erm-order-gate" "cannot determine project root"
fi

payload="$(cat 2>/dev/null || true)"

# The python source is written to a temp file first (rather than fed via a
# heredoc directly on the python3 invocation) because a heredoc attached to
# a command consumes that command's stdin, which would otherwise clobber
# the piped-in $payload before python ever sees it.
PYSCRIPT="$(mktemp)"
cat > "$PYSCRIPT" <<'PYEOF'
import importlib.util, json, os, re, sys

project_dir = sys.argv[1]

_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gate_lib)


def deny(msg):
    print("DENY::" + msg)
    sys.exit(0)


raw = sys.stdin.read()
event = gate_lib.gate_parse_json_or_deny(raw, deny)

tool_name = event.get("tool_name", "")
tool_input = event.get("tool_input", {}) or {}
file_path = tool_input.get("file_path", "")
if not file_path:
    print("ALLOW::no file_path")
    sys.exit(0)

SCOPE = re.compile(r"^docs/issue-[0-9]+/(proposals/.*risk-management.*|reports/risk-management)\.md$")
rel = gate_lib.gate_normalize_path(project_dir, file_path)
if rel is None or not SCOPE.match(rel):
    print("ALLOW::out of scope")
    sys.exit(0)

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
        "resulting content undeterminable, tool=%r); use Write for full "
        "content, or an Edit/MultiEdit whose old_string matches the "
        "current content" % tool_name
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

# Trigger-only special case (mandatory test 6): forcing an internal crash
# by malformed-but-JSON-valid input the business logic mishandles. A
# document consisting solely of this exact marker forces an uncaught
# exception here so the crash-path (§1.1 rc-check) is exercisable by a
# real gate run.
if content.strip() == "__FORCE_INTERNAL_CRASH__":
    raise RuntimeError("forced internal crash for regression test 6")

STAGES = [
    "Governance/context",
    "Assessment",
    "Risk treatment",
    "Monitoring and review",
]

def find_section(name):
    for sec in sections:
        if norm(sec["text"]) == norm(name):
            return sec
    return None

positions = []
for stage in STAGES:
    sec = find_section(stage)
    if sec is None:
        deny("missing required stage marker: ## %s" % stage)
    positions.append((stage, sec["start"]))

for i in range(1, len(positions)):
    if positions[i][1] < positions[i - 1][1]:
        deny("stage markers out of order: %s appears before %s" % (positions[i][0], positions[i - 1][0]))

# "Objective linkage" is now a sub-marker under Governance/context, not a
# standalone top-level stage (issue-10 §2.4 ISO 31000 vocabulary fix).
gov = find_section("Governance/context")
gov_body = "\n".join(lines[gov["start"]:gov["end"]])
if not (find_section("Objective linkage") and gov["start"] <= find_section("Objective linkage")["start"] < gov["end"]) \
   and "objective linkage" not in norm(gov_body):
    deny("Governance/context section is missing the Objective linkage sub-marker")

# risk-score-inherent/residual must live in the Assessment section, not
# merely anywhere in the document.
assessment = find_section("Assessment")
assessment_body = "\n".join(lines[assessment["start"]:assessment["end"]])

inherent = re.search(r"risk-score-inherent[:\s]+([^\n]+)", assessment_body)
residual = re.search(r"risk-score-residual[:\s]+([^\n]+)", assessment_body)
if not inherent:
    deny("missing risk-score-inherent label within the Assessment section")
if not residual:
    deny("missing risk-score-residual label within the Assessment section")
if inherent.group(1).strip() == residual.group(1).strip():
    deny("risk-score-inherent and risk-score-residual share the same value — must be distinct")

print("ALLOW::ok")
PYEOF

if ! result="$(printf '%s' "$payload" | python3 "$PYSCRIPT" "$PROJECT_DIR")"; then
  rc=$?
  rm -f "$PYSCRIPT"
  gate_deny "erm-order-gate" "internal judge crashed (rc=$rc) — failing closed"
fi
rm -f "$PYSCRIPT"

verdict="${result%%::*}"
reason="${result#*::}"

if [ "$verdict" = "DENY" ]; then
  gate_deny "erm-order-gate" "$reason"
fi
gate_allow
