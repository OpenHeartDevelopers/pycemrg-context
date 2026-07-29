# pycemrg — API Reference for External Consumers

## Purpose
`pycemrg` is the stable core utility library of the pycemrg suite for cardiac
medical image analysis. It provides stateless building blocks — anatomical label
translation, versioned asset fetching/verification, safe external-command
execution, CARPentry environment injection, and config/project scaffolding —
that orchestrators in downstream projects wire together.

Version documented: 0.1.3, plus one uncommitted local fix to
`CommandRunner.run` (see `dry_run` below) that is **not yet in any release**.
Requires Python >= 3.8.

## Install
```bash
pip install pycemrg              # from PyPI
pip install -e /path/to/pycemrg  # editable, from a local checkout
```
Runtime dependencies: `pyyaml>=6,<7`, `click>=8,<9`, `tqdm>=4.64,<5`
(plus `importlib-resources` on Python < 3.9).

The package uses a `src/` layout, so it must be installed (editable or
otherwise) before imports resolve. Installing also puts the `pycemrg` CLI on
PATH.

`src/pycemrg/__init__.py` is empty — there are no top-level re-exports. Always
import from a subpackage (`pycemrg.data`, `pycemrg.assets`, `pycemrg.files`,
`pycemrg.system`, `pycemrg.core`).

## Key Entry Points

### LabelManager
Import: `from pycemrg.data import LabelManager`
Purpose: Load a labels YAML manifest and translate between anatomical names,
named groups, and integer segmentation values.

```python
LabelManager(config_path: Union[str, Path])
get_value(name: str) -> int
get_name(value: int) -> str
get_values_from_names(names: List[str]) -> List[int]
get_tags_string(names: List[str], separator: str = ",") -> str
```
Notes: constructor raises `FileNotFoundError` if the file is absent; missing
`labels:` / `groups:` keys default to empty dicts rather than erroring.
`get_values_from_names` accepts label names, group names, and digit strings
(`"12"` passes through as `12`), resolves groups recursively, and returns a
sorted deduplicated list; an unknown key raises `KeyError` listing available
keys. `get_tags_string` flattens one level of nested lists before resolving.
`get_name` relies on inverting the labels dict, so duplicate integer values
silently collapse.

### LabelMapper
Import: `from pycemrg.data import LabelMapper`
Purpose: Translate integer tags between two different labelling standards by
matching shared anatomical names.

```python
LabelMapper(source: LabelManager, target: LabelManager)
get_source_to_target_mapping() -> Dict[int, int]
get_source_tags(names: List[str]) -> List[int]
get_target_tags(names: List[str]) -> List[int]
```
Notes: the mapping contains only entries where source and target values
*differ* — identical values are omitted, so a missing key means "unchanged",
not "unmapped". Names present in source but absent from target are silently
skipped. Groups are not mapped, only labels.

### AssetManager
Import: `from pycemrg.assets import AssetManager`
Purpose: Download, SHA256-verify, cache, and extract versioned assets (ML
weights, compiled binaries, reference datasets) declared in a YAML manifest.

```python
AssetManager(manifest_path: Union[str, Path],
             cache_dir: Union[str, Path, None] = None)
get_asset_path(asset_name: str, version: str = "default") -> Path
get_model_path(model_name: str, version: str = "default") -> Path   # legacy alias
```
Notes: constructor raises `FileNotFoundError` for a missing manifest and creates
`cache_dir` (default `~/.cache/pycemrg`) eagerly. `get_asset_path` delegates to
`get_model_path`; the latter is the backwards-compatible name. Network download
happens on first call, with a tqdm progress bar; subsequent calls return the
cached path without touching the network. A hash mismatch on a cached archive
deletes it and re-downloads; any failure during download or extraction deletes
the partial archive and raises `RuntimeError`. An omitted `sha256` skips
verification silently. Tar members are checked for path traversal before
extraction and raise `ValueError` if a member escapes the target directory.
Supported archives: `.zip`, `.tar`, `.tar.gz`, `.tgz`, `.tar.bz2`, `.tbz2`,
`.tar.xz`, `.txz`. Unknown asset or version raises `KeyError`; a remote entry
without `unzipped_target_path` raises `ValueError`.

### ModelManager (deprecated)
Import: `from pycemrg.models.manager import ModelManager`
Purpose: Backwards-compatible subclass of `AssetManager`.

Notes: emits a `DeprecationWarning` on construction; scheduled for removal in
release N+2. Use `AssetManager` in new code. Note the full module path —
`pycemrg/models/__init__.py` is empty, so `from pycemrg.models import
ModelManager` raises `ImportError`.

