#!/usr/bin/env bash
# Directive fragment owned by phase2-record-norms.
#
# Per proposal docs/issue-7/proposals/risk-management-plugin-enforcement.md
# §1.3 (phase2 half), this fragment is sourced and concatenated by a
# role's own hooks/directive.sh (per §0.4's composition mechanism) into
# that role's phase-2 --produces string. This file performs no sourcing
# of its own and has no side effects when sourced — it only defines
# phase2_record_norms_fragment, to be called by the composing role.
#
# Role-agnostic by design (proposal §0.2): this prose names no specific
# role or methodology, so it composes into any role's phase-2 norm.

phase2_record_norms_fragment() {
  cat <<'EOF'
### Phase-2 record norm (phase2-record-norms)

A phase-2 record (docs/issue-<n>/reports/<role>.md) must cite the
phase-1 proposal it implements via an explicit "Implements:" backlink
line naming the proposal file (docs/issue-<n>/proposals/*.md, same
issue number as the record itself). A record with no such backlink
breaks the phase-1/phase-2 handoff and will be denied by this plugin's
gate.

A phase-2 write must also not occur before an Approve marker exists for
the phase-1 proposal it implements (contract v3 s19's phase gate). This
requirement is stated here as a human-process obligation: the gate
script this plugin ships cannot itself verify an Approve marker, since
a PreToolUse hook has no GitHub API access to check issue/PR state. The
author and reviewer are responsible for honoring this ordering; the
script only enforces the backlink-presence half.
EOF
}
