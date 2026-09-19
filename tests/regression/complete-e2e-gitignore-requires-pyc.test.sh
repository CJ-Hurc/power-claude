#!/usr/bin/env bash
# Fail-closed gate: tidy Layer 3 / enforce Layer 4 must require ACTIVE
# __pycache__/ AND *.pyc AND *.pyo (not OR-base). Blind spot theater:
# has_base = (__pycache__/ OR *.pyc) previously greenwashed PASS without
# *.pyc while a planted orphan scripts/**/*.pyc stayed trackable —
# git check-ignore does not ignore it under __pycache__/ alone.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TIDY_PY="$ROOT/scripts/tidy/run.py"
ENFORCE_PY="$ROOT/scripts/enforce/run.py"
GI="$ROOT/.gitignore"
[[ -f "$TIDY_PY" ]] || { echo "FAIL gitignore-requires-pyc: missing tidy/run.py" >&2; exit 1; }
[[ -f "$ENFORCE_PY" ]] || { echo "FAIL gitignore-requires-pyc: missing enforce/run.py" >&2; exit 1; }
[[ -f "$GI" ]] || { echo "FAIL gitignore-requires-pyc: missing .gitignore" >&2; exit 1; }

# Source must require *.pyc distinctly (not OR'd away by __pycache__/).
grep -q 'has_pyc' "$TIDY_PY" \
  || { echo "FAIL gitignore-requires-pyc: tidy/run.py missing has_pyc" >&2; exit 1; }
grep -q 'has_pycache' "$TIDY_PY" \
  || { echo "FAIL gitignore-requires-pyc: tidy/run.py missing has_pycache" >&2; exit 1; }
grep -q 'has_pycache and has_pyc and has_pyo' "$TIDY_PY" \
  || { echo "FAIL gitignore-requires-pyc: tidy/run.py missing AND predicate" >&2; exit 1; }
grep -q 'has_pyc' "$ENFORCE_PY" \
  || { echo "FAIL gitignore-requires-pyc: enforce/run.py missing has_pyc" >&2; exit 1; }
grep -q 'has_pycache and has_pyc and has_pyo' "$ENFORCE_PY" \
  || { echo "FAIL gitignore-requires-pyc: enforce/run.py missing AND predicate" >&2; exit 1; }
# Old OR-base must be gone.
grep -qE 'has_base = .*__pycache__.*or.*"\*\.pyc"' "$TIDY_PY" \
  && { echo "FAIL gitignore-requires-pyc: tidy still has OR-base has_base" >&2; exit 1; }