### CommandRunner
Import: `from pycemrg.system import CommandRunner`
Purpose: Execute external tools without a shell, capture output, and validate
that expected artifacts were produced.

```python
CommandRunner(logger: Optional[logging.Logger] = None)
run(cmd: Sequence[Union[str, Path]],
    expected_outputs: Optional[Sequence[Path]] = None,
    cwd: Optional[Path] = None,
    ignore_errors: Optional[Sequence[str]] = None,
    env: Optional[Dict[str, str]] = None,
    dry_run: bool = False) -> str
dry_run(cmd: Sequence[Union[str, Path]]) -> None
```
Notes: `cmd` parts are stringified, so `Path` objects are accepted directly. No
shell is used — globs, pipes, and redirection are not interpreted. A non-zero
exit raises `CommandExecutionError` unless a string from `ignore_errors` appears
in stderr, in which case it is logged as a warning and treated as success.
`expected_outputs` are existence-checked only after a successful exit; missing
files raise `FileNotFoundError`. Passing `env` *replaces* the child environment
entirely rather than merging with the parent; `env=None` inherits it. Returns
captured stdout.

`dry_run=True` short-circuits before the subprocess: it logs
`[dry-run] Would execute: <cmd>` at INFO, returns `""`, launches nothing, and
does **not** validate `expected_outputs` — so a dry run cannot raise. The
standalone `dry_run()` method is equivalent but returns `None`. Prefer the
keyword when toggling a real call site by a flag, the method when you only ever
want to preview.

### CarpRunner
Import: `from pycemrg.system import CarpRunner`
Purpose: Run openCARP / CARPentry tools with the environment produced by
sourcing the installation's `config.sh`.

```python
CarpRunner(runner: CommandRunner,
           carp_config_path: Union[str, Path],
           logger: Optional[logging.Logger] = None)
run(cmd, expected_outputs=None, cwd=None, ignore_errors=None) -> str
carp_env -> Dict[str, str]              # property, cached
installation_root -> Path               # property
reload_environment() -> None
get_carp_path(relative_path: str = "") -> Path
validate_command_exists(command: str) -> bool
get_carputils_settings_path() -> Optional[Path]
get_license_path() -> Optional[Path]
CarpRunner.find_installation(search_paths: Optional[Sequence[Path]] = None) -> Optional[Path]   # classmethod
```
Notes: constructor raises `FileNotFoundError` if `config.sh` is absent, but the
environment is loaded lazily on first `carp_env` access — a broken `config.sh`
surfaces at first command, not at construction. Loading runs
`source <config.sh> && env` through `/bin/bash` with `shell=True`. The parsed
environment must contain `PATH`, `LD_LIBRARY_PATH`, `CARPENTRY_LICENSE`, and
`CARPUTILS_SETTINGS` or `CarpEnvironmentError` is raised. The environment is
cached until `reload_environment()` is called. `run()` delegates to the injected
`CommandRunner` with `env=carp_env`, so the child process sees *only* the
CARPentry environment and `run()` exposes no `env` parameter of its own.
`installation_root` is `config.sh`'s parent directory. `find_installation()`
checks `~/carpentry_bundle`, `~/CARPentry`, `~/opencarp`,
`/opt/carpentry_bundle`, `/opt/CARPentry`, `/usr/local/carpentry_bundle` and
returns the path to `config.sh`, not the installation directory.

### OutputManager
Import: `from pycemrg.files import OutputManager`
Purpose: Build consistent, prefixed absolute output paths for a pipeline run.

```python
OutputManager(output_dir: Union[str, Path], output_prefix: str)
get_path(suffix: str) -> Path
```
Notes: the constructor resolves `output_dir` and creates it immediately
(`mkdir(parents=True, exist_ok=True)`) — instantiating has a filesystem side
effect. `get_path` concatenates prefix and suffix with no separator, so the
suffix must carry its own leading separator and extension (`"_seg.nii.gz"` →
`<dir>/<prefix>_seg.nii.gz`). An empty or non-string suffix raises `ValueError`.
The class does not create the file and knows no pipeline filenames.

### ConfigScaffolder
Import: `from pycemrg.files import ConfigScaffolder`
Purpose: Write starter `models.yaml` / `labels.yaml` manifests.

```python
ConfigScaffolder()
create_models_manifest(output_path: Union[str, Path] = "models.yaml",
                       overwrite: bool = False) -> None
create_labels_manifest(output_path: Union[str, Path] = "labels.yaml",
                       overwrite: bool = False,
                       num_labels: int = 3,
                       num_groups: int = 1) -> None
```
Notes: raises `FileExistsError` unless `overwrite=True`; creates parent
directories. `create_models_manifest` copies the packaged
`models.yaml.template` verbatim — placeholder URLs and hashes, not usable
without editing. `create_labels_manifest` generates content programmatically:
always emits `background: 0`, then `structure_1..structure_N` mapped to `1..N`,
distributed into `group_a`, `group_b`, … in equal chunks.

