#!/usr/bin/env bash
# Fail-closed gate: tidy Layer 3 / enforce Layer 4 must live-verify bytecode
# ignores via `git check-ignore` (not rule-text AND alone). Blind spot theater:
# has_pycache AND has_pyc AND has_pyo previously greenwashed PASS while
# !*.pyc (negation after *.pyc) left orphan scripts/**/*.pyc trackable —
# git check-ignore would not ignore.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TIDY_PY="$ROOT/scripts/tidy/run.py"
ENFORCE_PY="$ROOT/scripts/enforce/run.py"
GI="$ROOT/.gitignore"
[[ -f "$TIDY_PY" ]] || { echo "FAIL gitignore-check-ignore: missing tidy/run.py" >&2; exit 1; }
[[ -f "$ENFORCE_PY" ]] || { echo "FAIL gitignore-check-ignore: missing enforce/run.py" >&2; exit 1; }
[[ -f "$GI" ]] || { echo "FAIL gitignore-check-ignore: missing .gitignore" >&2; exit 1; }

# Source must invoke git check-ignore (not rule-text-only).
grep -q 'check-ignore' "$TIDY_PY" \
  || { echo "FAIL gitignore-check-ignore: tidy/run.py missing git check-ignore" >&2; exit 1; }
grep -q 'check-ignore' "$ENFORCE_PY" \
  || { echo "FAIL gitignore-check-ignore: enforce/run.py missing git check-ignore" >&2; exit 1; }
grep -q 'gitignore-floor-probe' "$TIDY_PY" \
  || { echo "FAIL gitignore-check-ignore: tidy/run.py missing probe paths" >&2; exit 1; }
grep -q 'gitignore-floor-probe' "$ENFORCE_PY" \
  || { echo "FAIL gitignore-check-ignore: enforce/run.py missing probe paths" >&2; exit 1; }
# enforce --fix must strip bytecode negations (append-only cannot beat !*.pyc).
grep -q '_strip_bytecode_negations\|strip_bytecode_negations\|stripped bytecode negations' "$ENFORCE_PY" \
  || { echo "FAIL gitignore-check-ignore: enforce/run.py missing negation strip under --fix" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-gitignore-check-ignore-XXXXXX")"
gi_bak="$tmp/gitignore.bak"
cp "$GI" "$gi_bak"
trap 'cp "$gi_bak" "$GI" 2>/dev/null || true; rm -rf "$tmp"' EXIT

# Theater-kill: active __pycache__/ + *.pyc + *.pyo WITH !*.pyc — old AND PASSes.
python3 - "$ROOT" <<'PY'
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
gi_path = root / ".gitignore"
gi_path.write_text(
    ".hurc-harness/\ntmp/\n"
    "__pycache__/\n*.pyc\n*.pyo\n!*.pyc\n"
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
has_pycache = "__pycache__/" in rules or "__pycache__" in rules
has_pyc = "*.pyc" in rules
has_pyo = "*.pyo" in rules
old_ok = has_pycache and has_pyc and has_pyo
assert old_ok, "sanity: old rule-text AND must PASS with !*.pyc; rules=" + repr(rules)
probe = "scripts/complete-e2e/.gitignore-floor-probe.pyc"
r = subprocess.run(["git", "check-ignore", "-q", probe], cwd=str(root))
assert r.returncode != 0, "sanity: !*.pyc must make probe.pyc NOT ignored"
print("runtime plant: old rule-text AND PASS / check-ignore FAIL under !*.pyc")
PY

# Live tidy --full must FAIL closed (not greenwash Layer 3 / TIDY: PASS).
# Do not invoke full enforce here: Layer 3b would re-enter this regression.
set +e
python3 "$TIDY_PY" --full >"$tmp/tidy.out" 2>"$tmp/tidy.err"
tidy_rc=$?
set -e
tidy_text="$(cat "$tmp/tidy.out" "$tmp/tidy.err" 2>/dev/null || true)"
[[ "$tidy_rc" -ne 0 ]] \
  || { echo "FAIL gitignore-check-ignore: tidy --full rc=0 with !*.pyc"$'\n'"$tidy_text" >&2; exit 1; }
printf '%s' "$tidy_text" | grep -qiE 'gitignore|check-ignore|negation|FAIL' \
  || { echo "FAIL gitignore-check-ignore: tidy fail diagnostic missing"$'\n'"$tidy_text" >&2; exit 1; }
printf '%s' "$tidy_text" | grep -q 'TIDY: PASS' \
  && { echo "FAIL gitignore-check-ignore: tidy still TIDY: PASS with !*.pyc"$'\n'"$tidy_text" >&2; exit 1; }
printf '%s' "$tidy_text" | grep -qiE 'check-ignore miss|gitignore check-ignore' \
  || { echo "FAIL gitignore-check-ignore: tidy missing check-ignore FAIL label"$'\n'"$tidy_text" >&2; exit 1; }

# Restore real gitignore and confirm clean PASS + check-ignore probes.
cp "$gi_bak" "$GI"
for probe in \
  scripts/complete-e2e/.gitignore-floor-probe.pyc \
  scripts/complete-e2e/.gitignore-floor-probe.pyo \
  scripts/complete-e2e/__pycache__/.gitignore-floor-probe
do
  git -C "$ROOT" check-ignore -q "$probe" \
    || { echo "FAIL gitignore-check-ignore: real .gitignore does not ignore $probe" >&2; exit 1; }
done

python3 "$TIDY_PY" --full >"$tmp/tidy-clean.out" 2>"$tmp/tidy-clean.err"
clean_rc=$?
clean_text="$(cat "$tmp/tidy-clean.out" "$tmp/tidy-clean.err" 2>/dev/null || true)"
[[ "$clean_rc" -eq 0 ]] \
  || { echo "FAIL gitignore-check-ignore: tidy --full exited $clean_rc on restored gitignore"$'\n'"$clean_text" >&2; exit 1; }
printf '%s' "$clean_text" | grep -q 'TIDY: PASS' \
  || { echo "FAIL gitignore-check-ignore: tidy clean missing TIDY: PASS"$'\n'"$clean_text" >&2; exit 1; }
printf '%s' "$clean_text" | grep -q 'PASS  .gitignore covers bytecode' \
  || { echo "FAIL gitignore-check-ignore: tidy clean missing gitignore PASS"$'\n'"$clean_text" >&2; exit 1; }

echo "PASS complete-e2e-gitignore-check-ignore: tidy/enforce live git check-ignore bytecode floor; !*.pyc rule-text theater fail-closed"
