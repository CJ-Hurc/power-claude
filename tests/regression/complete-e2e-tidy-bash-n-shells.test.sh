#!/usr/bin/env bash
# Fail-closed gate: tidy Layer 2 must bash -n scripts+devtools/**/*.sh
# (peer to python compile()). Blind spot theater: shebang-only previously
# greenwashed TIDY: PASS while a syntax-broken planted .sh stayed invisible;
# prove/build.sh already caught it, but standalone tidy --full did not.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TIDY_PY="$ROOT/scripts/tidy/run.py"
BUILD_SH="$ROOT/scripts/complete-e2e/prove/build.sh"
[[ -f "$TIDY_PY" ]] || { echo "FAIL tidy-bash-n: missing tidy/run.py" >&2; exit 1; }
[[ -f "$BUILD_SH" ]] || { echo "FAIL tidy-bash-n: missing prove/build.sh" >&2; exit 1; }

# Source must invoke bash -n (not shebang-only).
grep -q 'bash", "-n"' "$TIDY_PY" || grep -q "bash', '-n'" "$TIDY_PY" \
  || grep -qE 'bash", "-n"|\[.bash., .-n.\]' "$TIDY_PY" \
  || { echo "FAIL tidy-bash-n: tidy/run.py missing bash -n invocation" >&2; exit 1; }
grep -q 'bash -n' "$TIDY_PY" \
  || { echo "FAIL tidy-bash-n: tidy/run.py missing bash -n label/comment" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-tidy-bash-n-XXXXXX")"
PLANT="$ROOT/scripts/complete-e2e/.tidy-bash-n-plant.sh"
trap 'rm -rf "$tmp"; rm -f "$PLANT"' EXIT

# Plant: valid shebang + syntax error (if then).
printf '%s\n' '#!/bin/sh' 'if then' >"$PLANT"
chmod +x "$PLANT"

# Theater-kill: shebang-only predicate must miss the plant.
python3 - "$ROOT" "$PLANT" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
plant = Path(sys.argv[2])
assert plant.is_file()
text = plant.read_text(encoding="utf-8", errors="replace")
assert text.startswith("#!"), "plant must have shebang"
# Old tidy: shebang present => PASS; no bash -n.
old_fails = []
if not text.startswith("#!"):
    old_fails.append("missing shebang")
assert not old_fails, "sanity: shebang-only must not fail plant"
print("runtime plant: shebang-only miss (would PASS); plant=", plant.relative_to(root))
PY

# Live tidy --full must FAIL closed on the plant (not greenwash TIDY: PASS).
set +e
python3 "$TIDY_PY" --full >"$tmp/tidy.out" 2>"$tmp/tidy.err"
tidy_rc=$?
set -e
tidy_text="$(cat "$tmp/tidy.out" "$tmp/tidy.err" 2>/dev/null || true)"
[[ "$tidy_rc" -ne 0 ]] \
  || { echo "FAIL tidy-bash-n: tidy --full rc=0 with syntax-broken plant"$'\n'"$tidy_text" >&2; exit 1; }
printf '%s' "$tidy_text" | grep -qiE 'bash -n|syntax|FAIL' \
  || { echo "FAIL tidy-bash-n: tidy fail diagnostic missing"$'\n'"$tidy_text" >&2; exit 1; }
printf '%s' "$tidy_text" | grep -q 'TIDY: PASS' \
  && { echo "FAIL tidy-bash-n: tidy still TIDY: PASS with syntax-broken plant"$'\n'"$tidy_text" >&2; exit 1; }
printf '%s' "$tidy_text" | grep -q 'bash -n scripts/complete-e2e/.tidy-bash-n-plant.sh' \
  || { echo "FAIL tidy-bash-n: tidy missing bash -n FAIL for plant"$'\n'"$tidy_text" >&2; exit 1; }

# Sanity: build prover also rejects the plant (peer coverage).
set +e
bash "$BUILD_SH" >"$tmp/build.out" 2>"$tmp/build.err"
build_rc=$?
set -e
build_text="$(cat "$tmp/build.out" "$tmp/build.err" 2>/dev/null || true)"
[[ "$build_rc" -ne 0 ]] \
  || { echo "FAIL tidy-bash-n: build.sh rc=0 with syntax-broken plant"$'\n'"$build_text" >&2; exit 1; }

rm -f "$PLANT"

# Live clean: no plant → tidy --full PASS with bash -n lines.
python3 "$TIDY_PY" --full >"$tmp/tidy-clean.out" 2>"$tmp/tidy-clean.err"
clean_rc=$?
clean_text="$(cat "$tmp/tidy-clean.out" "$tmp/tidy-clean.err" 2>/dev/null || true)"
[[ "$clean_rc" -eq 0 ]] \
  || { echo "FAIL tidy-bash-n: tidy --full exited $clean_rc on clean tree"$'\n'"$clean_text" >&2; exit 1; }
printf '%s' "$clean_text" | grep -q 'TIDY: PASS' \
  || { echo "FAIL tidy-bash-n: tidy clean missing TIDY: PASS"$'\n'"$clean_text" >&2; exit 1; }
printf '%s' "$clean_text" | grep -q 'bash -n scripts/tidy/run.sh' \
  || { echo "FAIL tidy-bash-n: tidy clean missing bash -n PASS lines"$'\n'"$clean_text" >&2; exit 1; }
printf '%s' "$clean_text" | grep -q 'bash -n devtools/enforce/run.sh' \
  || { echo "FAIL tidy-bash-n: tidy clean missing bash -n for devtools"$'\n'"$clean_text" >&2; exit 1; }

echo "PASS complete-e2e-tidy-bash-n-shells: tidy Layer 2 bash -n scripts+devtools; syntax plant fail-closed (no shebang-only blind spot)"
