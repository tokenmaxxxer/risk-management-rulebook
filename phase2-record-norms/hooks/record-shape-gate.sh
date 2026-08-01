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
#
# Canon migration (issue-10 §1): sources core's gate-house standard
# library instead of hand-rolling the trap/kill-switch/deny/parse/
# reconstruct machinery.
. "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh"
gate_trap_fail_closed
set -uo pipefail

gate_kill_switch_active "${PHASE2_RECORD_NORMS_GATE_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || gate_deny "record-shape-gate" "python3 not found - failing closed"
command -v git >/dev/null 2>&1 || gate_deny "record-shape-gate" "git not found - failing closed"

ROOT="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$ROOT" ]; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
  gate_deny "record-shape-gate" "could not determine project root - failing closed"
fi

PAYLOAD="$(cat 2>/dev/null || true)"

if ! RESULT="$(ROOT="$ROOT" PAYLOAD="$PAYLOAD" GATE_LIB_PY="$GATE_LIB_PY" python3 <<'PYEOF'
import importlib.util, json, os, re, sys

root = os.environ["ROOT"]
raw_payload = os.environ["PAYLOAD"]

_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gate_lib)


def deny(msg):
    print("DENY::" + msg)
    sys.exit(0)


payload = gate_lib.gate_parse_json_or_deny(raw_payload, deny)

tool_name = payload.get("tool_name")
tool_input = payload.get("tool_input") or {}
file_path = tool_input.get("file_path")

if not tool_name or not file_path:
    deny("missing tool_name or file_path in payload - failing closed")

rel_path = gate_lib.gate_normalize_path(root, file_path)

SCOPE_RE = re.compile(r"^docs/issue-[0-9]+/reports/[a-z-]+\.md$")
if rel_path is None or not SCOPE_RE.match(rel_path):
    print("ALLOW::out of scope for phase2-record-norms gate")
    sys.exit(0)

own_issue_m = re.match(r"^docs/issue-([0-9]+)/reports/[a-z-]+\.md$", rel_path)
own_issue = own_issue_m.group(1)

abs_path = file_path if os.path.isabs(file_path) else os.path.join(root, file_path)

current = None
if os.path.isfile(abs_path):
    try:
        with open(abs_path, "r", encoding="utf-8") as f:
            current = f.read()
    except OSError:
        deny("could not read existing file - failing closed")

if tool_name not in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
    print("ALLOW::tool_name not Write/Edit/MultiEdit/NotebookEdit")
    sys.exit(0)

content, ok = gate_lib.gate_reconstruct_write(tool_name, tool_input, current)
if not ok or content is None:
    deny(
        "old_string not found (or the tool input's shape makes the "
        "resulting content undeterminable, tool=%r) - failing closed" % tool_name
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

implements_re = re.compile(r"^Implements:\s*(.+)$", re.MULTILINE)
match = implements_re.search(checked_text)
if not match:
    deny('no "Implements:" backlink line found - phase-2 record must cite the phase-1 proposal it implements')

target = match.group(1).strip()
proposal_re = re.compile(r"docs/issue-([0-9]+)/proposals/[^\s]+\.md")
pm = proposal_re.search(target)
if not pm:
    deny('"Implements:" backlink does not reference a docs/issue-<n>/proposals/*.md path (got: %s)' % target)

target_issue = pm.group(1)
if target_issue != own_issue:
    deny('"Implements:" backlink issue number (%s) does not match record\'s own issue number (%s)' % (target_issue, own_issue))

print("ALLOW::Implements backlink present and issue numbers match")
PYEOF
)"; then
  rc=$?
  gate_deny "record-shape-gate" "internal judge crashed (rc=$rc) - failing closed"
fi

STATUS="${RESULT%%::*}"
REASON="${RESULT#*::}"

if [ "$STATUS" = "ALLOW" ]; then
  gate_allow
elif [ "$STATUS" = "DENY" ]; then
  gate_deny "record-shape-gate" "$REASON"
else
  gate_deny "record-shape-gate" "gate produced unrecognized output - failing closed: $RESULT"
fi
