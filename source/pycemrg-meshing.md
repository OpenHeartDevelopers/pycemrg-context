# pycemrg-meshing — API Reference for External Consumers

## Purpose
Python wrapper for the `meshtools3d` and `laplace_solver` C++ binaries used in
cardiac mesh generation. Handles `.par` parameter-file authoring, binary
discovery via `pycemrg.ModelManager`, process invocation with library-path
injection, and typed reporting of the files a run produced.

## Capabilities

- Author, validate, and persist a `meshtools3d`-compatible `.par` file; unknown
  sections or keys raise `KeyError` on both `set` and `load`
- Load an existing `.par` file, merged over defaults so every core key is present
- Build a job that binds segmentation, output directory, output basename, and
  parameter-file path — or reconstruct one from an existing `.par`
- Convert a non-`.inr` segmentation via a caller-injected converter; this
  library imports no image I/O
- Predict the output files a run will produce from the `[output] out_*` flags
- Run `meshtools3d` with run-time path overrides that do not modify the `.par`
- Run `laplace_solver` on an existing CARP mesh with `.vtx` boundary conditions
- Emit a default parameter file from the CLI without writing Python

## Install

```
pip install pycemrg-meshing
```

Depends on `pycemrg` (`ModelManager`, `CommandRunner`), `pyyaml>=6`, `click>=8`.
`pycemrg` is a sibling repo and is not on PyPI — install it first.

Note: the published wheel currently omits the `pycemrg_meshing.logic`
subpackage (no `__init__.py`, so `setuptools.packages.find` skips it) while the
top-level `__init__.py` imports from it. Until fixed, install from source or an
editable checkout.

## Key Entry Points

### MeshingParameters
Import: `from pycemrg_meshing import MeshingParameters`
Purpose: In-memory `.par` file with a validated schema; `set`/`get` reject any
unknown section or key.

```python
MeshingParameters(config_file: str | Path | None = None)

.load(path: str | Path) -> None
.save(path: str | Path) -> Path
.set(section: str, option: str, value: object) -> None
.get(section: str, option: str) -> str
.reset_to_defaults() -> None
.create_dict() -> dict[str, dict[str, str]]
```

Notes: key case is preserved (`optionxform = str`) because the C++ side is
case-sensitive. `save` creates parent directories. Extended keys (see
`EXTENDED_DEFAULTS`) are accepted by `set`/`get` but are only written to disk
once explicitly set; `get` returns their documented default until then.

---

### MeshingJob
Import: `from pycemrg_meshing import MeshingJob`
Purpose: Frozen path contract for one `meshtools3d` run, plus parameter
rendering and output prediction.

```python
MeshingJob.create(segmentation_path, output_dir, output_name: str,
                  parfile_path) -> MeshingJob

MeshingJob.from_segmentation(segmentation_path, output_dir, output_name: str,
                             parfile_path, *,
                             converter: Callable[[Path, Path], Path] | None = None
                             ) -> MeshingJob

MeshingJob.from_parfile(parfile_path) -> MeshingJob

.to_parameters(*, base: MeshingParameters | None = None,
               overrides: Mapping[str, Mapping[str, object]] | None = None
               ) -> MeshingParameters
.write_parfile(*, base=None, overrides=None) -> Path
.expected_outputs(params: MeshingParameters, *, output_dir=None,
                  output_name: str | None = None) -> list[Path]
```

Notes: `from_segmentation` raises `ValueError` for a non-`.inr` input when no
`converter` is given; the converted file lands beside `parfile_path`.
`from_parfile` joins `[segmentation] seg_dir` + `seg_name`. `expected_outputs`
covers CARP ASCII, VTK ASCII, and MEDIT only.

---

### LaplaceSolveJob
Import: `from pycemrg_meshing import LaplaceSolveJob`
Purpose: Frozen path contract for one `laplace_solver` run over an existing
CARP mesh. Unlike `MeshingJob` there is no `.par` carrying these paths, so the
job renders them itself.

```python
LaplaceSolveJob.create(mesh_dir, mesh_name: str, output_dir, output_name: str,
                       *, zero_bc: tuple = (), one_bc: tuple = (),
                       parfile_path=None) -> LaplaceSolveJob

.as_cli_args() -> list[str]
.expected_outputs(options: LaplaceSolveOptions | None = None, *,
                  output_dir=None, output_name: str | None = None) -> list[Path]
```

Notes: `parfile_path` is optional — the `-f` file only carries
`[laplacesolver]` tolerances. Thickness evaluation is ON unless
`LaplaceSolveOptions.no_thickness` is set, and drives most predicted outputs.

---

### MeshtoolsRunner
Import: `from pycemrg_meshing import MeshtoolsRunner`
Purpose: Resolves and invokes `meshtools3d`, injecting the bundled `lib/` on
`DYLD_LIBRARY_PATH` / `LD_LIBRARY_PATH`.

