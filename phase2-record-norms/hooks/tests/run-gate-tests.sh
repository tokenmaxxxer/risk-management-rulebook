#!/usr/bin/env bash
# Test harness for phase2-record-norms/hooks/record-shape-gate.sh.
#
# Real subprocess invocation with synthetic PreToolUse JSON payloads
# piped via stdin, against a throwaway git repo. Structure mirrors the
# real-subprocess / synthetic-payload / throwaway-git-init harness cited
# in implementation-rulebook/tests/run-gate-tests.sh (path-only
# citation, no body copied), per proposal §3.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../record-shape-gate.sh"

PASS=0
FAIL=0

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

git -C "$WORKDIR" init -q
export CLAUDE_PROJECT_DIR="$WORKDIR"

mkdir -p "$WORKDIR/docs/issue-9/reports"
mkdir -p "$WORKDIR/docs/issue-9/proposals"

run_case() {
  local name="$1"
  local payload="$2"
  local expect_exit="$3"
  local expect_stderr_substr="${4:-}"

  local stderr_file
  stderr_file="$(mktemp)"
  local extra_env="${5:-}"

  local actual_exit
  if [[ -n "$extra_env" ]]; then
    printf '%s' "$payload" | env "$extra_env" "$GATE" >/dev/null 2>"$stderr_file"
    actual_exit=$?
  else
    printf '%s' "$payload" | "$GATE" >/dev/null 2>"$stderr_file"
    actual_exit=$?
  fi

  local ok=1
  if [[ "$actual_exit" != "$expect_exit" ]]; then
    ok=0
  fi
  if [[ -n "$expect_stderr_substr" ]] && ! grep -qF "$expect_stderr_substr" "$stderr_file"; then
    ok=0
  fi

  if [[ "$ok" == "1" ]]; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (exit=$actual_exit, expected=$expect_exit)"
    echo "  stderr: $(cat "$stderr_file")"
    FAIL=$((FAIL + 1))
  fi
  rm -f "$stderr_file"
}

make_payload() {
  # args: tool_name file_path key1 val1 ...(content or old_string/new_string)
  python3 - "$@" <<'PYEOF'
import json, sys
tool_name = sys.argv[1]
file_path = sys.argv[2]
rest = sys.argv[3:]
tool_input = {"file_path": file_path}
if tool_name == "Write":
    tool_input["content"] = rest[0]
elif tool_name == "Edit":
    tool_input["old_string"] = rest[0]
    tool_input["new_string"] = rest[1]
print(json.dumps({"tool_name": tool_name, "tool_input": tool_input}))
PYEOF
}

# --- Case 1: Allow, backlink present, matching issue numbers, distinct issue 9 ---
CONTENT_ALLOW="# Some Role Record

Implements: docs/issue-9/proposals/foo.md

Body text.
"
PAYLOAD_ALLOW="$(make_payload Write docs/issue-9/reports/some-role.md "$CONTENT_ALLOW")"
run_case "allow: backlink present, matching issue numbers" "$PAYLOAD_ALLOW" 0

# --- Case 2: Deny, backlink missing entirely ---
CONTENT_NOBACKLINK="# Some Role Record

Body text with no backlink.
"
PAYLOAD_NOBACKLINK="$(make_payload Write docs/issue-9/reports/some-role.md "$CONTENT_NOBACKLINK")"
run_case "deny: backlink missing" "$PAYLOAD_NOBACKLINK" 2 "no \"Implements:\""

# --- Case 3: Deny, backlink points to a different issue number ---
CONTENT_MISMATCH="# Some Role Record

Implements: docs/issue-3/proposals/foo.md

Body text.
"
PAYLOAD_MISMATCH="$(make_payload Write docs/issue-9/reports/some-role.md "$CONTENT_MISMATCH")"
run_case "deny: backlink issue number mismatch" "$PAYLOAD_MISMATCH" 2 "does not match record's own issue number"

# --- Case 4a: Allow, out of scope path (docs/other.md) ---
PAYLOAD_OUTOFSCOPE1="$(make_payload Write docs/other.md "no implements line at all")"
run_case "allow: out of scope (docs/other.md)" "$PAYLOAD_OUTOFSCOPE1" 0

# --- Case 4b: Allow, out of scope path (proposals dir, not reports) ---
PAYLOAD_OUTOFSCOPE2="$(make_payload Write docs/issue-9/proposals/x.md "no implements line at all")"
run_case "allow: out of scope (docs/issue-9/proposals/x.md)" "$PAYLOAD_OUTOFSCOPE2" 0

