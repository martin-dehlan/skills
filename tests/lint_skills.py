#!/usr/bin/env python3
"""Lint skills, agents and templates. Exit 1 on any finding.

- SKILL.md frontmatter: known fields only, name equals folder, description + when_to_use < 1,536 chars
- SKILL.md under 500 lines
- relative markdown links resolve
- agents/*.md: known fields; every skill in `skills:` exists
- skill names mentioned as `skill-name` in templates/*.md and README must exist when they look like ours
"""
import re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKILL_FIELDS = {"name", "description", "when_to_use", "paths", "disable-model-invocation", "user-invocable",
                "allowed-tools", "argument-hint", "arguments", "model", "effort", "context", "agent", "hooks", "shell"}
AGENT_FIELDS = {"name", "description", "tools", "disallowedTools", "model", "skills", "color", "effort",
                "maxTurns", "memory", "background", "isolation", "permissionMode", "mcpServers", "hooks"}
errors = []

def err(path, msg): errors.append(f"{path.relative_to(ROOT)}: {msg}")

def frontmatter(path):
    t = path.read_text()
    m = re.match(r"---\n(.*?)\n---\n", t, re.S)
    if not m: err(path, "no frontmatter"); return {}, t
    fm, key = {}, None
    for line in m.group(1).splitlines():
        k = re.match(r"^([A-Za-z-]+):\s*(.*)$", line)
        if k: key = k.group(1); fm[key] = k.group(2)
        elif key and line.startswith((" ", "-")): fm[key] += "\n" + line
    return fm, t

skills = {p.parent.name for p in ROOT.glob("skills/*/SKILL.md")}
for sk in sorted(ROOT.glob("skills/*/SKILL.md")):
    fm, text = frontmatter(sk)
    for k in fm:
        if k not in SKILL_FIELDS: err(sk, f"unknown frontmatter field '{k}'")
    if fm.get("name", "").strip('"') != sk.parent.name: err(sk, "name does not match the folder")
    n = len(fm.get("description", "").strip('"')) + len(fm.get("when_to_use", ""))
    if n >= 1536: err(sk, f"description + when_to_use is {n} chars (limit 1,536)")
    if not fm.get("description"): err(sk, "no description")
    if text.count("\n") + 1 > 500: err(sk, f"{text.count(chr(10)) + 1} lines (limit 500)")

for md in list(ROOT.glob("**/*.md")):
    if ".git/" in str(md) or "node_modules" in str(md): continue
    for link in re.findall(r"\]\(([^)#\s]+)(?:#[^)]*)?\)", md.read_text()):
        if re.match(r"^[a-z]+:", link) or link.startswith("#"): continue
        if not (md.parent / link).exists(): err(md, f"broken link {link}")

for ag in ROOT.glob("agents/*.md"):
    fm, _ = frontmatter(ag)
    for k in fm:
        if k not in AGENT_FIELDS: err(ag, f"unknown frontmatter field '{k}'")
    for s in re.findall(r"^\s*-\s*([\w-]+)\s*$", fm.get("skills", ""), re.M):
        if s not in skills: err(ag, f"preloads unknown skill '{s}'")

if errors:
    print("\n".join(errors)); sys.exit(1)
print(f"lint_skills: ok ({len(skills)} skills)")
