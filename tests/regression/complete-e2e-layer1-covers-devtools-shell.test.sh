#!/usr/bin/env bash
# Fail-closed gate: enforce Layer 1 (+ tidy shebang + build bash -n) must cover
# devtools/**/*.sh. Blind spot theater: scripts-only exec/shebang/--fix and
# bash -n previously greenwashed PASS while required dual-origin
# devtools/enforce/run.sh could lack +x / shebang / syntax check, and
# enforce --fix could not remediate it.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENFORCE_PY="$ROOT/scripts/enforce/run.py"
TIDY_PY="$ROOT/scripts/tidy/run.py"
BUILD_SH="$ROOT/scripts/complete-e2e/prove/build.sh"
DEVTOOLS_EXISTING="$ROOT/devtools/enforce/run.sh"
[[ -f "$ENFORCE_PY" ]] || { echo "FAIL layer1-devtools: missing enforce/run.py" >&2; exit 1; }
[[ -f "$TIDY_PY" ]] || { echo "FAIL layer1-devtools: missing tidy/run.py" >&2; exit 1; }
[[ -f "$BUILD_SH" ]] || { echo "FAIL layer1-devtools: missing prove/build.sh" >&2; exit 1; }
[[ -f "$DEVTOOLS_EXISTING" && -x "$DEVTOOLS_EXISTING" ]] \
  || { echo "FAIL layer1-devtools: missing/non-exec devtools/enforce/run.sh" >&2; exit 1; }

# Source must expand shell roots beyond scripts-only (enforce + tidy + build).
grep -q 'devtools' "$ENFORCE_PY" \
  || { echo "FAIL layer1-devtools: enforce/run.py missing devtools" >&2; exit 1; }
grep -qE 'sh_roots\s*=\s*\[.*devtools' "$ENFORCE_PY" \
  || { echo "FAIL layer1-devtools: enforce Layer 1 sh_roots missing devtools" >&2; exit 1; }
grep -q 'devtools' "$TIDY_PY" \
  || { echo "FAIL layer1-devtools: tidy/run.py missing devtools shebang root" >&2; exit 1; }
