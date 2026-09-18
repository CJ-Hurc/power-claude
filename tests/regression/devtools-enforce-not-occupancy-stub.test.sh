#!/usr/bin/env bash
# Fail-closed gate: devtools/enforce/run.sh must delegate to real
# scripts/enforce/run.py — not occupancy theater that echoes "enforce stub: ok"
# and exits 0 without exercising the enforce floor.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STUB="$ROOT/devtools/enforce/run.sh"
ENFORCE_PY="$ROOT/scripts/enforce/run.py"

[[ -f "$STUB" && -x "$STUB" ]] || { echo "FAIL devtools-enforce: missing/non-exec run.sh" >&2; exit 1; }
[[ -f "$ENFORCE_PY" ]] || { echo "FAIL devtools-enforce: missing scripts/enforce/run.py" >&2; exit 1; }

# Theater-kill: source must not be occupancy-only stub.
if grep -qE '^# Occupancy stub|enforce stub: ok' "$STUB"; then
  echo "FAIL devtools-enforce: still occupancy theater (stub echo)" >&2
  exit 1
fi
grep -q 'scripts/enforce/run.py' "$STUB" \
  || { echo "FAIL devtools-enforce: must reference scripts/enforce/run.py" >&2; exit 1; }
grep -qE '\bexec\b' "$STUB" \
  || { echo "FAIL devtools-enforce: must exec real enforce floor" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-devtools-enforce-XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

# --help must stay cheap (no full enforce) and identify power-claude.
set +e
bash "$STUB" --help >"$tmp/help.out" 2>"$tmp/help.err"
help_rc=$?
set -e
help_text="$(cat "$tmp/help.out" "$tmp/help.err" 2>/dev/null || true)"
[[ "$help_rc" -eq 0 ]] || { echo "FAIL devtools-enforce: --help exited $help_rc"$'\n'"$help_text" >&2; exit 1; }
printf '%s' "$help_text" | grep -qiE 'usage:|power-claude' \
  || { echo "FAIL devtools-enforce: --help missing usage/identity"$'\n'"$help_text" >&2; exit 1; }
printf '%s' "$help_text" | grep -qiE 'stub: ok|occupied' \
  && { echo "FAIL devtools-enforce: --help still stub/occupied theater" >&2; exit 1; }

# Unknown command must fail-closed (never silent stub success).
set +e
bash "$STUB" --hurc-ce2e-no-such-enforce-flag >"$tmp/bad.out" 2>"$tmp/bad.err"
bad_rc=$?
set -e
bad_text="$(cat "$tmp/bad.out" "$tmp/bad.err" 2>/dev/null || true)"
[[ "$bad_rc" -ne 0 ]] || { echo "FAIL devtools-enforce: accepted unknown flag (rc=$bad_rc)" >&2; exit 1; }
printf '%s' "$bad_text" | grep -qiE 'unknown|usage:' \
  || { echo "FAIL devtools-enforce: unknown-option diagnostic missing"$'\n'"$bad_text" >&2; exit 1; }

# Do NOT invoke status|scan here: that execs full enforce (Layer 3b) and would recurse.
echo "PASS devtools-enforce-not-occupancy-stub: delegates to scripts/enforce/run.py (not stub theater)"
