#!/usr/bin/env bash
# Test harness for phase1-proposal-norms/hooks/proposal-shape-gate.sh.
# Real subprocess invocation with synthetic PreToolUse JSON payloads piped
# via stdin, throwaway mktemp -d + git init repo, CLAUDE_PROJECT_DIR set.
# Structure mirrors implementation-rulebook/tests/run-gate-tests.sh (cited
# by path only, no script body copied).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../proposal-shape-gate.sh"

# shellcheck source=lib/resolve-core.sh
. "$SCRIPT_DIR/lib/resolve-core.sh"
RESOLVED_CORE="$(resolve_core "$SCRIPT_DIR/../../../core" "$SCRIPT_DIR/../../../../tokenmaxxxer-core/core")"
RESOLVE_EC=$?
if [ "$RESOLVE_EC" -ne 0 ]; then
  exit 75
fi
export CLAUDE_PLUGIN_ROOT_CORE="$RESOLVED_CORE"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

cd "$WORKDIR" || exit 1
git init -q .
export CLAUDE_PROJECT_DIR="$WORKDIR"
unset PHASE1_PROPOSAL_NORMS_GATE_OFF

PASS=0
FAIL=0

run_case() {
  local name="$1" payload="$2" expect_exit="$3"
  local out ec
  out="$(printf '%s' "$payload" | bash "$GATE" 2>&1)"
  ec=$?
  if [ "$ec" = "$expect_exit" ]; then
    echo "PASS: $name"
    PASS=$((PASS+1))
  else
    echo "FAIL: $name (expected exit $expect_exit, got $ec; output: $out)"
    FAIL=$((FAIL+1))
  fi
}

make_payload() {
  # $1=tool_name $2=file_path $3=content (via stdin-safe env vars)
  TN="$1" FP="$2" CT="$3" python3 -c "
import json, os
print(json.dumps({
  'tool_name': os.environ['TN'],
  'tool_input': {'file_path': os.environ['FP'], 'content': os.environ['CT']}
}))
"
}

GOOD_CONTENT='# Proposal

Status: Phase 1 proposal — APPROVE is out of scope for this PR.

See docs/issue-9/reports/foo/survey.md for current-state findings.
'

# Case 1: Allow — phase-gate statement + survey citation both present.
mkdir -p docs/issue-9/proposals
payload="$(make_payload 'Write' 'docs/issue-9/proposals/foo.md' "$GOOD_CONTENT")"
run_case "allow: phase-gate + survey citation present" "$payload" 0

# Case 2: Deny — phase-gate statement missing.
NO_GATE_CONTENT='# Proposal

See docs/issue-9/reports/foo/survey.md for current-state findings.
'
payload="$(make_payload 'Write' 'docs/issue-9/proposals/foo.md' "$NO_GATE_CONTENT")"
run_case "deny: phase-gate statement missing" "$payload" 2

# Case 3: Deny — survey citation missing.
NO_SURVEY_CONTENT='# Proposal

Status: Phase 1 proposal — APPROVE is out of scope for this PR.
'
payload="$(make_payload 'Write' 'docs/issue-9/proposals/foo.md' "$NO_SURVEY_CONTENT")"
run_case "deny: survey citation missing" "$payload" 2

# Case 4: Allow — write outside scope regex, content irrelevant.
payload="$(make_payload 'Write' 'README.md' 'no gate stuff at all')"
run_case "allow: outside scope (README.md)" "$payload" 0

payload="$(make_payload 'Write' 'docs/issue-9/reports/x.md' 'no gate stuff at all')"
run_case "allow: outside scope (docs/issue-9/reports/x.md)" "$payload" 0

# Case 5: Deny — malformed JSON payload (fail-closed).
run_case "deny: malformed JSON payload" "{not valid json" 2

# Case 6: Deny — Edit whose old_string doesn't match.
mkdir -p docs/issue-9/proposals
printf '%s' "$GOOD_CONTENT" > docs/issue-9/proposals/existing.md
payload="$(python3 -c "
import json
print(json.dumps({
  'tool_name': 'Edit',
  'tool_input': {
    'file_path': 'docs/issue-9/proposals/existing.md',
    'old_string': 'THIS STRING DOES NOT EXIST IN THE FILE',
    'new_string': 'replacement'
  }
}))
")"
run_case "deny: Edit old_string not found" "$payload" 2

# Case 7: Allow — kill switch set, allow regardless of content.
PHASE1_PROPOSAL_NORMS_GATE_OFF=1
export PHASE1_PROPOSAL_NORMS_GATE_OFF
payload="$(make_payload 'Write' 'docs/issue-9/proposals/foo.md' 'no gate stuff at all')"
run_case "allow: kill switch set" "$payload" 0
unset PHASE1_PROPOSAL_NORMS_GATE_OFF

# ============================================================================
# Mandatory test cases (issue-10 §3, 6 per plugin)
# ============================================================================

mkdir -p docs/issue-9/proposals

# 1. Edit with replace_all: true against multiply-occurring old_string.
DUP_CONTENT='# Proposal

Status: Phase 1 proposal — APPROVE is out of scope for this PR.

