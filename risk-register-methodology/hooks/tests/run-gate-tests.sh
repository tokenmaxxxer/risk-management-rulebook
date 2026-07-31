#!/usr/bin/env bash
# run-gate-tests.sh
#
# Real-subprocess test harness for risk-register-methodology's
# register-fields-gate.sh. Structure adapted BY PATH ONLY (no body copied)
# from implementation-rulebook/coding/hooks/tests/run-gate-tests.sh's
# real-subprocess / synthetic-JSON-payload / throwaway-git-init-repo harness
# (per docs/issue-7/proposals/risk-management-plugin-enforcement.md §3;
# source file not present in this repo checkout).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../register-fields-gate.sh"

WORKDIR="$(mktemp -d)"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

git init -q "$WORKDIR"
export CLAUDE_PROJECT_DIR="$WORKDIR"

PASS=0
FAIL=0

# --- fixture: a fully valid risk-register-entry body ------------------------
VALID_BODY='## Risk register entry

risk-id: RR-001
risk-description: Vendor outage impacting billing pipeline
risk-category: operational
likelihood: medium
impact: high
risk-score-inherent: 12
existing-controls: dual-vendor failover configured
risk-score-residual: 6
risk-appetite-threshold: 8
mitigation-owner: Jane Kim
mitigation-plan: Add secondary vendor contract and automated failover test
review-date: 2026-09-01
'

run_case() {
  # run_case <name> <expected: allow|deny> <payload_json> [deny_substring]
  local name="$1"
  local expected="$2"
  local payload="$3"
  local deny_substr="${4:-}"

  local out_file err_file
  out_file="$(mktemp)"
  err_file="$(mktemp)"

  printf '%s' "$payload" | "$GATE" >"$out_file" 2>"$err_file"
  local ec=$?

  local ok=1
  if [ "$expected" = "allow" ]; then
    if [ "$ec" -ne 0 ]; then
      ok=0
    fi
  else
    if [ "$ec" -ne 2 ]; then
      ok=0
    fi
    if [ -n "$deny_substr" ] && ! grep -qi -- "$deny_substr" "$err_file"; then
      ok=0
    fi
  fi

  if [ "$ok" -eq 1 ]; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (exit=$ec, expected=$expected)"
    echo "  stderr: $(cat "$err_file")"
    FAIL=$((FAIL + 1))
  fi

  rm -f "$out_file" "$err_file"
}

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

write_payload() {
  # write_payload <rel_path> <content>
  local rel_path="$1"
  local content="$2"
  local content_json
  content_json="$(printf '%s' "$content" | json_escape)"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s/%s","content":%s}}' \
    "$WORKDIR" "$rel_path" "$content_json"
}

# ============================================================================
# Case: Allow — all 12 fields present, valid category/owner/date
# ============================================================================
run_case "allow: valid register entry" "allow" \
  "$(write_payload "docs/issue-7/proposals/risk-management-test.md" "$VALID_BODY")"

# ============================================================================
# Deny: one field missing — representative subset (>= 4 fields)
# ============================================================================
missing_field_case() {
  local field="$1"
  local body
  body="$(printf '%s' "$VALID_BODY" | grep -v "^${field}:")"
  run_case "deny: missing field $field" "deny" \
    "$(write_payload "docs/issue-7/proposals/risk-management-test.md" "$body")" \
    "$field"
}
missing_field_case "risk-id"
missing_field_case "risk-score-residual"
missing_field_case "mitigation-plan"
missing_field_case "review-date"
missing_field_case "existing-controls"

# ============================================================================
# Deny: mitigation-owner placeholder
# ============================================================================
TBD_BODY="$(printf '%s' "$VALID_BODY" | sed 's/^mitigation-owner:.*/mitigation-owner: TBD/')"
run_case "deny: mitigation-owner TBD" "deny" \
  "$(write_payload "docs/issue-7/proposals/risk-management-test.md" "$TBD_BODY")" \
  "mitigation-owner"

# ============================================================================
# Deny: risk-category invalid free text, no justification marker
# ============================================================================
BAD_CATEGORY_BODY="$(printf '%s' "$VALID_BODY" | sed 's/^risk-category:.*/risk-category: reputational/')"
run_case "deny: risk-category invalid, no justification" "deny" \
  "$(write_payload "docs/issue-7/proposals/risk-management-test.md" "$BAD_CATEGORY_BODY")" \
  "risk-category"

# Allow: risk-category with justification marker should pass this check
# (verify convention works, not part of required minimum cases but useful signal)
JUSTIFIED_CATEGORY_BODY="$(printf '%s' "$VALID_BODY" | sed 's/^risk-category:.*/risk-category: reputational (justified: brand-facing incident)/')"
run_case "allow: risk-category justified free text" "allow" \
  "$(write_payload "docs/issue-7/proposals/risk-management-test.md" "$JUSTIFIED_CATEGORY_BODY")"

# ============================================================================
# Allow: write outside scope regex → allow regardless of content
# ============================================================================
run_case "allow: out of scope path" "allow" \
  "$(write_payload "docs/issue-7/notes/random.md" "garbage content with no fields at all")"

# ============================================================================
# Deny: malformed JSON payload (fail-closed)
# ============================================================================
run_case "deny: malformed JSON" "deny" \
  '{"tool_name":"Write","tool_input":{'

# ============================================================================
# Deny: Edit whose old_string doesn't match
# ============================================================================
IN_SCOPE_REL="docs/issue-7/reports/risk-management.md"
IN_SCOPE_ABS="$WORKDIR/$IN_SCOPE_REL"
mkdir -p "$(dirname "$IN_SCOPE_ABS")"
printf '%s' "$VALID_BODY" > "$IN_SCOPE_ABS"

EDIT_PAYLOAD=$(python3 - "$IN_SCOPE_ABS" <<'PYEOF'
import json, sys
path = sys.argv[1]
payload = {
    "tool_name": "Edit",
    "tool_input": {
        "file_path": path,
        "old_string": "this-string-does-not-exist-anywhere",
        "new_string": "replacement",
    },
}
print(json.dumps(payload))
PYEOF
)
run_case "deny: Edit old_string mismatch" "deny" "$EDIT_PAYLOAD" "old_string"

# ============================================================================
# Allow: kill switch set → allow regardless of content
# ============================================================================
KILLSWITCH_OUT="$(mktemp)"
KILLSWITCH_ERR="$(mktemp)"
printf '%s' "$(write_payload "docs/issue-7/proposals/risk-management-test.md" "garbage, no fields")" | \
  RISK_REGISTER_METHODOLOGY_GATE_OFF=1 "$GATE" >"$KILLSWITCH_OUT" 2>"$KILLSWITCH_ERR"
KS_EC=$?
if [ "$KS_EC" -eq 0 ]; then
  echo "PASS: allow: kill switch bypasses gate"
  PASS=$((PASS + 1))
else
  echo "FAIL: allow: kill switch bypasses gate (exit=$KS_EC)"
  echo "  stderr: $(cat "$KILLSWITCH_ERR")"
  FAIL=$((FAIL + 1))
fi
rm -f "$KILLSWITCH_OUT" "$KILLSWITCH_ERR"

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "=== summary: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