### ProjectScaffolder
Import: `from pycemrg.files import ProjectScaffolder`
Purpose: Create a starter directory layout for a project consuming the pycemrg
suite.

```python
ProjectScaffolder()
create_project(name: str,
               parent_dir: Union[str, Path] = ".",
               with_src: bool = False,
               force: bool = False) -> Path
```
Notes: `name` must match `^[a-z0-9][a-z0-9-]*$` or `InvalidProjectNameError`
(a `ValueError` subclass, importable from `pycemrg.files.project`) is raised.
Writes `scripts/`, `config/`, `outputs/.gitkeep`, `.gitignore`,
`pyproject.toml`, `README.md`, and `scripts/example_run.py`. With
`with_src=True` it additionally writes `src/<name_with_underscores>/` and adds
a setuptools packages block. Raises `FileExistsError` on a non-empty target
unless `force=True`, which overwrites file-by-file without cleaning. The
generated `pyproject.toml` declares dependencies on `pycemrg`,
`pycemrg-image-analysis`, `pycemrg-meshing`, and `pycemrg-model-creation`.
Returns the absolute project root.

### setup_logging
Import: `from pycemrg.core import setup_logging`
Purpose: Configure the root logger for an orchestrator process.

```python
setup_logging(log_level: int = logging.INFO,
              log_file: Optional[Path] = None) -> None
```
Notes: **removes all existing handlers on the root logger** before installing
its own — call it once, early, from the orchestrator, never from library code.
Console format is `[%(name)s] %(message)s` at `log_level`. If `log_file` is
given, its parent directory is created and a file handler is added at DEBUG
with timestamps and module/function names. `log_file` must be a `Path`
(`.parent` is accessed), not a string.

## CLI

Installed as the `pycemrg` console script (`pycemrg.cli:main`, a `click` group).

```bash
pycemrg init-models  [-o PATH] [--force]
pycemrg init-labels  [-o PATH] [--force] [--num-labels N] [--num-groups N]
pycemrg init NAME    [-p PARENT_DIR] [--with-src] [--force]
```
Notes: `init-models` / `init-labels` catch all exceptions, print them in colour,
and exit 0 regardless — do not rely on their exit code in scripts. `init` exits
2 on an invalid project name and 1 if the directory exists and is non-empty.

## Contracts and Data Structures

There are **no dataclasses, TypedDicts, or NamedTuples** in this library. The
contracts that cross the boundary are YAML file shapes and one exception set.

### Labels manifest (consumed by `LabelManager`)
```yaml
labels:            # Dict[str, int] — anatomical name -> integer value
  LV_myo: 2
  RV_myo: 3
groups:            # Dict[str, List[str]] — group name -> member names
  ventricles:      # members may be label names, digit strings, or other groups
    - LV_myo
    - RV_myo
```
Both top-level keys are optional and default to `{}`.

### Asset manifest (consumed by `AssetManager`)
```yaml
<asset_name>:
  default: <version_key>                # str, required
  versions:
    <version_key>:
      url: str                          # required; http(s) or "file://<relative>"
      unzipped_target_path: str         # required for remote URLs; path inside the archive
      sha256: str                       # optional; verification skipped if absent
```
`file://` URLs are resolved relative to the *manifest file's directory* (not
CWD) and returned directly — `unzipped_target_path` and `sha256` are ignored for
them. For remote URLs the returned path is
`<cache_dir>/<archive-stem>/<unzipped_target_path>`.

### Exceptions
| Exception | Import | Base | Raised by |
|---|---|---|---|
| `CommandExecutionError` | `pycemrg.system` | `RuntimeError` | `CommandRunner.run` on non-zero exit. Carries `.returncode`, `.stdout`, `.stderr`. |
| `CarpEnvironmentError` | `pycemrg.system` | `RuntimeError` | `CarpRunner` when `config.sh` fails to source or required variables are missing. |
| `InvalidProjectNameError` | `pycemrg.files.project` | `ValueError` | `ProjectScaffolder.create_project` on a name failing the pattern. |

Standard exceptions also cross the boundary: `FileNotFoundError` (missing
config/manifest/expected outputs), `KeyError` (unknown label, group, asset, or
version), `FileExistsError` (scaffolding without overwrite), `ValueError` (bad
suffix, unsupported archive, tar traversal, missing `unzipped_target_path`),
`IOError` (SHA256 mismatch), `RuntimeError` (asset download/extract failure).