```python
MeshtoolsRunner(binary_path: str | Path | None = None, *,
                model_manager: ModelManager | None = None,
                runner: CommandRunner | None = None,
                logger: logging.Logger | None = None)

.resolve_binary() -> Path
.run(job: MeshingJob, *, overrides: MeshingOverrides | None = None,
     cwd: str | Path | None = None) -> MeshingResult
```

Notes: `job.parfile_path` must already exist — authoring is a separate step.
The `.par` is passed via `-f`; overrides become native `-seg_dir` / `-seg_name`
/ `-out_dir` / `-out_name` flags and do not modify the file. Discovery is
exactly explicit `binary_path` → `ModelManager`; no env-var or `PATH` fallback.

---

### LaplaceRunner
Import: `from pycemrg_meshing import LaplaceRunner`
Purpose: Same construction and discovery as `MeshtoolsRunner`, targeting
`laplace_solver`.

```python
LaplaceRunner(binary_path=None, *, model_manager=None, runner=None, logger=None)

.resolve_binary() -> Path
.run(job: LaplaceSolveJob, *, options: LaplaceSolveOptions | None = None,
     cwd: str | Path | None = None) -> LaplaceSolveResult
```

Notes: mesh, output, and BC flags come from the job; `options` adds only
behavioural toggles. A supplied `parfile_path` must exist or `FileNotFoundError`
is raised before the binary runs.

---

### CLI — `pycemrg-meshing`
Entry point: `pycemrg_meshing.cli:main`

```
pycemrg-meshing [-v] init-par [-o OUTPUT] [--set SECTION.KEY=VALUE ...]
pycemrg-meshing [-v] run PARFILE [--binary PATH] [--cwd DIR]
                    [--seg-dir D] [--seg-name N] [--out-dir D] [--out-name N]
pycemrg-meshing [-v] laplace --mesh-dir D --mesh-name N --out-dir D --out-name N
                    [--zero-bc VTX ...] [--one-bc VTX ...] [-f PARFILE]
                    [--binary PATH] [--cwd DIR] [--vtk] [--vtk-binary]
                    [--potential] [--no-thickness] [--swap-regions]
                    [--thickness-algo N] [--solver-verbose]
```

Notes: `laplace` takes no positional argument; the four `--mesh-*` / `--out-*`
options are all required. `--set` is repeatable and validated against the schema.

## Contracts and Data Structures

### MeshingJob (frozen dataclass)
| Field | Type | Description |
|---|---|---|
| `segmentation_path` | `Path` | Path to the `.inr` segmentation |
| `output_dir` | `Path` | Directory where outputs will be written |
| `output_name` | `str` | Basename without extension (`[output] name`) |
| `parfile_path` | `Path` | Path to the `.par` file to write/read |

### LaplaceSolveJob (frozen dataclass)
| Field | Type | Default | Description |
|---|---|---|---|
| `mesh_dir` | `Path` | — | Directory holding the CARP mesh |
| `mesh_name` | `str` | — | CARP mesh basename |
| `output_dir` | `Path` | — | Output directory |
| `output_name` | `str` | — | Output basename |
| `zero_bc` | `tuple[Path, ...]` | `()` | `.vtx` node-sets held at 0.0 |
| `one_bc` | `tuple[Path, ...]` | `()` | `.vtx` node-sets held at 1.0 |
| `parfile_path` | `Path \| None` | `None` | Optional `-f` GetPot file |

### MeshingOverrides (frozen dataclass)
Run-time overrides for `meshtools3d` paths; `None` means "use the `.par` value".
Values are stored verbatim, never expanded or resolved.

| Field | Type | Default | Emitted flag |
|---|---|---|---|
| `seg_dir` | `str \| None` | `None` | `-seg_dir` |
| `seg_name` | `str \| None` | `None` | `-seg_name` |
| `out_dir` | `str \| None` | `None` | `-out_dir` |
| `out_name` | `str \| None` | `None` | `-out_name` |
| `thickness_algorithm` | `int \| None` | `None` | `--thickness-algorithm` |
| `verbose` | `bool` | `False` | `--verbose` |

`.as_cli_args() -> list[str]` renders only the fields that are set.

### LaplaceSolveOptions (frozen dataclass)
Behavioural toggles only — no paths. `.as_cli_args() -> list[str]`.

| Field | Type | Default | Emitted flag |
|---|---|---|---|
| `no_thickness` | `bool` | `False` | `--no-thickness` |
| `swap_regions` | `bool` | `False` | `--swap-regions` |
| `thickness_algorithm` | `int \| None` | `None` | `--thickness-algorithm` |
| `vtk` | `bool` | `False` | `--vtk` |
| `vtk_binary` | `bool` | `False` | `--vtk-binary` |
| `potential` | `bool` | `False` | `--potential` |
| `verbose` | `bool` | `False` | `--verbose` |

`thickness_algorithm`: 1 = Bishop, 2 = Corrado.

