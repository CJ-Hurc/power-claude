#!/usr/bin/env bash
# Fail-closed gate: enforce/release-ready policy scan must catch JSON-object
# CERTIFIED / ALLOW_UNPROVEN enables under configs/*.json.
# Blind spot theater: {"CERTIFIED": true} / {"ALLOW_UNPROVEN": true} previously
# greenwashed "no ... enables in scripts+devtools+configs+media" PASS because
# needles only matched shell-style CERTIFIED=1 / ALLOW_UNPROVEN=1 (and
# "certified = true") while required proof input configs/complete-e2e/runtime.json
# is JSON — object-shaped enables stayed invisible.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENFORCE_PY="$ROOT/scripts/enforce/run.py"
RELEASE_PY="$ROOT/scripts/release-ready/run.py"
RUNTIME_EXISTING="$ROOT/configs/complete-e2e/runtime.json"
[[ -f "$ENFORCE_PY" ]] || { echo "FAIL policy-scan-json-object: missing enforce/run.py" >&2; exit 1; }
[[ -f "$RELEASE_PY" ]] || { echo "FAIL policy-scan-json-object: missing release-ready/run.py" >&2; exit 1; }
[[ -f "$RUNTIME_EXISTING" ]] || { echo "FAIL policy-scan-json-object: missing runtime.json (scan target)" >&2; exit 1; }

# Source must build JSON-object needles (concatenated — never contiguous banned literals).
grep -qE '"CERTIFIED".*: true' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-json-object: enforce missing JSON CERTIFIED needle construction" >&2; exit 1; }
grep -qE '"CERTIFIED".*: true' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-json-object: release-ready missing JSON CERTIFIED needle construction" >&2; exit 1; }
grep -qE '"ALLOW_UNPROVEN".*: true' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-json-object: enforce missing JSON ALLOW_UNPROVEN needle construction" >&2; exit 1; }
grep -qE '"ALLOW_UNPROVEN".*: true' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-json-object: release-ready missing JSON ALLOW_UNPROVEN needle construction" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-policy-scan-json-object-XXXXXX")"
trap 'rm -rf "$tmp"; rm -f "$ROOT/configs/complete-e2e/.policy-scan-plant-certified-object.json"' EXIT

PLANT="$ROOT/configs/complete-e2e/.policy-scan-plant-certified-object.json"
# JSON-object enable shape (not shell CERTIFIED=1).
printf '%s\n' '{"CERTIFIED": true, "_plant": "policy-scan json-object regression"}' >"$PLANT"

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
# Fixed floors must construct JSON-object needles (concat form).
assert '"CERTIFIED"' in src and ": true" in src, "enforce must build JSON CERTIFIED needle"
assert '"ALLOW_UNPROVEN"' in src and ": true" in src, "enforce must build JSON ALLOW_UNPROVEN needle"


def scan(roots: list[str], suffixes: set[str], *, json_object: bool) -> list[str]:
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
            if allow_a in text or allow_b in text or (json_object and allow_j in text):
                banned.append(rel + ": " + allow_a)
            cert_a = "CERTIFIED" + "=1"
            cert_b = "certified" + " = true"
            cert_j = '"CERTIFIED"' + ": true"
            cert_jl = '"certified"' + ": true"
            if cert_a in text or cert_b in text.lower():
                banned.append(rel + ": fake CERTIFIED enable")
            elif json_object and (cert_j in text or cert_jl in text.lower()):
                banned.append(rel + ": fake CERTIFIED enable")
    return banned


# Theater-kill: old shell-style-only needles must miss the JSON-object plant.
miss = scan(["scripts", "devtools", "configs", "media"], suffix_set, json_object=False)
assert not any(str(plant.relative_to(root)) in b for b in miss), (
    "sanity: shell-style-only needles unexpectedly caught JSON-object plant: " + repr(miss)
)

# Fixed needles must catch {"CERTIFIED": true} in the planted configs JSON.
hit = scan(["scripts", "devtools", "configs", "media"], suffix_set, json_object=True)
plant_hits = [b for b in hit if str(plant.relative_to(root)) in b]
assert plant_hits, (
    "policy scan with JSON-object needles must catch {\"CERTIFIED\": true} "
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
        if ('"ALLOW_UNPROVEN"' + ": true") in text:
            banned.append(rel)
        if ("CERTIFIED" + "=1") in text or ("certified" + " = true") in text.lower():
            banned.append(rel)
        if ('"CERTIFIED"' + ": true") in text or ('"certified"' + ": true") in text.lower():
            banned.append(rel)
assert not banned, f"live scripts+devtools+configs+media still have policy violations after plant cleanup: {banned}"
rt = root / "configs/complete-e2e/runtime.json"
assert rt.is_file()
assert rt.suffix in suffix_set, suffix_set
print("live scan clean; configs JSON-object CERTIFIED/ALLOW_UNPROVEN enables covered")
PY

echo "PASS complete-e2e-policy-scan-covers-json-object-enables: JSON-object CERTIFIED/ALLOW_UNPROVEN enables fail-closed in enforce+release-ready policy scan (no configs/*.json object-shape blind spot)"
