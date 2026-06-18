# pycemrg Suite — Library Registry

One row per library in the suite. Used by `/pycemrg-build` to produce 
correct install instructions per library.

When a library migrates from clone to PyPI, change the `Distribution` 
column from `clone` to `pypi` — no other edits needed elsewhere.

| Library                | Distribution | Install                                                                                                   |
| ---------------------- | ------------ | --------------------------------------------------------------------------------------------------------- |
| pycemrg                | clone         | `git clone https://github.com/OpenHeartDevelopers/pycemrg && pip install -e pycemrg`        |
| pycemrg-image-analysis | clone        | `git clone https://github.com/OpenHeartDevelopers/pycemrg-image-analysis && pip install -e pycemrg-image-analysis` |
| pycemrg-meshing        | clone        | `git clone https://github.com/OpenHeartDevelopers/pycemrg-meshing && pip install -e pycemrg-meshing`               |
| pycemrg-model-creation | clone        | `git clone https://github.com/OpenHeartDevelopers/pycemrg-model-creation && pip install -e pycemrg-model-creation` |
| pycemrg-interpolation | clone        | `git clone https://github.com/OpenHeartDevelopers/pycemrg-interpolation && pip install -e pycemrg-interpolation` |

## Docs palette registry

Each suite library gets a unique MkDocs Material `primary`/`accent` colour so the
sites are visually distinct but clearly one family. Used by the `pycemrg-docs`
skill when scaffolding a fresh docs site. Colours are spread around the wheel
(red → amber → teal → indigo) for at-a-glance distinction. On a docs **refresh**
the skill preserves a site's existing palette; it only assigns from this table on
a **fresh scaffold**. Add a row when a library joins the suite, keeping each
primary unique.

| Library                | Primary | Accent  |
| ---------------------- | ------- | ------- |
| pycemrg                | indigo  | blue    |
| pycemrg-image-analysis | red     | *(existing — preserve)* |
| pycemrg-meshing        | teal    | cyan    |
| pycemrg-model-creation | amber   | orange  |
| pycemrg-interpolation  | purple  | deep purple |

## Canonical branch

All clone-distribution libraries: `main`.

## Import name convention

PyPI/repo name uses hyphens; Python module uses underscores. 
`pycemrg-image-analysis` is imported as `pycemrg_image_analysis`.