## What the Consumer Must Provide

This library derives nothing and looks for nothing. The calling code owns:

- **All paths.** Manifest paths, output directories, working directories,
  `config.sh` location, and expected-output paths are arguments. Nothing is
  inferred from a project layout or the current working directory.
- **The YAML manifests themselves.** `pycemrg` can scaffold placeholder
  templates, but real label mappings, asset URLs, and SHA256 hashes are the
  consumer's.
- **Logger configuration.** Modules call `logging.getLogger(__name__)` and never
  configure handlers. The orchestrator calls `setup_logging` (or its own
  equivalent) exactly once. `CommandRunner` and `CarpRunner` accept an injected
  logger.
- **The environment for subprocesses.** `CommandRunner.run(env=...)` replaces
  the child environment wholesale; nothing is merged or defaulted. `pycemrg`
  reads no environment variables of its own.
- **External tools.** `meshtool`, `openCARP`, and anything else invoked must
  already be installed and resolvable — via `PATH`, an explicit `env`, or a
  `CarpRunner` `config.sh`.
- **A CARPentry installation** with a generated `config.sh` if `CarpRunner` is
  used.
- **Cache location and disk budget.** `AssetManager` writes to
  `~/.cache/pycemrg` unless `cache_dir` is passed, and never evicts.
- **Object lifecycle.** Every class is instantiated directly and injected by the
  caller — pass a `CommandRunner` into `CarpRunner`, two `LabelManager`s into
  `LabelMapper`. There are no singletons, no module-level state, no global
  registry.

## Known Constraints

- **`dry_run` does not work in released 0.1.3.** The keyword was added to
  `CommandRunner.run` in 0.1.3 but never read, so `run(dry_run=True)` executed
  the command anyway. Fixed after tagging and **not yet released** — against a
  pinned 0.1.3 from PyPI, use the standalone `CommandRunner.dry_run(cmd)`
  method, which has always worked. Consumers needing the keyword must wait for
  the next release or install from source.
- **0.1.3 stopped logging the command before execution.** Up to 0.1.2,
  `CommandRunner.run` emitted `Executing command: <cmd>` at INFO; that line was
  removed. Nothing is now logged until stdout/stderr at DEBUG, so consumers
  whose run logs showed the invoked command line will find them silent after
  upgrading.
- **`from pycemrg.models import ModelManager` fails.** `models/__init__.py` is
  empty despite the README showing that import. Use
  `from pycemrg.models.manager import ModelManager` (deprecated) or, preferably,
  `from pycemrg.assets import AssetManager`.
- **`src/` layout:** the package must be pip-installed before imports resolve;
  running scripts against the source tree without installing fails.
- **`CarpRunner` is bash/Linux-only.** It shells out to `/bin/bash` with
  `shell=True` to source `config.sh`, and uses `which` for command validation.
- **Constructors have filesystem side effects.** `OutputManager.__init__`
  creates the output directory; `AssetManager.__init__` creates the cache
  directory. Neither is lazy.
- **`CarpRunner.run` does not expose `env`.** It always injects `carp_env`, so
  the child process loses the parent environment entirely, including variables
  the consumer may have set. The env is cached — call `reload_environment()`
  after editing `config.sh` mid-session.
- **`AssetManager` downloads over the network on first call** and writes a tqdm
  progress bar. In CI, pre-warm the cache or point `cache_dir` at a prepared
  location.
- **`AssetManager` does not verify that extraction produced
  `unzipped_target_path`.** It returns the composed path whether or not the file
  exists afterwards.
- **Label values must be unique** for `get_name` to be reliable; the reverse map
  is built by inverting the dict, so duplicate integers silently collapse.
- **`get_values_from_names` treats digit strings as literal values**, bypassing
  the manifest — `"7"` resolves to `7` even if no label has that value.
- **CLI config commands swallow errors** and exit 0; only `pycemrg init` uses
  meaningful exit codes.
- **`LabelMapper.get_source_to_target_mapping` reads `source._labels`**, a
  private attribute. Anything subclassing or substituting `LabelManager` must
  preserve it.
- **Adding a bundled template** requires placing it in
  `src/pycemrg/files/templates/` and registering it as package data in
  `pyproject.toml` (`[tool.setuptools.package-data]`).
- **Breaking changes to these APIs propagate downstream** to
  `pycemrg-image-analysis`, `pycemrg-meshing`, `pycemrg-model-creation`, and
  `pycemrg-interpolation`.
