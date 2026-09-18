#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Goal     : clean-room-replay fail-closes when PC_SKIP_NPM=1 (partial/skip env).
# Purpose  : Product prover for complete-e2e universal missing-env fault.
# Consumers: complete-e2e occupancy; exec _exec_product_universal_fault; humans.
# Inputs   : cwd = repo root. Forces PC_SKIP_NPM=1 (never greenwashes live prove).
# Outputs  : PASS/FAIL on stdout.
# Exit codes: 0 product fail-closed / 1 product passed when it must not / 2 usage
# Side effects: none (refuses before prove; never writes receipts).
# -----------------------------------------------------------------------------
set -uo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
	exit 0
fi

# Fail-closed: unknown argv must not greenwash PASS (ignore-and-run theater).
if [[ "$#" -gt 0 ]]; then
	echo "usage: scripts/complete-e2e/prove/missing-env.sh" >&2
	echo "unrecognized arguments: $*" >&2
	exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT" || exit 2
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "python3 missing"
[[ -f "$ROOT/scripts/complete-e2e/clean-room-replay.py" ]] || fail "clean-room-replay.py missing"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

set +e
PC_SKIP_NPM=1 python3 "$ROOT/scripts/complete-e2e/clean-room-replay.py" \
	>"$tmp/out" 2>"$tmp/err"
rc=$?
set -e
text="$(cat "$tmp/out" "$tmp/err" 2>/dev/null || true)"
[[ "$rc" -ne 0 ]] || fail "clean-room-replay passed with PC_SKIP_NPM=1 (rc=$rc)"
printf '%s' "$text" | grep -qiE 'PC_SKIP_NPM|not a clean-room|refusing|FAIL' \
	|| fail "PC_SKIP_NPM refuse diagnostic missing from fail-closed output"
echo "PASS missing-env PC_SKIP_NPM=1 clean-room refuse rc=$rc"
exit 0
