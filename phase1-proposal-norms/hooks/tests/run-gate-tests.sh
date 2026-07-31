#!/usr/bin/env bash
# Test harness for phase1-proposal-norms/hooks/proposal-shape-gate.sh.
# Real subprocess invocation with synthetic PreToolUse JSON payloads piped
# via stdin, throwaway mktemp -d + git init repo, CLAUDE_PROJECT_DIR set.
# Structure mirrors implementation-rulebook/tests/run-gate-tests.sh (cited
# by path only, no script body copied).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../proposal-shape-gate.sh"

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

echo ""
echo "Summary: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
exit 0
