#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Goal     : first-party scripts compile/parse offline without npm.
# Purpose  : Product prover for complete-e2e universal build (artifact-or-compile).
# Consumers: complete-e2e occupancy; exec _exec_product_universal_lifecycle; humans.
# Inputs   : cwd = repo root. Compiles scripts/**/*.py; bash -n scripts+devtools/**/*.sh.
# Outputs  : PASS/FAIL on stdout.
# Exit codes: 0 compile ok / 1 compile failure / 2 missing prover or usage
# Side effects: none (read-only; no npm; no PC_SKIP_NPM greenwash).
# -----------------------------------------------------------------------------
set -uo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
	exit 0
fi

# Fail-closed: unknown argv must not greenwash PASS (ignore-and-run theater).
if [[ "$#" -gt 0 ]]; then
	echo "usage: scripts/complete-e2e/prove/build.sh" >&2
	echo "unrecognized arguments: $*" >&2
	exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT" || exit 2
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "python3 missing"
command -v bash >/dev/null 2>&1 || fail "bash missing"
[[ -d "$ROOT/scripts" ]] || fail "scripts/ missing"

# Refuse skip-env theater: build must not claim PASS under PC_SKIP_NPM.
if [[ "${PC_SKIP_NPM:-}" == "1" ]]; then
	fail "PC_SKIP_NPM=1 refuses build prove (not a clean compile gate)"
fi

mapfile -t py_files < <(find "$ROOT/scripts" -type f -name '*.py' ! -path '*/__pycache__/*' | sort)
# scripts/ + devtools/: required dual-origin shell must be bash -n checked
# (scripts-only previously left devtools/enforce/run.sh unscanned).
mapfile -t sh_files < <(find "$ROOT/scripts" "$ROOT/devtools" -type f -name '*.sh' 2>/dev/null | sort)
[[ "${#py_files[@]}" -gt 0 ]] || fail "no scripts/**/*.py to compile"
[[ "${#sh_files[@]}" -gt 0 ]] || fail "no scripts|devtools /**/*.sh to bash -n"

for py in "${py_files[@]}"; do
	python3 -c 'import pathlib,sys; p=pathlib.Path(sys.argv[1]); compile(p.read_text(encoding="utf-8"), str(p), "exec")' "$py" \
		|| fail "python compile failed: ${py#"$ROOT"/}"
done

for sh in "${sh_files[@]}"; do
	bash -n "$sh" || fail "bash -n failed: ${sh#"$ROOT"/}"
done

echo "PASS build artifact-or-compile-succeeds offline py=${#py_files[@]} sh=${#sh_files[@]}"
exit 0
