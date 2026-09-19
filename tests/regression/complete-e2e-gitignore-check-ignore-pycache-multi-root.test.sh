#!/usr/bin/env bash
# Fail-closed gate: tidy Layer 3 / enforce Layer 4 git check-ignore bytecode
# floor must probe __pycache__/ dirs under product roots beyond
# scripts/complete-e2e/ (devtools/, configs/, media/, docs/, root).
# Blind spot theater: *.pyc/*.pyo multi-root probes previously greenwashed
# PASS while !media/__pycache__/ left product-tree __pycache__/ dirs
# trackable — git check-ignore would not ignore under those roots.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TIDY_PY="$ROOT/scripts/tidy/run.py"
ENFORCE_PY="$ROOT/scripts/enforce/run.py"
GI="$ROOT/.gitignore"
[[ -f "$TIDY_PY" ]] || { echo "FAIL gitignore-check-ignore-pycache-multi-root: missing tidy/run.py" >&2; exit 1; }
[[ -f "$ENFORCE_PY" ]] || { echo "FAIL gitignore-check-ignore-pycache-multi-root: missing enforce/run.py" >&2; exit 1; }
[[ -f "$GI" ]] || { echo "FAIL gitignore-check-ignore-pycache-multi-root: missing .gitignore" >&2; exit 1; }

# Source must probe __pycache__/ beyond scripts/complete-e2e/ (media + root minimum).
grep -q 'media/__pycache__/.gitignore-floor-probe' "$TIDY_PY" \
  || { echo "FAIL gitignore-check-ignore-pycache-multi-root: tidy/run.py missing media/__pycache__ probe" >&2; exit 1; }
grep -q 'devtools/__pycache__/.gitignore-floor-probe' "$TIDY_PY" \
  || { echo "FAIL gitignore-check-ignore-pycache-multi-root: tidy/run.py missing devtools/__pycache__ probe" >&2; exit 1; }
grep -q 'configs/__pycache__/.gitignore-floor-probe' "$TIDY_PY" \
  || { echo "FAIL gitignore-check-ignore-pycache-multi-root: tidy/run.py missing configs/__pycache__ probe" >&2; exit 1; }
grep -q 'docs/__pycache__/.gitignore-floor-probe' "$TIDY_PY" \
  || { echo "FAIL gitignore-check-ignore-pycache-multi-root: tidy/run.py missing docs/__pycache__ probe" >&2; exit 1; }
grep -qE '"__pycache__/\.gitignore-floor-probe"' "$TIDY_PY" \
  || { echo "FAIL gitignore-check-ignore-pycache-multi-root: tidy/run.py missing root __pycache__ probe" >&2; exit 1; }
grep -q 'media/__pycache__/.gitignore-floor-probe' "$ENFORCE_PY" \
  || { echo "FAIL gitignore-check-ignore-pycache-multi-root: enforce/run.py missing media/__pycache__ probe" >&2; exit 1; }
