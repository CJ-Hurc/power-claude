#!/usr/bin/env python3
"""release-ready gate for public power-claude mirror."""
# Never ALLOW_UNPROVEN. Never fake CERTIFIED.
from __future__ import annotations
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def pass_(m): print("  PASS  " + m, flush=True)
def fail_(m): print("  FAIL  " + m, flush=True)

def purge_bytecode() -> None:
    for p in list(ROOT.rglob("*")):
        if ".git" in p.parts:
            continue
        if p.name == "__pycache__" and p.is_dir():
            shutil.rmtree(p, ignore_errors=True)
        elif p.suffix == ".pyc" and p.is_file():
            p.unlink(missing_ok=True)

def run_gate(label: str, script: str, extra_args: list[str] | None = None) -> bool:
    path = ROOT / script
    print("Gate -- " + label)
    if not path.is_file():
        fail_(label + " missing " + script)
        return False
    env = os.environ.copy()
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    env.pop("PC_SKIP_NPM", None)
    cmd = ["bash", str(path)] + (extra_args or [])
    r = subprocess.run(cmd, cwd=str(ROOT), env=env)
    if r.returncode == 0:
        pass_(label)
        return True
    fail_(label)
    return False

def main() -> int:
    print("power-claude release-ready")
    print("----------------------------------------")
    print("Policy: never ALLOW_UNPROVEN; never fake CERTIFIED")
    # Skip-npm cannot greenwash RELEASE_READY: PASS (strip-and-run theater via env.pop).
    if os.environ.get("PC_SKIP_NPM") == "1":
        fail_("PC_SKIP_NPM=1 refuses release-ready (not a live package gate)")
        print("----------------------------------------")
        print("RELEASE_READY: FAIL")
        return 1
    purge_bytecode()
    ok = True
    print("Gate -- policy scan (no ALLOW_UNPROVEN / fake CERTIFIED)")
    banned = []
    # Scan scripts/, devtools/, configs/, and media/: verify requires media/;
    # shipping loaders live under media/loaders/*.js|*.html and consumer requires
    # media/icon.svg — scripts+devtools+configs-only previously greenwashed PASS
    # while a fake CERTIFIED enable in that required product surface stayed
    # invisible. .js/.html/.svg must be in the suffix set or media/*.svg stays
    # a blind spot.
    policy_roots = [ROOT / "scripts", ROOT / "devtools", ROOT / "configs", ROOT / "media"]
    for policy_root in policy_roots:
        if not policy_root.is_dir():
            continue
        for path in sorted(policy_root.rglob("*")):
            if ".git" in path.parts or not path.is_file():
                continue
            if path.suffix not in {".py", ".sh", ".md", ".yml", ".yaml", ".ts", ".json", ".js", ".html", ".svg"}:
                continue
            text = path.read_text(encoding="utf-8", errors="replace")
            rel = str(path.relative_to(ROOT))
            # Comments stating the ban are OK; assignments / enables are not.
            # Build needles without embedding banned assignments as contiguous literals.
            allow_a = "ALLOW_UNPROVEN" + "=1"
            allow_b = "ALLOW_UNPROVEN" + " = 1"
            # Shell =true enables (scripts/*.sh): =1 / " = 1" needles previously
            # greenwashed PASS while env =true forms stayed invisible.
            allow_t = "ALLOW_UNPROVEN" + "=true"
            allow_ts = "ALLOW_UNPROVEN" + " = true"
            # JSON object enables (configs/*.json): shell-style env needles
            # previously greenwashed PASS while JSON boolean CERTIFIED stayed invisible.
            allow_j = '"ALLOW_UNPROVEN"' + ": true"
            # JSON numeric enables (configs/*.json): boolean ": true" needles
            # previously greenwashed PASS while JSON numeric CERTIFIED stayed invisible.
            allow_jn = '"ALLOW_UNPROVEN"' + ": 1"
            # JSON minified enables (configs/*.json): spaced ": true"/": 1" needles
            # previously greenwashed PASS while JSON.stringify-style CERTIFIED:true/:1
            # (no space after colon) stayed invisible.
            allow_jm = '"ALLOW_UNPROVEN"' + ":true"
            allow_jnm = '"ALLOW_UNPROVEN"' + ":1"
            # YAML unquoted-key enables (configs/*.yml|*.yaml): JSON-quoted
            # key needles previously greenwashed PASS while YAML unquoted-key
            # boolean ": true" forms stayed invisible even though .yml/.yaml
            # are already in the suffix set.
            allow_y = "ALLOW_UNPROVEN" + ": true"
            # YAML unquoted-key numeric: boolean ": true" needles previously
            # greenwashed PASS while unquoted-key numeric ": 1" forms stayed
            # invisible under .yml/.yaml already in the suffix set.
            allow_yn = "ALLOW_UNPROVEN" + ": 1"
            if (
                allow_a in text
                or allow_b in text
                or allow_t in text
                or allow_ts in text
                or allow_j in text
                or allow_jn in text
                or allow_jm in text
                or allow_jnm in text
                or allow_y in text
                or allow_yn in text
            ):
                banned.append(rel + ": " + allow_a)
            cert_a = "CERTIFIED" + "=1"
            # Shell spaced numeric enable: ALLOW_UNPROVEN already has allow_b
            # (" = 1"); CERTIFIED + "=1"-only previously greenwashed PASS while the
            # spaced numeric form stayed invisible in scripts/*.sh.
            cert_as = "certified" + " = 1"
            cert_b = "certified" + " = true"
            # Shell env =true (no spaces): spaced certified + " = true" previously
            # greenwashed PASS while no-space =true stayed invisible in scripts/*.sh.
            cert_t = "certified" + "=true"
            cert_j = '"CERTIFIED"' + ": true"
            cert_jl = '"certified"' + ": true"
            cert_jn = '"CERTIFIED"' + ": 1"
            cert_jnl = '"certified"' + ": 1"
            cert_jm = '"CERTIFIED"' + ":true"
            cert_jml = '"certified"' + ":true"
            cert_jnm = '"CERTIFIED"' + ":1"
            cert_jnml = '"certified"' + ":1"
            # YAML unquoted-key boolean: JSON quoted-key needles previously
            # greenwashed PASS while unquoted-key ": true" stayed invisible
            # under .yml/.yaml already listed in the suffix set.
            cert_y = "certified" + ": true"
            # YAML unquoted-key numeric: cert_y ": true" previously greenwashed
            # PASS while unquoted-key numeric ": 1" stayed invisible under .yml/.yaml.
            cert_yn = "certified" + ": 1"
            if (
                cert_a in text
                or cert_as in text.lower()
                or cert_b in text.lower()
                or cert_t in text.lower()
                or cert_j in text
                or cert_jl in text.lower()
                or cert_jn in text
                or cert_jnl in text.lower()
                or cert_jm in text
                or cert_jml in text.lower()
                or cert_jnm in text
                or cert_jnml in text.lower()
                or cert_y in text.lower()
                or cert_yn in text.lower()
            ):
                banned.append(rel + ": fake CERTIFIED enable")
    if not banned:
        pass_("no ALLOW_UNPROVEN/fake CERTIFIED enables in scripts+devtools+configs+media")
    else:
        fail_("policy violations: " + "; ".join(banned[:5]))
        ok = False
    # enforce --fix first so bytecode from prior runs is cleared
    if not run_gate("enforce --fix", "scripts/enforce/run.sh", ["--fix"]):
        ok = False
    purge_bytecode()
    if not run_gate("tidy --full", "scripts/tidy/run.sh", ["--full"]):
        ok = False
    purge_bytecode()
    if not run_gate("verify", "scripts/verify/run.sh"):
        ok = False
    purge_bytecode()
    print("----------------------------------------")
    if ok:
        print("RELEASE_READY: PASS")
        print("Note: PASS means consumer scripts floor gates green — not a product CERTIFIED claim.")
        return 0
    print("RELEASE_READY: FAIL")
    return 1

if __name__ == "__main__":
    # CE2E_HELP_FASTPATH: harness CLI probes must not run full release-ready
    _argv = sys.argv[1:]
    _a = set(_argv)
    if _a & {"-h", "--help"}:
        print("usage: scripts/release-ready/run.py [--help]\npower-claude-release-ready: floor gates (enforce+tidy+verify) — use without flags")
        raise SystemExit(0)
    if _a & {"-V", "--version"}:
        print("power-claude-release-ready 1.0.0")
        raise SystemExit(0)
    # Fail-closed: unknown argv must not greenwash RELEASE_READY: PASS.
    if _argv:
        print("usage: scripts/release-ready/run.py [--help]\npower-claude-release-ready: floor gates (enforce+tidy+verify) — use without flags", file=sys.stderr)
        print("unrecognized arguments: " + " ".join(_argv), file=sys.stderr)
        raise SystemExit(2)
    raise SystemExit(main())
