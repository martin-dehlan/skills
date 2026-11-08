#!/usr/bin/env python3
"""Fails when CLAUDE.md names a helper that no longer exists in the code.

The "## Helpers" table in CLAUDE.md maps the skills' generic names to this
app's classes, functions, files and paths. After a rename it silently goes
stale and Claude starts inventing names again. This check reads every
`backticked` value in the table's right-hand column and verifies it:

  contains "/"           -> the path (globs allowed) exists in the repo
  ends in a file suffix  -> a tracked file with that name exists
  anything else          -> each identifier in it appears in tracked source

Usage: python3 scripts/check_claude_helpers.py   (from the repo root)
"""
import re
import subprocess
import sys
from fnmatch import fnmatch
from pathlib import Path

SOURCE_DIRS = ("lib", "test", "integration_test", "supabase", "scripts", "tool", "e2e")
FILE_SUFFIXES = (".dart", ".ts", ".sh", ".py", ".md", ".txt", ".yaml", ".yml", ".json")
IGNORED = {"context", "ref", "the", "and", "or", "via", "per", "lib", "test"}


def helpers_rows(text):
    section = re.search(r"^## Helpers\s*$(.*?)(?=^## |\Z)", text, re.M | re.S)
    if not section:
        sys.exit("CLAUDE.md has no '## Helpers' section")
    for line in section.group(1).splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) >= 2 and not set(cells[0]) <= set("-: ") and cells[0] != "Skills say":
            yield cells[0], "|".join(cells[1:])


def main():
    files = subprocess.run(["git", "ls-files"], capture_output=True, text=True,
                           check=True).stdout.split()
    # Docs are not evidence: CLAUDE.md would otherwise always "find" itself.
    source = [f for f in files
              if (f.split("/")[0] in SOURCE_DIRS or "/" not in f) and not f.endswith(".md")]
    blob = "\n".join(Path(f).read_text(errors="ignore") for f in source if Path(f).is_file())
    missing = []

    for label, value in helpers_rows(Path("CLAUDE.md").read_text()):
        for span in re.findall(r"`([^`]+)`", value):
            if "/" in span and " " not in span:
                pattern = span.rstrip("/")
                if not any(fnmatch(f, pattern) or fnmatch(f, pattern + "/*") or f.startswith(pattern + "/")
                           for f in files):
                    missing.append((label, span, "path not found"))
            elif span.endswith(FILE_SUFFIXES):
                if not any(fnmatch(Path(f).name, span) for f in files):
                    missing.append((label, span, "file not found"))
            else:
                for ident in re.findall(r"[A-Za-z_][A-Za-z0-9_]*(?:-[A-Za-z0-9_]+)*", span):
                    if len(ident) < 3 or ident.lower() in IGNORED:
                        continue
                    if not re.search(r"(?<![\w-])" + re.escape(ident) + r"(?![\w-])", blob):
                        missing.append((label, span, f"'{ident}' not found in source"))

    if missing:
        print("CLAUDE.md helpers that no longer match the code:")
        for label, span, why in missing:
            print(f"  {label}: `{span}` ({why})")
        print("\nUpdate the Helpers table in CLAUDE.md, or restore the name.")
        return 1
    print("CLAUDE.md helpers: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
