# pycemrg-meshing — API Reference for External Consumers

## Purpose
Python wrapper for the `meshtools3d` and `laplace_solver` C++ binaries used in
cardiac mesh generation workflows. Handles parameter-file authoring, binary
discovery via `pycemrg.ModelManager`, and process invocation with correct
library-path injection.

## Capabilities

- Author and persist a `meshtools3d`-compatible `.par` parameter file with
  validated section/key schema
- Load, override, and round-trip an existing `.par` file without losing unknown
  sections being silently introduced
- Build a structured job description that binds a segmentation path, output
  directory, and output basename, then render it to a parameter file in one call
- Convert a non-`.inr` segmentation to `.inr` via an injected converter before
  constructing the job (converter is caller-supplied; this library imports no
  image I/O)
- Enumerate the output files a job is expected to produce given the parameter
  flags (`out_carp`, `out_vtk`, `out_medit`)
- Execute `meshtools3d` against a parameter file, resolving the binary either
  from an explicit path or via `pycemrg.ModelManager` against the bundled
  `models.yaml`
- Execute `laplace_solver` against a parameter file using the same resolution
  and library-injection mechanism
- Emit a default parameter file from the CLI without writing any Python

## Install

```
pip install pycemrg-meshing
```

Requires `pycemrg` (for `ModelManager` and `CommandRunner`) and `pyyaml>=6`.

## Key Entry Points

### MeshingParameters
Import: `from pycemrg_meshing import MeshingParameters`  
Purpose: In-memory representation of a `meshtools3d` `.par` file with a
validated schema; every `set`/`get` call rejects unknown section or key names.

```python
MeshingParameters(config_file: str | Path | None = None)

.load(path: str | Path) -> None
.save(path: str | Path) -> Path
.set(section: str, option: str, value: object) -> None
.get(section: str, option: str) -> str
.reset_to_defaults() -> None
.create_dict() -> dict[str, dict[str, str]]
```

Notes: `optionxform = str` is enforced; case-sensitive keys (`rescaleFactor`,
`dimKrilovSp`) are preserved. `load` validates against the schema and merges
over defaults, so the result always contains every required key.

---

### MeshingJob
Import: `from pycemrg_meshing import MeshingJob`  
Purpose: Frozen dataclass that binds a segmentation path, output directory,
output basename, and parameter-file path; provides helpers to render and
persist the parameter file and to predict output files.

```python
MeshingJob.create(
    segmentation_path: str | Path,
    output_dir: str | Path,
    output_name: str,
    parfile_path: str | Path,
) -> MeshingJob

MeshingJob.from_segmentation(
    segmentation_path: str | Path,
    output_dir: str | Path,
    output_name: str,
    parfile_path: str | Path,
    *,
    converter: Callable[[Path, Path], Path] | None = None,
) -> MeshingJob

.to_parameters(
    *,
    base: MeshingParameters | None = None,
    overrides: Mapping[str, Mapping[str, object]] | None = None,
) -> MeshingParameters

.write_parfile(
    *,
    base: MeshingParameters | None = None,
    overrides: Mapping[str, Mapping[str, object]] | None = None,
) -> Path

.expected_outputs(params: MeshingParameters) -> list[Path]
```

Notes: `from_segmentation` raises `ValueError` if the input is not `.inr` and
no `converter` is provided. `expected_outputs` covers CARP ASCII, VTK ASCII,
and MEDIT only; binary variants and the Laplace potential field are not
enumerated.

---

### MeshtoolsRunner
Import: `from pycemrg_meshing import MeshtoolsRunner`  
Purpose: Resolves and invokes the `meshtools3d` binary; injects
`DYLD_LIBRARY_PATH` / `LD_LIBRARY_PATH` for the bundled `lib/` directory.

```python
MeshtoolsRunner(
    binary_path: str | Path | None = None,
    *,
    model_manager: ModelManager | None = None,
    runner: CommandRunner | None = None,
    logger: logging.Logger | None = None,
)

.resolve_binary() -> Path

.run(
    par_path: str | Path,
    *,
    cwd: str | Path | None = None,
    extra_args: Sequence[str] | None = None,
) -> Path
```