# --- Case 5: Deny, malformed JSON ---
run_case "deny: malformed JSON payload" "{not valid json" 2 "not valid JSON"

# --- Case 6: Deny, Edit whose old_string doesn't match ---
mkdir -p "$WORKDIR/docs/issue-9/reports"
cat > "$WORKDIR/docs/issue-9/reports/existing.md" <<'EOF'
# Existing Record

Implements: docs/issue-9/proposals/foo.md
EOF
PAYLOAD_EDIT_MISMATCH="$(make_payload Edit docs/issue-9/reports/existing.md "THIS STRING DOES NOT EXIST" "replacement")"
run_case "deny: Edit old_string not found" "$PAYLOAD_EDIT_MISMATCH" 2 "old_string not found"

# --- Case 7: Allow, kill switch set, regardless of content ---
run_case "allow: kill switch set" "$PAYLOAD_NOBACKLINK" 0 "" "PHASE2_RECORD_NORMS_GATE_OFF=1"

# ============================================================================
# Mandatory test cases (issue-10 §3, 6 per plugin)
# ============================================================================

# 1. Edit with replace_all: true against multiply-occurring old_string.
DUP_CONTENT="# Some Role Record

Implements: docs/issue-9/proposals/foo.md

PLACEHOLDER body. PLACEHOLDER again.
"
printf '%s' "$DUP_CONTENT" > "$WORKDIR/docs/issue-9/reports/dup.md"
DUP_PAYLOAD=$(python3 - "$WORKDIR/docs/issue-9/reports/dup.md" <<'PYEOF'
import json, sys
print(json.dumps({"tool_name": "Edit", "tool_input": {
  "file_path": sys.argv[1], "old_string": "PLACEHOLDER", "new_string": "filled", "replace_all": True
}}))
PYEOF
)
run_case "replace_all true replaces every occurrence" "$DUP_PAYLOAD" 0

# 2. MultiEdit with mixed replace_all true/false edits.
MULTI_CONTENT="# Some Role Record

Implements: docs/issue-9/proposals/foo.md

AAA BBB body.
"
printf '%s' "$MULTI_CONTENT" > "$WORKDIR/docs/issue-9/reports/multi.md"
MULTI_PAYLOAD=$(python3 - "$WORKDIR/docs/issue-9/reports/multi.md" <<'PYEOF'
import json, sys
print(json.dumps({"tool_name": "MultiEdit", "tool_input": {
  "file_path": sys.argv[1],
  "edits": [
    {"old_string": "AAA", "new_string": "XXX", "replace_all": True},
    {"old_string": "BBB", "new_string": "YYY", "replace_all": False},
  ],
}}))
PYEOF
)
run_case "MultiEdit honors each edit's own replace_all flag" "$MULTI_PAYLOAD" 0

# 3. Malformed JSON: truncated, non-object top level, empty payload -> deny not crash.
run_case "deny: truncated JSON" '{"tool_name": "Write"' 2
run_case "deny: non-object top-level JSON" '["not", "an", "object"]' 2 "not a JSON object"
run_case "deny: empty payload" '' 2 "empty tool-use payload"

# 4. Kill switch set to an unrecognized/typo value -> gate stays ACTIVE.
run_case "deny: kill switch unrecognized value keeps gate active" "$PAYLOAD_NOBACKLINK" 2 "" "PHASE2_RECORD_NORMS_GATE_OFF=onn"

# 5. Absolute file_path matching the same scope a relative-path fixture
#    already matches, plus a ./-prefixed variant.
run_case "allow: absolute file_path normalizes to in-scope" "$PAYLOAD_ALLOW" 0
PAYLOAD_DOTPATH="$(make_payload Write ./docs/issue-9/reports/some-role-dot.md "$CONTENT_ALLOW")"
run_case "allow: ./-prefixed file_path normalizes to in-scope" "$PAYLOAD_DOTPATH" 0

# 6. Internal-judge-crash simulation: JSON-valid input the business logic
#    mishandles, forcing an uncaught exception -> deny with a crash reason.
PAYLOAD_CRASH="$(make_payload Write docs/issue-9/reports/crash.md "__FORCE_INTERNAL_CRASH__")"
run_case "deny: internal judge crash fails closed" "$PAYLOAD_CRASH" 2 "crashed"

echo ""
echo "=== phase2-record-norms gate tests: $PASS passed, $FAIL failed ==="

if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
exit 0
