# pycemrg Suite — Library Registry

One row per library in the suite. Used by `/pycemrg-build` to produce 
correct install instructions per library.

When a library migrates from clone to PyPI, change the `Distribution` 
column from `clone` to `pypi` — no other edits needed elsewhere.

| Library                | Distribution | Install                                                                                                   |
| ---------------------- | ------------ | --------------------------------------------------------------------------------------------------------- |
| pycemrg                | pypi         | `git clone https://github.com/OpenHeartDevelopers/pycemrg`        |
| pycemrg-image-analysis | clone        | `git clone https://github.com/OpenHeartDevelopers/pycemrg-image-analysis && pip install -e pycemrg-image-analysis` |
| pycemrg-meshing        | clone        | `git clone https://github.com/OpenHeartDevelopers/pycemrg-meshing && pip install -e pycemrg-meshing`               |
| pycemrg-model-creation | clone        | `git clone https://github.com/OpenHeartDevelopers/pycemrg-model-creation && pip install -e pycemrg-model-creation` |

## Canonical branch

All clone-distribution libraries: `main`.

## Import name convention

PyPI/repo name uses hyphens; Python module uses underscores. 
`pycemrg-image-analysis` is imported as `pycemrg_image_analysis`.