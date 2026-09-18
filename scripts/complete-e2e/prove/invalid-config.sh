#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Goal     : operator CLIs reject reserved --hurc-ce2e-* unknown options.
# Purpose  : Product prover for complete-e2e universal invalid-config fault.
# Consumers: complete-e2e occupancy; exec _exec_product_universal_fault; humans.
# Inputs   : cwd = repo root.
# Outputs  : PASS/FAIL on stdout.
# Exit codes: 0 product fail-closed / 1 product accepted invalid option / 2 usage
# Side effects: none (never runs full consumer/prove — reject path only).
# -----------------------------------------------------------------------------
set -uo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
	exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT" || exit 2
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "python3 missing"
[[ -f "$ROOT/scripts/complete-e2e/list-surfaces.py" ]] || fail "list-surfaces.py missing"
[[ -f "$ROOT/scripts/complete-e2e/run.py" ]] || fail "run.py missing"
[[ -f "$ROOT/scripts/complete-e2e/consumer.py" ]] || fail "consumer.py missing"
[[ -f "$ROOT/scripts/verify/run.py" ]] || fail "verify/run.py missing"
[[ -f "$ROOT/scripts/complete-e2e/prove.py" ]] || fail "prove.py missing"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Inventory CLI (argparse) + operator CLIs that previously ignored unknown argv
# and greenwashed a live PASS — must all fail-closed without running full prove.
targets=(
	"scripts/complete-e2e/list-surfaces.py"
	"scripts/complete-e2e/run.py"
	"scripts/complete-e2e/consumer.py"
	"scripts/verify/run.py"
	"scripts/complete-e2e/prove.py"
)

for rel in "${targets[@]}"; do
	set +e
	python3 "$ROOT/$rel" --hurc-ce2e-no-such-flag \
		>"$tmp/out" 2>"$tmp/err"
	rc=$?
	set -e
	text="$(cat "$tmp/out" "$tmp/err" 2>/dev/null || true)"
	[[ "$rc" -ne 0 ]] || fail "$rel accepted --hurc-ce2e-no-such-flag (rc=$rc)"
	printf '%s' "$text" | grep -qiE 'unrecognized arguments|unknown option|usage:' \
		|| fail "$rel unknown-option diagnostic missing from fail-closed output"
	# Theater-kill: must not start a live consumer/complete-e2e run under bad argv.
	if printf '%s' "$text" | grep -qiE 'COMPLETE_E2E: PASS|VERIFY: PASS|consumer complete-e2e'; then
		fail "$rel still ran live prove under unknown flag"
	fi
done

echo "PASS invalid-config reserved --hurc-ce2e-* fail-closed on list-surfaces+operator CLIs"
exit 0
