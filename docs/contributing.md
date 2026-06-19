# Contributing

This repo is the suite's **consumer-side context**. It does not accept
contributions to library *code* — that goes through normal GitHub Issues/PRs in
the individual library repos. What you maintain here is the routing data and the
generated API references.

## Adding a library to the suite

1. Add a row to
   [`LIBRARY_REGISTRY.md`](https://github.com/OpenHeartDevelopers/pycemrg-context/blob/main/LIBRARY_REGISTRY.md)
   — name, distribution mode (`clone` or `pypi`), and install command.
2. Add a row to the **Docs palette registry** table in the same file, keeping
   each `primary` colour unique.
3. Add a section to
   [`PYCEMRG_SUITE.md`](https://github.com/OpenHeartDevelopers/pycemrg-context/blob/main/PYCEMRG_SUITE.md)
   — one-paragraph purpose plus a task-phrased capabilities list (until CI
   generates this).
4. Wire up the [`export-api`](tools/export-api.md) workflow in the new library's
   repo so its `source/{library}.md` reference lands here on the next push to
   `main`.

Both registry files are the **canonical source** — the
[Overview](suite/overview.md) and [Library Registry](suite/registry.md) pages on
this site include them verbatim, so editing the root files updates the site.

## Distribution mode changes

When a library migrates from clone to PyPI, change its `Distribution` column in
`LIBRARY_REGISTRY.md` from `clone` to `pypi`. No other edits are needed —
`/pycemrg-build` reads that column to choose between a `pip install` and a
`git clone`.

## Maintenance ownership

| File | Maintained by |
|---|---|
| `LIBRARY_REGISTRY.md` | Hand |
| `PYCEMRG_SUITE.md` | CI (future) / hand |
| `source/*.md` | CI on push to `main` in each library repo |
| `commands/*.md`, `pycemrg-docs/` | Hand |

## Building the docs locally

```bash
pip install mkdocs-material
mkdocs serve      # live preview at http://127.0.0.1:8000
mkdocs build --strict   # the CI gate — fails on broken internal links
```

The site deploys to GitHub Pages automatically via
`.github/workflows/docs.yml` on every push to `main` that touches `docs/`,
`mkdocs.yml`, or the canonical registry files.

!!! note "One-time repo setting"
    GitHub Pages must be set to deploy from Actions: repo **Settings → Pages →
    Source = "GitHub Actions"**, or the workflow deploys nothing.
