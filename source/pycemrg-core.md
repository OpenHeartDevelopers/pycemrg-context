# pycemrg — API Reference for External Consumers

## Purpose
`pycemrg` is the stable core library for cardiac imaging and electrophysiology
simulation workflows. It provides reusable, stateless components for label
management, asset caching, subprocess execution, output path generation, and
project scaffolding that downstream suite packages depend on.

## Capabilities

- Translate anatomical label names and groups to integer voxel tags for segmentation masks
- Produce comma-separated tag strings for CLI tools such as meshtool
- Cross-map integer labels between two different segmentation standards
- Download, SHA256-verify, unzip, and cache versioned model weights or any binary asset
- Execute external shell commands safely, capture output, and validate expected outputs
- Source a CARPentry `config.sh` to build the full openCARP environment, then run any CARPentry tool
- Generate consistent, prefix-based output file paths and ensure the output directory exists
- Write starter `labels.yaml` and `models.yaml` YAML manifests from bundled templates
- Scaffold a complete project directory (scripts, config, outputs, pyproject.toml, README) for a pycemrg-suite consumer
- Configure the root logger with optional file output from the orchestrator entry point

## Install

```bash
pip install pycemrg
# or for development
pip install -e ".[dev]"
```

Requires Python >= 3.9.

---

## Key Entry Points

### LabelManager
Import: `from pycemrg.data import LabelManager`
Purpose: Loads a `labels.yaml` manifest and translates between human-readable
anatomical names, named groups, and integer voxel values.

```python
LabelManager(config_path: Union[str, Path])

get_value(name: str) -> int
get_name(value: int) -> str
get_values_from_names(names: List[str]) -> List[int]
get_tags_string(names: List[str], separator: str = ",") -> str
```

Notes:
- `get_values_from_names` accepts raw digit strings (e.g. `"5"`) alongside
  named labels and group names, so callers can mix resolved names and raw
  integers in a single call.
- `get_tags_string` flattens nested lists before resolution.
- Group resolution is recursive: groups may reference other groups.

---

### LabelMapper
Import: `from pycemrg.data import LabelMapper`
Purpose: Translates integer tags between two `LabelManager` instances that
represent different segmentation standards, keyed on shared anatomical names.

```python
LabelMapper(source: LabelManager, target: LabelManager)

get_source_to_target_mapping() -> Dict[int, int]
get_source_tags(names: List[str]) -> List[int]
get_target_tags(names: List[str]) -> List[int]
```

Notes:
- `get_source_to_target_mapping` only includes entries where source and target
  values differ; identical-value labels are silently skipped.
- Labels present in source but absent in target are silently skipped.

---

### AssetManager
Import: `from pycemrg.assets import AssetManager`
Purpose: Downloads, SHA256-verifies, unzips, and returns local paths to
versioned assets (model weights, atlases, compiled binaries, etc.) defined
in a YAML manifest.

```python
AssetManager(
    manifest_path: Union[str, Path],
    cache_dir: Union[str, Path, None] = None   # default: ~/.cache/pycemrg
)

get_asset_path(asset_name: str, version: str = "default") -> Path
get_model_path(model_name: str, version: str = "default") -> Path  # backwards-compat alias
```

Notes:
- Supports a `file://` URL scheme for local assets. The path after `file://`
  is resolved relative to the manifest file's parent directory, not CWD.
- On cache hit the download and unzip steps are skipped entirely.
- A hash mismatch on a cached archive triggers a re-download, not an exception.
- `ModelManager` in `pycemrg.models` is a deprecated alias; use `AssetManager`.

---

### CommandRunner
Import: `from pycemrg.system import CommandRunner`
Purpose: Executes external commands without a shell, captures stdout/stderr,
and optionally validates that expected output files were produced.

```python
CommandRunner(logger: Optional[logging.Logger] = None)

run(
    cmd: Sequence[Union[str, Path]],
    expected_outputs: Optional[Sequence[Path]] = None,
    cwd: Optional[Path] = None,
    ignore_errors: Optional[Sequence[str]] = None,
    env: Optional[Dict[str, str]] = None
) -> str
```

Notes:
- Raises `CommandExecutionError` (with `.returncode`, `.stdout`, `.stderr`
  attributes) on non-zero exit, unless the stderr text matches a string in
  `ignore_errors`.
- Raises `FileNotFoundError` if the command succeeds but an expected output
  file is absent.
- `env=None` inherits the current process environment; passing an explicit
  dict replaces the environment entirely.

---

### CarpRunner
Import: `from pycemrg.system import CarpRunner`
Purpose: Wraps `CommandRunner` to source a CARPentry `config.sh` and inject
the full openCARP environment (PATH, LD_LIBRARY_PATH, CARPENTRY_LICENSE,
CARPUTILS_SETTINGS, MPI vars) before every command.

```python
CarpRunner(
    runner: CommandRunner,
    carp_config_path: Union[str, Path],
    logger: Optional[logging.Logger] = None
)

run(
    cmd: Sequence[Union[str, Path]],
    expected_outputs: Optional[Sequence[Path]] = None,
    cwd: Optional[Path] = None,
    ignore_errors: Optional[Sequence[str]] = None
) -> str

reload_environment() -> None
validate_command_exists(command: str) -> bool
get_carp_path(relative_path: str = "") -> Path
get_carputils_settings_path() -> Optional[Path]
get_license_path() -> Optional[Path]

CarpRunner.find_installation(
    search_paths: Optional[Sequence[Path]] = None
) -> Optional[Path]   # classmethod
```

