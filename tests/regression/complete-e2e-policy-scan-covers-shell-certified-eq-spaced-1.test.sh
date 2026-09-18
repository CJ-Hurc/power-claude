#!/usr/bin/env bash
# Fail-closed gate: enforce/release-ready policy scan must catch shell-style
# CERTIFIED = 1 (spaced) enables under scripts/*.sh (and peers).
# Blind spot theater: CERTIFIED = 1 previously greenwashed
# "no ... enables in scripts+devtools+configs+media" PASS because needles only
# matched CERTIFIED=1 (no spaces) / "certified = true" while ALLOW_UNPROVEN
# already had allow_b (" = 1") — asymmetric CERTIFIED spaced-=1 stayed invisible
# in required product scripts/.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENFORCE_PY="$ROOT/scripts/enforce/run.py"
RELEASE_PY="$ROOT/scripts/release-ready/run.py"
[[ -f "$ENFORCE_PY" ]] || { echo "FAIL policy-scan-shell-certified-eq-spaced-1: missing enforce/run.py" >&2; exit 1; }
[[ -f "$RELEASE_PY" ]] || { echo "FAIL policy-scan-shell-certified-eq-spaced-1: missing release-ready/run.py" >&2; exit 1; }

# Source must build shell spaced = 1 CERTIFIED needle (concatenated — never contiguous banned literals).
grep -qF '+ " = 1"' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-shell-certified-eq-spaced-1: enforce missing CERTIFIED spaced = 1 needle concat" >&2; exit 1; }
grep -qF '+ " = 1"' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-shell-certified-eq-spaced-1: release-ready missing CERTIFIED spaced = 1 needle concat" >&2; exit 1; }
grep -qF 'cert_as' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-shell-certified-eq-spaced-1: enforce missing cert_as" >&2; exit 1; }
grep -qF 'cert_as' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-shell-certified-eq-spaced-1: release-ready missing cert_as" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-policy-scan-shell-certified-eq-spaced-1-XXXXXX")"
trap 'rm -rf "$tmp"; rm -f "$ROOT/scripts/complete-e2e/.policy-scan-plant-certified-eq-spaced.sh"' EXIT

PLANT="$ROOT/scripts/complete-e2e/.policy-scan-plant-certified-eq-spaced.sh"
# Shell spaced = 1 enable shape (not CERTIFIED=1 / not "certified = true").
printf '%s\n' '#!/usr/bin/env bash' '# plant: policy-scan shell-certified-eq-spaced-1 regression' 'CERTIFIED = 1' >"$PLANT"

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
assert ".sh" in suffix_set, suffix_set
assert "policy_roots" in src and "scripts" in src, "enforce must scan policy_roots including scripts"
assert "cert_as" in src and '+ " = 1"' in src, "enforce must build cert_as spaced = 1 needle"
assert "ALLOW_UNPROVEN" in src and "certified" in src, "enforce must build ALLOW/CERTIFIED needles"


def scan(roots: list[str], suffixes: set[str], *, shell_eq_spaced_1: bool) -> list[str]:
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
            if (
                allow_a in text
                or allow_b in text
                or allow_t in text
                or allow_ts in text
                or allow_j in text
                or allow_jn in text
                or allow_jm in text
                or allow_jnm in text
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
            if cert_a in text or cert_b in text.lower() or cert_t in text.lower():
                banned.append(rel + ": fake CERTIFIED enable")
            elif cert_j in text or cert_jl in text.lower():
                banned.append(rel + ": fake CERTIFIED enable")
            elif cert_jn in text or cert_jnl in text.lower():
                banned.append(rel + ": fake CERTIFIED enable")
            elif cert_jm in text or cert_jml in text.lower() or cert_jnm in text or cert_jnml in text.lower():
                banned.append(rel + ": fake CERTIFIED enable")
            elif shell_eq_spaced_1 and cert_as in text.lower():
                banned.append(rel + ": fake CERTIFIED enable")
    return banned


# Theater-kill: pre-spaced-=1 needles must miss the CERTIFIED = 1 plant.
miss = scan(["scripts", "devtools", "configs", "media"], suffix_set, shell_eq_spaced_1=False)
assert not any(str(plant.relative_to(root)) in b for b in miss), (
    "sanity: pre-spaced-=1 needles unexpectedly caught CERTIFIED = 1 plant: " + repr(miss)
)

# Fixed needles must catch CERTIFIED = 1 in the planted scripts/*.sh.
hit = scan(["scripts", "devtools", "configs", "media"], suffix_set, shell_eq_spaced_1=True)
plant_hits = [b for b in hit if str(plant.relative_to(root)) in b]
assert plant_hits, (
    "policy scan with shell CERTIFIED spaced = 1 needles must catch CERTIFIED = 1 "
    f"in planted scripts sh; banned={hit!r}"
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
assert not banned, f"live scripts+devtools+configs+media still have policy violations after plant cleanup: {banned}"
print("live scan clean; scripts shell CERTIFIED = 1 enables covered")
PY

echo "PASS complete-e2e-policy-scan-covers-shell-certified-eq-spaced-1: shell CERTIFIED = 1 enables fail-closed in enforce+release-ready policy scan (no scripts/*.sh spaced-=1-shape blind spot)"