### MeshingResult / LaplaceSolveResult (frozen dataclasses)
| Field | Type | Description |
|---|---|---|
| `outdir` | `Path` | Effective output dir, resolved against the run's cwd |
| `outputs` | `list[OutputFile]` | Files the run was expected to produce |
| `stdout` | `str` | Captured standard output of the binary |

### OutputFile (frozen dataclass)
| Field | Type | Description |
|---|---|---|
| `path` | `Path` | Produced file |
| `size` | `int` | On-disk size in bytes at collection time |

### DEFAULT_VALUES schema (ParamDict)
Core sections and keys, always written by `save`:

| Section | Keys |
|---|---|
| `segmentation` | `seg_dir`, `seg_name`, `mesh_from_segmentation`, `boundary_relabeling` |
| `meshing` | `facet_angle`, `facet_size`, `facet_distance`, `cell_rad_edge_ratio`, `cell_size`, `rescaleFactor` |
| `laplacesolver` | `abs_toll`, `rel_toll`, `itr_max`, `dimKrilovSp`, `verbose` |
| `others` | `eval_thickness` |
| `output` | `outdir`, `name`, `out_medit`, `out_carp`, `out_carp_binary`, `out_vtk`, `out_vtk_binary`, `out_potential` |

### EXTENDED_DEFAULTS schema (ParamDict)
Valid but not written until explicitly set:

| Section | Keys |
|---|---|
| `meshing` | `readTheMesh`, `mesh_dir`, `mesh_name` |
| `others` | `swapregions`, `thickalgo` |
| `output` | `debug_output`, `debug_frequency` |

All values are strings; the C++ side parses them.

### BinaryName (Literal)
`"meshtools3d" | "laplace_solver"` — selects the `models.yaml` entry name via
`pycemrg_meshing.tools.binaries.model_name_for`.

### MacOSGatekeeperError (RuntimeError)
Raised by `resolve_binary()` on macOS whenever the `ModelManager` download path
is taken. Exposes `.binary` and `.install_root`; the message contains the exact
`codesign` commands to run.

## What the Consumer Must Provide

- A `.inr` segmentation, or a `converter` callable `(src: Path, dst: Path) -> Path`
  for `MeshingJob.from_segmentation`. This library never imports image I/O.
- An existing `.par` file before calling `MeshtoolsRunner.run` — the runner does
  not author one. Use `MeshingJob.write_parfile` or the `init-par` CLI first.
- For `laplace_solver`: an existing CARP mesh (`.elem`/`.pts`/`.lon`) and any
  `.vtx` boundary-condition node-sets.
- On macOS: an ad-hoc-signed binary passed as `binary_path=` / `--binary`. The
  automatic download path always fails there by design.
- Optionally a `pycemrg.ModelManager` or `pycemrg.system.CommandRunner` for
  custom manifests, logging, or subprocess behaviour; both are injectable and
  default to the bundled manifest and a plain `CommandRunner`.
- The working directory when relative paths matter — pass `cwd=` explicitly
  rather than relying on the derivation described below.

## Known Constraints

- **macOS always raises `MacOSGatekeeperError`** on the `ModelManager` path.
  Apple Silicon SIGKILLs the unsigned prebuilt arm64 binaries, so the library
  refuses to invoke a freshly downloaded build. Sign once, then pass the path
  explicitly. This is a deliberate stop, not a bug.
- Binary discovery is exactly two paths: explicit `binary_path` → `ModelManager`.
  There is no `MESHTOOLS3D_BIN` env var and no `shutil.which` fallback.
- Platforms with a `models.yaml` entry are exactly `linux-x86_64` and
  `macos-arm64`; anything else raises `UnsupportedPlatformError` unless
  `binary_path` is supplied.
- The working directory is derived, not fixed: explicit `cwd` wins; otherwise an
  absolute primary input dir (`seg_dir` / `mesh_dir`) becomes the cwd; otherwise
  the parfile's parent; otherwise the process cwd. Relative `[output] outdir` is
  resolved against that choice.
- `expected_outputs` is deliberately conservative and feeds
  `CommandRunner(expected_outputs=...)`, which raises `FileNotFoundError`
  post-run if any listed file is missing. Binary CARP/VTK are not enumerated
  because the upstream filenames are undocumented; over-predicting would break
  otherwise-valid runs.
- `MeshingParameters.load` validates on read: a `.par` with vendor-extended or
  custom sections raises `KeyError`.
- Key case is significant. `rescaleFactor`, `dimKrilovSp`, and `readTheMesh` are
  camelCase; `swapregions` and `thickalgo` are lowercase. Do not normalise.
- `CommandRunner.run(env=...)` replaces the entire environment. The runners
  start from `os.environ.copy()` and prepend the bundled `lib/`, so ambient
  variables survive — but a caller passing its own `CommandRunner` must preserve
  that behaviour.
- `pycemrg` ships no `py.typed`, so strict type-checkers report the import as
  untyped.