Notes:
- The environment is loaded lazily on first use and cached in `_carp_env`.
  Call `reload_environment()` if `config.sh` changes mid-session.
- Raises `CarpEnvironmentError` (not a generic exception) if any of the four
  required vars (`PATH`, `LD_LIBRARY_PATH`, `CARPENTRY_LICENSE`,
  `CARPUTILS_SETTINGS`) are missing after sourcing.
- Uses `shell=True` with `/bin/bash` specifically to source `config.sh`; all
  subsequent commands delegate to `CommandRunner` with `shell=False`.

---

### OutputManager
Import: `from pycemrg.files import OutputManager`
Purpose: Generates absolute output file paths from a fixed directory and
filename prefix; creates the directory on initialization.

```python
OutputManager(output_dir: Union[str, Path], output_prefix: str)

get_path(suffix: str) -> Path
```

Notes:
- `get_path("_segmentation.nii.gz")` → `<output_dir>/<prefix>_segmentation.nii.gz`
- `suffix` must be a non-empty string; the caller is responsible for including
  the file extension.

---

### ConfigScaffolder
Import: `from pycemrg.files import ConfigScaffolder`
Purpose: Writes starter YAML manifests (`labels.yaml`, `models.yaml`) from
bundled package templates.

```python
ConfigScaffolder()

create_labels_manifest(
    output_path: Union[str, Path] = "labels.yaml",
    overwrite: bool = False,
    num_labels: int = 3,
    num_groups: int = 1
) -> None

create_models_manifest(
    output_path: Union[str, Path] = "models.yaml",
    overwrite: bool = False
) -> None
```

Notes:
- Raises `FileExistsError` if the target file already exists and
  `overwrite=False`.
- Adding a new template requires placing the file in
  `src/pycemrg/files/templates/` and registering it as package data.

---

### ProjectScaffolder
Import: `from pycemrg.files import ProjectScaffolder`
Purpose: Creates a complete starter project directory for a pycemrg-suite
consumer, including `scripts/`, `config/`, `outputs/`, `pyproject.toml`,
`README.md`, `.gitignore`, and an annotated example orchestrator.

```python
ProjectScaffolder()

create_project(
    name: str,
    parent_dir: Union[str, Path] = ".",
    with_src: bool = False,
    force: bool = False
) -> Path
```

Notes:
- `name` must match `[a-z0-9][a-z0-9-]*`; raises `InvalidProjectNameError`
  otherwise.
- `with_src=True` also creates `src/<name>/` with a stub module and adds a
  setuptools `packages.find` block to `pyproject.toml`.
- Raises `FileExistsError` if the target directory is non-empty and
  `force=False`.

---

### setup_logging
Import: `from pycemrg.core.logs import setup_logging`
Purpose: Configures the root logger once from the orchestrator entry point,
with optional structured file output.

```python
setup_logging(
    log_level: int = logging.INFO,
    log_file: Optional[Path] = None
) -> None
```

Notes:
- Clears any pre-existing root logger handlers before adding new ones;
  call this once at program start, not from library code.
- The file handler always logs at `DEBUG` regardless of `log_level`.

---

## Contracts and Data Structures

There are no shared dataclasses or TypedDicts in this library's public API.
All entry points accept primitive types (`str`, `int`, `Path`, standard
collections) and return primitives or `Path` objects.

The YAML manifest schemas consumed by `LabelManager` and `AssetManager` act
as the effective data contracts:

**labels.yaml**
```yaml
labels:
  <name>: <int>   # one entry per anatomical label
groups:
  <group_name>:
    - <name_or_group_name>  # recursive; may reference other groups
```

**assets.yaml / models.yaml**
```yaml
<asset_name>:
  default: <version_key>
  versions:
    <version_key>:
      url: <https://... | file://<relative_path>>
      sha256: <hex_string>          # optional; skip verification if absent
      unzipped_target_path: <str>   # required for remote zip assets
```

---

## What the Consumer Must Provide

- A `labels.yaml` file on disk, constructed ahead of time (scaffold with
  `pycemrg init-labels`).
- An `assets.yaml` / `models.yaml` manifest file on disk for each
  `AssetManager` instance.
- For `CarpRunner`: a valid CARPentry installation with a `config.sh`
  generated by the CARPentry installer.
- A configured `logging.Logger` instance, or acceptance of the default module
  logger that `CommandRunner` and `CarpRunner` create internally.
- Output directory path and filename prefix for `OutputManager`; the class
  creates the directory but does not choose names.

---

## Known Constraints

- The `src/` layout requires `pip install -e .` before any imports work;
  running `python src/pycemrg/...` directly will fail.
- `LabelMapper.get_source_to_target_mapping()` iterates over `source._labels`
  directly, so it only resolves individual labels, not groups.
- `CarpRunner` requires `/bin/bash` to be present; it will not work in
  environments where only `sh` is available.
- `AssetManager` uses `urllib.request.urlretrieve` (no proxy or auth support).
  Large downloads block the calling thread; there is no async interface.
- Most test files under `tests/` are empty stubs. Only `tests/system/`
  contains substantive tests.
- `ModelManager` (`pycemrg.models`) is deprecated; it re-exports `AssetManager`
  via a thin subclass that emits `DeprecationWarning` on construction.
  Scheduled for removal two releases after the deprecation was introduced.
