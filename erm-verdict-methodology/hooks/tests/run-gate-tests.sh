#!/usr/bin/env bash
# Test harness for erm-verdict-methodology/hooks/erm-order-gate.sh.
# Runs the gate as a real subprocess against synthetic PreToolUse JSON
# payloads, in a throwaway git repo, per proposal §3
# (docs/issue-7/proposals/risk-management-plugin-enforcement.md).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../erm-order-gate.sh"

PASS=0
FAIL=0

FULL_DOC='## Governance/context
Objective: uptime SLA. Appetite: low.

## Objective linkage
Objective at risk: production uptime.

## Assessment
likelihood: medium
impact: high
risk-score-inherent: 12
existing controls: monitoring
risk-score-residual: 6
appetite threshold: 8

## Response
response tier: mitigate
mitigation owner: jane

## Monitoring
review-date: 2026-09-01
trigger: quarterly review
'

setup_repo() {
  local dir
  dir="$(mktemp -d)"
  (cd "$dir" && git init -q)
  mkdir -p "$dir/docs/issue-7/proposals"
  echo "$dir"
}

# run_case name expected_exit expected_stderr_substr payload_file
run_case() {
  local name="$1" expected_exit="$2" expected_substr="$3" payload="$4" env_extra="${5:-}"
  local out err ec
  err="$(mktemp)"
  if [ -n "$env_extra" ]; then
    out=$(env $env_extra bash "$GATE" < "$payload" 2> "$err")
  else
    out=$(bash "$GATE" < "$payload" 2> "$err")
  fi
  ec=$?
  local stderr_content
  stderr_content="$(cat "$err")"
  rm -f "$err"

  local ok=1
  if [ "$ec" != "$expected_exit" ]; then
    ok=0
  fi
  if [ -n "$expected_substr" ]; then
    case "$stderr_content" in
      *"$expected_substr"*) ;;
      *) ok=0 ;;
    esac
  fi

  if [ "$ok" = 1 ]; then
    echo "PASS: $name"
    PASS=$((PASS+1))
  else
    echo "FAIL: $name (exit=$ec expected=$expected_exit stderr='$stderr_content' expected_substr='$expected_substr')"
    FAIL=$((FAIL+1))
  fi
}

make_payload() {
  # make_payload tool_name file_path content
  local tool="$1" path="$2" content="$3"
  local content_file
  content_file="$(mktemp)"
  printf '%s' "$content" > "$content_file"
  python3 - "$tool" "$path" "$content_file" <<'PYEOF'
import json, sys
tool, path, content_file = sys.argv[1], sys.argv[2], sys.argv[3]
with open(content_file, "r", encoding="utf-8") as f:
    content = f.read()
print(json.dumps({"tool_name": tool, "tool_input": {"file_path": path, "content": content}}))
PYEOF
  rm -f "$content_file"
}

REPO="$(setup_repo)"
export CLAUDE_PROJECT_DIR="$REPO"
TARGET="docs/issue-7/proposals/risk-management-verdict.md"

# Case: Allow — full doc, correctly ordered, distinct scores
p="$(mktemp)"; make_payload "Write" "$TARGET" "$FULL_DOC" > "$p"
run_case "allow: full doc correctly ordered, distinct scores" 0 "" "$p"

# Case: Deny — markers out of order (swap Assessment and Objective linkage)
OUT_OF_ORDER='## Governance/context
ctx

## Assessment
risk-score-inherent: 12
risk-score-residual: 6

## Objective linkage
obj

## Response
resp

## Monitoring
mon
'
p="$(mktemp)"; make_payload "Write" "$TARGET" "$OUT_OF_ORDER" > "$p"
run_case "deny: markers out of order" 2 "out of order" "$p"

# Case: Deny — each stage missing, one at a time
STAGES=("## Governance/context" "## Objective linkage" "## Assessment" "## Response" "## Monitoring")
for stage in "${STAGES[@]}"; do
  doc="$FULL_DOC"
  # remove the line containing the stage marker
  missing_doc="$(printf '%s\n' "$doc" | grep -Fv -- "$stage")"
  p="$(mktemp)"; make_payload "Write" "$TARGET" "$missing_doc" > "$p"
  run_case "deny: missing stage marker $stage" 2 "missing required stage marker: $stage" "$p"
done

# Case: Deny — inherent/residual share same value
SAME_SCORE='## Governance/context
ctx

## Objective linkage
obj

## Assessment
risk-score-inherent: 8
risk-score-residual: 8

## Response
resp

## Monitoring
mon
'
p="$(mktemp)"; make_payload "Write" "$TARGET" "$SAME_SCORE" > "$p"
run_case "deny: inherent and residual share same value" 2 "must be distinct" "$p"

# Case: Allow — out of scope path
p="$(mktemp)"; make_payload "Write" "docs/other-file.md" "anything at all" > "$p"
run_case "allow: out of scope path" 0 "" "$p"

# Case: Deny — malformed JSON
p="$(mktemp)"; printf '{not valid json' > "$p"
run_case "deny: malformed JSON payload" 2 "malformed JSON payload" "$p"

# Case: Deny — Edit whose old_string doesn't match existing file
mkdir -p "$REPO/docs/issue-7/proposals"
printf '%s' "$FULL_DOC" > "$REPO/$TARGET"
p="$(mktemp)"
python3 - "$TARGET" > "$p" <<'PYEOF'
import json, sys
print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": sys.argv[1], "old_string": "NO SUCH STRING PRESENT", "new_string": "x"}}))
PYEOF
run_case "deny: Edit old_string not found" 2 "old_string not found" "$p"

# Case: Allow — kill switch set, deny-shaped content
BAD_DOC='## Governance/context only, nothing else'
p="$(mktemp)"; make_payload "Write" "$TARGET" "$BAD_DOC" > "$p"
run_case "allow: kill switch overrides" 0 "" "$p" "ERM_VERDICT_METHODOLOGY_GATE_OFF=1"

rm -rf "$REPO"

echo ""
echo "Summary: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
