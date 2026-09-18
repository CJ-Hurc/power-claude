#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Goal     : operator+readme-media+prove-floor CLIs reject reserved --hurc-ce2e-* unknown options.
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

# Fail-closed: unknown argv must not greenwash PASS (ignore-and-run theater).
if [[ "$#" -gt 0 ]]; then
	echo "usage: scripts/complete-e2e/prove/invalid-config.sh" >&2
	echo "unrecognized arguments: $*" >&2
	exit 2
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
[[ -f "$ROOT/scripts/tidy/run.py" ]] || fail "tidy/run.py missing"
[[ -f "$ROOT/scripts/enforce/run.py" ]] || fail "enforce/run.py missing"
[[ -f "$ROOT/scripts/release-ready/run.py" ]] || fail "release-ready/run.py missing"
[[ -f "$ROOT/scripts/complete-e2e/check_readme_media.py" ]] || fail "check_readme_media.py missing"
[[ -f "$ROOT/scripts/complete-e2e/prove/build.sh" ]] || fail "prove/build.sh missing"
[[ -f "$ROOT/scripts/complete-e2e/prove/cleanup.sh" ]] || fail "prove/cleanup.sh missing"
[[ -f "$ROOT/scripts/complete-e2e/prove/missing-env.sh" ]] || fail "prove/missing-env.sh missing"
[[ -f "$ROOT/scripts/complete-e2e/prove/startup.sh" ]] || fail "prove/startup.sh missing"
[[ -f "$ROOT/scripts/complete-e2e/prove/invalid-config.sh" ]] || fail "prove/invalid-config.sh missing"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Inventory + operator + floor + readme-media + prove-floor CLIs that previously
# ignored unknown argv and greenwashed a live PASS — must all fail-closed.
py_targets=(
	"scripts/complete-e2e/list-surfaces.py"
	"scripts/complete-e2e/run.py"
	"scripts/complete-e2e/consumer.py"
	"scripts/verify/run.py"
	"scripts/complete-e2e/prove.py"
	"scripts/tidy/run.py"
	"scripts/enforce/run.py"
	"scripts/release-ready/run.py"
	"scripts/complete-e2e/check_readme_media.py"
)
sh_targets=(
	"scripts/complete-e2e/prove/build.sh"
	"scripts/complete-e2e/prove/cleanup.sh"
	"scripts/complete-e2e/prove/missing-env.sh"
	"scripts/complete-e2e/prove/startup.sh"
	"scripts/complete-e2e/prove/invalid-config.sh"
)

check_unknown() {
	local runner="$1" rel="$2"
	set +e
	"$runner" "$ROOT/$rel" --hurc-ce2e-no-such-flag \
		>"$tmp/out" 2>"$tmp/err"
	local rc=$?
	set -e
	local text
	text="$(cat "$tmp/out" "$tmp/err" 2>/dev/null || true)"
	[[ "$rc" -ne 0 ]] || fail "$rel accepted --hurc-ce2e-no-such-flag (rc=$rc)"
	printf '%s' "$text" | grep -qiE 'unrecognized arguments|unknown option|usage:' \
		|| fail "$rel unknown-option diagnostic missing from fail-closed output"
	# Theater-kill: must not start a live consumer/complete-e2e/floor/prove-floor run under bad argv.
	if printf '%s' "$text" | grep -qiE 'COMPLETE_E2E: PASS|VERIFY: PASS|consumer complete-e2e|TIDY: PASS|ENFORCE: PASS|RELEASE_READY: PASS|^checked=|^PASS build|^PASS cleanup|^PASS missing-env|^PASS startup|^PASS invalid-config'; then
		fail "$rel still ran live prove under unknown flag"
	fi
}

for rel in "${py_targets[@]}"; do
	check_unknown python3 "$rel"
done
for rel in "${sh_targets[@]}"; do
	check_unknown bash "$rel"
done

echo "PASS invalid-config reserved --hurc-ce2e-* fail-closed on list-surfaces+operator+floor+readme-media+prove-floor CLIs"
exit 0
