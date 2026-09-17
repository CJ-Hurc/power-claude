#!/usr/bin/env bash
# Occupancy stub for complete-e2e proof input + CLI contract (CLI-only product).
set -euo pipefail
usage() { echo "Usage: run.sh [scan|status] [--scope=period|global]"; echo "Options: -h, --help"; }
for a in "$@"; do case "$a" in -h|--help) usage; exit 0;; esac; done
cmd="${1:-status}"
case "$cmd" in
  status|scan)
    usage
    echo "enforce stub: ok"
    exit 0
    ;;
  *)
    echo "unknown command: $cmd" >&2
    usage >&2
    exit 2
    ;;
esac