Notes: `run` returns the resolved `[output] outdir` from the parameter file.
If `outdir` is relative it is resolved against the parent of `par_path`. Binary
discovery order: explicit `binary_path` → `ModelManager.get_model_path` against
the bundled `models.yaml`; no `shutil.which` fallback, no env-var override.

---

### LaplaceRunner
Import: `from pycemrg_meshing import LaplaceRunner`  
Purpose: Identical interface to `MeshtoolsRunner` but targets the
`laplace_solver` binary.

```python
LaplaceRunner(
    binary_path: str | Path | None = None,
    *,
    model_manager: ModelManager | None = None,
    runner: CommandRunner | None = None,
    logger: logging.Logger | None = None,
)

.run(par_path: str | Path, *, cwd: str | Path | None = None,
     extra_args: Sequence[str] | None = None) -> Path
```

---

### CLI — `pycemrg-meshing`
Entry point: `pycemrg_meshing.cli:main`

```
pycemrg-meshing init-par [-o OUTPUT] [--set SECTION.KEY=VALUE ...]
pycemrg-meshing run      PARFILE [--binary PATH] [--cwd DIR]
pycemrg-meshing laplace  PARFILE [--binary PATH] [--cwd DIR]
```

## Contracts and Data Structures

### MeshingJob (frozen dataclass)
| Field | Type | Description |
|---|---|---|
| `segmentation_path` | `Path` | Absolute path to the `.inr` segmentation |
| `output_dir` | `Path` | Directory where outputs will be written |
| `output_name` | `str` | Basename without extension (`[output] name`) |
| `parfile_path` | `Path` | Path to the `.par` file to write/read |

### DEFAULT_VALUES schema (ParamDict)
Sections and their keys accepted by `MeshingParameters.set`/`get`:

| Section | Keys |
|---|---|
| `segmentation` | `seg_dir`, `seg_name`, `mesh_from_segmentation`, `boundary_relabeling` |
| `meshing` | `facet_angle`, `facet_size`, `facet_distance`, `cell_rad_edge_ratio`, `cell_size`, `rescaleFactor` |
| `laplacesolver` | `abs_toll`, `rel_toll`, `itr_max`, `dimKrilovSp`, `verbose` |
| `others` | `eval_thickness` |
| `output` | `outdir`, `name`, `out_medit`, `out_carp`, `out_carp_binary`, `out_vtk`, `out_vtk_binary`, `out_potential` |

All values are strings; the C++ side parses them.

### BinaryName (Literal)
`"meshtools3d" | "laplace_solver"` — used by `tools.binaries` helpers to select
the correct `models.yaml` entry name.

## What the Consumer Must Provide

- A `.inr` segmentation file (or a `converter` callable that produces one).
- A `pycemrg.ModelManager` instance or a `binary_path` pointing to the binary,
  unless the bundled `models.yaml` already registers a build for the running
  platform.
- A `pycemrg.system.CommandRunner` if custom logging or subprocess behaviour is
  required (otherwise the default `CommandRunner` is used).
- If using `from_segmentation` with a non-`.inr` input: a `converter` with
  signature `(src: Path, dst: Path) -> Path`; this library never imports image
  I/O libraries itself.
- Output directory creation is handled by `MeshingParameters.save`
  (`mkdir -p`); the `[output] outdir` directory itself is created by the
  `meshtools3d` binary at runtime.

## Known Constraints

- Supported platforms for binary resolution via `ModelManager`: Linux x86_64
  and macOS arm64. Any other platform raises `UnsupportedPlatformError` unless
  `binary_path` is supplied explicitly.
- `expected_outputs` does not enumerate binary CARP (`.elembc`), binary VTK, or
  the Laplace potential field — those require the caller to inspect the
  parameter file directly.
- The runners call `CommandRunner.run(env=...)` which replaces the entire
  process environment. The library starts from `os.environ.copy()` and prepends
  the bundled `lib/` directory; other ambient env vars are preserved.
- `MeshingParameters.load` validates against the schema on read. A `.par` file
  with custom / vendor-extended sections will raise `KeyError`.
