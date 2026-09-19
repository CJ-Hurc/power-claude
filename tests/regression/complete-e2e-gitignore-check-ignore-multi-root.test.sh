#!/usr/bin/env bash
# Fail-closed gate: tidy Layer 3 / enforce Layer 4 git check-ignore bytecode
# floor must probe product roots beyond scripts/complete-e2e/ (devtools/,
# configs/, media/, docs/, root). Blind spot theater: scripts-only probes
# previously greenwashed PASS while !media/*.pyc / !devtools/**/*.pyc left
# product-tree bytecode trackable — git check-ignore would not ignore.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TIDY_PY="$ROOT/scripts/tidy/run.py"
ENFORCE_PY="$ROOT/scripts/enforce/run.py"
GI="$ROOT/.gitignore"
[[ -f "$TIDY_PY" ]] || { echo "FAIL gitignore-check-ignore-multi-root: missing tidy/run.py" >&2; exit 1; }
[[ -f "$ENFORCE_PY" ]] || { echo "FAIL gitignore-check-ignore-multi-root: missing enforce/run.py" >&2; exit 1; }
[[ -f "$GI" ]] || { echo "FAIL gitignore-check-ignore-multi-root: missing .gitignore" >&2; exit 1; }

# Source must probe beyond scripts/complete-e2e/ (media + devtools minimum).
grep -q 'media/.gitignore-floor-probe' "$TIDY_PY" \
  || { echo "FAIL gitignore-check-ignore-multi-root: tidy/run.py missing media probe" >&2; exit 1; }
grep -q 'devtools/.gitignore-floor-probe' "$TIDY_PY" \
  || { echo "FAIL gitignore-check-ignore-multi-root: tidy/run.py missing devtools probe" >&2; exit 1; }
grep -q 'media/.gitignore-floor-probe' "$ENFORCE_PY" \
  || { echo "FAIL gitignore-check-ignore-multi-root: enforce/run.py missing media probe" >&2; exit 1; }
grep -q 'devtools/.gitignore-floor-probe' "$ENFORCE_PY" \
  || { echo "FAIL gitignore-check-ignore-multi-root: enforce/run.py missing devtools probe" >&2; exit 1; }
grep -q 'configs/.gitignore-floor-probe' "$TIDY_PY" \
  || { echo "FAIL gitignore-check-ignore-multi-root: tidy/run.py missing configs probe" >&2; exit 1; }
grep -q 'docs/.gitignore-floor-probe' "$TIDY_PY" \
  || { echo "FAIL gitignore-check-ignore-multi-root: tidy/run.py missing docs probe" >&2; exit 1; }
