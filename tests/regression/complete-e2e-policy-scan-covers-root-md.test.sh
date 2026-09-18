#!/usr/bin/env bash
# Fail-closed gate: enforce/release-ready policy scan must cover root-level *.md
# (README.md / CHANGELOG.md). Blind spot theater: CERTIFIED=1 under root README.md
# previously greenwashed "no ... enables in scripts+devtools+configs+media+docs"
# PASS because scan used dir-only policy_roots while .md was already in the suffix
# set and verify Layer 1 requires README.md/CHANGELOG.md as product surfaces.
# Fix uses ROOT.iterdir() files only (not rglob) so tests/ plant needles stay out.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENFORCE_PY="$ROOT/scripts/enforce/run.py"
RELEASE_PY="$ROOT/scripts/release-ready/run.py"
README="$ROOT/README.md"
CHANGELOG="$ROOT/CHANGELOG.md"
[[ -f "$ENFORCE_PY" ]] || { echo "FAIL policy-scan-root-md: missing enforce/run.py" >&2; exit 1; }
[[ -f "$RELEASE_PY" ]] || { echo "FAIL policy-scan-root-md: missing release-ready/run.py" >&2; exit 1; }
[[ -f "$README" ]] || { echo "FAIL policy-scan-root-md: missing README.md (scan target)" >&2; exit 1; }
[[ -f "$CHANGELOG" ]] || { echo "FAIL policy-scan-root-md: missing CHANGELOG.md (scan target)" >&2; exit 1; }

# Source must iterdir root files (both floors). .md already in suffix set.
grep -q 'ROOT.iterdir()' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-root-md: enforce/run.py missing ROOT.iterdir() root-file scan" >&2; exit 1; }
grep -q 'ROOT.iterdir()' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-root-md: release-ready/run.py missing ROOT.iterdir() root-file scan" >&2; exit 1; }
grep -qE 'scripts\+devtools\+configs\+media\+docs\+root' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-root-md: enforce PASS message missing +root" >&2; exit 1; }
grep -qE 'scripts\+devtools\+configs\+media\+docs\+root' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-root-md: release-ready PASS message missing +root" >&2; exit 1; }
grep -qE 'suffix not in \{[^}]*"\.md"' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-root-md: enforce suffix set does not list .md" >&2; exit 1; }
grep -qE 'suffix not in \{[^}]*"\.md"' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-root-md: release-ready suffix set does not list .md" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-policy-scan-root-md-XXXXXX")"
trap 'rm -rf "$tmp"; rm -f "$ROOT/.policy-scan-plant-certified-root.md"' EXIT

PLANT="$ROOT/.policy-scan-plant-certified-root.md"
# Needle matches enforce/release-ready policy scan (CERTIFIED + "=1").
# Plant as a root-level .md sibling of README (not under docs/) to prove iterdir coverage.
printf '%s\n' '# plant for policy-scan regression — CERTIFIED=1' >"$PLANT"

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
suffix_set = eval("{" + m.group(1) + "}", {"__builtins__": {}})
assert ".md" in suffix_set, suffix_set
assert "ROOT.iterdir()" in src, "enforce must scan ROOT.iterdir() root files"


def scan(dir_roots: list[str], include_root_files: bool, suffixes: set[str]) -> list[str]:
    banned: list[str] = []
    paths: list[Path] = []
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


# Theater-kill: old dir-only roots (no root iterdir) must miss the plant.
miss = scan(["scripts", "devtools", "configs", "media", "docs"], False, suffix_set)
assert not any(str(plant.relative_to(root)) in b for b in miss), (
    "sanity: dir-only roots unexpectedly caught root plant: " + repr(miss)
)

# Fixed roots+iterdir must catch CERTIFIED=1 in the planted root .md.
hit = scan(["scripts", "devtools", "configs", "media", "docs"], True, suffix_set)
plant_hits = [b for b in hit if str(plant.relative_to(root)) in b]
assert plant_hits, (
    "policy scan with dir roots + ROOT.iterdir() and .md must catch CERTIFIED=1 "
    f"in planted root file; banned={hit!r}"
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
    if path.is_file() and path.suffix in suffix_set:
        paths.append(path)
for path in paths:
    text = path.read_text(encoding="utf-8", errors="replace")
    rel = str(path.relative_to(root))
    if ("ALLOW_UNPROVEN" + "=1") in text or ("ALLOW_UNPROVEN" + " = 1") in text:
        banned.append(rel)
    if ("CERTIFIED" + "=1") in text or ("certified" + " = true") in text.lower():
        banned.append(rel)
assert not banned, f"live scripts+devtools+configs+media+docs+root still have policy violations after plant cleanup: {banned}"
readme = root / "README.md"
assert readme.is_file()
assert readme.suffix in suffix_set, suffix_set
assert "ROOT.iterdir()" in src
print("live scan clean; README.md covered by ROOT.iterdir()+.md")
PY

echo "PASS complete-e2e-policy-scan-covers-root-md: scripts+devtools+configs+media+docs+root and .md in enforce+release-ready policy scan; CERTIFIED=1 plant fail-closed (no root README blind spot)"
