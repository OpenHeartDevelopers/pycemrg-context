# pycemrg-model-creation — API Reference for External Consumers

## Purpose
Provides a pipeline for building simulation-ready cardiac meshes from NIfTI segmentations: volumetric meshing, myocardium refinement, cardiac surface extraction, and Universal Ventricular Coordinate (UVC) calculation. Wraps CARPentry/openCARP CLI tools behind stateless, path-contract–driven Python logic classes.

## Capabilities
- Generate a volumetric tetrahedral mesh from a NIfTI segmentation image (via meshtools3d)
- Extract and relabel the myocardium from a raw four-chamber mesh
- Extract epicardial, endocardial, septal, and base surfaces from a four-chamber mesh
- Identify and label epicardium vs. LV/RV endocardium automatically using geometric analysis
- Extract BiV, LA, and RA submeshes from a four-chamber mesh
- Map vertex (VTX) boundary files from a four-chamber mesh to a chamber submesh
- Compute Universal Ventricular Coordinates (Z, Rho, Phi, Ven) on a BiV mesh using mguvc
- Generate rule-based fibre fields using GlRuleFibres and UVC coordinate data
- Convert meshes between CARP text format and VTK for visualization
- Smooth, interpolate, and insert data across meshes via meshtool

## Install

```bash
pip install -e .
```

Requires `pycemrg` (provides `CarpRunner`, `CommandRunner`, `LabelManager`) installed in the same environment.

---

## Key Entry Points

### MeshingLogic
Import: `from pycemrg_model_creation.logic import MeshingLogic`  
Purpose: Orchestrates the meshtools3d workflow from NIfTI segmentation to CARP mesh.

```python
MeshingLogic(meshtools3d_wrapper: Meshtools3DWrapper)

run_meshing(
    paths: MeshingPaths,
    meshing_params: Dict[str, Any] = None,
    cleanup: bool = True
) -> None
```

Notes: Converts NIfTI → INR → meshtools3d parameter file → `.pts`/`.elem`. `meshing_params` overrides sections in the generated `.par` file (e.g., `{'meshing': {'facet_size': '0.7'}}`). Does not produce `.lon` fibre files.

---

### RefinementLogic
Import: `from pycemrg_model_creation.logic import RefinementLogic`  
Purpose: Post-processes a raw mesh by extracting myocardium tags, optionally simplifying topology, and relabeling element tags.

```python
RefinementLogic(meshtool_wrapper: MeshtoolWrapper)

run_myocardium_postprocessing(
    paths: MeshPostprocessingPaths,
    myocardium_tags: List[int],
    tag_mapping: Dict[int, int],
    simplify: bool = False
) -> None
```

Notes: Always produces a final `.vtk` alongside the CARP output. `simplify=True` requires the `simplify_tag_topology` standalone binary to be present at `meshtool_install_dir/standalones/`; if not available the step is silently skipped.

---

### SurfaceLogic
Import: `from pycemrg_model_creation.logic import SurfaceLogic`  
Purpose: Extracts cardiac surfaces (epi, endo, septum, base) and submeshes from a four-chamber mesh, producing VTX files for UVC computation.

```python
SurfaceLogic(meshtool: MeshtoolWrapper, label_manager: LabelManager)

# Convenience workflows (run full pipeline for a chamber)
run_ventricular_extraction(paths: VentricularSurfacePaths) -> None
run_atrial_extraction(paths: AtrialSurfacePaths, chamber: Chamber, files_to_map: Optional[List[Path]] = None) -> None
run_biv_mesh_extraction(paths: BiVMeshPaths, tags: TagsConfig) -> None
run_atrial_mesh_extraction(paths: AtrialMeshPaths, tags: TagsConfig, chamber: Chamber) -> None

# Full pipeline in one call
run_all(
    paths: UVCSurfaceExtractionPaths,
    tags: TagsConfig,
    ventricular_files_to_map: Optional[List[Path]] = None,
    la_files_to_map: Optional[List[Path]] = None,
    ra_files_to_map: Optional[List[Path]] = None,
) -> None
```

