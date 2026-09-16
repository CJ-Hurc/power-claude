#!/usr/bin/env bash
# Dual-origin CLI for complete-e2e (declarative scripts/bin + runtime list-surfaces).
# Engine valid grain for scripts/*.sh passes project-dir as argv[1]; accept and ignore.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ $# -eq 1 && -d "$1" ]]; then
  set --
fi
exec python3 "$ROOT/scripts/complete-e2e/execute-consumer.py" "$@"
