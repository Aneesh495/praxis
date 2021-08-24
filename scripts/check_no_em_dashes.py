#!/usr/bin/env python3
"""
Zero-tolerance verification script to enforce that NO em dashes (U+2014) exist
in any comments, documentation, markdown files, code files, or configuration.
"""

import os
import sys

EM_DASH = "\u2014"
EXCLUDE_DIRS = {".git", "target", ".cargo"}


def scan_file(filepath: str) -> list[tuple[int, str]]:
    violations = []
    try:
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            for line_no, line in enumerate(f, start=1):
                if EM_DASH in line:
                    violations.append((line_no, line.rstrip()))
    except Exception as e:
        print(f"Error reading {filepath}: {e}", file=sys.stderr)
    return violations


def main() -> int:
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    total_violations = 0

    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
        for filename in filenames:
            ext = os.path.splitext(filename)[1].lower()
            if ext in {".nix", ".md", ".rs", ".py", ".sh", ".toml", ".yaml", ".yml", ".json", ".txt"}:
                full_path = os.path.join(dirpath, filename)
                rel_path = os.path.relpath(full_path, root)
                violations = scan_file(full_path)
                if violations:
                    for line_no, line in violations:
                        print(f"VIOLATION: Em dash found in {rel_path}:{line_no}: {line}")
                    total_violations += len(violations)

    if total_violations > 0:
        print(f"\nFAILURE: Found {total_violations} em dash violation(s).")
        return 1
    print("SUCCESS: 0 em dash violations detected across codebase.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
