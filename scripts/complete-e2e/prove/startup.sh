#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Goal     : product CLI entrypoints start healthy offline (no live prove).
# Purpose  : Product prover for complete-e2e universal startup (process-starts-healthy).
# Consumers: complete-e2e occupancy; exec _exec_product_universal_lifecycle; humans.
# Inputs   : cwd = repo root. Exercises bin --help + unknown-flag fail-closed.
# Outputs  : PASS/FAIL on stdout.
# Exit codes: 0 entrypoints healthy / 1 boot contract broken / 2 usage
# Side effects: none (never runs full prove/consumer; help/fail paths only).
# -----------------------------------------------------------------------------
set -uo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
	exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT" || exit 2
fail() { echo "FAIL: $*" >&2; exit 1; }

need=(
	scripts/bin/prove.sh
	scripts/bin/verify.sh
	scripts/bin/consumer.sh
	scripts/complete-e2e/list-surfaces.py
)
for rel in "${need[@]}"; do
	[[ -f "$ROOT/$rel" || -x "$ROOT/$rel" ]] || fail "missing startup entrypoint $rel"
done
command -v python3 >/dev/null 2>&1 || fail "python3 missing"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Operator entrypoints must answer --help (exit 0 + usage/identity text).
for entry in scripts/bin/prove.sh scripts/bin/verify.sh scripts/bin/consumer.sh; do
	set +e
	bash "$ROOT/$entry" --help >"$tmp/help.out" 2>"$tmp/help.err"
	rc=$?
	set -e
	[[ "$rc" -eq 0 ]] || fail "$entry --help exited $rc"
	text="$(cat "$tmp/help.out" "$tmp/help.err" 2>/dev/null || true)"
	printf '%s' "$text" | grep -qiE 'usage:|power-claude' \
		|| fail "$entry --help missing usage/identity diagnostic"
done

# Unknown option must fail-closed (never silently succeed into a full prove).
set +e
python3 "$ROOT/scripts/complete-e2e/list-surfaces.py" --hurc-ce2e-no-such-startup-flag \
	>"$tmp/bad.out" 2>"$tmp/bad.err"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || fail "list-surfaces accepted unknown startup flag (rc=$rc)"
text="$(cat "$tmp/bad.out" "$tmp/bad.err" 2>/dev/null || true)"
printf '%s' "$text" | grep -qiE 'unrecognized arguments|unknown option|usage:' \
	|| fail "unknown-option diagnostic missing from startup fail-closed output"

echo "PASS startup process-starts-healthy offline entrypoints"
exit 0
