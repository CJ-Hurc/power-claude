#!/usr/bin/env bash
# Fail-closed gate: enforce/release-ready policy scan must catch JSON-minified
# CERTIFIED / ALLOW_UNPROVEN enables under configs/*.json.
# Blind spot theater: {"CERTIFIED":1} / {"CERTIFIED":true} (no space after colon —
# JSON.stringify / separators=(',',':') form) previously greenwashed
# "no ... enables in scripts+devtools+configs+media" PASS because spaced needles
# only matched ": true" / ": 1" while minified enables stayed invisible in
# required proof input configs/.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENFORCE_PY="$ROOT/scripts/enforce/run.py"
RELEASE_PY="$ROOT/scripts/release-ready/run.py"
RUNTIME_EXISTING="$ROOT/configs/complete-e2e/runtime.json"
[[ -f "$ENFORCE_PY" ]] || { echo "FAIL policy-scan-json-minified: missing enforce/run.py" >&2; exit 1; }
[[ -f "$RELEASE_PY" ]] || { echo "FAIL policy-scan-json-minified: missing release-ready/run.py" >&2; exit 1; }
[[ -f "$RUNTIME_EXISTING" ]] || { echo "FAIL policy-scan-json-minified: missing runtime.json (scan target)" >&2; exit 1; }

# Source must build JSON-minified needles (concatenated — never contiguous banned literals).
# Require minified concat operands '+ ":true"' / '+ ":1"' (spaced ": true"/": 1" alone is insufficient).
grep -qF '+ ":true"' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-json-minified: enforce missing JSON minified :true needle concat" >&2; exit 1; }
grep -qF '+ ":1"' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-json-minified: enforce missing JSON minified :1 needle concat" >&2; exit 1; }
grep -qF '"ALLOW_UNPROVEN"' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-json-minified: enforce missing ALLOW_UNPROVEN JSON needle key" >&2; exit 1; }
grep -qF '"CERTIFIED"' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-json-minified: enforce missing CERTIFIED JSON needle key" >&2; exit 1; }
grep -qF '+ ":true"' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-json-minified: release-ready missing JSON minified :true needle concat" >&2; exit 1; }
grep -qF '+ ":1"' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-json-minified: release-ready missing JSON minified :1 needle concat" >&2; exit 1; }
grep -qF '"ALLOW_UNPROVEN"' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-json-minified: release-ready missing ALLOW_UNPROVEN JSON needle key" >&2; exit 1; }
grep -qF '"CERTIFIED"' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-json-minified: release-ready missing CERTIFIED JSON needle key" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-policy-scan-json-minified-XXXXXX")"
trap 'rm -rf "$tmp"; rm -f "$ROOT/configs/complete-e2e/.policy-scan-plant-certified-minified.json"' EXIT

PLANT="$ROOT/configs/complete-e2e/.policy-scan-plant-certified-minified.json"
# JSON-minified enable shape (no space after colon — not spaced ": 1"/": true").
printf '%s\n' '{"CERTIFIED":1,"_plant":"policy-scan json-minified regression"}' >"$PLANT"

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
# Fixed floors must construct JSON-minified needles (concat form).
assert '"CERTIFIED"' in src and ":true" in src and ":1" in src, (
    "enforce must build JSON minified CERTIFIED needles"
)
assert '"ALLOW_UNPROVEN"' in src, "enforce must build JSON minified ALLOW_UNPROVEN needles"
# Minified fragments must appear as concat operands (not only spaced forms).
assert '":true"' in src and '":1"' in src, "enforce must contain minified ':true'/':1' string literals"


