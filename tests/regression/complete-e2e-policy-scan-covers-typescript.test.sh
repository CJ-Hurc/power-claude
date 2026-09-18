#!/usr/bin/env bash
# Fail-closed gate: enforce/release-ready policy scan must cover scripts/**/*.ts.
# Blind spot theater: CERTIFIED=1 / ALLOW_UNPROVEN=1 in .ts previously greenwashed
# "no ... enables in scripts" PASS because suffix set omitted .ts while
# scripts/complete-e2e/issue-accepted-receipt.ts exists under scripts/.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENFORCE_PY="$ROOT/scripts/enforce/run.py"
RELEASE_PY="$ROOT/scripts/release-ready/run.py"
TS_EXISTING="$ROOT/scripts/complete-e2e/issue-accepted-receipt.ts"
[[ -f "$ENFORCE_PY" ]] || { echo "FAIL policy-scan-ts: missing enforce/run.py" >&2; exit 1; }
[[ -f "$RELEASE_PY" ]] || { echo "FAIL policy-scan-ts: missing release-ready/run.py" >&2; exit 1; }
[[ -f "$TS_EXISTING" ]] || { echo "FAIL policy-scan-ts: missing issue-accepted-receipt.ts (scan target)" >&2; exit 1; }

# Source must include .ts in the policy suffix set (both floors).
grep -q '\.ts' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-ts: enforce/run.py suffix set missing .ts" >&2; exit 1; }
grep -q '\.ts' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-ts: release-ready/run.py suffix set missing .ts" >&2; exit 1; }
grep -qE 'suffix not in \{[^}]*"\.ts"' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-ts: enforce suffix set does not list .ts" >&2; exit 1; }
grep -qE 'suffix not in \{[^}]*"\.ts"' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-ts: release-ready suffix set does not list .ts" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-policy-scan-ts-XXXXXX")"
trap 'rm -rf "$tmp"; rm -f "$ROOT/scripts/complete-e2e/.policy-scan-plant-certified.ts"' EXIT

PLANT="$ROOT/scripts/complete-e2e/.policy-scan-plant-certified.ts"
# Needle matches enforce/release-ready policy scan (CERTIFIED + "=1").
printf '%s\n' '// plant for policy-scan regression — CERTIFIED=1' >"$PLANT"

python3 - "$ROOT" "$PLANT" "$ENFORCE_PY" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
plant = Path(sys.argv[2])
enforce_py = Path(sys.argv[3])
src = enforce_py.read_text(encoding="utf-8")
m = re.search(r"path\.suffix not in \{([^}]+)\}", src)
assert m, "could not parse enforce policy suffix set"
# Eval the set literal safely from the captured contents
suffix_set = eval("{" + m.group(1) + "}", {"__builtins__": {}})
assert ".ts" in suffix_set, suffix_set

def scan(suffixes: set[str]) -> list[str]:
    banned: list[str] = []
    for path in sorted((root / "scripts").rglob("*")):
        if not path.is_file():
            continue
        if path.suffix not in suffixes:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        rel = str(path.relative_to(root))
        allow_a = "ALLOW_UNPROVEN" + "=1"
        allow_b = "ALLOW_UNPROVEN" + " = 1"
        if allow_a in text or allow_b in text:
            banned.append(rel + ": " + allow_a)
        cert_a = "CERTIFIED" + "=1"
        cert_b = "certified" + " = true"
        if cert_a in text or cert_b in text.lower():
            banned.append(rel + ": fake CERTIFIED enable")
    return banned

# Theater-kill: old suffix set (no .ts) must miss the plant.
old = {".py", ".sh", ".md", ".yml", ".yaml"}
miss = scan(old)
assert not any(str(plant.relative_to(root)) in b for b in miss), (
    "sanity: old suffix set unexpectedly caught plant: " + repr(miss)
)

# Fixed suffix set must catch CERTIFIED=1 in the planted .ts.
hit = scan(suffix_set)
plant_hits = [b for b in hit if str(plant.relative_to(root)) in b]
assert plant_hits, (
    "policy scan with enforce suffix set must catch CERTIFIED=1 in planted .ts; "
    f"banned={hit!r}"
)
assert any("CERTIFIED" in b for b in plant_hits), plant_hits
print("runtime plant caught:", plant_hits[0])
PY

rm -f "$PLANT"

# After plant removal, live floors must still PASS policy (no leftover enable).
python3 - "$ROOT" "$ENFORCE_PY" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
enforce_py = Path(sys.argv[2])
src = enforce_py.read_text(encoding="utf-8")
m = re.search(r"path\.suffix not in \{([^}]+)\}", src)
suffix_set = eval("{" + m.group(1) + "}", {"__builtins__": {}})
banned = []
for path in sorted((root / "scripts").rglob("*")):
    if not path.is_file() or path.suffix not in suffix_set:
        continue
    text = path.read_text(encoding="utf-8", errors="replace")
    rel = str(path.relative_to(root))
    if ("ALLOW_UNPROVEN" + "=1") in text or ("ALLOW_UNPROVEN" + " = 1") in text:
        banned.append(rel)
    if ("CERTIFIED" + "=1") in text or ("certified" + " = true") in text.lower():
        banned.append(rel)
assert not banned, f"live scripts still have policy violations after plant cleanup: {banned}"
# Existing .ts must be inside the scanned set.
ts = root / "scripts/complete-e2e/issue-accepted-receipt.ts"
assert ts.suffix in suffix_set, suffix_set
assert ts.is_file()
print("live scan clean; issue-accepted-receipt.ts covered by suffix set")
PY

echo "PASS complete-e2e-policy-scan-covers-typescript: .ts in enforce+release-ready suffix set; CERTIFIED=1 plant fail-closed (no scripts/ blind spot)"
