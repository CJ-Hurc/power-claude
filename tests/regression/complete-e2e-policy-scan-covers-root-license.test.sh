#!/usr/bin/env bash
# Fail-closed gate: enforce/release-ready policy scan must cover extensionless
# root files (LICENSE). Blind spot theater: CERTIFIED=1 under root LICENSE
# previously greenwashed "no ... enables in scripts+devtools+configs+media+docs+root"
# PASS because ROOT.iterdir() only kept files whose suffix was in the set while
# LICENSE has suffix "" and verify Layer 1 requires LICENSE as a product surface.
# Fix: empty-suffix root files are scanned; unknown non-empty suffixes stay out.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENFORCE_PY="$ROOT/scripts/enforce/run.py"
RELEASE_PY="$ROOT/scripts/release-ready/run.py"
LICENSE="$ROOT/LICENSE"
[[ -f "$ENFORCE_PY" ]] || { echo "FAIL policy-scan-root-license: missing enforce/run.py" >&2; exit 1; }
[[ -f "$RELEASE_PY" ]] || { echo "FAIL policy-scan-root-license: missing release-ready/run.py" >&2; exit 1; }
[[ -f "$LICENSE" ]] || { echo "FAIL policy-scan-root-license: missing LICENSE (scan target)" >&2; exit 1; }

# Source must include empty-suffix root files (both floors).
grep -q "ROOT.iterdir()" "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-root-license: enforce/run.py missing ROOT.iterdir() root-file scan" >&2; exit 1; }
grep -q "ROOT.iterdir()" "$RELEASE_PY" \
  || { echo "FAIL policy-scan-root-license: release-ready/run.py missing ROOT.iterdir() root-file scan" >&2; exit 1; }
grep -qE "path\.suffix and path\.suffix not in" "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-root-license: enforce missing empty-suffix root inclusion (path.suffix and ...)" >&2; exit 1; }
grep -qE "path\.suffix and path\.suffix not in" "$RELEASE_PY" \
  || { echo "FAIL policy-scan-root-license: release-ready missing empty-suffix root inclusion (path.suffix and ...)" >&2; exit 1; }
grep -qE "scripts\+devtools\+configs\+media\+docs\+root" "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-root-license: enforce PASS message missing +root" >&2; exit 1; }
grep -qE "scripts\+devtools\+configs\+media\+docs\+root" "$RELEASE_PY" \
  || { echo "FAIL policy-scan-root-license: release-ready PASS message missing +root" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-policy-scan-root-license-XXXXXX")"
trap "rm -rf \"$tmp\"; rm -f \"$ROOT/.policy-scan-plant-certified-root-extless\"" EXIT

PLANT="$ROOT/.policy-scan-plant-certified-root-extless"
# Needle matches enforce/release-ready policy scan (CERTIFIED + "=1").
# Plant as extensionless root sibling of LICENSE (not .md) to prove empty-suffix coverage.
printf "%s\n" "# plant for policy-scan regression — CERTIFIED=1" >"$PLANT"

python3 - "$ROOT" "$PLANT" "$ENFORCE_PY" <<"PY"
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
plant = Path(sys.argv[2])
enforce_py = Path(sys.argv[3])
src = enforce_py.read_text(encoding="utf-8")
m = re.search(r"path\.suffix not in \{([^}]+)\}", src)
assert m, "could not parse enforce policy suffix set"
suffix_set = eval("{" + m.group(1) + "}", {"__builtins__": {}})
assert "ROOT.iterdir()" in src, "enforce must scan ROOT.iterdir() root files"
assert "path.suffix and path.suffix not in" in src, "enforce must include empty-suffix root files"
assert plant.suffix == "", (plant, plant.suffix)


def scan(dir_roots, include_root_files, allow_empty_root, suffixes):
    banned = []
    paths = []
    for root_name in dir_roots:
        base = root / root_name
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*")):
            if not path.is_file():
                continue
            if path.suffix not in suffixes:
                continue
            paths.append(path)
    if include_root_files:
        for path in sorted(root.iterdir()):
            if not path.is_file():
                continue
            if allow_empty_root:
                if path.suffix and path.suffix not in suffixes:
                    continue
            else:
                if path.suffix not in suffixes:
                    continue
            paths.append(path)
    for path in paths:
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


# Theater-kill: old suffix-set-only root iterdir must miss the extensionless plant.
miss = scan(["scripts", "devtools", "configs", "media", "docs"], True, False, suffix_set)
assert not any(str(plant.relative_to(root)) in b for b in miss), (
    "sanity: suffix-set-only root scan unexpectedly caught extensionless plant: " + repr(miss)
)

# Fixed empty-suffix inclusion must catch CERTIFIED=1 in the planted root file.
hit = scan(["scripts", "devtools", "configs", "media", "docs"], True, True, suffix_set)
plant_hits = [b for b in hit if str(plant.relative_to(root)) in b]
assert plant_hits, (
    "policy scan with empty-suffix root inclusion must catch CERTIFIED=1 "
    f"in planted extensionless root file; banned={hit!r}"
)
assert any("CERTIFIED" in b for b in plant_hits), plant_hits
print("runtime plant caught:", plant_hits[0])
PY

rm -f "$PLANT"

# After plant removal, live floors must still PASS policy (no leftover enable).
python3 - "$ROOT" "$ENFORCE_PY" <<"PY"
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
enforce_py = Path(sys.argv[2])
src = enforce_py.read_text(encoding="utf-8")
m = re.search(r"path\.suffix not in \{([^}]+)\}", src)
suffix_set = eval("{" + m.group(1) + "}", {"__builtins__": {}})
banned = []
paths = []
for root_name in ("scripts", "devtools", "configs", "media", "docs"):
    base = root / root_name
    if not base.is_dir():
        continue
    for path in sorted(base.rglob("*")):
        if not path.is_file() or path.suffix not in suffix_set:
            continue
        paths.append(path)
for path in sorted(root.iterdir()):
    if not path.is_file():
        continue
    if path.suffix and path.suffix not in suffix_set:
        continue
    paths.append(path)
for path in paths:
    text = path.read_text(encoding="utf-8", errors="replace")
    rel = str(path.relative_to(root))
    if ("ALLOW_UNPROVEN" + "=1") in text or ("ALLOW_UNPROVEN" + " = 1") in text:
        banned.append(rel)
    if ("CERTIFIED" + "=1") in text or ("certified" + " = true") in text.lower():
        banned.append(rel)
assert not banned, f"live scripts+devtools+configs+media+docs+root still have policy violations after plant cleanup: {banned}"
license_path = root / "LICENSE"
assert license_path.is_file()
assert license_path.suffix == ""
assert "path.suffix and path.suffix not in" in src
print("live scan clean; LICENSE covered by ROOT.iterdir()+empty-suffix")
PY

echo "PASS complete-e2e-policy-scan-covers-root-license: scripts+devtools+configs+media+docs+root empty-suffix in enforce+release-ready policy scan; CERTIFIED=1 plant fail-closed (no root LICENSE blind spot)"