grep -q 'devtools/__pycache__/.gitignore-floor-probe' "$ENFORCE_PY" \
  || { echo "FAIL gitignore-check-ignore-pycache-multi-root: enforce/run.py missing devtools/__pycache__ probe" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-gitignore-check-ignore-pycache-multi-root-XXXXXX")"
gi_bak="$tmp/gitignore.bak"
cp "$GI" "$gi_bak"
trap 'cp "$gi_bak" "$GI" 2>/dev/null || true; rm -rf "$tmp"' EXIT

# Theater-kill: active __pycache__/ + *.pyc + *.pyo WITH !media/__pycache__/ —
# *.pyc/*.pyo multi-root probes PASS; media/__pycache__/ stays trackable.
python3 - "$ROOT" <<'PY'
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
gi_path = root / ".gitignore"
gi_path.write_text(
    ".hurc-harness/\ntmp/\n"
    "__pycache__/\n*.pyc\n*.pyo\n!media/__pycache__/\n"
    ".venv/\nscripts/complete-e2e/.receipts/\n",
    encoding="utf-8",
)
# Prior floor probes (file-suffix + scripts-only __pycache__) still ignore.
prior_probes = [
    "scripts/complete-e2e/.gitignore-floor-probe.pyc",
    "scripts/complete-e2e/.gitignore-floor-probe.pyo",
    "scripts/complete-e2e/__pycache__/.gitignore-floor-probe",
    "media/.gitignore-floor-probe.pyc",
    "media/.gitignore-floor-probe.pyo",
    "devtools/.gitignore-floor-probe.pyc",
]
for rel in prior_probes:
    r = subprocess.run(["git", "check-ignore", "-q", rel], cwd=str(root))
    assert r.returncode == 0, "sanity: prior multi-root file probes must still be ignored: " + rel
media_dir = "media/__pycache__/.gitignore-floor-probe"
r = subprocess.run(["git", "check-ignore", "-q", media_dir], cwd=str(root))
assert r.returncode != 0, "sanity: !media/__pycache__/ must leave media/__pycache__ probe NOT ignored"
print("runtime plant: *.pyc/*.pyo multi-root PASS / media/__pycache__ check-ignore FAIL under !media/__pycache__/")
PY

# Live tidy --full must FAIL closed (not greenwash Layer 3 / TIDY: PASS).
# Do not invoke full enforce here: Layer 3b would re-enter this regression.
set +e
python3 "$TIDY_PY" --full >"$tmp/tidy.out" 2>"$tmp/tidy.err"
tidy_rc=$?
set -e
tidy_text="$(cat "$tmp/tidy.out" "$tmp/tidy.err" 2>/dev/null || true)"
[[ "$tidy_rc" -ne 0 ]] \
  || { echo "FAIL gitignore-check-ignore-pycache-multi-root: tidy --full rc=0 with !media/__pycache__/"$'\n'"$tidy_text" >&2; exit 1; }
printf '%s' "$tidy_text" | grep -qiE 'gitignore|check-ignore|negation|FAIL' \
  || { echo "FAIL gitignore-check-ignore-pycache-multi-root: tidy fail diagnostic missing"$'\n'"$tidy_text" >&2; exit 1; }
printf '%s' "$tidy_text" | grep -q 'TIDY: PASS' \
  && { echo "FAIL gitignore-check-ignore-pycache-multi-root: tidy still TIDY: PASS with !media/__pycache__/"$'\n'"$tidy_text" >&2; exit 1; }
printf '%s' "$tidy_text" | grep -qiE 'check-ignore miss|gitignore check-ignore' \
  || { echo "FAIL gitignore-check-ignore-pycache-multi-root: tidy missing check-ignore FAIL label"$'\n'"$tidy_text" >&2; exit 1; }
printf '%s' "$tidy_text" | grep -q 'media/__pycache__/.gitignore-floor-probe' \
  || { echo "FAIL gitignore-check-ignore-pycache-multi-root: tidy miss list missing media/__pycache__ probe"$'\n'"$tidy_text" >&2; exit 1; }

# Restore real gitignore and confirm clean PASS + multi-root __pycache__ probes.
cp "$gi_bak" "$GI"
for probe in \
  scripts/complete-e2e/__pycache__/.gitignore-floor-probe \
  devtools/__pycache__/.gitignore-floor-probe \
  configs/__pycache__/.gitignore-floor-probe \
  media/__pycache__/.gitignore-floor-probe \
  docs/__pycache__/.gitignore-floor-probe \
  __pycache__/.gitignore-floor-probe
do
  git -C "$ROOT" check-ignore -q "$probe" \
    || { echo "FAIL gitignore-check-ignore-pycache-multi-root: real .gitignore does not ignore $probe" >&2; exit 1; }
done

python3 "$TIDY_PY" --full >"$tmp/tidy-clean.out" 2>"$tmp/tidy-clean.err"
clean_rc=$?
clean_text="$(cat "$tmp/tidy-clean.out" "$tmp/tidy-clean.err" 2>/dev/null || true)"
[[ "$clean_rc" -eq 0 ]] \
  || { echo "FAIL gitignore-check-ignore-pycache-multi-root: tidy --full exited $clean_rc on restored gitignore"$'\n'"$clean_text" >&2; exit 1; }
printf '%s' "$clean_text" | grep -q 'TIDY: PASS' \
  || { echo "FAIL gitignore-check-ignore-pycache-multi-root: tidy clean missing TIDY: PASS"$'\n'"$clean_text" >&2; exit 1; }
printf '%s' "$clean_text" | grep -q 'PASS  .gitignore covers bytecode' \
  || { echo "FAIL gitignore-check-ignore-pycache-multi-root: tidy clean missing gitignore PASS"$'\n'"$clean_text" >&2; exit 1; }

echo "PASS complete-e2e-gitignore-check-ignore-pycache-multi-root: tidy/enforce multi-root __pycache__/ git check-ignore floor; !media/__pycache__/ theater fail-closed"
