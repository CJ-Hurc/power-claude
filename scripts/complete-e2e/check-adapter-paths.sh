#!/usr/bin/env bash

for _a in "$@"; do
  case "$_a" in
    -h|--help) echo "Usage: $(basename "$0") [options]"; exit 0 ;;
  esac
done
exec python3 "$(dirname "$0")/check-adapter-paths.py" "$@"
