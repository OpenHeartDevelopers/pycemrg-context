---
name: pycemrg-docs
description: Scaffold or refresh the MkDocs + Material documentation site for a
  pycemrg-suite library. Run from inside the target library's repo root. Copies
  the suite docs kit, fills per-library values from the repo's CLAUDE.md and code,
  and verifies with a strict build.
---

# pycemrg-docs

Give any [pycemrg-suite](https://github.com/OpenHeartDevelopers) library the same
MkDocs + Material documentation site as the reference library
`pycemrg-image-analysis`. This skill is the orchestrator; the stateless template
data lives in `assets/`. Run it **from inside the target library's repo root** —
it operates on the current working directory and never takes a folder argument.

The bundled templates are referenced relative to this skill's own directory
(`assets/...`). The target files are written relative to the user's cwd.

## The generic / per-library rule (respect it throughout)

- **Generic — copy byte-for-byte, never edit per library:** the `mkdocs.yml`
  `theme` / `markdown_extensions` / `plugins` blocks, and both workflow files.
- **Per-library — fill per repo:** `site_name`, `site_description`, `site_url`,
  `repo_url`, `repo_name`, the `palette` colours, and the `nav` contents.
- The `nav` spine order is fixed across the suite: Home → Getting Started →
  Tutorials → Architecture → API Reference → CLI → Developer Guides. Delete
  sections the library lacks; **never reorder**.

## Step 1 — Preflight

1. Confirm the cwd is a Python library repo root: look for `pyproject.toml` or
   `setup.py`. If neither is present, stop and tell the user to run the skill
   from the library root.
2. Detect **fresh scaffold vs. refresh**: does `mkdocs.yml` and/or `docs/`
   already exist? Record which — it changes the write paths (Step 3) and the
   palette/nav handling (Step 4). Step 2 confirms this with a full inventory.
3. Read the repo's own `CLAUDE.md` if present — it is the preferred source for
   the two content tables (Design principles, Key domain terms). Note whether it
   is rich or thin; a thin/absent `CLAUDE.md` triggers the inference fallback in
   Step 4.
4. Read the git remote (`git remote get-url origin`) and `pyproject.toml`
   (name, description) to derive the site/repo fields.

## Step 2 — Inventory existing docs (do this before writing anything)

List everything already present so the write paths below are decided by fact, not
assumption:

- Does `./mkdocs.yml` exist? Does `./docs/` exist, and what is in it (every file,
  not just the two the skill knows about — `getting-started/`, `tutorials/`,
  `guides/`, `cli/`, custom `api/*` pages)?
- Do `./.github/workflows/docs.yml` / `publish.yml` exist?

Classify the run: **fresh scaffold** (no `mkdocs.yml` and no `docs/`) vs.
**refresh** (either exists). Report the inventory to the user. Everything you find
that the skill does not explicitly write below is **out of scope — never delete,
move, or rewrite it.**

## Step 3 — Copy the machinery

The split below is structural, not discretionary. Generic machinery is safe to
write; content skeletons must never clobber existing content.

**Generic machinery — safe to write/overwrite (it is meant to be identical
suite-wide):**

- `assets/workflows/docs.yml` → `./.github/workflows/docs.yml`
- `assets/workflows/publish.yml` → `./.github/workflows/publish.yml`
  (skip if the repo already publishes to PyPI another way — ask if unsure)
- `assets/mkdocs.yml` → `./mkdocs.yml` **only on a fresh scaffold.** On a
  **refresh**, do **not** copy it; treat it as a merge in Step 4 — preserve the
  existing `nav`, `palette`, and `site_*` fields and only add missing generic
  `theme`/`markdown_extensions`/`plugins` keys.

Note the rename: assets store the workflows flat in `workflows/`; they land in
`.github/workflows/`.

**Content skeletons — copy ONLY into a path that does not already exist:**

- `assets/docs/index.md` → `./docs/index.md`
- `assets/docs/api/index.md` → `./docs/api/index.md`

On a **refresh** where either already exists, do **not** copy the skeleton over
it. Leave the existing file in place and, in Step 5, edit it *in place* to fill
genuine gaps (and only with the user's confirmation). The skeletons are a
starting point for empty repos, never a replacement for written content.

## Step 4 — Fill the per-library markers in `mkdocs.yml`

On a fresh scaffold you are filling the freshly copied template; on a refresh you
are editing the existing `mkdocs.yml` in place (the merge from Step 3). Either
way, leave all generic blocks byte-for-byte identical and only touch the
per-library keys.

- `site_name`, `site_description`, `site_url`, `repo_url`, `repo_name` — derive
  from the git remote and `pyproject.toml`. Site URL follows
  `https://openheartdevelopers.github.io/<repo>/`. On a refresh, keep any real
  existing value; only fill markers/gaps.
- **`palette` primary/accent** — use the palette registry in the suite's
  `LIBRARY_REGISTRY.md` (the "Docs palette registry" table). Look it up at
  `~/.claude/pycemrg-context/LIBRARY_REGISTRY.md` (installed) or in the
  pycemrg-context repo.
  - **Fresh scaffold:** assign the library's registered primary/accent. If the
    library is not in the table, pick a Material primary **not already used** by
    any row and tell the user to add it to the registry.
  - **Refresh:** if the existing `mkdocs.yml` already has a real palette, **read
    and preserve it** — do not overwrite with the registry value. Only fill if
    the palette is still a `FILL-IN` marker.
- `nav` — keep the fixed spine order; never reorder.
  - **Fresh scaffold:** start from the template spine and delete sections the
    library does not have (no tutorials yet → drop the Tutorials block, etc.).
  - **Refresh:** **preserve the existing `nav` entries** — they point at real
    pages. Do not prune sections on a refresh; only add an entry for a section
    you are newly creating.

## Step 5 — Populate content

- `docs/index.md` — fill the four-section skeleton: What this library does /
  Where to go next / Design principles (table) / Key domain terms (table).
- `docs/api/index.md` — group the package's public modules into themed
  Module / What it does / Page tables.
- **Refresh safety:** for any page that already existed (per the Step 2
  inventory), do not regenerate it from the skeleton — edit it in place to fill
  genuine gaps only, and surface the proposed edits at the Step 6 gate. Only
  fully author a page when the skill itself just created it as empty.
- **Source for the two tables:** lift Design principles and Key domain terms from
  the repo's `CLAUDE.md` when it is rich enough.
- **Thin-CLAUDE.md fallback:** if those tables cannot be lifted (thin or absent
  `CLAUDE.md`), infer them from the code (public modules, docstrings, package
  layout) and clearly mark the inferred values as needing confirmation in
  Step 6 — do not silently ship guesses, and do not fail.

## Step 6 — Inference + confirm gate

Present **one** summary before writing the final content: site fields, the chosen
palette (and whether it was assigned or preserved), the proposed contents of both
tables (flagging anything inferred under the fallback), and — on a refresh — an
explicit list of which existing files you propose to edit and a diff of the
changes. Get explicit approval, then write. Never overwrite an existing page
without that approval.

## Step 7 — Verify

1. Run `mkdocs build --strict` from the repo root. This is the real CI gate; it
   **fails on broken internal links**. Report the result.
   - Local build needs `pip install mkdocs-material` (plus `mkdocstrings[python]`
     if the mkdocstrings plugin was enabled in `mkdocs.yml`). Surface this if the
     command is missing rather than assuming it is installed.
2. Grep the written files for leftover `FILL-IN` markers and report any as
   incomplete.

## Step 8 — Closing manual checklist

The skill cannot perform these one-time repo-settings actions. Print them for the
user to do by hand:

- **GitHub Pages:** repo Settings → Pages → Source = "GitHub Actions" (not a
  branch), or `docs.yml` deploys nothing.
- **PyPI:** add the repo secret `PYPI_API_TOKEN` (a project-scoped PyPI token), or
  `publish.yml` cannot upload on release.
- Confirm the site goes live at the `site_url` after the first push to `main`.

## Optional — auto-generate API reference from docstrings

The reference site hand-writes its API pages. To instead generate from docstrings:
uncomment the `mkdocstrings` plugin block in `mkdocs.yml`, append
`mkdocstrings[python]` to the install step in `.github/workflows/docs.yml`, and
render a symbol with `::: package.module.Symbol`. Hand-written and generated pages
mix fine.
