#!/usr/bin/env bash
# Fail-closed gate: enforce/release-ready policy scan must cover media/**/*.svg.
# Blind spot theater: CERTIFIED=1 / ALLOW_UNPROVEN=1 under media/*.svg previously
# greenwashed "no ... enables in scripts+devtools+configs+media" PASS because
# suffix set omitted .svg while verify requires media/ and consumer requires
# shipping product icon media/icon.svg.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENFORCE_PY="$ROOT/scripts/enforce/run.py"
RELEASE_PY="$ROOT/scripts/release-ready/run.py"
SVG_EXISTING="$ROOT/media/icon.svg"
[[ -f "$ENFORCE_PY" ]] || { echo "FAIL policy-scan-svg: missing enforce/run.py" >&2; exit 1; }
[[ -f "$RELEASE_PY" ]] || { echo "FAIL policy-scan-svg: missing release-ready/run.py" >&2; exit 1; }
[[ -f "$SVG_EXISTING" ]] || { echo "FAIL policy-scan-svg: missing media/icon.svg (scan target)" >&2; exit 1; }
[[ -d "$ROOT/media" ]] || { echo "FAIL policy-scan-svg: missing media/ (verify requires it)" >&2; exit 1; }

# Source must include .svg in the policy suffix set (both floors).
grep -qE 'suffix not in \{[^}]*"\.svg"' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-svg: enforce suffix set does not list .svg" >&2; exit 1; }
grep -qE 'suffix not in \{[^}]*"\.svg"' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-svg: release-ready suffix set does not list .svg" >&2; exit 1; }
grep -qE 'policy_roots\s*=\s*\[.*media' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-svg: enforce policy_roots missing media" >&2; exit 1; }
grep -qE 'policy_roots\s*=\s*\[.*media' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-svg: release-ready policy_roots missing media" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-policy-scan-svg-XXXXXX")"
trap 'rm -rf "$tmp"; rm -f "$ROOT/media/.policy-scan-plant-certified.svg"' EXIT

PLANT="$ROOT/media/.policy-scan-plant-certified.svg"
# Needle matches enforce/release-ready policy scan (CERTIFIED + "=1").
printf '%s\n' '<!-- plant for policy-scan regression — CERTIFIED=1 -->' >"$PLANT"

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
assert ".svg" in suffix_set, suffix_set
assert "policy_roots" in src and "media" in src, "enforce must scan policy_roots including media"


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


# Theater-kill: media root without .svg suffix must miss the plant.
old_suffixes = {".py", ".sh", ".md", ".yml", ".yaml", ".ts", ".json", ".js", ".html"}
miss_suffix = scan(["scripts", "devtools", "configs", "media"], old_suffixes)
assert not any(str(plant.relative_to(root)) in b for b in miss_suffix), (
    "sanity: media root without .svg unexpectedly caught plant: " + repr(miss_suffix)
)

# Fixed roots+suffix must catch CERTIFIED=1 in the planted .svg.
hit = scan(["scripts", "devtools", "configs", "media"], suffix_set)
plant_hits = [b for b in hit if str(plant.relative_to(root)) in b]
assert plant_hits, (
    "policy scan with scripts+devtools+configs+media and .svg must catch CERTIFIED=1 "
    f"in planted media svg; banned={hit!r}"
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
for root_name in ("scripts", "devtools", "configs", "media"):
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
assert not banned, f"live scripts+devtools+configs+media still have policy violations after plant cleanup: {banned}"
# Existing required product svg must be inside a scanned root with .svg suffix.
svg = root / "media/icon.svg"
assert svg.is_file()
assert svg.suffix in suffix_set, suffix_set
assert "media" in src
print("live scan clean; media/icon.svg covered by policy_roots+.svg")
PY

echo "PASS complete-e2e-policy-scan-covers-svg: scripts+devtools+configs+media and .svg in enforce+release-ready policy scan; CERTIFIED=1 plant fail-closed (no media/*.svg blind spot)"