Notes: Epicardium identification uses outward surface normals; LV/RV endo is distinguished by distance from LV center. Expects exactly 3 connected components for ventricles — raises `SurfaceIdentificationError` if fewer are found. `LabelManager` must carry LV, RV, LA, RA, MV, TV, AV, PV tag definitions.

---

### UvcLogic
Import: `from pycemrg_model_creation.logic import UvcLogic`  
Purpose: Runs the mguvc UVC calculation workflow on a BiV submesh.

```python
UvcLogic(carp_wrapper: CarpWrapper)

run_ventricular_uvc_calculation(
    paths: VentricularUVCPaths,
    lv_tag: int,
    rv_tag: int,
    np: int = 1
) -> None
```

Notes: Validates all 6 VTX boundary files before running. Generates the `etags.sh` script automatically. VTX files **must** exist in `biv_mesh.parent` with standard names (`base.vtx`, `epi.vtx`, `lvendo.vtx`, `rvendo.vtx`, `rvsept.vtx`, `rvendo_nosept.vtx`) — the caller is responsible for placing them there.

---

### MeshtoolWrapper
Import: `from pycemrg_model_creation.tools import MeshtoolWrapper`  
Purpose: Pythonic wrapper for the meshtool CLI (extract, convert, smooth, interpolate, insert, map).

```python
# Factory methods
MeshtoolWrapper.from_system_path(meshtool_install_dir: Optional[Path] = None) -> MeshtoolWrapper
MeshtoolWrapper.from_carp_runner(carp_runner: CarpRunner) -> MeshtoolWrapper

# Key methods
extract_mesh(input_mesh_path, output_submesh_path, tags, ifmt="carp_txt", normalise=False) -> None
extract_surface(input_mesh_path, output_surface_path, ofmt="vtk", op_tag_base=None) -> None
convert(input_mesh_path, output_mesh_path, ofmt="vtk", ifmt=None) -> None
map(submesh_path, files_list, output_folder, mode="m2s") -> None
smooth(input_mesh_path, output_mesh_path, smoothing_params, ...) -> None
interpolate(mesh_path, input_data_path, output_data_path, mode) -> None
insert_data(target_mesh_path, source_submesh_path, source_data_path, output_data_path, mode) -> None
simplify_topology(input_mesh_path, output_mesh_path, neighbors=50, ...) -> None
```

Notes: Use `from_system_path()` if meshtool is on PATH; use `from_carp_runner()` to share an active CARPentry environment. `simplify_topology` requires `meshtool_install_dir` with the `standalones/simplify_tag_topology` binary.

---

### CarpWrapper
Import: `from pycemrg_model_creation.tools import CarpWrapper`  
Purpose: Pythonic wrapper for CARPentry CLI tools (GlRuleFibres, GlVTKConvert, mguvc, igbextract, carp.pt, ekbatch).

```python
CarpWrapper(carp_runner: CarpRunner)

gl_rule_fibres(mesh_name, uvc_apba, uvc_epi, uvc_lv, uvc_rv, output_name,
               angles=DEFAULT_FIBRE_ANGLES, fibre_type="biv") -> None
gl_vtk_convert(mesh_name, output_name, node_data=(), elem_data=(), trim_names=True) -> None
run_mguvc(model_name, input_model_type, output_model_type, tags_file,
          output_dir, np=1, laplace_solution=True, custom_apex=False,
          uvc_phi_model="full", expected_outputs=None) -> None
igb_extract(igb_file, output_file, output_format="ascii", first_frame=0, last_frame=0) -> None
```

Notes: `DEFAULT_FIBRE_ANGLES` is `{"alpha_endo": 60, "alpha_epi": -60, "beta_endo": -65, "beta_epi": 25}`. `run_mguvc` is called internally by `UvcLogic`; consumers can also call it directly.

---

### Meshtools3DWrapper
Import: `from pycemrg_model_creation.tools import Meshtools3DWrapper`  
Purpose: Minimal wrapper that executes the meshtools3d binary with a `.par` parameter file.

```python
Meshtools3DWrapper(runner: CommandRunner, meshtools3d_path: Path)
run(parameter_file: Path, expected_outputs: List[Path]) -> None
```

