# pycemrg Suite — API Index

Compressed index of public API across all three libraries.
Purpose: answer "does this exist and how do I call it?" before implementing anything.
For full signatures and examples, load the library's own API_reference.md.

---

## pycemrg (core)

**Install:** `pip install pycemrg`

### `pycemrg.data`
```python
from pycemrg.data import LabelManager, LabelMapper

LabelManager(config_path: Path)
  .get_value(name: str) -> int
  .get_name(value: int) -> str
  .get_values_from_names(names: List[str]) -> List[int]   # resolves groups recursively
  .get_tags_string(names: List[str], separator=",") -> str

LabelMapper(source: LabelManager, target: LabelManager)
  .get_source_to_target_mapping() -> Dict[int, int]
  .get_source_tags(names: List[str]) -> List[int]
  .get_target_tags(names: List[str]) -> List[int]
```

### `pycemrg.models`
```python
from pycemrg.models import ModelManager

ModelManager(manifest_path: Path, cache_dir: Path = ~/.cache/pycemrg)
  .get_model_path(model_name: str, version: str = "default") -> Path
  # Idempotent: downloads once, returns cached path on subsequent calls
```

### `pycemrg.files`
```python
from pycemrg.files import OutputManager, ConfigScaffolder

OutputManager(output_dir, output_prefix: str)
  .get_path(suffix: str) -> Path
  # Returns: {output_dir}/{prefix}{suffix}

ConfigScaffolder()
  .create_models_manifest(output_path, overwrite=False)
  .create_labels_manifest(output_path, overwrite=False, num_labels=3, num_groups=1)
```

### `pycemrg.system`
```python
from pycemrg.system import CommandRunner, CarpRunner
from pycemrg.system import CommandExecutionError, CarpEnvironmentError

CommandRunner(logger=None)
  .run(cmd, expected_outputs=None, cwd=None, ignore_errors=None, env=None) -> str
  # Never uses shell=True. Raises CommandExecutionError on failure.

CarpRunner(runner: CommandRunner, carp_config_path)
  .run(cmd, expected_outputs=None, cwd=None, ignore_errors=None) -> str
  .carp_env -> Dict[str, str]           # lazy-loaded, cached
  .installation_root -> Path
  .validate_command_exists(command: str) -> bool
  .reload_environment() -> None
  .get_carp_path(relative_path="") -> Path
  .get_carputils_settings_path() -> Optional[Path]
  .get_license_path() -> Optional[Path]
  CarpRunner.find_installation(search_paths=None) -> Optional[Path]  # classmethod
```

### `pycemrg` CLI
```bash
pycemrg init-labels --output config/labels.yaml --num-labels 10 --num-groups 3
pycemrg init-models --output config/models.yaml
```

---

## pycemrg-image-analysis

**Install:** `pip install pycemrg-image-analysis`
**Requires:** SimpleITK, pycemrg

### Entry Points
```python
from pycemrg_image_analysis import ImageAnalysisScaffolder

ImageAnalysisScaffolder()
  .scaffold_components(output_dir: Path, component_names: List[str])
  .scaffold_components_with_mapping(...)   # use when Slicer has reset labels to 1-N
```

### Logic Engines
```python
from pycemrg_image_analysis.logic import MyocardiumLogic, ValveLogic

# Engines are stateless. All state is in the contract.
MyocardiumLogic()
  .create_from_semantic_map(contract: MyocardiumCreationContract) -> sitk.Image
  .push_structure(image: sitk.Image, contract: PushStructureContract) -> sitk.Image

ValveLogic()
  .create_from_rule(contract: ValveCreationContract) -> sitk.Image
```

### Contracts
```python
from pycemrg_image_analysis.logic.contracts import (
    MyocardiumRule, MyocardiumCreationContract,
    ValveRule, ValveCreationContract,
    PushStructureContract
)
# All are frozen dataclasses. Build from semantic_map.json dicts.
```

### Recipes
```python
from pycemrg_image_analysis.recipes import (
    biventricular_basic,
    four_chamber_full,
    # 4 additional named variants
)
# Pre-sequenced workflow variants. Orchestrator calls one recipe function.
```

