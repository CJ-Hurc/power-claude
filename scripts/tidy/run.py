#!/usr/bin/env python3
"""tidy --full floor for public power-claude mirror."""
from __future__ import annotations
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
def pass_(m): print("  PASS  " + m, flush=True)
def fail_(m): print("  FAIL  " + m, flush=True)
def main():
    print("power-claude tidy --full")
    print("----------------------------------------")
    rc = 0
    print("Layer 1 -- no bytecode junk")
    junk = []
    for p in ROOT.rglob("*"):
        if ".git" in p.parts: continue
        if p.name == "__pycache__" or p.suffix == ".pyc": junk.append(p)
    if not junk: pass_("no __pycache__/.pyc")
    else:
        fail_("bytecode: " + ", ".join(str(x.relative_to(ROOT)) for x in junk[:8]))
        rc = 1
    print("Layer 2 -- scripts compile + shebang")
    scripts_root = ROOT / "scripts"
    py_files = sorted(scripts_root.rglob("*.py")) if scripts_root.is_dir() else []
    # Include devtools/**/*.sh: required dual-origin CLI shebang must not be a
    # scripts-only blind spot (peer to enforce Layer 1 sh_roots).
    sh_files = []
    for sh_root in (scripts_root, ROOT / "devtools"):
        if sh_root.is_dir():
            sh_files.extend(sorted(sh_root.rglob("*.sh")))
    for py in py_files:
        if "__pycache__" in py.parts: continue
        try:
            # compile() checks syntax without writing __pycache__/.pyc
            compile(py.read_text(encoding="utf-8"), str(py), "exec")
            pass_("compile " + str(py.relative_to(ROOT)))
        except Exception as e:
            fail_("compile " + str(py.relative_to(ROOT)) + ": " + str(e))
            rc = 1
    for sh in sh_files:
        text = sh.read_text(encoding="utf-8", errors="replace")
        if text.startswith("#!"): pass_("shebang " + str(sh.relative_to(ROOT)))
        else:
            fail_("missing shebang " + str(sh.relative_to(ROOT)))
            rc = 1
    print("Layer 3 -- gitignore covers bytecode")
    gi = (ROOT / ".gitignore").read_text(encoding="utf-8", errors="replace")
    if "__pycache__" in gi or "*.pyc" in gi: pass_(".gitignore covers bytecode")
    else:
        fail_(".gitignore missing __pycache__/*.pyc")
        rc = 1
    print("----------------------------------------")
    print("TIDY: PASS" if rc == 0 else "TIDY: FAIL")
    return rc
if __name__ == "__main__":
    # CE2E_HELP_FASTPATH: harness CLI probes must not run full tidy
    _argv = sys.argv[1:]
    _a = set(_argv)
    if _a & {"-h", "--help"}:
        print("usage: scripts/tidy/run.py --full\npower-claude-tidy: bytecode/compile/shebang floor — requires --full")
        raise SystemExit(0)
    if _a & {"-V", "--version"}:
        print("power-claude-tidy 1.0.0")
        raise SystemExit(0)
    # Fail-closed: advertised floor is tidy --full; bare/unknown argv must not
    # greenwash TIDY: PASS (ignore-and-run theater). Callers must pass --full.
    if _argv != ["--full"]:
        print("usage: scripts/tidy/run.py --full\npower-claude-tidy: bytecode/compile/shebang floor — requires --full", file=sys.stderr)
        if _argv:
            print("unrecognized arguments: " + " ".join(_argv), file=sys.stderr)
        else:
            print("unrecognized arguments: (missing required --full)", file=sys.stderr)
        raise SystemExit(2)
    raise SystemExit(main())
