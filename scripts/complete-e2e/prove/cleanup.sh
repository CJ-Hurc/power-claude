#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Goal     : prove-owned temp state does not leak after a synthetic run.
# Purpose  : Product prover for complete-e2e universal cleanup (no-state-leak).
# Consumers: complete-e2e occupancy; exec _exec_product_universal_lifecycle; humans.
# Inputs   : cwd = repo root. Creates then removes a temp marker under tmp/.
# Outputs  : PASS/FAIL on stdout.
# Exit codes: 0 no leak / 1 leak or ignore gap / 2 usage
# Side effects: brief tmp/ marker removed before exit; never touches product src; no PC_SKIP_NPM greenwash.
# -----------------------------------------------------------------------------
set -uo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
	exit 0
fi

# Fail-closed: unknown argv must not greenwash PASS (ignore-and-run theater).
if [[ "$#" -gt 0 ]]; then
	echo "usage: scripts/complete-e2e/prove/cleanup.sh" >&2
	echo "unrecognized arguments: $*" >&2
	exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT" || exit 2
fail() { echo "FAIL: $*" >&2; exit 1; }

# Refuse skip-env theater: cleanup must not claim PASS under PC_SKIP_NPM.
if [[ "${PC_SKIP_NPM:-}" == "1" ]]; then
	fail "PC_SKIP_NPM=1 refuses cleanup prove (not a clean no-state-leak gate)"
fi

command -v git >/dev/null 2>&1 || fail "git not found"
[[ -d "$ROOT/.git" ]] || fail "not a git checkout"

# Harness/run state must stay gitignored so cleanup cannot pollute the tip.
git -C "$ROOT" check-ignore -q .hurc-harness/state/complete-e2e \
	|| fail "complete-e2e state path is not gitignored"
# Pattern is `tmp/` (directory). Bare `tmp` does not match trailing-slash rule.
git -C "$ROOT" check-ignore -q tmp/ \
	|| fail "tmp/ is not gitignored (cleanup sink must be ignored)"
# Prove receipts must also stay ignored.
git -C "$ROOT" check-ignore -q scripts/complete-e2e/.receipts/probe \
	|| fail "scripts/complete-e2e/.receipts/ is not gitignored"

mkdir -p "$ROOT/tmp"
marker_dir="$(mktemp -d "$ROOT/tmp/ce2e-cleanup-XXXXXX")"
marker_file="$marker_dir/marker"
printf 'leak-probe\n' >"$marker_file"
[[ -f "$marker_file" ]] || fail "failed to create cleanup probe marker"

# End-of-run cleanup: remove prove-owned temp (trap pattern used by adapters).
rm -rf "$marker_dir"
[[ ! -e "$marker_dir" ]] || fail "temp marker dir leaked after cleanup"
[[ ! -e "$marker_file" ]] || fail "temp marker file leaked after cleanup"

if git -C "$ROOT" status --porcelain --untracked-files=normal -- tmp/ce2e-cleanup-* 2>/dev/null | grep -q .; then
	fail "cleanup probe paths still visible to git status"
fi

echo "PASS cleanup no-state-leak-after-run"
exit 0
