#!/usr/bin/env bash
# Thin delegate to the sibling .py CLI. Do not short-circuit --help here:
# stub usage text without power-claude identity is help theater. Unknown argv
# and rich --help are owned by the Python entrypoint.
set -euo pipefail
exec python3 "$(dirname "$0")/$(basename "$0" .sh).py" "$@"
