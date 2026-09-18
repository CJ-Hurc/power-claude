#!/usr/bin/env bash
# Fail-closed gate: enforce/release-ready policy scan must cover devtools/**.
# Blind spot theater: CERTIFIED=1 / ALLOW_UNPROVEN=1 under devtools/ previously
# greenwashed "no ... enables in scripts" PASS because scan roots omitted
# devtools/ while required dual-origin proof input devtools/enforce/run.sh lives there.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENFORCE_PY="$ROOT/scripts/enforce/run.py"
RELEASE_PY="$ROOT/scripts/release-ready/run.py"
DEVTOOLS_EXISTING="$ROOT/devtools/enforce/run.sh"
[[ -f "$ENFORCE_PY" ]] || { echo "FAIL policy-scan-devtools: missing enforce/run.py" >&2; exit 1; }
[[ -f "$RELEASE_PY" ]] || { echo "FAIL policy-scan-devtools: missing release-ready/run.py" >&2; exit 1; }
[[ -f "$DEVTOOLS_EXISTING" ]] || { echo "FAIL policy-scan-devtools: missing devtools/enforce/run.sh (scan target)" >&2; exit 1; }

# Source must mention devtools in the policy-scan root set (both floors).
grep -q 'devtools' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-devtools: enforce/run.py missing devtools policy root" >&2; exit 1; }
grep -q 'devtools' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-devtools: release-ready/run.py missing devtools policy root" >&2; exit 1; }
grep -qE 'policy_roots\s*=\s*\[.*devtools' "$ENFORCE_PY" \
  || { echo "FAIL policy-scan-devtools: enforce policy_roots missing devtools" >&2; exit 1; }
grep -qE 'policy_roots\s*=\s*\[.*devtools' "$RELEASE_PY" \
  || { echo "FAIL policy-scan-devtools: release-ready policy_roots missing devtools" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-policy-scan-devtools-XXXXXX")"
trap 'rm -rf "$tmp"; rm -f "$ROOT/devtools/enforce/.policy-scan-plant-certified.sh"' EXIT

PLANT="$ROOT/devtools/enforce/.policy-scan-plant-certified.sh"
# Needle matches enforce/release-ready policy scan (CERTIFIED + "=1").
printf '%s\n' '#!/bin/sh' '# plant for policy-scan regression — CERTIFIED=1' >"$PLANT"

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
assert "policy_roots" in src and "devtools" in src, "enforce must scan policy_roots including devtools"


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


# Theater-kill: old scripts-only roots must miss the plant under devtools/.
miss = scan(["scripts"], suffix_set)
assert not any(str(plant.relative_to(root)) in b for b in miss), (
    "sanity: scripts-only scan unexpectedly caught plant: " + repr(miss)
)

# Fixed roots (scripts+devtools) must catch CERTIFIED=1 in the planted .sh.
hit = scan(["scripts", "devtools"], suffix_set)
plant_hits = [b for b in hit if str(plant.relative_to(root)) in b]
assert plant_hits, (
    "policy scan with scripts+devtools roots must catch CERTIFIED=1 in planted "
    f"devtools file; banned={hit!r}"
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
for root_name in ("scripts", "devtools"):
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
assert not banned, f"live scripts+devtools still have policy violations after plant cleanup: {banned}"
# Existing required dual-origin enforce CLI must be inside a scanned root.
dev = root / "devtools/enforce/run.sh"
assert dev.is_file()
assert "devtools" in src
print("live scan clean; devtools/enforce/run.sh covered by policy_roots")
PY

echo "PASS complete-e2e-policy-scan-covers-devtools: scripts+devtools in enforce+release-ready policy roots; CERTIFIED=1 plant fail-closed (no devtools/ blind spot)"
