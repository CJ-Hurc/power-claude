#!/usr/bin/env bash
# Fail-closed gate: enforce/release-ready policy scan must cover media/**/*.{js,html,md}.
# Blind spot theater: CERTIFIED=1 / ALLOW_UNPROVEN=1 under media/loaders/*.js previously
# greenwashed "no ... enables in scripts+devtools+configs" PASS because scan roots omitted
# media/ and suffix set omitted .js/.html while verify requires media/ and shipping
# product loaders (power-claude-loaders.js, gallery.html) live there.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENFORCE_PY="$ROOT/scripts/enforce/run.py"
RELEASE_PY="$ROOT/scripts/release-ready/run.py"
LOADERS_EXISTING="$ROOT/media/loaders/power-claude-loaders.js"
[[ -f "$ENFORCE_PY" ]] || { echo "FAIL policy-scan-media: missing enforce/run.py" >&2; exit 1; }
[[ -f "$RELEASE_PY" ]] || { echo "FAIL policy-scan-media: missing release-ready/run.py" >&2; exit 1; }
[[ -f "$LOADERS_EXISTING" ]] || { echo "FAIL policy-scan-media: missing power-claude-loaders.js (scan target)" >&2; exit 1; }
[[ -d "$ROOT/media" ]] || { echo "FAIL policy-scan-media: missing media/ (verify requires it)" >&2; exit 1; }

# Source must include media root + .js/.html suffixes (both floors).
grep -q 'media' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-media: enforce/run.py missing media policy root" >&2; exit 1; }
grep -q 'media' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-media: release-ready/run.py missing media policy root" >&2; exit 1; }
grep -qE 'policy_roots\s*=\s*\[.*media' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-media: enforce policy_roots missing media" >&2; exit 1; }
grep -qE 'policy_roots\s*=\s*\[.*media' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-media: release-ready policy_roots missing media" >&2; exit 1; }
grep -qE 'suffix not in \{[^}]*"\.js"' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-media: enforce suffix set does not list .js" >&2; exit 1; }
grep -qE 'suffix not in \{[^}]*"\.js"' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-media: release-ready suffix set does not list .js" >&2; exit 1; }
grep -qE 'suffix not in \{[^}]*"\.html"' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-media: enforce suffix set does not list .html" >&2; exit 1; }
grep -qE 'suffix not in \{[^}]*"\.html"' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-media: release-ready suffix set does not list .html" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-policy-scan-media-XXXXXX")"
trap 'rm -rf "$tmp"; rm -f "$ROOT/media/loaders/.policy-scan-plant-certified.js"' EXIT

PLANT="$ROOT/media/loaders/.policy-scan-plant-certified.js"
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
suffix_set = eval("{" + m.group(1) + "}", {"__builtins__": {}})
assert ".js" in suffix_set, suffix_set
assert ".html" in suffix_set, suffix_set
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


# Theater-kill: old scripts+devtools+configs roots (no media) must miss the plant.
miss_roots = scan(["scripts", "devtools", "configs"], suffix_set)
assert not any(str(plant.relative_to(root)) in b for b in miss_roots), (
    "sanity: scripts+devtools+configs roots unexpectedly caught media plant: "
    + repr(miss_roots)
)

# Theater-kill: media root without .js/.html suffix must miss the plant.
old_suffixes = {".py", ".sh", ".md", ".yml", ".yaml", ".ts", ".json"}
miss_suffix = scan(["scripts", "devtools", "configs", "media"], old_suffixes)
assert not any(str(plant.relative_to(root)) in b for b in miss_suffix), (
    "sanity: media root without .js unexpectedly caught plant: " + repr(miss_suffix)
)

# Fixed roots+suffix must catch CERTIFIED=1 in the planted .js.
hit = scan(["scripts", "devtools", "configs", "media"], suffix_set)
plant_hits = [b for b in hit if str(plant.relative_to(root)) in b]
assert plant_hits, (
    "policy scan with scripts+devtools+configs+media and .js must catch CERTIFIED=1 "
    f"in planted media file; banned={hit!r}"
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
# Existing required product loader must be inside a scanned root with .js suffix.
js = root / "media/loaders/power-claude-loaders.js"
assert js.is_file()
assert js.suffix in suffix_set, suffix_set
assert "media" in src
print("live scan clean; media/loaders/power-claude-loaders.js covered by policy_roots+.js")
PY

echo "PASS complete-e2e-policy-scan-covers-media: scripts+devtools+configs+media and .js/.html in enforce+release-ready policy scan; CERTIFIED=1 plant fail-closed (no media/ blind spot)"
