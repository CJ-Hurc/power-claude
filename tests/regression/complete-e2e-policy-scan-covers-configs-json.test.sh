#!/usr/bin/env bash
# Fail-closed gate: enforce/release-ready policy scan must cover configs/**/*.json.
# Blind spot theater: CERTIFIED=1 / ALLOW_UNPROVEN=1 under configs/*.json previously
# greenwashed "no ... enables in scripts+devtools" PASS because scan roots omitted
# configs/ and suffix set omitted .json while required proof input
# configs/complete-e2e/runtime.json lives there.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENFORCE_PY="$ROOT/scripts/enforce/run.py"
RELEASE_PY="$ROOT/scripts/release-ready/run.py"
RUNTIME_EXISTING="$ROOT/configs/complete-e2e/runtime.json"
[[ -f "$ENFORCE_PY" ]] || { echo "FAIL policy-scan-configs-json: missing enforce/run.py" >&2; exit 1; }
[[ -f "$RELEASE_PY" ]] || { echo "FAIL policy-scan-configs-json: missing release-ready/run.py" >&2; exit 1; }
[[ -f "$RUNTIME_EXISTING" ]] || { echo "FAIL policy-scan-configs-json: missing runtime.json (scan target)" >&2; exit 1; }

# Source must include configs root + .json suffix (both floors).
grep -q 'configs' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-configs-json: enforce/run.py missing configs policy root" >&2; exit 1; }
grep -q 'configs' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-configs-json: release-ready/run.py missing configs policy root" >&2; exit 1; }
grep -qE 'policy_roots\s*=\s*\[.*configs' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-configs-json: enforce policy_roots missing configs" >&2; exit 1; }
grep -qE 'policy_roots\s*=\s*\[.*configs' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-configs-json: release-ready policy_roots missing configs" >&2; exit 1; }
grep -qE 'suffix not in \{[^}]*"\.json"' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-configs-json: enforce suffix set does not list .json" >&2; exit 1; }
grep -qE 'suffix not in \{[^}]*"\.json"' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-configs-json: release-ready suffix set does not list .json" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-policy-scan-configs-json-XXXXXX")"
trap 'rm -rf "$tmp"; rm -f "$ROOT/configs/complete-e2e/.policy-scan-plant-certified.json"' EXIT

PLANT="$ROOT/configs/complete-e2e/.policy-scan-plant-certified.json"
# Needle matches enforce/release-ready policy scan (CERTIFIED + "=1").
printf '%s\n' '{"_plant":"policy-scan regression — CERTIFIED=1"}' >"$PLANT"

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
assert ".json" in suffix_set, suffix_set
assert "policy_roots" in src and "configs" in src, "enforce must scan policy_roots including configs"


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


# Theater-kill: old scripts+devtools roots (no configs) must miss the plant.
old_suffixes = {".py", ".sh", ".md", ".yml", ".yaml", ".ts"}
miss_roots = scan(["scripts", "devtools"], suffix_set)
assert not any(str(plant.relative_to(root)) in b for b in miss_roots), (
    "sanity: scripts+devtools roots unexpectedly caught configs plant: " + repr(miss_roots)
)

# Theater-kill: configs root without .json suffix must miss the plant.
miss_suffix = scan(["scripts", "devtools", "configs"], old_suffixes)
assert not any(str(plant.relative_to(root)) in b for b in miss_suffix), (
    "sanity: configs root without .json unexpectedly caught plant: " + repr(miss_suffix)
)

# Fixed roots+suffix must catch CERTIFIED=1 in the planted .json.
hit = scan(["scripts", "devtools", "configs"], suffix_set)
plant_hits = [b for b in hit if str(plant.relative_to(root)) in b]
assert plant_hits, (
    "policy scan with scripts+devtools+configs and .json must catch CERTIFIED=1 "
    f"in planted configs file; banned={hit!r}"
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
for root_name in ("scripts", "devtools", "configs"):
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
assert not banned, f"live scripts+devtools+configs still have policy violations after plant cleanup: {banned}"
# Existing required runtime.json must be inside a scanned root with .json suffix.
rt = root / "configs/complete-e2e/runtime.json"
assert rt.is_file()
assert rt.suffix in suffix_set, suffix_set
assert "configs" in src
print("live scan clean; configs/complete-e2e/runtime.json covered by policy_roots+.json")
PY

echo "PASS complete-e2e-policy-scan-covers-configs-json: scripts+devtools+configs and .json in enforce+release-ready policy scan; CERTIFIED=1 plant fail-closed (no configs/ blind spot)"
