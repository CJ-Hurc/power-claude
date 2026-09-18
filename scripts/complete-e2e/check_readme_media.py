#!/usr/bin/env python3
"""Fail-closed README media ref presence gate (paths exist + non-empty)."""
from __future__ import annotations
import re, sys
from pathlib import Path


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    readme = (root / "README.md").read_text(encoding="utf-8", errors="replace")
    refs = sorted(set(re.findall(r"(media/[A-Za-z0-9_./\\-]+)", readme)))
    missing = []
    ok = []
    empty = []
    for ref in refs:
        ref = ref.rstrip(").,]")
        p = root / ref
        if not p.exists():
            missing.append(ref)
        elif p.is_file() and p.stat().st_size == 0:
            empty.append(ref)
        else:
            ok.append(ref)
    print(f"checked={len(refs)} present={len(ok)} missing={len(missing)} empty={len(empty)}")
    for m in missing:
        print(f"MISSING {m}")
    for e in empty:
        print(f"EMPTY {e}")
    return 1 if missing or empty else 0


if __name__ == "__main__":
    # Fail-closed: unknown argv must not greenwash a live media check (ignore-and-run theater).
    _argv = sys.argv[1:]
    _a = set(_argv)
    if _a & {"-h", "--help"}:
        print(
            "usage: scripts/complete-e2e/check_readme_media.py [--help]\n"
            "power-claude-check-readme-media: README media/ path presence gate — use without flags"
        )
        raise SystemExit(0)
    if _a & {"-V", "--version"}:
        print("power-claude-check-readme-media 1.0.0")
        raise SystemExit(0)
    if _argv:
        print(
            "usage: scripts/complete-e2e/check_readme_media.py [--help]\n"
            "power-claude-check-readme-media: README media/ path presence gate — use without flags",
            file=sys.stderr,
        )
        print("unrecognized arguments: " + " ".join(_argv), file=sys.stderr)
        raise SystemExit(2)

    raise SystemExit(main())
