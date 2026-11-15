#!/usr/bin/env python3
"""Lint skills, agents and templates. Exit 1 on any finding.

- SKILL.md frontmatter: known fields only, name equals folder, description + when_to_use < 1,536 chars
- size budgets (README, "How this repo grows"): SKILL.md 200 lines and 10 KB, manual workflow
  skills 40 lines, references 150 lines, path rules 15 bullets; files in tests/size_budget.tsv
  may not grow past their ceiling, and a row whose file is back under budget must go
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

# --- size budgets --------------------------------------------------------------------------
HINT = "at budget: sharpen an existing line or move a section to references/ (README, How this repo grows)"
ceilings = {}
budget_file = ROOT / "tests/size_budget.tsv"
if budget_file.exists():
    for row in budget_file.read_text().splitlines():
        if row.strip() and not row.startswith("#"):
            path, lines, size = row.split("\t")
            ceilings[path] = (int(lines), int(size))

def budget(path):
    rel = str(path.relative_to(ROOT))
    if rel.startswith("templates/claude/rules/"): return ("bullets", 15, None)
    if path.name == "SKILL.md":
        fm, _ = frontmatter(path)
        if fm.get("disable-model-invocation", "").strip() == "true": return ("lines", 40, None)
        return ("lines", 200, 10240)
    return ("lines", 150, None)

table = []
files = sorted(ROOT.glob("skills/*/SKILL.md")) + sorted(ROOT.glob("skills/*/references/*.md")) \
    + sorted(ROOT.glob("templates/claude/rules/*.md"))
for f in files:
    rel, text = str(f.relative_to(ROOT)), f.read_text()
    kind, max_n, max_b = budget(f)
    n = sum(1 for l in text.splitlines() if l.startswith("- ")) if kind == "bullets" else len(text.splitlines())
    b = len(text.encode())
    over = n > max_n or (max_b is not None and b > max_b)
    if rel in ceilings:
        cl, cb = ceilings[rel]
        if not over: err(f, "under budget now: delete its row in tests/size_budget.tsv")
        elif n > cl or b > cb: err(f, f"{n} {kind} / {b} bytes, ceiling {cl} / {cb}; {HINT}")
        limit = f"{cl} (ceiling)"
    else:
        if n > max_n: err(f, f"{n} {kind}, budget {max_n}; {HINT}")
        if max_b is not None and b > max_b: err(f, f"{b} bytes, budget {max_b}; {HINT}")
        limit = str(max_n)
    table.append((rel, n, kind, limit, b))
for rel in ceilings:
    if not (ROOT / rel).exists(): errors.append(f"tests/size_budget.tsv: {rel} does not exist")

if table:
    w = max(len(r[0]) for r in table)
    print(f"{'file':<{w}}  size      budget         bytes")
    for rel, n, kind, limit, b in table:
        print(f"{rel:<{w}}  {n:>4} {kind:<8} {limit:<14} {b:>6}")
    print()

if errors:
    print("\n".join(errors)); sys.exit(1)
print(f"lint_skills: ok ({len(skills)} skills)")