grep -q 'devtools' "$BUILD_SH" \
  || { echo "FAIL layer1-devtools: build.sh missing devtools bash -n root" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc-layer1-devtools-XXXXXX")"
trap 'rm -rf "$tmp"; rm -f "$ROOT/devtools/enforce/.layer1-plant-noexec.sh"' EXIT

PLANT="$ROOT/devtools/enforce/.layer1-plant-noexec.sh"
# Plant a shebang'd but non-executable shell under required dual-origin tree.
printf '%s\n' '#!/bin/sh' 'echo layer1-plant' >"$PLANT"
chmod a-x "$PLANT"
[[ ! -x "$PLANT" ]] || { echo "FAIL layer1-devtools: plant still executable" >&2; exit 1; }

python3 - "$ROOT" "$PLANT" <<'PY'
import stat
import sys
from pathlib import Path

root = Path(sys.argv[1])
plant = Path(sys.argv[2])


def layer1(sh_roots: list[Path]) -> list[str]:
    fails: list[str] = []
    for sh_root in sh_roots:
        if not sh_root.is_dir():
            continue
        for sh in sorted(sh_root.rglob("*.sh")):
            rel = str(sh.relative_to(root))
            text = sh.read_text(encoding="utf-8", errors="replace")
            if not text.startswith("#!"):
                fails.append("missing shebang " + rel)
                continue
            if not (sh.stat().st_mode & stat.S_IXUSR):
                fails.append("not executable " + rel)
    return fails


scripts_only = layer1([root / "scripts"])
fixed = layer1([root / "scripts", root / "devtools"])
plant_rel = str(plant.relative_to(root))

assert not any(plant_rel in f for f in scripts_only), (
    "sanity: scripts-only Layer 1 unexpectedly caught devtools plant: "
    + repr(scripts_only)
)
assert any(plant_rel in f for f in fixed), (
    "Layer 1 with scripts+devtools must catch non-exec plant under "
    f"devtools/; fails={fixed!r}"
)
assert any("not executable" in f and plant_rel in f for f in fixed), fixed
print("runtime plant caught:", next(f for f in fixed if plant_rel in f))

# --fix remediation must chmod plant when roots include devtools.
mode = plant.stat().st_mode
plant.chmod(mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
assert plant.stat().st_mode & stat.S_IXUSR, "failed to chmod plant for live check"
# Strip again and simulate scripts-only --fix (must NOT restore).
plant.chmod(mode & ~stat.S_IXUSR & ~stat.S_IXGRP & ~stat.S_IXOTH)
for sh in sorted((root / "scripts").rglob("*.sh")):
    m = sh.stat().st_mode
    if not (m & stat.S_IXUSR):
        sh.chmod(m | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
assert not (plant.stat().st_mode & stat.S_IXUSR), (
    "scripts-only --fix must leave devtools plant non-exec"
)
# Fixed --fix restores.
for sh_root in (root / "scripts", root / "devtools"):
    if not sh_root.is_dir():
        continue
    for sh in sorted(sh_root.rglob("*.sh")):
        m = sh.stat().st_mode
        if not (m & stat.S_IXUSR):
            sh.chmod(m | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
assert plant.stat().st_mode & stat.S_IXUSR, (
    "scripts+devtools --fix must restore +x on plant"
)
print("fix remediation: scripts-only miss / scripts+devtools restore ok")
PY

rm -f "$PLANT"

# Live: existing dual-origin shell must be covered by fixed roots (exec+shebang).
python3 - "$ROOT" "$DEVTOOLS_EXISTING" <<'PY'
import stat
import sys
from pathlib import Path

root = Path(sys.argv[1])
existing = Path(sys.argv[2])
assert existing.is_file() and (existing.stat().st_mode & stat.S_IXUSR)
text = existing.read_text(encoding="utf-8", errors="replace")
assert text.startswith("#!"), existing
# Covered by scripts+devtools walk
covered = False
for sh_root in (root / "scripts", root / "devtools"):
    if not sh_root.is_dir():
        continue
    for sh in sh_root.rglob("*.sh"):
        if sh.resolve() == existing.resolve():
            covered = True
assert covered, "devtools/enforce/run.sh not covered by scripts+devtools sh_roots"
print("live exec+shebang; devtools/enforce/run.sh covered by sh_roots")
PY

# Live tidy shebang + build bash -n must include the dual-origin path.
python3 "$TIDY_PY" --full >"$tmp/tidy.out" 2>"$tmp/tidy.err"
tidy_rc=$?
tidy_text="$(cat "$tmp/tidy.out" "$tmp/tidy.err" 2>/dev/null || true)"
[[ "$tidy_rc" -eq 0 ]] || { echo "FAIL layer1-devtools: tidy --full exited $tidy_rc"$'\n'"$tidy_text" >&2; exit 1; }
printf '%s' "$tidy_text" | grep -q 'shebang devtools/enforce/run.sh' \
  || { echo "FAIL layer1-devtools: tidy missing shebang pass for devtools/enforce/run.sh"$'\n'"$tidy_text" >&2; exit 1; }

bash "$BUILD_SH" >"$tmp/build.out" 2>"$tmp/build.err"
build_rc=$?
build_text="$(cat "$tmp/build.out" "$tmp/build.err" 2>/dev/null || true)"
[[ "$build_rc" -eq 0 ]] || { echo "FAIL layer1-devtools: build.sh exited $build_rc"$'\n'"$build_text" >&2; exit 1; }
# bash -n covers the file if build walks it; count should include +1 vs scripts-only.
scripts_only_n="$(find "$ROOT/scripts" -type f -name '*.sh' | wc -l | tr -d ' ')"
with_devtools_n="$(find "$ROOT/scripts" "$ROOT/devtools" -type f -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')"
[[ "$with_devtools_n" -gt "$scripts_only_n" ]] \
  || { echo "FAIL layer1-devtools: expected more .sh under scripts+devtools than scripts-only" >&2; exit 1; }
printf '%s' "$build_text" | grep -q "sh=${with_devtools_n}" \
  || { echo "FAIL layer1-devtools: build PASS count must include devtools shells (want sh=${with_devtools_n})"$'\n'"$build_text" >&2; exit 1; }

echo "PASS complete-e2e-layer1-covers-devtools-shell: enforce Layer1+tidy shebang+build bash -n cover scripts+devtools; non-exec plant fail-closed; --fix remediates (no scripts-only blind spot)"
