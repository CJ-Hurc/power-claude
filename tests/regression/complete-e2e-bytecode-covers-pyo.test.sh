#!/usr/bin/env bash
# Fail-closed gate: tidy/enforce/release-ready bytecode floors must treat
# lone *.pyo (opt-level bytecode) as junk — not only __pycache__/ and *.pyc.
# Blind spot theater: planted scripts/**/*.pyo previously greenwashed
# TIDY: PASS / enforce Layer 2 PASS while bytecode stayed in-tree; *.pyc-only
# .gitignore also greenwashed Layer 3/4.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TIDY_PY="$ROOT/scripts/tidy/run.py"
ENFORCE_PY="$ROOT/scripts/enforce/run.py"
RELEASE_PY="$ROOT/scripts/release-ready/run.py"
GI="$ROOT/.gitignore"
[[ -f "$TIDY_PY" ]] || { echo "FAIL bytecode-pyo: missing tidy/run.py" >&2; exit 1; }
[[ -f "$ENFORCE_PY" ]] || { echo "FAIL bytecode-pyo: missing enforce/run.py" >&2; exit 1; }
[[ -f "$RELEASE_PY" ]] || { echo "FAIL bytecode-pyo: missing release-ready/run.py" >&2; exit 1; }
[[ -f "$GI" ]] || { echo "FAIL bytecode-pyo: missing .gitignore" >&2; exit 1; }

# Source must scan *.pyo (tidy + enforce + release-ready purge).
grep -q '\.pyo' "$TIDY_PY" \
  || { echo "FAIL bytecode-pyo: tidy/run.py missing .pyo" >&2; exit 1; }
grep -q '\.pyo' "$ENFORCE_PY" \
  || { echo "FAIL bytecode-pyo: enforce/run.py missing .pyo" >&2; exit 1; }
grep -q '\.pyo' "$RELEASE_PY" \
  || { echo "FAIL bytecode-pyo: release-ready/run.py missing .pyo" >&2; exit 1; }
grep -qF '*.pyo' "$GI" \
  || { echo "FAIL bytecode-pyo: .gitignore missing *.pyo" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-bytecode-pyo-XXXXXX")"
PLANT="$ROOT/scripts/complete-e2e/.bytecode-plant-pyo.pyo"
trap 'rm -rf "$tmp"; rm -f "$PLANT"' EXIT

# Theater-kill: old .pyc-only predicate must miss the plant.
python3 - "$ROOT" "$PLANT" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
plant = Path(sys.argv[2])
plant.write_bytes(b"FAKE_PYO_BYTECODE")
assert plant.is_file()

def junk_old():
    return [
        p
        for p in root.rglob("*")
        if ".git" not in p.parts and (p.name == "__pycache__" or p.suffix == ".pyc")
    ]

def junk_fixed():
    return [
        p
        for p in root.rglob("*")
        if ".git" not in p.parts
        and (p.name == "__pycache__" or p.suffix in {".pyc", ".pyo"})
    ]

old = junk_old()
fixed = junk_fixed()
plant_rel = str(plant.relative_to(root))
assert not any(p.resolve() == plant.resolve() for p in old), (
    "sanity: old .pyc-only predicate unexpectedly caught .pyo plant: " + repr(old)
)
assert any(p.resolve() == plant.resolve() for p in fixed), (
    "fixed .pyc+.pyo predicate must catch plant; fixed=" + repr(fixed)
)
print("runtime plant: old miss / fixed catch:", plant_rel)
PY

# Live tidy --full must FAIL closed on the plant (not greenwash TIDY: PASS).
set +e
python3 "$TIDY_PY" --full >"$tmp/tidy.out" 2>"$tmp/tidy.err"
tidy_rc=$?
set -e
tidy_text="$(cat "$tmp/tidy.out" "$tmp/tidy.err" 2>/dev/null || true)"
[[ "$tidy_rc" -ne 0 ]] \
  || { echo "FAIL bytecode-pyo: tidy --full rc=0 with planted .pyo"$'\n'"$tidy_text" >&2; exit 1; }
printf '%s' "$tidy_text" | grep -qiE 'bytecode|\.pyo|FAIL' \
  || { echo "FAIL bytecode-pyo: tidy fail diagnostic missing"$'\n'"$tidy_text" >&2; exit 1; }
printf '%s' "$tidy_text" | grep -q 'TIDY: PASS' \
  && { echo "FAIL bytecode-pyo: tidy still TIDY: PASS with planted .pyo"$'\n'"$tidy_text" >&2; exit 1; }

rm -f "$PLANT"

# Live clean: no plant → tidy --full PASS; gitignore requires *.pyo.
python3 "$TIDY_PY" --full >"$tmp/tidy-clean.out" 2>"$tmp/tidy-clean.err"
clean_rc=$?
clean_text="$(cat "$tmp/tidy-clean.out" "$tmp/tidy-clean.err" 2>/dev/null || true)"
[[ "$clean_rc" -eq 0 ]] \
  || { echo "FAIL bytecode-pyo: tidy --full exited $clean_rc on clean tree"$'\n'"$clean_text" >&2; exit 1; }
printf '%s' "$clean_text" | grep -q 'TIDY: PASS' \
  || { echo "FAIL bytecode-pyo: tidy clean missing TIDY: PASS"$'\n'"$clean_text" >&2; exit 1; }
printf '%s' "$clean_text" | grep -q 'no __pycache__/.pyc/.pyo' \
  || { echo "FAIL bytecode-pyo: tidy clean missing .pyo-aware PASS label"$'\n'"$clean_text" >&2; exit 1; }

# Theater-kill gitignore: strip *.pyo line → tidy Layer 3 must fail.
gi_bak="$tmp/gitignore.bak"
cp "$GI" "$gi_bak"
# Remove *.pyo lines only
grep -vF '*.pyo' "$gi_bak" >"$GI"
set +e
python3 "$TIDY_PY" --full >"$tmp/tidy-gi.out" 2>"$tmp/tidy-gi.err"
gi_rc=$?
set -e
gi_text="$(cat "$tmp/tidy-gi.out" "$tmp/tidy-gi.err" 2>/dev/null || true)"
cp "$gi_bak" "$GI"
[[ "$gi_rc" -ne 0 ]] \
  || { echo "FAIL bytecode-pyo: tidy --full rc=0 without *.pyo in .gitignore"$'\n'"$gi_text" >&2; exit 1; }
printf '%s' "$gi_text" | grep -qiE 'gitignore|MISSING|\.pyo|FAIL' \
  || { echo "FAIL bytecode-pyo: tidy gitignore-fail diagnostic missing"$'\n'"$gi_text" >&2; exit 1; }

echo "PASS complete-e2e-bytecode-covers-pyo: tidy/enforce/release-ready treat *.pyo as bytecode; plant fail-closed; .gitignore requires *.pyo"