### Utilities (pure functions, no class state)
```python
from pycemrg_image_analysis.utilities import load_image, save_image

# Image I/O
load_image(path: Path) -> sitk.Image
save_image(image: sitk.Image, path: Path)

# Metrics (all expect pre-normalised [0,1] data in (Z,Y,X) format)
from pycemrg_image_analysis.utilities.metrics import (
    compute_mse, compute_psnr, compute_ssim,
    compute_gradient_error, compare_volumes
)
compare_volumes(predicted, ground_truth, metrics=None) -> Dict[str, float]
# Default metrics: ['mse', 'psnr', 'ssim', 'gradient']
```

### Domain Terminology
- **BP:** Blood Pool cavity label (LV_BP, RV_BP, LA_BP, RA_BP)
- **Myo:** Muscle wall, derived by growing outward from BP
- **Semantic Map:** JSON mapping role enums → label names/values
- **Recipe:** Named sequence of operations
- **Contract:** Frozen dataclass passed to a logic engine
- **Application Step:** Single mask operation (add/replace/keep) in a sequence

### Non-Obvious Constraints
- Image spacing must be correct — MyocardiumLogic uses physical-space distance maps
- Application step order is critical — steps write to same output array
- `keep_largest_component` vs `keep_largest_structure` — different cleanup semantics
- Slicer often resets labels to sequential 1-N; use `scaffold_components_with_mapping`

---

## pycemrg-model-creation

**Install:** `pip install pycemrg-model-creation`
**Requires:** pycemrg, numpy, pyvista, SimpleITK
**External tools:** meshtools3d, meshtool, CARPentry/openCARP (optional)

### Pipeline
```
NIfTI segmentation
  → MeshingLogic      → .pts/.elem volumetric mesh
  → RefinementLogic   → extract myocardium, relabel tags
  → SurfaceLogic      → boundary surfaces → VTX files
  → UvcLogic          → Universal Ventricular Coordinates
```

### Configuration
```python
from pycemrg_model_creation import TagsConfig

TagsConfig(LV, RV, LA, RA, MV, TV, AV, PV, PArt)  # all int
  .from_dict(tags_dict) -> TagsConfig               # classmethod
  .get_tags_string(keys: List[str]) -> str
  .get_tags_list(keys: List[str]) -> List[int]
```

### Logic Layer
```python
from pycemrg_model_creation import (
    MeshingLogic, RefinementLogic, SurfaceLogic
)
from pycemrg_model_creation.logic.uvc import UvcLogic

MeshingLogic(meshtools3d_wrapper: Meshtools3DWrapper)
  .run_meshing(paths: MeshingPaths, meshing_params=None, cleanup=True)
  # Output: .pts, .elem, .vtk

RefinementLogic(meshtool_wrapper: MeshtoolWrapper)
  .run_myocardium_postprocessing(
      paths, myocardium_tags: List[int],
      tag_mapping: Dict[int,int], simplify=False)
  # Output: refined .pts, .elem, .vtk

SurfaceLogic(meshtool: MeshtoolWrapper, label_manager: LabelManager)
  .run_ventricular_extraction(paths: VentricularSurfacePaths)
  .run_atrial_extraction(paths: AtrialSurfacePaths, chamber: Chamber)
  .run_biv_mesh_extraction(paths: BiVMeshPaths, tags: TagsConfig)
  .run_atrial_mesh_extraction(paths: AtrialMeshPaths, tags, chamber)
  .run_all(paths: UVCSurfaceExtractionPaths, tags: TagsConfig)

UvcLogic(carp_wrapper: CarpWrapper)
  .run_ventricular_uvc_calculation(
      paths: VentricularUVCPaths, lv_tag: int, rv_tag: int, np=1)
  # Output: .uvc_z, .uvc_rho, .uvc_phi, .uvc_ven in paths.output_dir
```