Notes: Does not generate the `.par` file — that is handled by `MeshingLogic`. Raises `FileNotFoundError` at construction if the binary does not exist.

---

### MeshingPathBuilder
Import: `from pycemrg_model_creation.logic import MeshingPathBuilder`  
Purpose: Creates `MeshingPaths` and `MeshPostprocessingPaths` contracts and the directory layout (`01_raw/`, `02_refined/`, `tmp/`) for the meshing pipeline.

```python
MeshingPathBuilder(output_dir: Union[Path, str])

build_meshing_paths(input_image: Path, raw_mesh_basename: str = "heart_mesh") -> MeshingPaths
build_postprocessing_paths(input_mesh_base: Path, refined_mesh_basename: str = "myocardium_clean") -> MeshPostprocessingPaths
```

Notes: Directories are created immediately on `__init__`. Does not share state with `ModelCreationPathBuilder`.

---

### ModelCreationPathBuilder
Import: `from pycemrg_model_creation.logic import ModelCreationPathBuilder`  
Purpose: Creates all surface and UVC path contracts and the directory layout (`BiV/`, `LA/`, `RA/`) for the surface extraction and UVC pipeline.

```python
ModelCreationPathBuilder(output_dir: Union[Path, str])

build_ventricular_paths(mesh_base_path: Path) -> VentricularSurfacePaths
build_atrial_paths(mesh_base_path: Path, chamber_prefix: str) -> AtrialSurfacePaths  # "la" or "ra"
build_biv_mesh_paths(mesh_base_path: Path, ventricular_paths: VentricularSurfacePaths) -> BiVMeshPaths
build_atrial_mesh_paths(mesh_base_path, atrial_paths, blank_files_dir, chamber_prefix) -> AtrialMeshPaths
build_ventricular_uvc_paths(biv_mesh: Path, output_subdir: str = "uvc", overwrite_existing: bool = True, backup_existing: bool = True) -> VentricularUVCPaths
build_all(mesh_base_path: Path, blank_files_dir: Path) -> UVCSurfaceExtractionPaths
```

Notes: Directories are created immediately on `__init__`. `build_ventricular_uvc_paths` backs up any existing `uvc/` subdirectory **at build time** if `backup_existing=True`. The VTX paths in the returned contract use a `{mesh_basename}.` prefix (e.g., `BiV.base.vtx`) — the caller must copy them to plain standard names before calling `UvcLogic`.

---

### TagsConfig
Import: `from pycemrg_model_creation import TagsConfig`  
Purpose: Maps anatomical region names to integer mesh element tags.

```python
@dataclass
TagsConfig:
    LV: Union[int, List[int]]
    RV: Union[int, List[int]]
    LA: Union[int, List[int]]
    RA: Union[int, List[int]]
    MV: Union[int, List[int]]   # Mitral valve
    TV: Union[int, List[int]]   # Tricuspid valve
    AV: Union[int, List[int]]   # Aortic valve
    PV: Union[int, List[int]]   # Pulmonary valve
    PArt: Union[int, List[int]] # Pulmonary artery

    @classmethod
    def from_dict(cls, tags_dict: Dict[str, Union[int, List[int]]]) -> TagsConfig
    def get_tags_string(self, keys: List[str]) -> str   # e.g. "1,2,3"
    def get_tags_list(self, keys: List[str]) -> List[int]
```

---

## Contracts and Data Structures

All contracts live in `pycemrg_model_creation.logic.contracts`.

