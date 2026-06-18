# pycemrg — API Reference for External Consumers

## Purpose
`pycemrg` is the stable core utility library for cardiac medical image analysis
workflows. It provides stateless building blocks — label translation, asset
fetching/verification, safe external-command execution, and output/config
scaffolding — that orchestrators in downstream projects wire together.

## Capabilities
- Translate cardiac anatomical names (e.g. `LV_myo`) to/from integer segmentation labels.
- Resolve named groups of labels (recursively) into sorted integer lists.
- Build comma-separated tag strings for CLI tools such as `meshtool`.
- Map labels between two different labelling standards by shared anatomical name.
- Download, SHA256-verify, cache, and extract versioned assets (ML weights, binaries, datasets) into `~/.cache/pycemrg/`.
- Resolve local assets via a `file://` manifest URL scheme.
- Run external shell commands safely (no shell), with output capture and expected-output validation.
- Run CARPentry/openCARP tools with the full sourced `config.sh` environment injected.
- Generate consistent prefixed output file paths for a pipeline.
- Scaffold starter `labels.yaml` / `models.yaml` manifests and whole consumer-project skeletons.

## Install
```bash
pip install pycemrg              # from PyPI / registry
pip install -e /path/to/pycemrg  # editable, from a local checkout
```
The `src/` layout requires an install (editable or otherwise) before imports
resolve; running scripts directly against the source tree without installing
will fail. The CLI entry point `pycemrg` is also installed.

## Key Entry Points

### LabelManager
Import: `from pycemrg.data import LabelManager`
Purpose: Load a labels YAML manifest and translate between names, groups, and integer values.

```python
LabelManager(config_path: Union[str, Path])
get_value(name: str) -> int
get_name(value: int) -> str
get_values_from_names(names: List[str]) -> List[int]
get_tags_string(names: List[str], separator: str = ",") -> str
```
Notes: `get_values_from_names` accepts raw digit strings (`"5"`), label names,
and group names; groups resolve recursively. Unknown names raise `KeyError`.
Missing config file raises `FileNotFoundError`. `get_tags_string` flattens one
level of nested lists.

### LabelMapper
Import: `from pycemrg.data import LabelMapper`
Purpose: Translate integer tags between a source and target labelling standard by shared name.

```python
LabelMapper(source: LabelManager, target: LabelManager)
get_source_to_target_mapping() -> Dict[int, int]
get_source_tags(names: List[str]) -> List[int]
get_target_tags(names: List[str]) -> List[int]
```
Notes: `get_source_to_target_mapping` only includes entries whose source and
target values differ; names present in source but absent in target are skipped.

### AssetManager
Import: `from pycemrg.assets import AssetManager`
Purpose: Download, verify, cache, and extract versioned assets described in a YAML manifest.

```python
AssetManager(manifest_path: Union[str, Path], cache_dir: Union[str, Path, None] = None)
get_asset_path(asset_name: str, version: str = "default") -> Path
get_model_path(model_name: str, version: str = "default") -> Path   # legacy alias
```
Notes: Caches to `~/.cache/pycemrg/` unless `cache_dir` is given. `file://` URLs
resolve relative to the manifest's parent directory (not CWD). SHA256 is verified
when present in the manifest; a mismatch on a cached archive triggers re-download.
Tar extraction rejects members that escape the target directory. Supports
`.zip`, `.tar`, `.tar.gz/.tgz`, `.tar.bz2/.tbz2`, `.tar.xz/.txz`. Missing manifest
raises `FileNotFoundError`; unknown asset/version raises `KeyError`.

### ModelManager (deprecated)
Import: `from pycemrg.models.manager import ModelManager`
Purpose: Deprecated subclass of `AssetManager`; emits `DeprecationWarning` on construction.
Notes: New code must use `AssetManager`. Scheduled for removal in release N+2.

### CommandRunner
Import: `from pycemrg.system import CommandRunner`
Purpose: Execute external commands safely (without a shell) and validate results.

```python
CommandRunner(logger: Optional[logging.Logger] = None)
run(cmd: Sequence[Union[str, Path]],
    expected_outputs: Optional[Sequence[Path]] = None,
    cwd: Optional[Path] = None,
    ignore_errors: Optional[Sequence[str]] = None,
    env: Optional[Dict[str, str]] = None) -> str
```
Notes: Returns captured stdout. Non-zero exit raises `CommandExecutionError`
(carrying `returncode`, `stdout`, `stderr`) unless a substring in `ignore_errors`
matches stderr. Missing `expected_outputs` raises `FileNotFoundError`. If `env`
is provided the subprocess sees only that environment.

### CarpRunner
Import: `from pycemrg.system import CarpRunner`
Purpose: Run CARPentry/openCARP tools with the full environment sourced from `config.sh`.

