#!/usr/bin/env bash
# Fail-closed gate: prove/{build,startup,cleanup}.sh must be real product
# lifecycle provers (compile / entrypoint-healthy / no-state-leak), not
# occupancy theater that only echoes "occupied" and exits 0.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="$ROOT/scripts/complete-e2e/prove/build.sh"
START="$ROOT/scripts/complete-e2e/prove/startup.sh"
CLEAN="$ROOT/scripts/complete-e2e/prove/cleanup.sh"

for f in "$BUILD" "$START" "$CLEAN"; do
  [[ -f "$f" && -x "$f" ]] || { echo "FAIL universal-lifecycle: missing/non-exec $(basename "$f")" >&2; exit 1; }
done

# Theater-kill: source must not be occupancy-only stubs.
for f in "$BUILD" "$START" "$CLEAN"; do
  if grep -qE 'prove (build|startup|cleanup): occupied' "$f"; then
    echo "FAIL universal-lifecycle: $f still occupancy theater (occupied echo)" >&2
    exit 1
  fi
done

# Must invoke real product checks (not echo-only).
grep -q 'compile\|bash -n' "$BUILD" || { echo "FAIL universal-lifecycle: build.sh must compile/bash -n" >&2; exit 1; }
grep -q 'scripts/bin/prove.sh' "$START" || { echo "FAIL universal-lifecycle: startup.sh must exercise bin prove --help" >&2; exit 1; }
grep -q 'scripts/complete-e2e/prove.sh' "$START" || { echo "FAIL universal-lifecycle: startup.sh must exercise complete-e2e prove wrapper --help" >&2; exit 1; }
grep -q 'power-claude' "$START" || { echo "FAIL universal-lifecycle: startup.sh must require power-claude help identity" >&2; exit 1; }
# Theater-kill: complete-e2e wrappers must not stub --help.
for w in \
  "$ROOT/scripts/complete-e2e/prove.sh" \
  "$ROOT/scripts/complete-e2e/consumer.sh" \
  "$ROOT/scripts/complete-e2e/run.sh" \
  "$ROOT/scripts/complete-e2e/execute-consumer.sh" \
  "$ROOT/scripts/complete-e2e/clean-room-replay.sh" \
  "$ROOT/scripts/complete-e2e/check-adapter-paths.sh"
do
  if grep -qE 'echo ["'\'']Usage:.*\[options\]' "$w"; then
    echo "FAIL universal-lifecycle: $(basename "$w") still stub --help short-circuit" >&2
    exit 1
  fi
done
grep -q 'check-ignore' "$CLEAN" || { echo "FAIL universal-lifecycle: cleanup.sh must check-ignore sinks" >&2; exit 1; }
grep -q 'ce2e-cleanup-' "$CLEAN" || { echo "FAIL universal-lifecycle: cleanup.sh must create/remove probe marker" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-ce2e-universal-lifecycle-XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

set +e
bash "$BUILD" >"$tmp/build.out" 2>"$tmp/build.err"
build_rc=$?
bash "$START" >"$tmp/start.out" 2>"$tmp/start.err"
start_rc=$?
bash "$CLEAN" >"$tmp/clean.out" 2>"$tmp/clean.err"
clean_rc=$?
set -e

build_text="$(cat "$tmp/build.out" "$tmp/build.err" 2>/dev/null || true)"
start_text="$(cat "$tmp/start.out" "$tmp/start.err" 2>/dev/null || true)"
clean_text="$(cat "$tmp/clean.out" "$tmp/clean.err" 2>/dev/null || true)"

[[ "$build_rc" -eq 0 ]] || { echo "FAIL universal-lifecycle: build.sh exited $build_rc"$'\n'"$build_text" >&2; exit 1; }
[[ "$start_rc" -eq 0 ]] || { echo "FAIL universal-lifecycle: startup.sh exited $start_rc"$'\n'"$start_text" >&2; exit 1; }
[[ "$clean_rc" -eq 0 ]] || { echo "FAIL universal-lifecycle: cleanup.sh exited $clean_rc"$'\n'"$clean_text" >&2; exit 1; }

printf '%s' "$build_text" | grep -q 'PASS build' \
  || { echo "FAIL universal-lifecycle: build missing PASS line"$'\n'"$build_text" >&2; exit 1; }
printf '%s' "$start_text" | grep -q 'PASS startup' \
  || { echo "FAIL universal-lifecycle: startup missing PASS line"$'\n'"$start_text" >&2; exit 1; }
printf '%s' "$clean_text" | grep -q 'PASS cleanup' \
  || { echo "FAIL universal-lifecycle: cleanup missing PASS line"$'\n'"$clean_text" >&2; exit 1; }

# Must not claim occupancy-only success.
printf '%s' "$build_text$start_text$clean_text" | grep -qiE ': occupied' \
  && { echo "FAIL universal-lifecycle: output still says occupied" >&2; exit 1; }

echo "PASS complete-e2e-universal-lifecycle-provers: build+startup+cleanup real (not occupied theater)"
