# pycemrg-model-creation — API Reference for External Consumers

## Purpose
A high-level Pythonic framework that wraps CARPentry/openCARP and meshing CLI
tools to take a cardiac NIfTI segmentation through to a simulation-ready mesh
with boundary surfaces and Universal Ventricular Coordinates (UVC). It separates
stateless scientific logic from explicit path contracts so orchestrators control
all file I/O.

## Capabilities
- Generate a volumetric CARP mesh (`.pts`/`.elem`) from a NIfTI segmentation
- Extract the myocardium from a raw heart mesh and relabel element tags
- Extract ventricular boundary surfaces (epi, LV endo, RV endo, septum, base)
- Extract atrial (LA/RA) boundary surfaces
- Produce VTX boundary-node files needed for UVC and submesh mapping
- Carve a BiV or atrial submesh from a four-chamber mesh and map VTX files into it
- Compute ventricular UVC coordinates (apico-basal, transmural, rotational, ventricular id) via `mguvc`
- Build standardized output directory layouts and fully-populated path contracts from a base directory
- Report per-label mesh volumes from CARP or VTK meshes (CLI)

## Install
```bash
pip install -e .            # from repo root
```
Requires `pycemrg` (provides `CarpRunner`, `CommandRunner`, `LabelManager`),
`numpy`, `pyvista`, `pyyaml`. External binaries `meshtool`, `meshtools3d`, and
CARPentry tools (`mguvc`, etc.) must be installed separately.

Import convenience: `from pycemrg_model_creation import TagsConfig, SurfaceLogic, CarpWrapper, MeshtoolWrapper`.

## Key Entry Points

### MeshingLogic
Import: `from pycemrg_model_creation.logic import MeshingLogic`
Purpose: build a volumetric mesh from a NIfTI segmentation via meshtools3d.
```python
MeshingLogic(meshtools3d_wrapper: Meshtools3DWrapper)
run_meshing(paths: MeshingPaths, meshing_params: Dict[str, Any] = None, cleanup: bool = True) -> None
```
Notes: converts NIfTI→INR, writes a `.par` file, runs meshtools3d. `meshing_params`
overrides defaults (e.g. `{'meshing': {'facet_size': '0.7'}}`). Deletes intermediate
`.inr`/`.par` when `cleanup=True`.

### RefinementLogic
Import: `from pycemrg_model_creation.logic import RefinementLogic`
Purpose: extract myocardium tags from a raw mesh and relabel them.
```python
RefinementLogic(meshtool_wrapper: MeshtoolWrapper)
run_myocardium_postprocessing(paths: MeshPostprocessingPaths, myocardium_tags: List[int],
                              tag_mapping: Dict[int, int], simplify: bool = False) -> None
```
Notes: topology simplification only runs if `simplify=True` and the meshtool build
supports it; otherwise skipped silently.

### SurfaceLogic
Import: `from pycemrg_model_creation.logic import SurfaceLogic`
Purpose: extract boundary surfaces and VTX files, carve submeshes, map VTX into them.
```python
SurfaceLogic(meshtool: MeshtoolWrapper, label_manager: LabelManager)
run_ventricular_extraction(paths: VentricularSurfacePaths) -> None
run_atrial_extraction(paths: AtrialSurfacePaths, tags: TagsConfig, chamber: Chamber) -> None
run_biv_mesh_extraction(paths: BiVMeshPaths, tags: TagsConfig) -> None
run_atrial_mesh_extraction(paths: AtrialMeshPaths, tags: TagsConfig, chamber: Chamber) -> None
run_all(paths: UVCSurfaceExtractionPaths, tags: TagsConfig,
        ventricular_files_to_map=None, la_files_to_map=None, ra_files_to_map=None) -> None
```
Notes: requires a `LabelManager` from `pycemrg`. `chamber` must be `Chamber.LA` or
`Chamber.RA`. Raises `SurfaceExtractionError` / `SurfaceIdentificationError`.

### UvcLogic
Import: `from pycemrg_model_creation.logic import UvcLogic`
Purpose: compute ventricular UVC coordinates by running `mguvc`.
```python
UvcLogic(carp_wrapper: CarpWrapper)
run_ventricular_uvc_calculation(paths: VentricularUVCPaths, lv_tag: int, rv_tag: int, np: int = 1) -> None
```
Notes: validates inputs, generates an etags script, runs `mguvc`. `mguvc` requires
the BiV mesh and all VTX files in one directory with exact standard names (see
constraints). Raises `FileNotFoundError` / `RuntimeError`.

### Path Builders
Import: `from pycemrg_model_creation.logic import MeshingPathBuilder, ModelCreationPathBuilder`
Purpose: construct standardized directory layouts and fully-populated path contracts.
```python
MeshingPathBuilder(output_dir: Union[Path, str])
  .build_meshing_paths(...) -> MeshingPaths
  .build_postprocessing_paths(...) -> MeshPostprocessingPaths
ModelCreationPathBuilder(output_dir: Union[Path, str])
  .build_ventricular_paths(mesh_base_path: Path) -> VentricularSurfacePaths
  .build_atrial_paths(...) -> AtrialSurfacePaths
  .build_biv_mesh_paths(...) -> BiVMeshPaths
  .build_atrial_mesh_paths(...) -> AtrialMeshPaths
  .build_ventricular_uvc_paths(...) -> VentricularUVCPaths
  .build_all(...) -> UVCSurfaceExtractionPaths
```
Notes: `MeshingPathBuilder` owns meshing/refinement; `ModelCreationPathBuilder`
owns surface/UVC. They are independent. `ModelCreationPathBuilder.__init__` creates
subdirectories immediately; `build_ventricular_uvc_paths` backs up any existing
`uvc/` directory at build time.

