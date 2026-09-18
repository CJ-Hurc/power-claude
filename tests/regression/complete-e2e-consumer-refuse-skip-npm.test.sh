#!/usr/bin/env bash
# Fail-closed gate: PC_SKIP_NPM=1 must not greenwash consumer / complete-e2e /
# verify with rc=0 while skipping the live package layer.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONSUMER="$ROOT/scripts/complete-e2e/consumer.py"
RUN_E2E="$ROOT/scripts/complete-e2e/run.py"
VERIFY="$ROOT/scripts/verify/run.py"

[[ -f "$CONSUMER" ]] || { echo "FAIL skip-npm-refuse: missing consumer.py" >&2; exit 1; }
[[ -f "$RUN_E2E" ]] || { echo "FAIL skip-npm-refuse: missing run.py" >&2; exit 1; }
[[ -f "$VERIFY" ]] || { echo "FAIL skip-npm-refuse: missing verify/run.py" >&2; exit 1; }

# Theater-kill: consumer must not keep the old "package layer skipped" success path.
if grep -qE 'print\(.*package layer skipped' "$CONSUMER"; then
  echo "FAIL skip-npm-refuse: consumer.py still prints package-layer-skipped greenwash" >&2
  exit 1
fi
grep -q 'PC_SKIP_NPM' "$CONSUMER" \
  || { echo "FAIL skip-npm-refuse: consumer.py must mention PC_SKIP_NPM refuse" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-skip-npm-refuse-XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

set +e
PC_SKIP_NPM=1 python3 "$CONSUMER" >"$tmp/c.out" 2>"$tmp/c.err"
c_rc=$?
PC_SKIP_NPM=1 python3 "$RUN_E2E" >"$tmp/r.out" 2>"$tmp/r.err"
r_rc=$?
PC_SKIP_NPM=1 python3 "$VERIFY" >"$tmp/v.out" 2>"$tmp/v.err"
v_rc=$?
set -e

c_text="$(cat "$tmp/c.out" "$tmp/c.err" 2>/dev/null || true)"
r_text="$(cat "$tmp/r.out" "$tmp/r.err" 2>/dev/null || true)"
v_text="$(cat "$tmp/v.out" "$tmp/v.err" 2>/dev/null || true)"

[[ "$c_rc" -ne 0 ]] || { echo "FAIL skip-npm-refuse: consumer rc=0 under PC_SKIP_NPM"$'\n'"$c_text" >&2; exit 1; }
printf '%s' "$c_text" | grep -qiE 'PC_SKIP_NPM|refuses|FAIL' \
  || { echo "FAIL skip-npm-refuse: consumer refuse diagnostic missing"$'\n'"$c_text" >&2; exit 1; }
printf '%s' "$c_text" | grep -qiE 'package layer skipped|COMPLETE_E2E: PASS' \
  && { echo "FAIL skip-npm-refuse: consumer still greenwash text" >&2; exit 1; }

[[ "$r_rc" -ne 0 ]] || { echo "FAIL skip-npm-refuse: run.py rc=0 under PC_SKIP_NPM"$'\n'"$r_text" >&2; exit 1; }
printf '%s' "$r_text" | grep -qiE 'PC_SKIP_NPM|COMPLETE_E2E: FAIL|refuses' \
  || { echo "FAIL skip-npm-refuse: run.py refuse/FAIL missing"$'\n'"$r_text" >&2; exit 1; }
printf '%s' "$r_text" | grep -qiE 'COMPLETE_E2E: PASS' \
  && { echo "FAIL skip-npm-refuse: run.py still COMPLETE_E2E: PASS under skip" >&2; exit 1; }

[[ "$v_rc" -ne 0 ]] || { echo "FAIL skip-npm-refuse: verify rc=0 under PC_SKIP_NPM"$'\n'"$v_text" >&2; exit 1; }
printf '%s' "$v_text" | grep -qiE 'VERIFY: FAIL|FAIL  complete-e2e|PC_SKIP_NPM|COMPLETE_E2E: FAIL' \
  || { echo "FAIL skip-npm-refuse: verify fail diagnostic missing"$'\n'"$v_text" >&2; exit 1; }
printf '%s' "$v_text" | grep -qiE 'VERIFY: PASS' \
  && { echo "FAIL skip-npm-refuse: verify still VERIFY: PASS under skip" >&2; exit 1; }

echo "PASS complete-e2e-consumer-refuse-skip-npm: consumer+run+verify refuse PC_SKIP_NPM=1 (no greenwash PASS)"