### Wrappers
```python
from pycemrg_model_creation import MeshtoolWrapper
from pycemrg_model_creation.tools.wrappers import CarpWrapper, Meshtools3DWrapper

MeshtoolWrapper.from_system_path(meshtool_install_dir=None) -> MeshtoolWrapper
MeshtoolWrapper.from_carp_runner(carp_runner) -> MeshtoolWrapper
  .extract_mesh(input, output, tags, ifmt="carp_txt", normalise=False)
  .extract_surface(input, output, ofmt="vtk", op_tag_base=None)
  .extract_unreachable(input, submsh, ofmt="vtk", ifmt="")
  .convert(input, output, ofmt="vtk", ifmt=None)
  .smooth(input, output, smoothing_params, tags=None, ifmt, ofmt)
  .map(submesh, files_list, output_folder, mode="m2s")
  .simplify_topology(input, output, neighbors=50, ifmt, ofmt)
  .is_simplify_topology_available -> bool

CarpWrapper(carp_runner: CarpRunner)
  .gl_rule_fibres(mesh_name, uvc_apba, uvc_epi, uvc_lv, uvc_rv,
                  output_name, angles=DEFAULT_FIBRE_ANGLES, fibre_type="biv")
  .gl_vtk_convert(mesh_name, output_name, node_data=(), elem_data=())
  .igb_extract(igb_file, output_file, output_format="ascii",
               first_frame=0, last_frame=0)
```

### Path Builders (always prefer over manual contract construction)
```python
from pycemrg_model_creation import ModelCreationPathBuilder
from pycemrg_model_creation.logic.builders import MeshingPathBuilder

MeshingPathBuilder(output_dir)
  .build_meshing_paths(input_image, raw_mesh_basename="heart_mesh")
  .build_postprocessing_paths(input_mesh_base, refined_mesh_basename)

ModelCreationPathBuilder(output_dir)
  # Note: __init__ creates subdirectories immediately
  .build_ventricular_paths(mesh_base_path) -> VentricularSurfacePaths
  .build_atrial_paths(mesh_base_path, chamber_prefix) -> AtrialSurfacePaths
  .build_biv_mesh_paths(mesh_base_path, ventricular_paths) -> BiVMeshPaths
  .build_atrial_mesh_paths(mesh_base_path, atrial_paths,
                           blank_files_dir, chamber_prefix)
  .build_ventricular_uvc_paths(biv_mesh, output_subdir="uvc",
                                backup_existing=True) -> VentricularUVCPaths
  .build_all(mesh_base_path, blank_files_dir) -> UVCSurfaceExtractionPaths
```

### Key Contracts
```python
from pycemrg_model_creation.logic.contracts import (
    MeshingPaths, MeshPostprocessingPaths,
    VentricularSurfacePaths, AtrialSurfacePaths,
    BiVMeshPaths, AtrialMeshPaths,
    UVCSurfaceExtractionPaths, VentricularUVCPaths  # only frozen contract
)
```

### Utilities
```python
from pycemrg_model_creation.utilities.mesh import (
    read_carp_mesh, read_pts, read_elem, read_surf,
    write_surf, write_vtx, write_pts,
    surf2vtx, surf2vtk,
    generate_vtx_from_surf,
    relabel_carp_elem_file,
    find_numbered_parts, keep_largest_n_components,
    remove_septum_from_endo, connected_component_to_surface
)
from pycemrg_model_creation.utilities.geometry import (
    compute_surface_center_of_gravity,
    compute_mesh_region_cog,
    identify_surface_orientation
)
from pycemrg_model_creation.utilities.image import convert_image_to_inr
from pycemrg_model_creation.utilities.config import Meshtools3DParameters
```

### Enums / Types
```python
from pycemrg_model_creation.types import Chamber, SurfaceType
from pycemrg_model_creation.utilities.mesh import ElemType
# Chamber: LV, RV, LA, RA
# SurfaceType: EPI, ENDO, BASE, SEPTUM
# ElemType: Tt (tetrahedra), Tr (triangles), Ln (lines)
```

### Critical Gotchas
- `mguvc` requires BiV mesh and all 6 VTX files co-located with exact names
- `ModelCreationPathBuilder.__init__` creates subdirectories on instantiation
- `build_ventricular_uvc_paths` backs up existing `uvc/` dir with timestamp by default
- etags file is written to `biv_mesh.parent`, NOT inside `output_dir`
- `SurfaceLogic` requires a `LabelManager` at construction, not at call time
- UVC error in pycemrg core: open item, not yet resolved