### Tool Wrappers
Import: `from pycemrg_model_creation.tools import CarpWrapper, MeshtoolWrapper, Meshtools3DWrapper`
```python
CarpWrapper(carp_runner: CarpRunner)
MeshtoolWrapper.from_system_path(logger=None, meshtool_install_dir: Optional[Path] = None) -> MeshtoolWrapper
MeshtoolWrapper.from_carp_runner(carp_runner: CarpRunner) -> MeshtoolWrapper
Meshtools3DWrapper(runner: CommandRunner, meshtools3d_path: Path)
```
Notes: use `from_system_path()` for a `meshtool` on PATH; `from_carp_runner()` for
the binary bundled with a CARPentry environment.

### TagsConfig
Import: `from pycemrg_model_creation import TagsConfig`
```python
TagsConfig(LV, RV, LA, RA, MV, TV, AV, PV, PArt)   # each int or List[int]
TagsConfig.from_dict(d) -> TagsConfig
.get_tags_string(keys: List[str]) -> str
.get_tags_list(keys: List[str]) -> List[int]
```

### CLI: mesh_cli volumes
`python scripts/utilities/mesh_cli.py volumes --input <mesh_base>`
Per-label volume analysis from CARP (`.pts/.elem`) or VTK meshes. Defaults assume
micrometre input / cm³ output; use `--input-mm` and `--output-mm3` to override.

## Contracts and Data Structures
All under `pycemrg_model_creation.logic`. Orchestrators construct these (usually
via the builders) and pass them into logic methods. Only `VentricularUVCPaths` is
`frozen=True`; the rest are mutable dataclasses.

- `MeshingPaths`: input_segmentation_nifti, output_dir, tmp_dir, intermediate_inr, intermediate_parameter_file, output_mesh_base (all `Path`)
- `MeshPostprocessingPaths`: input_mesh_base, output_dir, tmp_dir, intermediate_myocardium_mesh, output_mesh_base
- `VentricularSurfacePaths`: mesh, output_dir, tmp_dir; intermediate + final surfaces (epi/lv_endo/rv_endo/septum); base/epi/lv_endo/rv_endo/septum/rv_septum_point VTX paths
- `AtrialSurfacePaths`: mesh, output_dir, tmp_dir, epi/endo surfaces, base/epi/endo + apex/rv_septum_point VTX paths
- `BiVMeshPaths`: source_mesh, output_mesh, output_dir, vtx_files_to_map: List[Path], mapped_vtx_output_dir
- `AtrialMeshPaths`: source_mesh, output_mesh, output_dir, vtx_files_to_map, mapped_vtx_output_dir, apex/rv_septum templates + outputs
- `UVCSurfaceExtractionPaths`: ventricular, left_atrial, right_atrial, biv_mesh, la_mesh, ra_mesh (composed of the above)
- `VentricularUVCPaths` (frozen): biv_mesh; base/epi/lv_endo/rv_endo/septum/rvendo_nosept VTX; etags_file; output_dir; outputs uvc_z/rho/phi/ven, sol_apba/endoepi/lvendo/rvendo, aff_dat, m2s_dat
- Enums (`pycemrg_model_creation.types`): `Chamber` (LV/RV/LA/RA), `SurfaceType` (epi/endo/base/septum)

## What the Consumer Must Provide
- All file paths via contract dataclasses — logic never derives paths internally
- A `pycemrg` `CarpRunner` (for `CarpWrapper`/UVC and CARP-based meshtool), `CommandRunner` (for `Meshtools3DWrapper`), and `LabelManager` (for `SurfaceLogic`)
- Installed external binaries: `meshtool`, `meshtools3d`, CARPentry tools (`mguvc`)
- A `TagsConfig` describing how anatomical regions map to mesh element tags
- A logger (optional) and any environment/config for the CARP runner
- For UVC: VTX files copied/renamed to standard names (`base.vtx`, `epi.vtx`, `lvendo.vtx`, `rvendo.vtx`, `rvsept.vtx`, `rvendo_nosept.vtx`) in `biv_mesh.parent` before calling `UvcLogic`

## Known Constraints
- CARP mesh units default to micrometres in `.pts`; conversions are the consumer's concern
- `mguvc` reads VTX files by fixed standard names from the BiV mesh directory; contracts store `{mesh_basename}.`-prefixed names, so files must be copied/renamed first
- `ModelCreationPathBuilder.__init__` has side effects (creates directories); `build_ventricular_uvc_paths` backs up an existing `uvc/` at build time, not at execution time
- `MeshingPathBuilder` and `ModelCreationPathBuilder` cover disjoint pipeline stages — do not conflate them
- Topology simplification is skipped silently if the meshtool build lacks support
- Logic classes are stateless: they hold only a wrapper and logger; all state is passed per call
