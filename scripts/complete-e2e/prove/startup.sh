#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Goal     : product CLI entrypoints start healthy offline (no live prove).
# Purpose  : Product prover for complete-e2e universal startup (process-starts-healthy).
# Consumers: complete-e2e occupancy; exec _exec_product_universal_lifecycle; humans.
# Inputs   : cwd = repo root. Exercises bin + complete-e2e wrapper --help + unknown-flag fail-closed.
# Outputs  : PASS/FAIL on stdout.
# Exit codes: 0 entrypoints healthy / 1 boot contract broken / 2 usage
# Side effects: none (never runs full prove/consumer; help/fail paths only; no PC_SKIP_NPM greenwash).
# -----------------------------------------------------------------------------
set -uo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
	exit 0
fi

# Fail-closed: unknown argv must not greenwash PASS (ignore-and-run theater).
if [[ "$#" -gt 0 ]]; then
	echo "usage: scripts/complete-e2e/prove/startup.sh" >&2
	echo "unrecognized arguments: $*" >&2
	exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT" || exit 2
fail() { echo "FAIL: $*" >&2; exit 1; }

# Refuse skip-env theater: startup must not claim PASS under PC_SKIP_NPM.
if [[ "${PC_SKIP_NPM:-}" == "1" ]]; then
	fail "PC_SKIP_NPM=1 refuses startup prove (not a clean process-starts-healthy gate)"
fi

need=(
	scripts/bin/prove.sh
	scripts/bin/verify.sh
	scripts/bin/consumer.sh
	scripts/complete-e2e/list-surfaces.py
	scripts/complete-e2e/prove.sh
	scripts/complete-e2e/consumer.sh
	scripts/complete-e2e/run.sh
	scripts/complete-e2e/execute-consumer.sh
	scripts/complete-e2e/clean-room-replay.sh
	scripts/complete-e2e/check-adapter-paths.sh
)
for rel in "${need[@]}"; do
	[[ -f "$ROOT/$rel" || -x "$ROOT/$rel" ]] || fail "missing startup entrypoint $rel"
done
command -v python3 >/dev/null 2>&1 || fail "python3 missing"

# Theater-kill: complete-e2e wrappers must not short-circuit --help with stub usage.
for rel in \
	scripts/complete-e2e/prove.sh \
	scripts/complete-e2e/consumer.sh \
	scripts/complete-e2e/run.sh \
	scripts/complete-e2e/execute-consumer.sh \
	scripts/complete-e2e/clean-room-replay.sh \
	scripts/complete-e2e/check-adapter-paths.sh
do
	if grep -qE 'echo ["'\'']Usage:.*\[options\]' "$ROOT/$rel"; then
		fail "$rel still has stub --help short-circuit (help theater)"
	fi
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Operator entrypoints must answer --help (exit 0 + usage/identity text).
# Require power-claude identity so stub "Usage: name [options]" cannot greenwash.
help_entries=(
	scripts/bin/prove.sh
	scripts/bin/verify.sh
	scripts/bin/consumer.sh
	scripts/complete-e2e/prove.sh
	scripts/complete-e2e/consumer.sh
	scripts/complete-e2e/run.sh
	scripts/complete-e2e/execute-consumer.sh
	scripts/complete-e2e/clean-room-replay.sh
	scripts/complete-e2e/check-adapter-paths.sh
)
for entry in "${help_entries[@]}"; do
	set +e
	bash "$ROOT/$entry" --help >"$tmp/help.out" 2>"$tmp/help.err"
	rc=$?
	set -e
	[[ "$rc" -eq 0 ]] || fail "$entry --help exited $rc"
	text="$(cat "$tmp/help.out" "$tmp/help.err" 2>/dev/null || true)"
	printf '%s' "$text" | grep -qiE 'usage:' \
		|| fail "$entry --help missing usage diagnostic"
	printf '%s' "$text" | grep -qiE 'power-claude' \
		|| fail "$entry --help missing power-claude identity (stub help theater)"
done

# Unknown option must fail-closed (never silently succeed into a full prove).
# Cover inventory + operator bins + complete-e2e wrappers.
unknown_targets=(
	"python3|$ROOT/scripts/complete-e2e/list-surfaces.py"
	"bash|$ROOT/scripts/bin/prove.sh"
	"bash|$ROOT/scripts/bin/verify.sh"
	"bash|$ROOT/scripts/bin/consumer.sh"
	"bash|$ROOT/scripts/complete-e2e/prove.sh"
	"bash|$ROOT/scripts/complete-e2e/consumer.sh"
	"bash|$ROOT/scripts/complete-e2e/run.sh"
	"bash|$ROOT/scripts/complete-e2e/execute-consumer.sh"
	"bash|$ROOT/scripts/complete-e2e/clean-room-replay.sh"
	"bash|$ROOT/scripts/complete-e2e/check-adapter-paths.sh"
)
for spec in "${unknown_targets[@]}"; do
	runner="${spec%%|*}"
	target="${spec#*|}"
	set +e
	"$runner" "$target" --hurc-ce2e-no-such-startup-flag \
		>"$tmp/bad.out" 2>"$tmp/bad.err"
	rc=$?
	set -e
	[[ "$rc" -ne 0 ]] || fail "$target accepted unknown startup flag (rc=$rc)"
	text="$(cat "$tmp/bad.out" "$tmp/bad.err" 2>/dev/null || true)"
	printf '%s' "$text" | grep -qiE 'unrecognized arguments|unknown option|usage:' \
		|| fail "$target unknown-option diagnostic missing from startup fail-closed output"
	if printf '%s' "$text" | grep -qiE 'COMPLETE_E2E: PASS|VERIFY: PASS|consumer complete-e2e'; then
		fail "$target still ran live prove under unknown startup flag"
	fi
done

echo "PASS startup process-starts-healthy offline entrypoints"
exit 0
