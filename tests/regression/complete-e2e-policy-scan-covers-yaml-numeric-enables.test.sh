#!/usr/bin/env bash
# Fail-closed gate: enforce/release-ready policy scan must catch YAML-style
# CERTIFIED: 1 / ALLOW_UNPROVEN: 1 enables under configs/*.yml|*.yaml.
# Blind spot theater: CERTIFIED: 1 previously greenwashed
# "no ... enables in scripts+devtools+configs+media" PASS because needles only
# matched YAML CERTIFIED: true / JSON-quoted "CERTIFIED": 1 while unquoted-key
# YAML numeric ": 1" stayed invisible under .yml/.yaml already in the suffix set.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENFORCE_PY="$ROOT/scripts/enforce/run.py"
RELEASE_PY="$ROOT/scripts/release-ready/run.py"
[[ -f "$ENFORCE_PY" ]] || { echo "FAIL policy-scan-yaml-numeric: missing enforce/run.py" >&2; exit 1; }
[[ -f "$RELEASE_PY" ]] || { echo "FAIL policy-scan-yaml-numeric: missing release-ready/run.py" >&2; exit 1; }

# Source must build YAML unquoted-key : 1 needles (concatenated — never contiguous banned literals).
grep -qF 'cert_yn' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-yaml-numeric: enforce missing cert_yn" >&2; exit 1; }
grep -qF 'cert_yn' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-yaml-numeric: release-ready missing cert_yn" >&2; exit 1; }
grep -qF 'allow_yn' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-yaml-numeric: enforce missing allow_yn" >&2; exit 1; }
grep -qF 'allow_yn' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-yaml-numeric: release-ready missing allow_yn" >&2; exit 1; }
grep -qF '+ ": 1"' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-yaml-numeric: enforce missing YAML : 1 needle concat" >&2; exit 1; }
grep -qF '+ ": 1"' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-yaml-numeric: release-ready missing YAML : 1 needle concat" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-policy-scan-yaml-numeric-XXXXXX")"
trap 'rm -rf "$tmp"; rm -f "$ROOT/configs/complete-e2e/.policy-scan-plant-certified-yaml-numeric.yml"' EXIT

PLANT="$ROOT/configs/complete-e2e/.policy-scan-plant-certified-yaml-numeric.yml"
# YAML unquoted-key numeric enable shape (not YAML CERTIFIED: true / not JSON "CERTIFIED": 1).
printf '%s\n' '# plant: policy-scan yaml-numeric regression' 'CERTIFIED: 1' >"$PLANT"

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
assert ".yml" in suffix_set and ".yaml" in suffix_set, suffix_set
assert "policy_roots" in src and "configs" in src, "enforce must scan policy_roots including configs"
assert "cert_yn" in src and '+ ": 1"' in src, "enforce must build cert_yn YAML : 1 needle"
assert "allow_yn" in src and "ALLOW_UNPROVEN" in src, "enforce must build allow_yn YAML needle"


def scan(roots: list[str], suffixes: set[str], *, yaml_colon_one: bool) -> list[str]:
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
            allow_t = "ALLOW_UNPROVEN" + "=true"
            allow_ts = "ALLOW_UNPROVEN" + " = true"
            allow_j = '"ALLOW_UNPROVEN"' + ": true"
            allow_jn = '"ALLOW_UNPROVEN"' + ": 1"
            allow_jm = '"ALLOW_UNPROVEN"' + ":true"
            allow_jnm = '"ALLOW_UNPROVEN"' + ":1"
            allow_y = "ALLOW_UNPROVEN" + ": true"
            allow_yn = "ALLOW_UNPROVEN" + ": 1"
            if (
                allow_a in text
                or allow_b in text
                or allow_t in text
                or allow_ts in text
                or allow_j in text
                or allow_jn in text
                or allow_jm in text
                or allow_jnm in text
                or allow_y in text
                or (yaml_colon_one and allow_yn in text)
            ):
                banned.append(rel + ": " + allow_a)
            cert_a = "CERTIFIED" + "=1"
            cert_as = "certified" + " = 1"
            cert_b = "certified" + " = true"
            cert_t = "certified" + "=true"
            cert_j = '"CERTIFIED"' + ": true"
            cert_jl = '"certified"' + ": true"
            cert_jn = '"CERTIFIED"' + ": 1"
            cert_jnl = '"certified"' + ": 1"
            cert_jm = '"CERTIFIED"' + ":true"
            cert_jml = '"certified"' + ":true"
            cert_jnm = '"CERTIFIED"' + ":1"
            cert_jnml = '"certified"' + ":1"
            cert_y = "certified" + ": true"
            cert_yn = "certified" + ": 1"
            if cert_a in text or cert_as in text.lower() or cert_b in text.lower() or cert_t in text.lower():
                banned.append(rel + ": fake CERTIFIED enable")
            elif cert_j in text or cert_jl in text.lower():
                banned.append(rel + ": fake CERTIFIED enable")
            elif cert_jn in text or cert_jnl in text.lower():
                banned.append(rel + ": fake CERTIFIED enable")
            elif cert_jm in text or cert_jml in text.lower() or cert_jnm in text or cert_jnml in text.lower():
                banned.append(rel + ": fake CERTIFIED enable")
            elif cert_y in text.lower():
                banned.append(rel + ": fake CERTIFIED enable")
            elif yaml_colon_one and cert_yn in text.lower():
                banned.append(rel + ": fake CERTIFIED enable")
    return banned


