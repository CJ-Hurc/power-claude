#!/usr/bin/env bash
# Fail-closed gate: tidy Layer 3 / enforce Layer 4 must require ACTIVE
# (non-comment) .gitignore bytecode rules. Blind spot theater: substring
# `("__pycache__" in gi or "*.pyc" in gi) and "*.pyo" in gi` previously
# greenwashed PASS while rules lived only inside # comments — git
# check-ignore would not ignore planted *.pyo.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TIDY_PY="$ROOT/scripts/tidy/run.py"
ENFORCE_PY="$ROOT/scripts/enforce/run.py"
GI="$ROOT/.gitignore"
[[ -f "$TIDY_PY" ]] || { echo "FAIL gitignore-active: missing tidy/run.py" >&2; exit 1; }
[[ -f "$ENFORCE_PY" ]] || { echo "FAIL gitignore-active: missing enforce/run.py" >&2; exit 1; }
[[ -f "$GI" ]] || { echo "FAIL gitignore-active: missing .gitignore" >&2; exit 1; }

# Source must skip comment lines when reading .gitignore (not substring-only).
grep -q 'startswith("#")' "$TIDY_PY" \
  || { echo "FAIL gitignore-active: tidy/run.py missing comment-skip for gitignore lines" >&2; exit 1; }
grep -q 'startswith("#")' "$ENFORCE_PY" \
  || { echo "FAIL gitignore-active: enforce/run.py missing comment-skip for gitignore lines" >&2; exit 1; }
grep -q 'missing active' "$TIDY_PY" \
  || { echo "FAIL gitignore-active: tidy/run.py missing active-rules fail label" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-gitignore-active-XXXXXX")"
gi_bak="$tmp/gitignore.bak"
cp "$GI" "$gi_bak"
trap 'cp "$gi_bak" "$GI" 2>/dev/null || true; rm -rf "$tmp"' EXIT

# Theater-kill: old substring predicate PASSes when rules are comments only.
python3 - "$ROOT" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
gi_path = root / ".gitignore"
# Comment-only bytecode rules (words present; no active ignore).
gi_path.write_text(
    ".hurc-harness/\ntmp/\n"
    "# __pycache__/\n# *.pyc\n# *.pyo\n"
    ".venv/\nscripts/complete-e2e/.receipts/\n",
    encoding="utf-8",
)
gi = gi_path.read_text(encoding="utf-8")
old_ok = ("__pycache__" in gi or "*.pyc" in gi) and "*.pyo" in gi
assert old_ok, "sanity: old substring predicate must PASS on comment-only rules"
# Active-line predicate must FAIL.
rules = set()
for raw in gi.splitlines():
    s = raw.strip()
    if not s or s.startswith("#"):
        continue
    rules.add(s)
has_base = "__pycache__/" in rules or "__pycache__" in rules or "*.pyc" in rules
fixed_ok = has_base and "*.pyo" in rules
assert not fixed_ok, "fixed active-line predicate must FAIL on comment-only; rules=" + repr(rules)
print("runtime plant: old substring PASS / fixed active-line FAIL on comment-only *.pyo")
PY

# Live tidy --full must FAIL closed (not greenwash Layer 3 / TIDY: PASS).
set +e
python3 "$TIDY_PY" --full >"$tmp/tidy.out" 2>"$tmp/tidy.err"
tidy_rc=$?
set -e
tidy_text="$(cat "$tmp/tidy.out" "$tmp/tidy.err" 2>/dev/null || true)"
[[ "$tidy_rc" -ne 0 ]] \
  || { echo "FAIL gitignore-active: tidy --full rc=0 with comment-only bytecode rules"$'\n'"$tidy_text" >&2; exit 1; }
printf '%s' "$tidy_text" | grep -qiE 'gitignore|active|FAIL' \
  || { echo "FAIL gitignore-active: tidy fail diagnostic missing"$'\n'"$tidy_text" >&2; exit 1; }
printf '%s' "$tidy_text" | grep -q 'TIDY: PASS' \
  && { echo "FAIL gitignore-active: tidy still TIDY: PASS with comment-only rules"$'\n'"$tidy_text" >&2; exit 1; }
printf '%s' "$tidy_text" | grep -qi 'gitignore missing active' \
  || { echo "FAIL gitignore-active: tidy missing gitignore FAIL label"$'\n'"$tidy_text" >&2; exit 1; }

# Restore real gitignore and confirm clean PASS + git check-ignore.
cp "$gi_bak" "$GI"
plant="$ROOT/scripts/complete-e2e/.gitignore-active-plant.pyo"
printf 'x' >"$plant"
trap 'cp "$gi_bak" "$GI" 2>/dev/null || true; rm -f "$plant"; rm -rf "$tmp"' EXIT
git -C "$ROOT" check-ignore -q "$plant" \
  || { echo "FAIL gitignore-active: real .gitignore does not ignore planted .pyo" >&2; exit 1; }
rm -f "$plant"

python3 "$TIDY_PY" --full >"$tmp/tidy-clean.out" 2>"$tmp/tidy-clean.err"
clean_rc=$?
clean_text="$(cat "$tmp/tidy-clean.out" "$tmp/tidy-clean.err" 2>/dev/null || true)"
[[ "$clean_rc" -eq 0 ]] \
  || { echo "FAIL gitignore-active: tidy --full exited $clean_rc on restored gitignore"$'\n'"$clean_text" >&2; exit 1; }
printf '%s' "$clean_text" | grep -q 'TIDY: PASS' \
  || { echo "FAIL gitignore-active: tidy clean missing TIDY: PASS"$'\n'"$clean_text" >&2; exit 1; }
printf '%s' "$clean_text" | grep -q 'PASS  .gitignore covers bytecode' \
  || { echo "FAIL gitignore-active: tidy clean missing gitignore PASS"$'\n'"$clean_text" >&2; exit 1; }

echo "PASS complete-e2e-gitignore-active-bytecode: tidy/enforce require active (non-comment) __pycache__/*.pyc/*.pyo gitignore rules; comment-only substring theater fail-closed"
