#!/usr/bin/env bash
# Fail-closed gate: enforce/release-ready policy scan must catch YAML-minified
# CERTIFIED:true / ALLOW_UNPROVEN:true enables under configs/*.yml|*.yaml
# (no space after colon — flow-style / compacted YAML).
# Blind spot theater: CERTIFIED:true previously greenwashed
# "no ... enables in scripts+devtools+configs+media" PASS because needles only
# matched spaced YAML CERTIFIED: true / JSON-quoted "CERTIFIED":true while
# unquoted-key minified ":true" stayed invisible under .yml/.yaml already in
# the suffix set.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENFORCE_PY="$ROOT/scripts/enforce/run.py"
RELEASE_PY="$ROOT/scripts/release-ready/run.py"
[[ -f "$ENFORCE_PY" ]] || { echo "FAIL policy-scan-yaml-minified: missing enforce/run.py" >&2; exit 1; }
[[ -f "$RELEASE_PY" ]] || { echo "FAIL policy-scan-yaml-minified: missing release-ready/run.py" >&2; exit 1; }

# Source must build YAML unquoted-key :true needles (concatenated — never contiguous banned literals).
grep -qF 'cert_ym' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-yaml-minified: enforce missing cert_ym" >&2; exit 1; }
grep -qF 'cert_ym' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-yaml-minified: release-ready missing cert_ym" >&2; exit 1; }
grep -qF 'allow_ym' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-yaml-minified: enforce missing allow_ym" >&2; exit 1; }
grep -qF 'allow_ym' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-yaml-minified: release-ready missing allow_ym" >&2; exit 1; }
# Require unquoted-key minified concat operands (JSON quoted-key + ":true" alone is insufficient).
grep -qF 'ALLOW_UNPROVEN" + ":true"' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-yaml-minified: enforce missing ALLOW_UNPROVEN + :true concat" >&2; exit 1; }
grep -qF 'ALLOW_UNPROVEN" + ":true"' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-yaml-minified: release-ready missing ALLOW_UNPROVEN + :true concat" >&2; exit 1; }
# cert_ym must use unquoted certified + ":true" (not JSON quoted-key minified form).
grep -qF 'certified" + ":true"' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-yaml-minified: enforce missing certified + :true concat" >&2; exit 1; }
grep -qF 'certified" + ":true"' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-yaml-minified: release-ready missing certified + :true concat" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-policy-scan-yaml-minified-XXXXXX")"
trap 'rm -rf "$tmp"; rm -f "$ROOT/configs/complete-e2e/.policy-scan-plant-certified-yaml-minified.yml"' EXIT

PLANT="$ROOT/configs/complete-e2e/.policy-scan-plant-certified-yaml-minified.yml"
# YAML unquoted-key minified boolean enable shape (not CERTIFIED: true / not "CERTIFIED":true).
printf '%s\n' '# plant: policy-scan yaml-minified regression' 'CERTIFIED:true' >"$PLANT"

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
assert "cert_ym" in src and 'certified" + ":true"' in src, "enforce must build cert_ym YAML :true needle"
assert "allow_ym" in src and 'ALLOW_UNPROVEN" + ":true"' in src, "enforce must build allow_ym YAML needle"


def scan(roots: list[str], suffixes: set[str], *, yaml_minified_true: bool) -> list[str]:
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
            allow_ym = "ALLOW_UNPROVEN" + ":true"
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
                or allow_yn in text
                or (yaml_minified_true and allow_ym in text)
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
            cert_ym = "certified" + ":true"
            if cert_a in text or cert_as in text.lower() or cert_b in text.lower() or cert_t in text.lower():
                banned.append(rel + ": fake CERTIFIED enable")
            elif cert_j in text or cert_jl in text.lower():
                banned.append(rel + ": fake CERTIFIED enable")
            elif cert_jn in text or cert_jnl in text.lower():
                banned.append(rel + ": fake CERTIFIED enable")
            elif cert_jm in text or cert_jml in text.lower() or cert_jnm in text or cert_jnml in text.lower():
                banned.append(rel + ": fake CERTIFIED enable")
            elif cert_y in text.lower() or cert_yn in text.lower():
                banned.append(rel + ": fake CERTIFIED enable")
            elif yaml_minified_true and cert_ym in text.lower():
                banned.append(rel + ": fake CERTIFIED enable")
    return banned


# Theater-kill: pre-YAML-minified needles must miss the CERTIFIED:true plant.
# Note: JSON-quoted "CERTIFIED":true and spaced CERTIFIED: true do not match.
miss = scan(["scripts", "devtools", "configs", "media"], suffix_set, yaml_minified_true=False)
assert not any(str(plant.relative_to(root)) in b for b in miss), (
    "sanity: pre-YAML-minified needles unexpectedly caught CERTIFIED:true plant: " + repr(miss)
)

# Fixed needles must catch CERTIFIED:true in the planted configs/*.yml.
hit = scan(["scripts", "devtools", "configs", "media"], suffix_set, yaml_minified_true=True)
plant_hits = [b for b in hit if str(plant.relative_to(root)) in b]
assert plant_hits, (
    "policy scan with YAML CERTIFIED:true needles must catch CERTIFIED:true "
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
        if ("ALLOW_UNPROVEN" + ":true") in text:
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
        if ("certified" + ":true") in text.lower():
            banned.append(rel)
assert not banned, f"live scripts+devtools+configs+media still have policy violations after plant cleanup: {banned}"
print("live scan clean; configs YAML-minified CERTIFIED/ALLOW_UNPROVEN enables covered")

PY

echo "PASS complete-e2e-policy-scan-covers-yaml-minified-enables: YAML CERTIFIED/ALLOW_UNPROVEN:true enables fail-closed in enforce+release-ready policy scan (no configs/*.yml|:true-minified-shape blind spot)"
