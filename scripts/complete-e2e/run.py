#!/usr/bin/env python3
"""Canonical complete-e2e entry: README media refs + consumer prove."""
from __future__ import annotations
import os, subprocess, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent

def main() -> int:
    print("power-claude complete-e2e")
    print("----------------------------------------")
    # Skip-npm cannot greenwash COMPLETE_E2E: PASS (consumer package layer).
    if os.environ.get("PC_SKIP_NPM") == "1":
        print("  FAIL  PC_SKIP_NPM=1 refuses complete-e2e (not a live package gate)", flush=True)
        print("----------------------------------------")
        print("COMPLETE_E2E: FAIL")
        return 1
    rc = 0
    media = HERE / "check_readme_media.py"
    r = subprocess.run([sys.executable, str(media)], cwd=str(ROOT))
    if r.returncode == 0:
        print("  PASS  readme media refs", flush=True)
    else:
        print("  FAIL  readme media refs", flush=True)
        rc = 1
    consumer = HERE / "consumer.py"
    env = os.environ.copy()
    env.pop("PC_SKIP_NPM", None)
    r = subprocess.run([sys.executable, str(consumer)], cwd=str(ROOT), env=env)
    if r.returncode == 0:
        print("  PASS  consumer complete-e2e", flush=True)
    else:
        print("  FAIL  consumer complete-e2e", flush=True)
        rc = 1
    print("----------------------------------------")
    print("COMPLETE_E2E: PASS" if rc == 0 else "COMPLETE_E2E: FAIL")
    return rc

if __name__ == "__main__":
    # CE2E_HELP_FASTPATH: harness CLI probes must not run full consumer prove
    import sys as _sys
    _argv = _sys.argv[1:]
    _a = set(_argv)
    if _a & {"-h", "--help"}:
        print('usage: scripts/complete-e2e/run.py [--help]\npower-claude-complete-e2e: consumer prove/verify entry — use without flags to run live proofs')
        raise SystemExit(0)
    if _a & {"-V", "--version"}:
        print('power-claude-complete-e2e 1.0.0')
        raise SystemExit(0)
    # Fail-closed: unknown argv must not greenwash a live PASS (ignore-and-run theater).
    if _argv:
        print('usage: scripts/complete-e2e/run.py [--help]\npower-claude-complete-e2e: consumer prove/verify entry — use without flags to run live proofs', file=_sys.stderr)
        print("unrecognized arguments: " + " ".join(_argv), file=_sys.stderr)
        raise SystemExit(2)

    raise SystemExit(main())
