#!/usr/bin/env python3
"""Inventory-only surface listing for complete-e2e runtime.

Fail-closed attestation guard: this adapter MUST NEVER set behavior_proven true.
Inventory listing is not a prove path — only execute/prove adapters may attest.

Paths use scripts/bin/*.sh so declarative + runtime share one path identity
(avoids reconciliation collisions with dual bin/ trees).
"""
from __future__ import annotations
import json, sys
from pathlib import Path

CANDIDATES = (
    ("cli:complete-e2e", "scripts/bin/complete-e2e.sh"),
    ("cli:consumer", "scripts/bin/consumer.sh"),
    ("cli:execute-consumer", "scripts/bin/execute-consumer.sh"),
    ("cli:verify", "scripts/bin/verify.sh"),
    ("cli:prove", "scripts/bin/prove.sh"),
    ("cli:clean-room-replay", "scripts/bin/clean-room-replay.sh"),
    ("cli:check-adapter-paths", "scripts/bin/check-adapter-paths.sh"),
)

HELP = (
    "usage: scripts/complete-e2e/list-surfaces.py [--help] [--project-dir PATH]\n"
    "power-claude-list-surfaces: inventory-only surface listing "
    "(behavior_proven always false) — optional --project-dir PATH"
)


def _surfaces(root: Path):
    out = []
    for sid, rel in CANDIDATES:
        if (root / rel).is_file():
            out.append({"id": sid, "kind": "cli", "path": rel, "origin": "runtime"})
    return out


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    a = set(argv)
    # CE2E_HELP_FASTPATH: harness CLI probes must not run inventory mutation.
    if a & {"-h", "--help"}:
        print(HELP)
        return 0
    if a & {"-V", "--version"}:
        print("power-claude-list-surfaces 1.0.0")
        return 0

    project_dir = ""
    args = list(argv)
    if "--project-dir" in args:
        i = args.index("--project-dir")
        if i + 1 >= len(args):
            print("list-surfaces: --project-dir requires a path", file=sys.stderr)
            return 2
        project_dir = args[i + 1]
        del args[i : i + 2]
    # Fail-closed: unknown argv must not greenwash inventory JSON (ignore-and-run theater).
    if args:
        print(HELP, file=sys.stderr)
        print("unrecognized arguments: " + " ".join(args), file=sys.stderr)
        return 2

    root = Path(project_dir).resolve() if project_dir else Path(__file__).resolve().parents[2]
    if not root.is_dir():
        print("list-surfaces: project-dir not a directory", file=sys.stderr)
        return 2
    payload = {
        "schema": "hurc-complete-e2e-runtime-surfaces/v1",
        "behavior_proven": False,
        "surfaces": _surfaces(root),
    }
    sys.stdout.write(json.dumps(payload, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
