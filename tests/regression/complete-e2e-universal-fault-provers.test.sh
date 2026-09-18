#!/usr/bin/env bash
# Fail-closed gate: prove/invalid-config.sh and prove/missing-env.sh must be
# real product provers (exercise fail-closed paths), not occupancy theater
# that only echoes "occupied" and exits 0.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INV="$ROOT/scripts/complete-e2e/prove/invalid-config.sh"
MISS="$ROOT/scripts/complete-e2e/prove/missing-env.sh"

[[ -f "$INV" && -x "$INV" ]] || { echo "FAIL universal-fault: missing/non-exec invalid-config.sh" >&2; exit 1; }
[[ -f "$MISS" && -x "$MISS" ]] || { echo "FAIL universal-fault: missing/non-exec missing-env.sh" >&2; exit 1; }

# Theater-kill: source must not be occupancy-only stubs.
for f in "$INV" "$MISS"; do
  if grep -qE 'prove (invalid-config|missing-env): occupied' "$f"; then
    echo "FAIL universal-fault: $f still occupancy theater (occupied echo)" >&2
    exit 1
  fi
done
# Must invoke real product entrypoints (list-surfaces alone is incomplete theater:
# operator CLIs historically ignored unknown argv and greenwashed PASS).
grep -q 'list-surfaces.py' "$INV" || { echo "FAIL universal-fault: invalid-config.sh must invoke list-surfaces.py" >&2; exit 1; }
grep -q 'consumer.py' "$INV" || { echo "FAIL universal-fault: invalid-config.sh must cover consumer.py" >&2; exit 1; }
grep -q 'run.py' "$INV" || { echo "FAIL universal-fault: invalid-config.sh must cover run.py" >&2; exit 1; }
grep -q 'prove.py' "$INV" || { echo "FAIL universal-fault: invalid-config.sh must cover prove.py" >&2; exit 1; }
grep -q 'verify/run.py' "$INV" || { echo "FAIL universal-fault: invalid-config.sh must cover verify/run.py" >&2; exit 1; }
grep -q 'tidy/run.py' "$INV" || { echo "FAIL universal-fault: invalid-config.sh must cover tidy/run.py" >&2; exit 1; }
grep -q 'enforce/run.py' "$INV" || { echo "FAIL universal-fault: invalid-config.sh must cover enforce/run.py" >&2; exit 1; }
grep -q 'release-ready/run.py' "$INV" || { echo "FAIL universal-fault: invalid-config.sh must cover release-ready/run.py" >&2; exit 1; }
grep -q 'check_readme_media.py' "$INV" || { echo "FAIL universal-fault: invalid-config.sh must cover check_readme_media.py" >&2; exit 1; }
grep -q 'prove/build.sh' "$INV" || { echo "FAIL universal-fault: invalid-config.sh must cover prove/build.sh" >&2; exit 1; }
grep -q 'prove/cleanup.sh' "$INV" || { echo "FAIL universal-fault: invalid-config.sh must cover prove/cleanup.sh" >&2; exit 1; }
grep -q 'prove/missing-env.sh' "$INV" || { echo "FAIL universal-fault: invalid-config.sh must cover prove/missing-env.sh" >&2; exit 1; }
grep -q 'prove/startup.sh' "$INV" || { echo "FAIL universal-fault: invalid-config.sh must cover prove/startup.sh" >&2; exit 1; }
grep -q 'prove/invalid-config.sh' "$INV" || { echo "FAIL universal-fault: invalid-config.sh must cover prove/invalid-config.sh" >&2; exit 1; }
grep -q 'clean-room-replay.py' "$MISS" || { echo "FAIL universal-fault: missing-env.sh must invoke clean-room-replay.py" >&2; exit 1; }
grep -q 'PC_SKIP_NPM' "$MISS" || { echo "FAIL universal-fault: missing-env.sh must force PC_SKIP_NPM=1" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-ce2e-universal-fault-XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

set +e
bash "$INV" >"$tmp/inv.out" 2>"$tmp/inv.err"
inv_rc=$?
bash "$MISS" >"$tmp/miss.out" 2>"$tmp/miss.err"
miss_rc=$?
set -e

inv_text="$(cat "$tmp/inv.out" "$tmp/inv.err" 2>/dev/null || true)"
miss_text="$(cat "$tmp/miss.out" "$tmp/miss.err" 2>/dev/null || true)"

[[ "$inv_rc" -eq 0 ]] || { echo "FAIL universal-fault: invalid-config.sh exited $inv_rc"$'\n'"$inv_text" >&2; exit 1; }
[[ "$miss_rc" -eq 0 ]] || { echo "FAIL universal-fault: missing-env.sh exited $miss_rc"$'\n'"$miss_text" >&2; exit 1; }
printf '%s' "$inv_text" | grep -q 'PASS invalid-config' \
  || { echo "FAIL universal-fault: invalid-config missing PASS line"$'\n'"$inv_text" >&2; exit 1; }
printf '%s' "$miss_text" | grep -q 'PASS missing-env' \
  || { echo "FAIL universal-fault: missing-env missing PASS line"$'\n'"$miss_text" >&2; exit 1; }
# Must not claim occupancy-only success.
printf '%s' "$inv_text$miss_text" | grep -qiE ': occupied' \
  && { echo "FAIL universal-fault: output still says occupied" >&2; exit 1; }

echo "PASS complete-e2e-universal-fault-provers: invalid-config+missing-env real fail-closed (not occupied theater)"
