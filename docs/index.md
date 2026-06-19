# pycemrg-context

Suite-level context for AI agents (Claude Code) when consumers compose projects
from the **pycemrg** library suite. Maintained by the
[Cardiac Electromechanics Research Group (CEMRG)](https://www.cemrg.com/) at
Imperial College London.

---

## What this is for

When you are building a project that needs pycemrg functionality — *"extract the
atrial myocardium, then mesh it"* — this repo gives Claude the context to:

1. **Recommend** which pycemrg libraries and functions to use.
2. **Output the right install instructions** per library (pip or git clone).
3. **Flag steps that aren't in the suite** — distinguishing project-specific glue
   from things that look like missing suite capabilities.

This is a **consumer-side** tool. It does not handle contribution back to the
suite; that goes through normal GitHub Issues/PRs in the individual library
repos.

---

## Where to go next

- **[Getting Started](getting-started/index.md)** — install the context into
  `~/.claude` (macOS/Linux/Windows) and run your first `/pycemrg-build`.
- **[The Suite → Overview](suite/overview.md)** — one paragraph plus capabilities
  for every library, the first-pass router for `/pycemrg-build`.
- **[The Suite → Library Registry](suite/registry.md)** — install command and
  docs palette per library.
- **[Commands & Skills](tools/pycemrg-build.md)** — the consumer command, the CI
  export command, and the docs-scaffolding skill.
- **[Dashboard](dashboard.md)** — a local web chat front-end for `/pycemrg-build`.
- **[Contributing](contributing.md)** — how to add a library to the suite.

---

## How it fits together

| Scope | Location |
|---|---|
| Personal practices, manifest | `~/.claude/CLAUDE.md` |
| Suite-level consumer routing | **this repo** |
| Library-specific commands + gotchas | `{library}/CLAUDE.md` |
| Full per-library API reference | `source/{library}.md` (this repo, CI-generated) |