# Root-level probes (leading "./" optional; bare .gitignore-floor-probe.pyc).
grep -qE '"\.gitignore-floor-probe\.pyc"' "$TIDY_PY" \
  || { echo "FAIL gitignore-check-ignore-multi-root: tidy/run.py missing root .pyc probe" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-gitignore-check-ignore-multi-root-XXXXXX")"
gi_bak="$tmp/gitignore.bak"
cp "$GI" "$gi_bak"
trap 'cp "$gi_bak" "$GI" 2>/dev/null || true; rm -rf "$tmp"' EXIT

# Theater-kill: active __pycache__/ + *.pyc + *.pyo WITH !media/*.pyc —
# scripts-only probes PASS; media orphan stays trackable.
python3 - "$ROOT" <<'PY'
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
gi_path = root / ".gitignore"
gi_path.write_text(
    ".hurc-harness/\ntmp/\n"
    "__pycache__/\n*.pyc\n*.pyo\n!media/*.pyc\n"
    ".venv/\nscripts/complete-e2e/.receipts/\n",
    encoding="utf-8",
)
scripts_probes = [
    "scripts/complete-e2e/.gitignore-floor-probe.pyc",
    "scripts/complete-e2e/.gitignore-floor-probe.pyo",
    "scripts/complete-e2e/__pycache__/.gitignore-floor-probe",
]
for rel in scripts_probes:
    r = subprocess.run(["git", "check-ignore", "-q", rel], cwd=str(root))
    assert r.returncode == 0, "sanity: scripts-only probe must still be ignored: " + rel
media = "media/.gitignore-floor-probe.pyc"
r = subprocess.run(["git", "check-ignore", "-q", media], cwd=str(root))
assert r.returncode != 0, "sanity: !media/*.pyc must leave media probe NOT ignored"
print("runtime plant: scripts-only probes PASS / media check-ignore FAIL under !media/*.pyc")
PY

# Live tidy --full must FAIL closed (not greenwash Layer 3 / TIDY: PASS).
# Do not invoke full enforce here: Layer 3b would re-enter this regression.
set +e
python3 "$TIDY_PY" --full >"$tmp/tidy.out" 2>"$tmp/tidy.err"
tidy_rc=$?
set -e
tidy_text="$(cat "$tmp/tidy.out" "$tmp/tidy.err" 2>/dev/null || true)"
[[ "$tidy_rc" -ne 0 ]] \
  || { echo "FAIL gitignore-check-ignore-multi-root: tidy --full rc=0 with !media/*.pyc"$'\n'"$tidy_text" >&2; exit 1; }
printf '%s' "$tidy_text" | grep -qiE 'gitignore|check-ignore|negation|FAIL' \
  || { echo "FAIL gitignore-check-ignore-multi-root: tidy fail diagnostic missing"$'\n'"$tidy_text" >&2; exit 1; }
printf '%s' "$tidy_text" | grep -q 'TIDY: PASS' \
  && { echo "FAIL gitignore-check-ignore-multi-root: tidy still TIDY: PASS with !media/*.pyc"$'\n'"$tidy_text" >&2; exit 1; }
printf '%s' "$tidy_text" | grep -qiE 'check-ignore miss|gitignore check-ignore' \
  || { echo "FAIL gitignore-check-ignore-multi-root: tidy missing check-ignore FAIL label"$'\n'"$tidy_text" >&2; exit 1; }
printf '%s' "$tidy_text" | grep -q 'media/.gitignore-floor-probe.pyc' \
  || { echo "FAIL gitignore-check-ignore-multi-root: tidy miss list missing media probe"$'\n'"$tidy_text" >&2; exit 1; }

# Restore real gitignore and confirm clean PASS + multi-root check-ignore probes.
cp "$gi_bak" "$GI"
for probe in \
  scripts/complete-e2e/.gitignore-floor-probe.pyc \
  scripts/complete-e2e/.gitignore-floor-probe.pyo \
  scripts/complete-e2e/__pycache__/.gitignore-floor-probe \
  devtools/.gitignore-floor-probe.pyc \
  devtools/.gitignore-floor-probe.pyo \
  configs/.gitignore-floor-probe.pyc \
  configs/.gitignore-floor-probe.pyo \
  media/.gitignore-floor-probe.pyc \
  media/.gitignore-floor-probe.pyo \
  docs/.gitignore-floor-probe.pyc \
  docs/.gitignore-floor-probe.pyo \
  .gitignore-floor-probe.pyc \
  .gitignore-floor-probe.pyo
do
  git -C "$ROOT" check-ignore -q "$probe" \
    || { echo "FAIL gitignore-check-ignore-multi-root: real .gitignore does not ignore $probe" >&2; exit 1; }
done

python3 "$TIDY_PY" --full >"$tmp/tidy-clean.out" 2>"$tmp/tidy-clean.err"
clean_rc=$?
clean_text="$(cat "$tmp/tidy-clean.out" "$tmp/tidy-clean.err" 2>/dev/null || true)"
[[ "$clean_rc" -eq 0 ]] \
  || { echo "FAIL gitignore-check-ignore-multi-root: tidy --full exited $clean_rc on restored gitignore"$'\n'"$clean_text" >&2; exit 1; }
printf '%s' "$clean_text" | grep -q 'TIDY: PASS' \
  || { echo "FAIL gitignore-check-ignore-multi-root: tidy clean missing TIDY: PASS"$'\n'"$clean_text" >&2; exit 1; }
printf '%s' "$clean_text" | grep -q 'PASS  .gitignore covers bytecode' \
  || { echo "FAIL gitignore-check-ignore-multi-root: tidy clean missing gitignore PASS"$'\n'"$clean_text" >&2; exit 1; }

echo "PASS complete-e2e-gitignore-check-ignore-multi-root: tidy/enforce multi-root git check-ignore bytecode floor; !media/*.pyc scripts-only theater fail-closed"
