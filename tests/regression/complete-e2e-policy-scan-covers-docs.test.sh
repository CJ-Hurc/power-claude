#!/usr/bin/env bash
# Fail-closed gate: enforce/release-ready policy scan must cover docs/**.
# Blind spot theater: CERTIFIED=1 / ALLOW_UNPROVEN=1 under docs/complete-e2e/*.md
# previously greenwashed "no ... enables in scripts+devtools+configs+media" PASS
# because scan roots omitted docs/ while .md was already in the suffix set and
# operator nightly/hold notes live under docs/complete-e2e/.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENFORCE_PY="$ROOT/scripts/enforce/run.py"
RELEASE_PY="$ROOT/scripts/release-ready/run.py"
DOCS_EXISTING="$ROOT/docs/complete-e2e/OPERATOR-NIGHTLY-2026-09-15.md"
[[ -f "$ENFORCE_PY" ]] || { echo "FAIL policy-scan-docs: missing enforce/run.py" >&2; exit 1; }
[[ -f "$RELEASE_PY" ]] || { echo "FAIL policy-scan-docs: missing release-ready/run.py" >&2; exit 1; }
[[ -f "$DOCS_EXISTING" ]] || { echo "FAIL policy-scan-docs: missing docs/complete-e2e operator note (scan target)" >&2; exit 1; }
[[ -d "$ROOT/docs" ]] || { echo "FAIL policy-scan-docs: missing docs/" >&2; exit 1; }

# Source must include docs root (both floors). .md already in suffix set.
grep -q 'docs' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-docs: enforce/run.py missing docs policy root" >&2; exit 1; }
grep -q 'docs' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-docs: release-ready/run.py missing docs policy root" >&2; exit 1; }
grep -qE 'policy_roots\s*=\s*\[.*docs' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-docs: enforce policy_roots missing docs" >&2; exit 1; }
grep -qE 'policy_roots\s*=\s*\[.*docs' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-docs: release-ready policy_roots missing docs" >&2; exit 1; }
grep -qE 'suffix not in \{[^}]*"\.md"' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-docs: enforce suffix set does not list .md" >&2; exit 1; }
grep -qE 'suffix not in \{[^}]*"\.md"' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-docs: release-ready suffix set does not list .md" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-policy-scan-docs-XXXXXX")"
trap 'rm -rf "$tmp"; rm -f "$ROOT/docs/complete-e2e/.policy-scan-plant-certified.md"' EXIT

PLANT="$ROOT/docs/complete-e2e/.policy-scan-plant-certified.md"
# Needle matches enforce/release-ready policy scan (CERTIFIED + "=1").
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
assert "policy_roots" in src and "docs" in src, "enforce must scan policy_roots including docs"


def scan(roots: list[str], suffixes: set[str]) -> list[str]:
    banned: list[str] = []
    for root_name in roots:
        base = root / root_name
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*")):
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


# Theater-kill: old scripts+devtools+configs+media roots (no docs) must miss the plant.
miss_roots = scan(["scripts", "devtools", "configs", "media"], suffix_set)
assert not any(str(plant.relative_to(root)) in b for b in miss_roots), (
    "sanity: scripts+devtools+configs+media roots unexpectedly caught docs plant: "
    + repr(miss_roots)
)

# Fixed roots must catch CERTIFIED=1 in the planted .md.
hit = scan(["scripts", "devtools", "configs", "media", "docs"], suffix_set)
plant_hits = [b for b in hit if str(plant.relative_to(root)) in b]
assert plant_hits, (
    "policy scan with scripts+devtools+configs+media+docs and .md must catch CERTIFIED=1 "
    f"in planted docs file; banned={hit!r}"
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
for root_name in ("scripts", "devtools", "configs", "media", "docs"):
    base = root / root_name
    if not base.is_dir():
        continue
    for path in sorted(base.rglob("*")):
        if not path.is_file() or path.suffix not in suffix_set:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        rel = str(path.relative_to(root))
        if ("ALLOW_UNPROVEN" + "=1") in text or ("ALLOW_UNPROVEN" + " = 1") in text:
            banned.append(rel)
        if ("CERTIFIED" + "=1") in text or ("certified" + " = true") in text.lower():
            banned.append(rel)
assert not banned, f"live scripts+devtools+configs+media+docs still have policy violations after plant cleanup: {banned}"
# Existing operator note must be inside a scanned root with .md suffix.
md = root / "docs/complete-e2e/OPERATOR-NIGHTLY-2026-09-15.md"
assert md.is_file()
assert md.suffix in suffix_set, suffix_set
assert "docs" in src
print("live scan clean; docs/complete-e2e/OPERATOR-NIGHTLY-2026-09-15.md covered by policy_roots+.md")
PY

echo "PASS complete-e2e-policy-scan-covers-docs: scripts+devtools+configs+media+docs and .md in enforce+release-ready policy scan; CERTIFIED=1 plant fail-closed (no docs/ blind spot)"
