# Test-env core resolution, per the canonical convention at
# tokenmaxxxer/on-the-record docs/specs/test-env-resolution.md (issue #551).
#
# Resolution order:
#   1. $CLAUDE_PLUGIN_ROOT_CORE if set and its hooks/lib/gate-lib.sh is
#      non-empty.
#   2. The first sibling candidate passed as an argument whose
#      hooks/lib/gate-lib.sh is non-empty.
#   3. Otherwise SKIP: print the convention's message to stderr and
#      return 75 (EX_TEMPFAIL) — no network fallback, per the doc.
#
# On success, prints the resolved core path to stdout and returns 0;
# callers export CLAUDE_PLUGIN_ROOT_CORE to that path themselves.

resolve_core() {
  local candidate

  if [ -n "${CLAUDE_PLUGIN_ROOT_CORE:-}" ] && [ -s "$CLAUDE_PLUGIN_ROOT_CORE/hooks/lib/gate-lib.sh" ]; then
    printf '%s\n' "$CLAUDE_PLUGIN_ROOT_CORE"
    return 0
  fi

  for candidate in "$@"; do
    if [ -s "$candidate/hooks/lib/gate-lib.sh" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  echo "SKIP: core plugin unreachable — unverifiable outside spawn env" >&2
  return 75
}
