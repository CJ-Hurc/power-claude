#!/usr/bin/env bash
# Fail-closed gate: PC_SKIP_NPM=1 must not greenwash consumer / complete-e2e /
# verify / execute-consumer / prove / release-ready / enforce with rc=0,
# fabricated receipts, or PASS (including strip-and-run theater).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONSUMER="$ROOT/scripts/complete-e2e/consumer.py"
RUN_E2E="$ROOT/scripts/complete-e2e/run.py"
VERIFY="$ROOT/scripts/verify/run.py"
EXECUTE="$ROOT/scripts/complete-e2e/execute-consumer.py"
PROVE="$ROOT/scripts/complete-e2e/prove.py"
RELEASE_READY="$ROOT/scripts/release-ready/run.py"
ENFORCE="$ROOT/scripts/enforce/run.py"
EXEC_RECEIPT="$ROOT/scripts/complete-e2e/.receipts/execute-receipt.json"
PROVE_RECEIPT="$ROOT/scripts/complete-e2e/.receipts/prove-receipt.json"

[[ -f "$CONSUMER" ]] || { echo "FAIL skip-npm-refuse: missing consumer.py" >&2; exit 1; }
[[ -f "$RUN_E2E" ]] || { echo "FAIL skip-npm-refuse: missing run.py" >&2; exit 1; }
[[ -f "$VERIFY" ]] || { echo "FAIL skip-npm-refuse: missing verify/run.py" >&2; exit 1; }
[[ -f "$EXECUTE" ]] || { echo "FAIL skip-npm-refuse: missing execute-consumer.py" >&2; exit 1; }
[[ -f "$PROVE" ]] || { echo "FAIL skip-npm-refuse: missing prove.py" >&2; exit 1; }
[[ -f "$RELEASE_READY" ]] || { echo "FAIL skip-npm-refuse: missing release-ready/run.py" >&2; exit 1; }
[[ -f "$ENFORCE" ]] || { echo "FAIL skip-npm-refuse: missing enforce/run.py" >&2; exit 1; }

# Theater-kill: consumer must not keep the old "package layer skipped" success path.
if grep -qE 'print\(.*package layer skipped' "$CONSUMER"; then
  echo "FAIL skip-npm-refuse: consumer.py still prints package-layer-skipped greenwash" >&2
  exit 1
fi
grep -q 'PC_SKIP_NPM' "$CONSUMER" \
  || { echo "FAIL skip-npm-refuse: consumer.py must mention PC_SKIP_NPM refuse" >&2; exit 1; }
grep -q 'PC_SKIP_NPM' "$EXECUTE" \
  || { echo "FAIL skip-npm-refuse: execute-consumer.py must mention PC_SKIP_NPM refuse" >&2; exit 1; }
grep -q 'PC_SKIP_NPM' "$PROVE" \
  || { echo "FAIL skip-npm-refuse: prove.py must mention PC_SKIP_NPM refuse" >&2; exit 1; }
grep -q 'PC_SKIP_NPM=1 refuses release-ready' "$RELEASE_READY" \
  || { echo "FAIL skip-npm-refuse: release-ready must refuse PC_SKIP_NPM at entry" >&2; exit 1; }
