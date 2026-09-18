#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Goal     : dual-origin enforce CLI for complete-e2e proof input + CLI contract.
# Purpose  : Real delegate to scripts/enforce/run.py (never a path-only placeholder).
# Consumers: issue-accepted-receipt proof inputs; CLI contract; humans.
# Inputs   : cwd = repo root. Verbs: status|scan|--fix|-h|--help; project-dir→help.
# Outputs  : enforce floor stdout / Usage on --help.
# Exit codes: enforce rc / 0 help / 2 unknown or missing floor
# Side effects: same as scripts/enforce/run.py when status|scan|--fix runs.
# -----------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENFORCE_PY="$ROOT/scripts/enforce/run.py"

usage() {
	echo "Usage: run.sh [scan|status|--fix] [-h|--help]"
	echo "power-claude-enforce: delegates to scripts/enforce/run.py (real enforce floor)"
}

# Engine valid grain may pass project-dir; map to --help (not a full enforce mutation).
if [[ $# -eq 1 && -d "$1" ]]; then
	set -- --help
fi

args=()
for a in "$@"; do
	case "$a" in
		-h|--help)
			usage
			exit 0
			;;
		status|scan)
			# Legacy occupancy verbs → real enforce default run.
			;;
		--scope=*)
			# Drop legacy no-op scope flag (was a no-op placeholder; not a real gate).
			;;
		--fix)
			args+=(--fix)
			;;
		-*)
			echo "unknown option: $a" >&2
			usage >&2
			exit 2
			;;
		*)
			echo "unknown command: $a" >&2
			usage >&2
			exit 2
			;;
	esac
done

[[ -f "$ENFORCE_PY" ]] || {
	echo "FAIL: missing scripts/enforce/run.py (devtools path is not a stub)" >&2
	exit 2
}

exec python3 "$ENFORCE_PY" "${args[@]}"