def scan(roots: list[str], suffixes: set[str], *, json_minified: bool) -> list[str]:
    banned: list[str] = []
    for root_name in roots:
        base = root / root_name
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*")):
            if not path.is_file() or path.suffix not in suffixes:
                continue
            text = path.read_text(encoding="utf-8", errors="replace")
            rel = str(path.relative_to(root))
            allow_a = "ALLOW_UNPROVEN" + "=1"
            allow_b = "ALLOW_UNPROVEN" + " = 1"
            allow_j = '"ALLOW_UNPROVEN"' + ": true"
            allow_jn = '"ALLOW_UNPROVEN"' + ": 1"
            allow_jm = '"ALLOW_UNPROVEN"' + ":true"
            allow_jnm = '"ALLOW_UNPROVEN"' + ":1"
            if allow_a in text or allow_b in text or allow_j in text or allow_jn in text:
                banned.append(rel + ": " + allow_a)
            elif json_minified and (allow_jm in text or allow_jnm in text):
                banned.append(rel + ": " + allow_a)
            cert_a = "CERTIFIED" + "=1"
            cert_b = "certified" + " = true"
            cert_j = '"CERTIFIED"' + ": true"
            cert_jl = '"certified"' + ": true"
            cert_jn = '"CERTIFIED"' + ": 1"
            cert_jnl = '"certified"' + ": 1"
            cert_jm = '"CERTIFIED"' + ":true"
            cert_jml = '"certified"' + ":true"
            cert_jnm = '"CERTIFIED"' + ":1"
            cert_jnml = '"certified"' + ":1"
            if cert_a in text or cert_b in text.lower():
                banned.append(rel + ": fake CERTIFIED enable")
            elif cert_j in text or cert_jl in text.lower():
                banned.append(rel + ": fake CERTIFIED enable")
            elif cert_jn in text or cert_jnl in text.lower():
                banned.append(rel + ": fake CERTIFIED enable")
            elif json_minified and (
                cert_jm in text
                or cert_jml in text.lower()
                or cert_jnm in text
                or cert_jnml in text.lower()
            ):
                banned.append(rel + ": fake CERTIFIED enable")
    return banned


# Theater-kill: spaced-only needles must miss the JSON-minified plant.
miss = scan(["scripts", "devtools", "configs", "media"], suffix_set, json_minified=False)
assert not any(str(plant.relative_to(root)) in b for b in miss), (
    "sanity: spaced needles unexpectedly caught JSON-minified plant: " + repr(miss)
)

# Fixed needles must catch {"CERTIFIED":1} in the planted configs JSON.
hit = scan(["scripts", "devtools", "configs", "media"], suffix_set, json_minified=True)
plant_hits = [b for b in hit if str(plant.relative_to(root)) in b]
assert plant_hits, (
    "policy scan with JSON-minified needles must catch {\"CERTIFIED\":1} "
    f"in planted configs json; banned={hit!r}"
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
        if ('"ALLOW_UNPROVEN"' + ": true") in text or ('"ALLOW_UNPROVEN"' + ": 1") in text:
            banned.append(rel)
        if ('"ALLOW_UNPROVEN"' + ":true") in text or ('"ALLOW_UNPROVEN"' + ":1") in text:
            banned.append(rel)
        if ("CERTIFIED" + "=1") in text or ("certified" + " = true") in text.lower():
            banned.append(rel)
        if ('"CERTIFIED"' + ": true") in text or ('"certified"' + ": true") in text.lower():
            banned.append(rel)
        if ('"CERTIFIED"' + ": 1") in text or ('"certified"' + ": 1") in text.lower():
            banned.append(rel)
        if ('"CERTIFIED"' + ":true") in text or ('"certified"' + ":true") in text.lower():
            banned.append(rel)
        if ('"CERTIFIED"' + ":1") in text or ('"certified"' + ":1") in text.lower():
            banned.append(rel)
assert not banned, f"live scripts+devtools+configs+media still have policy violations after plant cleanup: {banned}"
rt = root / "configs/complete-e2e/runtime.json"
assert rt.is_file()
assert rt.suffix in suffix_set, suffix_set
print("live scan clean; configs JSON-minified CERTIFIED/ALLOW_UNPROVEN enables covered")
PY

echo "PASS complete-e2e-policy-scan-covers-json-minified-enables: JSON-minified CERTIFIED/ALLOW_UNPROVEN enables fail-closed in enforce+release-ready policy scan (no configs/*.json minified-shape blind spot)"