grep -q 'PC_SKIP_NPM=1 refuses enforce' "$ENFORCE" \
  || { echo "FAIL skip-npm-refuse: enforce must refuse PC_SKIP_NPM at entry" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-skip-npm-refuse-XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

# Plant green-looking receipts; skip refuse must not leave/overwrite with fabricated cases.
mkdir -p "$(dirname "$EXEC_RECEIPT")"
printf '%s\n' '{"ok":true,"behavior_proven":true,"environment_status":"live","planted":true}' >"$EXEC_RECEIPT"
printf '%s\n' '{"ok":true,"behavior_proven":true,"environment_status":"live","planted":true}' >"$PROVE_RECEIPT"

set +e
PC_SKIP_NPM=1 python3 "$CONSUMER" >"$tmp/c.out" 2>"$tmp/c.err"
c_rc=$?
PC_SKIP_NPM=1 python3 "$RUN_E2E" >"$tmp/r.out" 2>"$tmp/r.err"
r_rc=$?
PC_SKIP_NPM=1 python3 "$VERIFY" >"$tmp/v.out" 2>"$tmp/v.err"
v_rc=$?
PC_SKIP_NPM=1 python3 "$EXECUTE" >"$tmp/e.out" 2>"$tmp/e.err"
e_rc=$?
PC_SKIP_NPM=1 python3 "$PROVE" --receipt >"$tmp/p.out" 2>"$tmp/p.err"
p_rc=$?
PC_SKIP_NPM=1 python3 "$PROVE" >"$tmp/pd.out" 2>"$tmp/pd.err"
pd_rc=$?
set -e

c_text="$(cat "$tmp/c.out" "$tmp/c.err" 2>/dev/null || true)"
r_text="$(cat "$tmp/r.out" "$tmp/r.err" 2>/dev/null || true)"
v_text="$(cat "$tmp/v.out" "$tmp/v.err" 2>/dev/null || true)"
e_text="$(cat "$tmp/e.out" "$tmp/e.err" 2>/dev/null || true)"
p_text="$(cat "$tmp/p.out" "$tmp/p.err" 2>/dev/null || true)"
pd_text="$(cat "$tmp/pd.out" "$tmp/pd.err" 2>/dev/null || true)"

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

[[ "$e_rc" -ne 0 ]] || { echo "FAIL skip-npm-refuse: execute-consumer rc=0 under PC_SKIP_NPM"$'\n'"$e_text" >&2; exit 1; }
printf '%s' "$e_text" | grep -qiE 'PC_SKIP_NPM|refuses execute|EXECUTE: FAIL' \
  || { echo "FAIL skip-npm-refuse: execute refuse/FAIL missing"$'\n'"$e_text" >&2; exit 1; }
printf '%s' "$e_text" | grep -qiE 'EXECUTE: PASS|partial_skip_npm|missing markers:' \
  && { echo "FAIL skip-npm-refuse: execute still greenwash/fabricated receipt theater"$'\n'"$e_text" >&2; exit 1; }
# Must not leave planted green execute receipt or write fabricated skip receipt.
[[ ! -f "$EXEC_RECEIPT" ]] \
  || { echo "FAIL skip-npm-refuse: execute-receipt.json survived skip refuse" >&2; cat "$EXEC_RECEIPT" >&2; exit 1; }

[[ "$p_rc" -ne 0 ]] || { echo "FAIL skip-npm-refuse: prove --receipt rc=0 under PC_SKIP_NPM"$'\n'"$p_text" >&2; exit 1; }
printf '%s' "$p_text" | grep -qiE 'PC_SKIP_NPM|refuses prove|COMPLETE_E2E: FAIL' \
  || { echo "FAIL skip-npm-refuse: prove --receipt refuse/FAIL missing"$'\n'"$p_text" >&2; exit 1; }
printf '%s' "$p_text" | grep -qiE 'behavior_proven.: true|partial_skip_npm|missing markers:' \
  && { echo "FAIL skip-npm-refuse: prove --receipt still fabricated receipt theater"$'\n'"$p_text" >&2; exit 1; }

[[ "$pd_rc" -ne 0 ]] || { echo "FAIL skip-npm-refuse: prove default rc=0 under PC_SKIP_NPM"$'\n'"$pd_text" >&2; exit 1; }
printf '%s' "$pd_text" | grep -qiE 'PC_SKIP_NPM|refuses prove|COMPLETE_E2E: FAIL' \
  || { echo "FAIL skip-npm-refuse: prove default refuse/FAIL missing"$'\n'"$pd_text" >&2; exit 1; }
# Must not leave planted green prove receipt after skip refuse (default or --receipt).
[[ ! -f "$PROVE_RECEIPT" ]] \
  || { echo "FAIL skip-npm-refuse: prove-receipt.json survived skip refuse" >&2; cat "$PROVE_RECEIPT" >&2; exit 1; }

set +e
PC_SKIP_NPM=1 python3 "$RELEASE_READY" >"$tmp/rr.out" 2>"$tmp/rr.err"
rr_rc=$?
PC_SKIP_NPM=1 python3 "$ENFORCE" >"$tmp/en.out" 2>"$tmp/en.err"
en_rc=$?
set -e

rr_text="$(cat "$tmp/rr.out" "$tmp/rr.err" 2>/dev/null || true)"
en_text="$(cat "$tmp/en.out" "$tmp/en.err" 2>/dev/null || true)"

[[ "$rr_rc" -ne 0 ]] || { echo "FAIL skip-npm-refuse: release-ready rc=0 under PC_SKIP_NPM"$'\n'"$rr_text" >&2; exit 1; }
printf '%s' "$rr_text" | grep -qiE 'PC_SKIP_NPM|refuses release-ready|RELEASE_READY: FAIL' \
  || { echo "FAIL skip-npm-refuse: release-ready refuse/FAIL missing"$'\n'"$rr_text" >&2; exit 1; }
printf '%s' "$rr_text" | grep -qiE 'RELEASE_READY: PASS' \
  && { echo "FAIL skip-npm-refuse: release-ready still RELEASE_READY: PASS under skip (strip-and-run theater)"$'\n'"$rr_text" >&2; exit 1; }

[[ "$en_rc" -ne 0 ]] || { echo "FAIL skip-npm-refuse: enforce rc=0 under PC_SKIP_NPM"$'\n'"$en_text" >&2; exit 1; }
printf '%s' "$en_text" | grep -qiE 'PC_SKIP_NPM|refuses enforce|ENFORCE: FAIL' \
  || { echo "FAIL skip-npm-refuse: enforce refuse/FAIL missing"$'\n'"$en_text" >&2; exit 1; }
printf '%s' "$en_text" | grep -qiE 'ENFORCE: PASS' \
  && { echo "FAIL skip-npm-refuse: enforce still ENFORCE: PASS under skip (strip-and-run theater)"$'\n'"$en_text" >&2; exit 1; }

echo "PASS complete-e2e-consumer-refuse-skip-npm: consumer+run+verify+execute+prove+release-ready+enforce refuse PC_SKIP_NPM=1 (no greenwash PASS/fabricated receipts)"