grep -qE 'has_base = .*__pycache__.*or.*"\*\.pyc"' "$ENFORCE_PY" \
  && { echo "FAIL gitignore-requires-pyc: enforce still has OR-base has_base" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-gitignore-requires-pyc-XXXXXX")"
gi_bak="$tmp/gitignore.bak"
cp "$GI" "$gi_bak"
trap 'cp "$gi_bak" "$GI" 2>/dev/null || true; rm -rf "$tmp"; rm -f "$ROOT/scripts/complete-e2e/.gitignore-requires-pyc-plant.pyc"' EXIT

# Theater-kill: active __pycache__/ + *.pyo WITHOUT *.pyc — old OR PASSes.
python3 - "$ROOT" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
gi_path = root / ".gitignore"
# Active __pycache__/ + *.pyo only (no *.pyc).
gi_path.write_text(
    ".hurc-harness/\ntmp/\n"
    "__pycache__/\n*.pyo\n"
    ".venv/\nscripts/complete-e2e/.receipts/\n",
    encoding="utf-8",
)
gi = gi_path.read_text(encoding="utf-8")
rules = set()
for raw in gi.splitlines():
    s = raw.strip()
    if not s or s.startswith("#"):
        continue
    rules.add(s)
has_base = "__pycache__/" in rules or "__pycache__" in rules or "*.pyc" in rules
old_ok = has_base and "*.pyo" in rules
assert old_ok, "sanity: old OR-base must PASS without *.pyc; rules=" + repr(rules)
has_pycache = "__pycache__/" in rules or "__pycache__" in rules
has_pyc = "*.pyc" in rules
has_pyo = "*.pyo" in rules
fixed_ok = has_pycache and has_pyc and has_pyo
assert not fixed_ok, "fixed AND predicate must FAIL without *.pyc; rules=" + repr(rules)
print("runtime plant: old OR-base PASS / fixed AND FAIL without active *.pyc")
PY

# Live tidy --full must FAIL closed (not greenwash Layer 3 / TIDY: PASS).
set +e
python3 "$TIDY_PY" --full >"$tmp/tidy.out" 2>"$tmp/tidy.err"
tidy_rc=$?
set -e
tidy_text="$(cat "$tmp/tidy.out" "$tmp/tidy.err" 2>/dev/null || true)"
[[ "$tidy_rc" -ne 0 ]] \
  || { echo "FAIL gitignore-requires-pyc: tidy --full rc=0 without *.pyc"$'\n'"$tidy_text" >&2; exit 1; }
printf '%s' "$tidy_text" | grep -qiE 'gitignore|active|FAIL|\.pyc' \
  || { echo "FAIL gitignore-requires-pyc: tidy fail diagnostic missing"$'\n'"$tidy_text" >&2; exit 1; }
printf '%s' "$tidy_text" | grep -q 'TIDY: PASS' \
  && { echo "FAIL gitignore-requires-pyc: tidy still TIDY: PASS without *.pyc"$'\n'"$tidy_text" >&2; exit 1; }
printf '%s' "$tidy_text" | grep -qi 'gitignore missing active' \
  || { echo "FAIL gitignore-requires-pyc: tidy missing gitignore FAIL label"$'\n'"$tidy_text" >&2; exit 1; }

# Orphan .pyc must NOT be check-ignored under __pycache__/-only rules.
plant="$ROOT/scripts/complete-e2e/.gitignore-requires-pyc-plant.pyc"
printf 'x' >"$plant"
if git -C "$ROOT" check-ignore -q "$plant"; then
  echo "FAIL gitignore-requires-pyc: orphan .pyc unexpectedly ignored without *.pyc rule" >&2
  exit 1
fi
echo "runtime plant: orphan .pyc NOT ignored under __pycache__/-only (theater proven)"
rm -f "$plant"

# Restore real gitignore and confirm clean PASS + check-ignore on orphan .pyc.
cp "$gi_bak" "$GI"
printf 'x' >"$plant"
git -C "$ROOT" check-ignore -q "$plant" \
  || { echo "FAIL gitignore-requires-pyc: real .gitignore does not ignore planted .pyc" >&2; exit 1; }
rm -f "$plant"

python3 "$TIDY_PY" --full >"$tmp/tidy-clean.out" 2>"$tmp/tidy-clean.err"
clean_rc=$?
clean_text="$(cat "$tmp/tidy-clean.out" "$tmp/tidy-clean.err" 2>/dev/null || true)"
[[ "$clean_rc" -eq 0 ]] \
  || { echo "FAIL gitignore-requires-pyc: tidy --full exited $clean_rc on restored gitignore"$'\n'"$clean_text" >&2; exit 1; }
printf '%s' "$clean_text" | grep -q 'TIDY: PASS' \
  || { echo "FAIL gitignore-requires-pyc: tidy clean missing TIDY: PASS"$'\n'"$clean_text" >&2; exit 1; }
printf '%s' "$clean_text" | grep -q 'PASS  .gitignore covers bytecode' \
  || { echo "FAIL gitignore-requires-pyc: tidy clean missing gitignore PASS"$'\n'"$clean_text" >&2; exit 1; }

echo "PASS complete-e2e-gitignore-requires-pyc: tidy/enforce require active __pycache__ AND *.pyc AND *.pyo; OR-base without *.pyc fail-closed; orphan .pyc check-ignore proven"