| Contract | Key Fields | Used By |
|---|---|---|
| `MeshingPaths` | `input_segmentation_nifti`, `output_dir`, `tmp_dir`, `intermediate_inr`, `intermediate_parameter_file`, `output_mesh_base` | `MeshingLogic` |
| `MeshPostprocessingPaths` | `input_mesh_base`, `output_dir`, `tmp_dir`, `intermediate_myocardium_mesh`, `output_mesh_base` | `RefinementLogic` |
| `VentricularSurfacePaths` | mesh, output_dir, tmp_dir, intermediate surfaces, final surfaces (epi/lv_endo/rv_endo/septum), VTX files | `SurfaceLogic` |
| `AtrialSurfacePaths` | mesh, output_dir, tmp_dir, epi/endo surfaces, VTX files | `SurfaceLogic` |
| `BiVMeshPaths` | `source_mesh`, `output_mesh`, `vtx_files_to_map`, `mapped_vtx_output_dir` | `SurfaceLogic` |
| `AtrialMeshPaths` | `source_mesh`, `output_mesh`, `vtx_files_to_map`, `mapped_vtx_output_dir`, blank template paths | `SurfaceLogic` |
| `UVCSurfaceExtractionPaths` | `ventricular`, `left_atrial`, `right_atrial`, `biv_mesh`, `la_mesh`, `ra_mesh` | `SurfaceLogic.run_all` |
| `VentricularUVCPaths` *(frozen)* | `biv_mesh`, 6 VTX paths, `etags_file`, `output_dir`, 4 UVC `.dat` outputs, Laplace solutions, mapping files | `UvcLogic` |

Enums: `Chamber` (`LV`, `RV`, `LA`, `RA`), `SurfaceType` (`EPI`, `ENDO`, `BASE`, `SEPTUM`) — import from `pycemrg_model_creation.types`.

---

## What the Consumer Must Provide

- **`CarpRunner`** (from `pycemrg`) — initialized with the CARPentry environment (config file, binary directory). Required by `CarpWrapper` and `UvcLogic`.
- **`CommandRunner`** (from `pycemrg`) — for running arbitrary subprocesses. Required by `MeshtoolWrapper.from_system_path()` and `Meshtools3DWrapper`.
- **`LabelManager`** (from `pycemrg`) — carries the tag-name-to-integer mapping. Required by `SurfaceLogic`.
- **`TagsConfig`** — anatomical region tag values for the specific segmentation being processed. Required by `SurfaceLogic` submesh extraction methods and `UvcLogic` (as `lv_tag`/`rv_tag` integers).
- **meshtools3d binary path** — absolute path to the meshtools3d executable. Required by `Meshtools3DWrapper`.
- **NIfTI segmentation** — the input image file. Required by `MeshingLogic`.
- **VTX files with standard names** — before calling `UvcLogic`, the caller must copy VTX files to `biv_mesh.parent/` with names: `base.vtx`, `epi.vtx`, `lvendo.vtx`, `rvendo.vtx`, `rvsept.vtx`, `rvendo_nosept.vtx`.
- **Blank template VTX files** — required by `ModelCreationPathBuilder.build_atrial_mesh_paths` for apex and RV septum point files (not anatomically meaningful for atria, but required for interface compatibility with mguvc).

---

## Known Constraints

- **VTX naming for mguvc**: `mguvc` reads VTX files by standard names from `biv_mesh.parent`. The builder stores them with a `{mesh_basename}.` prefix. The caller must copy/rename them before running `UvcLogic` — this is not done automatically.
- **Builder side effects at construction**: Both `MeshingPathBuilder` and `ModelCreationPathBuilder` create subdirectories immediately on `__init__`. `build_ventricular_uvc_paths` backs up any existing `uvc/` at build time, not at logic execution time.
- **`VentricularUVCPaths` is frozen**: It is the only frozen dataclass. Mutation after construction raises `FrozenInstanceError`.
- **Mesh units**: CARP `.pts` files use micrometers by default. The `mesh_cli.py` volumes script assumes µm input / cm³ output; pass `--input-mm` to override.
- **`SurfaceLogic` requires exactly 3 ventricular components**: If the mesh produces fewer than 3 connected components during surface extraction, the workflow raises `SurfaceIdentificationError` rather than silently producing wrong outputs.
- **`simplify_topology` is a separate standalone binary**: It lives at `meshtool_install_dir/standalones/simplify_tag_topology` and is not part of the main meshtool binary. If absent, the step is skipped (with a warning) rather than raising an error.
- **`pycemrg` must be installed separately**: This package does not bundle `CarpRunner`, `CommandRunner`, or `LabelManager`. They come from the `pycemrg` package.
