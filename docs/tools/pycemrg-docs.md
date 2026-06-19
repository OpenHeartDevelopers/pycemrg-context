# `pycemrg-docs` skill

Gives any pycemrg-suite **library** the same MkDocs + Material documentation site
as the reference library `pycemrg-image-analysis`. The skill is the orchestrator;
the stateless template data lives in its `assets/`.

Source: [`pycemrg-docs/`](https://github.com/OpenHeartDevelopers/pycemrg-context/tree/main/pycemrg-docs).
Installed to `~/.claude/skills/pycemrg-docs/`.

!!! warning "For libraries, not this hub"
    This skill expects a Python library repo (`pyproject.toml` / `setup.py`) and
    builds an API-reference-style site. **This documentation site you're reading
    was adapted by hand from the skill's template** because `pycemrg-context` is
    a context hub, not a Python library — running the skill here would not fit.

## Run it

From inside the **target library's repo root**:

```
/pycemrg-docs
```

It operates on the current working directory and never takes a folder argument.

## The generic / per-library rule

- **Generic — copied byte-for-byte across the suite:** the `mkdocs.yml`
  `theme` / `markdown_extensions` / `plugins` blocks, and both workflow files.
- **Per-library — filled per repo:** `site_name`, `site_description`, `site_url`,
  `repo_url`, `repo_name`, the `palette` colours, and the `nav` contents.

The nav spine order is fixed across the suite: Home → Getting Started → Tutorials
→ Architecture → API Reference → CLI → Developer Guides. Sections a library lacks
are deleted; the order is never changed.

## What it does (high level)

1. **Preflight & inventory** — confirms a library repo, detects fresh scaffold vs.
   refresh, and lists existing docs so nothing out of scope is touched.
2. **Copy machinery** — generic `mkdocs.yml` (fresh scaffold only), both workflows,
   and content skeletons only into paths that don't already exist.
3. **Fill per-library markers** — site fields from the git remote and
   `pyproject.toml`; palette from the **[Docs palette registry](../suite/registry.md)**.
4. **Populate content** — the landing page and API "toolbox map", lifting the
   Design principles and Key domain terms tables from the repo's `CLAUDE.md`
   (inferring from code when `CLAUDE.md` is thin).
5. **Confirm gate, then verify** — one summary for approval, then
   `mkdocs build --strict` (the real CI gate; fails on broken internal links).

## Palette registry

Each library gets a unique Material `primary`/`accent` so the sites are visually
distinct but clearly one family. The table lives in the
**[Library Registry](../suite/registry.md)** under "Docs palette registry". On a
refresh the skill preserves an existing palette; it only assigns from the table
on a fresh scaffold.