# Theater-kill: pre-YAML-numeric needles must miss the CERTIFIED: 1 plant.
# Note: JSON-quoted "CERTIFIED": 1 needles do not match unquoted YAML CERTIFIED: 1.
miss = scan(["scripts", "devtools", "configs", "media"], suffix_set, yaml_colon_one=False)
assert not any(str(plant.relative_to(root)) in b for b in miss), (
    "sanity: pre-YAML-numeric needles unexpectedly caught CERTIFIED: 1 plant: " + repr(miss)
)

# Fixed needles must catch CERTIFIED: 1 in the planted configs/*.yml.
hit = scan(["scripts", "devtools", "configs", "media"], suffix_set, yaml_colon_one=True)
plant_hits = [b for b in hit if str(plant.relative_to(root)) in b]
assert plant_hits, (
    "policy scan with YAML CERTIFIED: 1 needles must catch CERTIFIED: 1 "
    f"in planted configs yml; banned={hit!r}"
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
        if ("ALLOW_UNPROVEN" + "=true") in text or ("ALLOW_UNPROVEN" + " = true") in text:
            banned.append(rel)
        if ('"ALLOW_UNPROVEN"' + ": true") in text or ('"ALLOW_UNPROVEN"' + ": 1") in text:
            banned.append(rel)
        if ('"ALLOW_UNPROVEN"' + ":true") in text or ('"ALLOW_UNPROVEN"' + ":1") in text:
            banned.append(rel)
        if ("ALLOW_UNPROVEN" + ": true") in text or ("ALLOW_UNPROVEN" + ": 1") in text:
            banned.append(rel)
        if ("CERTIFIED" + "=1") in text or ("certified" + " = 1") in text.lower():
            banned.append(rel)
        if ("certified" + " = true") in text.lower() or ("certified" + "=true") in text.lower():
            banned.append(rel)
        if ('"CERTIFIED"' + ": true") in text or ('"certified"' + ": true") in text.lower():
            banned.append(rel)
        if ('"CERTIFIED"' + ": 1") in text or ('"certified"' + ": 1") in text.lower():
            banned.append(rel)
        if ('"CERTIFIED"' + ":true") in text or ('"certified"' + ":true") in text.lower():
            banned.append(rel)
        if ('"CERTIFIED"' + ":1") in text or ('"certified"' + ":1") in text.lower():
            banned.append(rel)
        if ("certified" + ": true") in text.lower() or ("certified" + ": 1") in text.lower():
            banned.append(rel)
assert not banned, f"live scripts+devtools+configs+media still have policy violations after plant cleanup: {banned}"
print("live scan clean; configs YAML-numeric CERTIFIED/ALLOW_UNPROVEN enables covered")

PY

echo "PASS complete-e2e-policy-scan-covers-yaml-numeric-enables: YAML CERTIFIED/ALLOW_UNPROVEN: 1 enables fail-closed in enforce+release-ready policy scan (no configs/*.yml|:1-shape blind spot)"