```python
CarpRunner(runner: CommandRunner, carp_config_path: Union[str, Path],
           logger: Optional[logging.Logger] = None)
run(cmd, expected_outputs=None, cwd=None, ignore_errors=None) -> str
reload_environment() -> None
validate_command_exists(command: str) -> bool
get_carp_path(relative_path: str = "") -> Path
get_carputils_settings_path() -> Optional[Path]
get_license_path() -> Optional[Path]
find_installation(search_paths: Optional[Sequence[Path]] = None) -> Optional[Path]  # classmethod
carp_env -> Dict[str, str]            # property, cached
installation_root -> Path             # property
```
Notes: Delegates execution to the injected `CommandRunner` with the sourced env.
Sources `config.sh` via `/bin/bash` and caches the result; call
`reload_environment()` if `config.sh` changes mid-session. Requires `PATH`,
`LD_LIBRARY_PATH`, `CARPENTRY_LICENSE`, and `CARPUTILS_SETTINGS` to be present or
raises `CarpEnvironmentError`. Missing config file raises `FileNotFoundError`.

### OutputManager
Import: `from pycemrg.files import OutputManager`
Purpose: Generate consistent absolute output paths from a directory and prefix.

```python
OutputManager(output_dir: Union[str, Path], output_prefix: str)
get_path(suffix: str) -> Path
```
Notes: Creates `output_dir` on construction (resolved to absolute). `get_path`
concatenates prefix + suffix (suffix must include any separator and extension,
e.g. `"_segmentation.nii.gz"`); empty/non-string suffix raises `ValueError`.

### ConfigScaffolder
Import: `from pycemrg.files import ConfigScaffolder`
Purpose: Write starter `labels.yaml` / `models.yaml` manifests from bundled templates.

```python
ConfigScaffolder()
create_models_manifest(output_path="models.yaml", overwrite=False)
create_labels_manifest(output_path="labels.yaml", overwrite=False,
                       num_labels=3, num_groups=1)
```
Notes: Writing over an existing file without `overwrite=True` raises
`FileExistsError`. `models.yaml` comes from a bundled package template;
`labels.yaml` is generated programmatically with placeholder labels/groups.

### ProjectScaffolder
Import: `from pycemrg.files import ProjectScaffolder`
Purpose: Create a starter directory layout for a project consuming the pycemrg suite.

```python
ProjectScaffolder()
create_project(name: str, parent_dir: Union[str, Path] = ".",
               with_src: bool = False, force: bool = False) -> Path
```
Notes: `name` must match `[a-z0-9][a-z0-9-]*` or raises `InvalidProjectNameError`.
Writing into an existing non-empty directory without `force=True` raises
`FileExistsError`. Creates `scripts/`, `config/`, `outputs/`, `pyproject.toml`,
`README.md`, and an example orchestrator; `with_src` adds `src/<name>/`.

### setup_logging
Import: `from pycemrg.core import setup_logging`
Purpose: Configure the root logger once, from the orchestrator.

```python
setup_logging(log_level: int = logging.INFO, log_file: Optional[Path] = None) -> None
```
Notes: Clears existing root handlers to avoid duplicate output. Console handler
is always added; an optional file handler logs at DEBUG with a richer format.

### CLI
Entry point: `pycemrg` (installed console script). Subcommands:
- `pycemrg init-labels -o config/labels.yaml [--num-labels N --num-groups N --force]`
- `pycemrg init-models -o config/models.yaml [--force]`
- `pycemrg init <name> [--path DIR --with-src --force]`

## Contracts and Data Structures
`pycemrg` does not export dataclasses or TypedDicts; its contracts are YAML
manifests and exception types.

- Labels manifest (`labels.yaml`): top-level `labels:` mapping `name -> int`, and
  optional `groups:` mapping `group_name -> list[name|group]` (recursive).
- Assets manifest (`models.yaml`): `asset_name -> { default: <version_key>,
  versions: { <version_key>: { url, sha256, unzipped_target_path } } }`. `url`
  may be `http(s)://...` or `file://<relative-to-manifest>`.
- Exceptions: `CommandExecutionError(message, returncode, stdout, stderr)` and
  `CarpEnvironmentError` (`from pycemrg.system`); `InvalidProjectNameError`
  (`from pycemrg.files.project`).

## What the Consumer Must Provide
This library is orchestration-free; the calling code is responsible for:
- All file paths: manifest paths, config paths, output directories, `config.sh` path.
- The YAML manifest contents (labels and assets).
- Constructing and injecting collaborators: pass a `CommandRunner` into `CarpRunner`.
- Logger setup and policy (call `setup_logging`, or pass a `logging.Logger`).
- Environment variables for subprocesses — nothing is read from ambient env unless
  the consumer passes `env=None` to `CommandRunner.run` to inherit it.
- A working CARPentry installation with a valid `config.sh` for `CarpRunner`.

## Known Constraints
- `src/` layout: must `pip install` before imports work; running source files directly fails.
- `AssetManager` `file://` paths resolve relative to the manifest's parent, not CWD.
- `CarpRunner` uses `shell=True` with `/bin/bash` to source `config.sh`; the env is
  cached after first load — `reload_environment()` is required after editing `config.sh`.
- `CarpRunner` requires four env vars present in the sourced environment or it raises
  `CarpEnvironmentError` (not a generic exception).
- `get_values_from_names` mixes raw digit strings with named labels in one call.
- `ModelManager` is a deprecated alias for `AssetManager` (warns on construct, removal N+2).
- Adding a new bundled template requires placing it in `src/pycemrg/files/templates/`
  and registering it as package data.
- Breaking changes to these public APIs propagate to downstream consumers:
  `pycemrg-image-analysis`, `pycemrg-model-creation`, `pycemrg-interpolation`.