See docs/issue-9/reports/foo/survey.md for current-state findings.
PLACEHOLDER note. PLACEHOLDER again.
'
printf '%s' "$DUP_CONTENT" > docs/issue-9/proposals/dup.md
payload="$(python3 -c "
import json
print(json.dumps({'tool_name': 'Edit', 'tool_input': {
  'file_path': 'docs/issue-9/proposals/dup.md',
  'old_string': 'PLACEHOLDER', 'new_string': 'filled', 'replace_all': True
}}))
")"
run_case "replace_all true replaces every occurrence" "$payload" 0

# 2. MultiEdit with mixed replace_all true/false edits.
MULTI_CONTENT='# Proposal

Status: Phase 1 proposal — APPROVE is out of scope for this PR.

See docs/issue-9/reports/foo/survey.md for current-state findings.
AAA BBB note.
'
printf '%s' "$MULTI_CONTENT" > docs/issue-9/proposals/multi.md
payload="$(python3 -c "
import json
print(json.dumps({'tool_name': 'MultiEdit', 'tool_input': {
  'file_path': 'docs/issue-9/proposals/multi.md',
  'edits': [
    {'old_string': 'AAA', 'new_string': 'XXX', 'replace_all': True},
    {'old_string': 'BBB', 'new_string': 'YYY', 'replace_all': False},
  ],
}}))
")"
run_case "MultiEdit honors each edit's own replace_all flag" "$payload" 0

# 3. Malformed JSON: truncated, non-object top level, empty payload -> deny not crash.
run_case "deny: truncated JSON" '{"tool_name": "Write"' 2
run_case "deny: non-object top-level JSON" '["not", "an", "object"]' 2
run_case "deny: empty payload" '' 2

# 4. Kill switch set to an unrecognized/typo value -> gate stays ACTIVE.
payload="$(make_payload 'Write' 'docs/issue-9/proposals/foo.md' 'garbage')"
out="$(printf '%s' "$payload" | PHASE1_PROPOSAL_NORMS_GATE_OFF=onn bash "$GATE" 2>&1)"
ec=$?
if [ "$ec" = 2 ]; then
  echo "PASS: deny: kill switch unrecognized value keeps gate active"
  PASS=$((PASS+1))
else
  echo "FAIL: deny: kill switch unrecognized value keeps gate active (exit=$ec; output: $out)"
  FAIL=$((FAIL+1))
fi

# 5. Absolute file_path matching the same scope a relative-path fixture
#    already matches, plus a ./-prefixed variant.
printf '%s' "$GOOD_CONTENT" > docs/issue-9/proposals/abscheck.md
payload="$(make_payload 'Write' "$WORKDIR/docs/issue-9/proposals/abscheck.md" "$GOOD_CONTENT")"
run_case "allow: absolute file_path normalizes to in-scope" "$payload" 0

payload="$(make_payload 'Write' './docs/issue-9/proposals/dotcheck.md' "$GOOD_CONTENT")"
run_case "allow: ./-prefixed file_path normalizes to in-scope" "$payload" 0

# 6. Internal-judge-crash simulation: JSON-valid input the business logic
#    mishandles, forcing an uncaught exception -> deny with a crash reason.
payload="$(make_payload 'Write' 'docs/issue-9/proposals/crash.md' '__FORCE_INTERNAL_CRASH__')"
out="$(printf '%s' "$payload" | bash "$GATE" 2>&1)"
ec=$?
if [ "$ec" = 2 ] && printf '%s' "$out" | grep -q "crashed"; then
  echo "PASS: deny: internal judge crash fails closed"
  PASS=$((PASS+1))
else
  echo "FAIL: deny: internal judge crash fails closed (exit=$ec; output: $out)"
  FAIL=$((FAIL+1))
fi

# 7. CLAUDE_PLUGIN_ROOT_CORE points at a nonexistent directory -> the
#    gate-lib.sh source fails and the gate must fail closed (exit 2),
#    per issue-13 item 1's `||` guard.
payload="$(make_payload 'Write' 'docs/issue-9/proposals/foo.md' "$GOOD_CONTENT")"
out="$(printf '%s' "$payload" | CLAUDE_PLUGIN_ROOT_CORE="/nonexistent-core-$$" bash "$GATE" 2>&1)"
ec=$?
if [ "$ec" = 2 ]; then
  echo "PASS: deny: missing CLAUDE_PLUGIN_ROOT_CORE fails closed"
  PASS=$((PASS+1))
else
  echo "FAIL: deny: missing CLAUDE_PLUGIN_ROOT_CORE fails closed (exit=$ec; output: $out)"
  FAIL=$((FAIL+1))
fi

# 8. Edit reconstruction that removes the "Status: Phase 1 proposal" line
#    from an initially-compliant proposal must be denied (issue-13 §3b).
printf '%s' "$GOOD_CONTENT" > docs/issue-9/proposals/edit-shape-removal.md
payload="$(python3 -c "
import json
print(json.dumps({'tool_name': 'Edit', 'tool_input': {
  'file_path': 'docs/issue-9/proposals/edit-shape-removal.md',
  'old_string': 'Status: Phase 1 proposal — APPROVE is out of scope for this PR.\n\n',
  'new_string': ''
}}))
")"
run_case "deny: Edit reconstruction removing phase-gate statement" "$payload" 2

echo ""
echo "Summary: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
exit 0
