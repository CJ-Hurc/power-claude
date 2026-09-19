#!/usr/bin/env python3
"""tidy --full floor for public power-claude mirror."""
from __future__ import annotations
import os
import subprocess
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
def pass_(m): print("  PASS  " + m, flush=True)
def fail_(m): print("  FAIL  " + m, flush=True)
def main():
    print("power-claude tidy --full")
    print("----------------------------------------")
    # Skip-npm cannot greenwash TIDY: PASS (peer enforce/release-ready refuse;
    # ignore-and-run under PC_SKIP_NPM=1 is floor-gate theater).
    if os.environ.get("PC_SKIP_NPM") == "1":
        fail_("PC_SKIP_NPM=1 refuses tidy (not a live package gate)")
        print("----------------------------------------")
        print("TIDY: FAIL")
        return 1
    rc = 0
    print("Layer 1 -- no bytecode junk")
    junk = []
    for p in ROOT.rglob("*"):
        if ".git" in p.parts: continue
        if p.name == "__pycache__" or p.suffix in {".pyc", ".pyo"}: junk.append(p)
    if not junk: pass_("no __pycache__/.pyc/.pyo")
    else:
        fail_("bytecode: " + ", ".join(str(x.relative_to(ROOT)) for x in junk[:8]))
        rc = 1
    print("Layer 2 -- scripts compile + shebang + bash -n")
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
        rel = str(sh.relative_to(ROOT))
        body = sh.read_text(encoding="utf-8", errors="replace")
        if body.startswith("#!"):
            pass_("shebang " + rel)
        else:
            fail_("missing shebang " + rel)
            rc = 1
        # bash -n: peer to python compile(); shebang-only previously greenwashed
        # TIDY: PASS while syntax-broken scripts|devtools/**/*.sh stayed invisible
        # (build prover already bash -n'd; standalone tidy --full did not).
        r = subprocess.run(
            ["bash", "-n", str(sh)],
            capture_output=True,
            text=True,
        )
        if r.returncode == 0:
            pass_("bash -n " + rel)
        else:
            err = (r.stderr or r.stdout or "").strip().splitlines()
            detail = err[-1] if err else "syntax error"
            fail_("bash -n " + rel + ": " + detail)
            rc = 1
    print("Layer 3 -- gitignore covers bytecode")
    gi = (ROOT / ".gitignore").read_text(encoding="utf-8", errors="replace")
    # Active (non-comment) rules only: substring `in gi` previously greenwashed
    # PASS while __pycache__/*.pyc/*.pyo lived only inside # comments (git check-ignore
    # would not ignore). *.pyo active rule still required (peer to junk scan).
    # Require __pycache__ AND *.pyc AND *.pyo: OR-base
    # (`__pycache__/` OR `*.pyc`) previously greenwashed Layer 3 PASS without
    # `*.pyc` while a planted orphan scripts/**/*.pyc stayed trackable
    # (git check-ignore would not ignore — __pycache__/ alone covers dirs only).
    rules = set()
    for raw in gi.splitlines():
        s = raw.strip()
        if not s or s.startswith("#"):
            continue
        rules.add(s)
    has_pycache = "__pycache__/" in rules or "__pycache__" in rules
    has_pyc = "*.pyc" in rules
    has_pyo = "*.pyo" in rules
    if has_pycache and has_pyc and has_pyo:
        # Live git check-ignore: rule-text AND previously greenwashed Layer 3
        # PASS while !*.pyc (negation after *.pyc) left orphan *.pyc trackable —
        # git check-ignore would not ignore. Probe pathnames need not exist.
        # Multi-root probes: scripts-only previously greenwashed Layer 3 PASS
        # while !media/*.pyc / !devtools/**/*.pyc left product-tree bytecode
        # trackable (git check-ignore would not ignore under those roots).
        probes = [
            "scripts/complete-e2e/.gitignore-floor-probe.pyc",
            "scripts/complete-e2e/.gitignore-floor-probe.pyo",
            "scripts/complete-e2e/__pycache__/.gitignore-floor-probe",
            "devtools/.gitignore-floor-probe.pyc",
            "devtools/.gitignore-floor-probe.pyo",
            "configs/.gitignore-floor-probe.pyc",
            "configs/.gitignore-floor-probe.pyo",
            "media/.gitignore-floor-probe.pyc",
            "media/.gitignore-floor-probe.pyo",
            "docs/.gitignore-floor-probe.pyc",
            "docs/.gitignore-floor-probe.pyo",
            ".gitignore-floor-probe.pyc",
            ".gitignore-floor-probe.pyo",
        ]
        miss = []
        for rel in probes:
            r = subprocess.run(
                ["git", "check-ignore", "-q", rel],
                cwd=str(ROOT),
                capture_output=True,
            )
            if r.returncode != 0:
                miss.append(rel)
        if not miss:
            pass_(".gitignore covers bytecode")
        else:
            fail_(".gitignore check-ignore miss (negation/ineffective): " + ", ".join(miss))
            rc = 1
    else:
        fail_(".gitignore missing active __pycache__/*.pyc/*.pyo rules")
        rc = 1
    print("----------------------------------------")
    print("TIDY: PASS" if rc == 0 else "TIDY: FAIL")
    return rc
if __name__ == "__main__":
    # CE2E_HELP_FASTPATH: harness CLI probes must not run full tidy
    _argv = sys.argv[1:]
    _a = set(_argv)
    if _a & {"-h", "--help"}:
        print("usage: scripts/tidy/run.py --full\npower-claude-tidy: bytecode/compile/shebang/bash -n floor — requires --full")
        raise SystemExit(0)
    if _a & {"-V", "--version"}:
        print("power-claude-tidy 1.0.0")
        raise SystemExit(0)
    # Fail-closed: advertised floor is tidy --full; bare/unknown argv must not
    # greenwash TIDY: PASS (ignore-and-run theater). Callers must pass --full.
    if _argv != ["--full"]:
        print("usage: scripts/tidy/run.py --full\npower-claude-tidy: bytecode/compile/shebang/bash -n floor — requires --full", file=sys.stderr)
        if _argv:
            print("unrecognized arguments: " + " ".join(_argv), file=sys.stderr)
        else:
            print("unrecognized arguments: (missing required --full)", file=sys.stderr)
        raise SystemExit(2)
    raise SystemExit(main())
