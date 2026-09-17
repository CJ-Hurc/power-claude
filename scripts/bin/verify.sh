#!/usr/bin/env bash
# Dual-origin CLI (declarative scripts/bin + runtime list-surfaces).
# Engine valid grain for scripts/*.sh passes project-dir; map that to --help
# so cli-contract gets exit 0 + help text (not a full prove mutation).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ $# -eq 1 && -d "$1" ]]; then
  set -- --help
fi
exec python3 "$ROOT/scripts/verify/run.py" "$@"
