# pycemrg-image-analysis — API Reference for External Consumers

## Purpose
Post-processing library for cardiac image segmentation. Takes an initial multi-label
SimpleITK segmentation (blood pools) and produces anatomical structures: myocardium
walls, valves, vein rings, and cylindrical masks, driven by rules and physical-space
distance maps.

## Capabilities

- Grow myocardium walls outward from blood pool labels using physical-space distance maps
- Create valves by intersecting two adjacent anatomical structures
- Create vein rings anchored to atrium myocardium boundaries
- Generate cylindrical masks in physical space (e.g., for inlet/outlet capping)
- Apply multi-step, rule-driven mask operations (add / replace / replace-except / replace-only)
- Scaffold YAML/JSON configuration files from named anatomy blueprints (schematics)
- Validate segmentation label values against schematic expectations and suggest remappings
- Post-process segmentation labels: remove, keep, relabel by integer or semantic name
- Measure physical volumes (mL or mm³) for one or more labels
- Keep largest connected component per label or across a multi-label structure
- Compute image quality metrics (MSE, PSNR, SSIM, gradient error) for ML validation
- Apply spatial/intensity augmentations and simulate acquisition artifacts for ML pipelines
- Extract center or random patches from 3-D volumes
- Resample images to isotropic spacing; convert INR format

## Install

```bash
pip install pycemrg-image-analysis
# or editable:
pip install -e .
```

Requires Python >= 3.10. Key runtime dependencies: `simpleitk`, `numpy`, `scipy`,
`pycemrg>=0.1.0` (provides `LabelManager` and `ConfigScaffolder`).

---

## Key Entry Points

### ImageAnalysisScaffolder
Import: `from pycemrg_image_analysis import ImageAnalysisScaffolder`  
Purpose: Generates `labels.yaml`, `parameters.json`, and per-component `semantic_maps/*.json`
from named anatomy blueprints.

```python
scaffold_components(
    output_dir: Path | str,
    component_names: list[str],
    overwrite: bool = False,
) -> None

scaffold_components_with_mapping(
    output_dir: Path | str,
    component_names: list[str],
    label_mapping: dict[str, int],   # label_name -> your integer value
    overwrite: bool = False,
) -> None
```

Notes: `scaffold_components_with_mapping` is required when Slicer has reset label integers
to sequential 1-N. Unknown component names raise `ValueError`. The base
`create_labels_manifest()` is disabled; use `scaffold_components()` instead.

Available component names: call `list_available_schematics()` at runtime or import
`ALL_SCHEMATICS` from `pycemrg_image_analysis.schematics`.

---

### MyocardiumLogic
Import: `from pycemrg_image_analysis.logic import MyocardiumLogic`  
Purpose: Grows a myocardium wall from a blood pool using a distance map and a
multi-step mask application rule.

```python
create_from_semantic_map(
    input_image: sitk.Image,
    label_manager: LabelManager,
    parameters: dict[str, float],
    semantic_map: dict[MyocardiumSemanticRole, Any],
) -> sitk.Image

push_structure(
    input_image: sitk.Image,
    contract: PushStructureContract,
) -> sitk.Image
```

Notes: `create_from_semantic_map` uses physical-space distance maps; image spacing must
be correct or wall thickness will be wrong. The semantic map keys are
`MyocardiumSemanticRole` enum values. Application step order in
`APPLICATION_STEPS` is critical — steps overwrite the same output array sequentially.

---

### ValveLogic
Import: `from pycemrg_image_analysis.logic import ValveLogic`  
Purpose: Creates a valve label by intersecting two adjacent structures within a
physical-space thickness band.

```python
create_from_rule(contract: ValveCreationContract) -> sitk.Image
```

Notes: The intersection zone is `±thickness` on both sides of Structure A's surface.
`contract.rule` must be set before calling; builders leave it as `None` by default.

---

### RingLogic
Import: `from pycemrg_image_analysis.logic import RingLogic`  
Purpose: Creates a vein ring by thresholding a distance map from a vein blood pool,
then trimming to the atrium myocardium boundary.

```python
create_from_rule(contract: RingCreationContract) -> sitk.Image
```

Notes: Pass a frozen `reference_image` (captured before the ring sequence begins) to
prevent ring geometry from drifting as the segmentation evolves.
Pre-compute `atrium_myocardium_threshold` once and share it across all rings on
the same atrium for efficiency.

---

### SegmentationLogic
Import: `from pycemrg_image_analysis.logic import SegmentationLogic`  
Purpose: Creates a cylinder mask in physical space.

```python
create_cylinder(contract: CylinderCreationContract) -> sitk.Image
```

Notes: `CylinderCreationContract.image_shape` is `(X, Y, Z)`; the internal axis swap
to `(Z, Y, X)` is performed by this method. Callers must not pre-swap.

---

### SegmentationPathBuilder
Import: `from pycemrg_image_analysis.logic import SegmentationPathBuilder`  
Purpose: Builds `CylinderCreationContract` objects from geometry metadata and a base
output directory, so the orchestrator does not repeat path construction.

```python
__init__(output_dir: Path, origin: np.ndarray, spacing: np.ndarray, image_shape: Tuple[int, int, int])

build_cylinder_contract(
    cylinder_name: str,
    points: np.ndarray,
    slicer_radius: float,
    slicer_height: float,
) -> CylinderCreationContract
```

---

### MyocardiumPathBuilder
Import: `from pycemrg_image_analysis.logic import MyocardiumPathBuilder`  
Purpose: Builds myocardium, valve, and ring contracts from shared workflow context
(label manager, parameters, input image, output directory).

```python
__init__(output_dir: Path, label_manager: LabelManager, parameters: dict[str, float], input_image: sitk.Image)

build_creation_contract(output_name: str) -> MyocardiumCreationContract
build_valve_contract(output_name: str) -> ValveCreationContract
build_ring_contract(
    output_name: str,
    reference_image: sitk.Image,
    atrium_myocardium_threshold: sitk.Image | None = None,
) -> RingCreationContract

update_input_image(new_input: sitk.Image) -> None
```

Notes: All builder methods return a contract with `rule=None`. The orchestrator must
set the rule (via `dataclasses.replace`) before passing to a logic engine.
Call `update_input_image` between steps when each step's output feeds the next.

---

### LabelDiagnostic
Import: `from pycemrg_image_analysis.utilities import LabelDiagnostic`  
Purpose: Compares integer labels present in a segmentation file against what a named
schematic expects; produces a `DiagnosticReport`.

```python
check_image_against_schematic(
    image_path: Path,
    schematic_name: str,
) -> DiagnosticReport

print_report(report: DiagnosticReport) -> None
```

---

### LabelRemapper
Import: `from pycemrg_image_analysis.utilities import LabelRemapper`  
Purpose: Builds a `dict[str, int]` label mapping suitable for
`scaffold_components_with_mapping`, either from user input or inferred from a
`DiagnosticReport`.

```python
create_mapping_from_dict(label_mapping: dict[str, int]) -> dict[str, int]

suggest_mapping_from_report(report: DiagnosticReport) -> dict[str, int] | None
```

Notes: `suggest_mapping_from_report` only returns a suggestion when image labels are
sequential starting at 1 and their count matches the schematic. Returns `None`
otherwise.

---

### Postprocessing utilities
Import: `from pycemrg_image_analysis.utilities import ...`  
Purpose: `sitk.Image`-level wrappers for label manipulation; all preserve image
metadata (spacing, origin, direction).

```python
remove_label(image: sitk.Image, label: int) -> sitk.Image
remove_labels(image: sitk.Image, labels: list[int]) -> sitk.Image
keep_labels(image: sitk.Image, labels_to_keep: list[int]) -> sitk.Image
remove_labels_by_name(image, label_names: list[str], label_manager: LabelManager) -> sitk.Image
keep_labels_by_name(image, label_names: list[str], label_manager: LabelManager) -> sitk.Image
relabel_image(image: sitk.Image, label_mapping: dict[int, int]) -> sitk.Image
relabel_image_by_name(image, label_mapping: dict[str, str], source_manager, target_manager) -> sitk.Image
inspect_labels(image: sitk.Image, label_manager: LabelManager) -> dict[int, str]
compute_label_volumes(image: sitk.Image, label_values: list[int], use_mm3: bool = False) -> LabelVolumes
```

---

### Component cleanup utilities
Import: `from pycemrg_image_analysis.utilities import keep_largest_component, keep_largest_structure`

```python
keep_largest_component(image: sitk.Image, label_values: list[int]) -> sitk.Image
keep_largest_structure(image: sitk.Image, label_values: list[int] | None) -> sitk.Image
```

Notes: `keep_largest_component` processes each label independently.
`keep_largest_structure` treats all listed labels as one connected structure —
use this to remove floating debris after neural-network segmentation. Choosing
the wrong variant silently preserves incorrect anatomy.

---

### Spatial and IO utilities
Import: `from pycemrg_image_analysis.utilities import ...`

```python
load_image(path: Path) -> sitk.Image
save_image(image: sitk.Image, path: Path) -> None
convert_inr_to_image(path: Path) -> sitk.Image
convert_image_to_inr(image: sitk.Image, path: Path) -> None
resample_to_isotropic(image: sitk.Image, target_spacing: float) -> sitk.Image
compute_target_shape(image: sitk.Image, target_spacing: float) -> tuple[int, int, int]
compute_actual_spacing(image: sitk.Image, target_shape: tuple) -> tuple[float, float, float]
get_voxel_physical_bounds(image: sitk.Image) -> np.ndarray
extract_slice_voxels(image: sitk.Image, axis: int, index: int) -> np.ndarray
sample_image_at_points(image: sitk.Image, points: np.ndarray) -> np.ndarray
calculate_cylinder_mask(image_shape, origin, spacing, points, slicer_radius, slicer_height) -> np.ndarray
```

---

### ML utilities (metrics, augmentation, sampling, artifact simulation)
Import: `from pycemrg_image_analysis.utilities import ...`  
Notes: All functions expect normalized `[0, 1]` float arrays in `(Z, Y, X)` order.
Wrong range or axis order produces silently incorrect results.

```python
# Metrics
compute_mse(a: np.ndarray, b: np.ndarray) -> float
compute_psnr(a: np.ndarray, b: np.ndarray) -> float
compute_ssim(a: np.ndarray, b: np.ndarray) -> float
compute_gradient_error(a: np.ndarray, b: np.ndarray) -> float
compare_volumes(a: np.ndarray, b: np.ndarray) -> dict[str, float]

# Augmentation
augment_brightness(volume: np.ndarray, factor: float) -> np.ndarray
augment_contrast(volume: np.ndarray, factor: float) -> np.ndarray
augment_noise(volume: np.ndarray, std: float) -> np.ndarray
create_slice_shifted_volumes(volume: np.ndarray, ...) -> list[np.ndarray]

# Artifact simulation
downsample_volume(volume: np.ndarray, factor: float, preserve_extent: bool = False) -> np.ndarray

# Patch extraction
extract_center_patch(volume: np.ndarray, patch_size: tuple) -> np.ndarray
extract_random_patch(volume: np.ndarray, patch_size: tuple) -> np.ndarray

# Intensity normalization
clip_intensities(image: sitk.Image, lower: float, upper: float) -> sitk.Image
normalize_min_max(image: sitk.Image) -> sitk.Image
normalize_percentile(image: sitk.Image, lower_pct: float, upper_pct: float) -> sitk.Image
```

Notes for `downsample_volume`: set `preserve_extent=True` for pipelines that
normalize by physical extent `(dim-1)*spacing`; leave off for standard resampling.
Results diverge for small volumes.

---

### Pre-defined workflow recipes
Import: `from pycemrg_image_analysis.recipes import RECIPE_CATALOG, get_recipe, list_recipes`

```python
get_recipe(name: str) -> Recipe      # raises KeyError if not found
list_recipes() -> None               # prints catalog to stdout
```

Available recipe names:
- `biventricular_basic` — LV + RV myocardium, mitral/tricuspid/aortic/pulmonary valves
- `four_chamber_myocardium` — all four chambers, push steps, no valves
- `four_chamber_full` — all four chambers plus all valves
- `left_atrium_with_veins` — LA myocardium + LPV1/LPV2/RPV1/RPV2/LAA rings
- `right_atrium_with_veins` — RA myocardium + SVC/IVC rings
- `atria_full` — both atria with all vein rings

Each `Recipe` has `.steps: list[WorkflowStep]` and `.required_schematics: list[str]`.

---

## Contracts and Data Structures

### CylinderCreationContract
```python
@dataclass(frozen=True)
class CylinderCreationContract:
    image_shape: Tuple[int, int, int]   # (X, Y, Z) — builder handles axis swap
    origin: np.ndarray
    spacing: np.ndarray
    points: np.ndarray
    slicer_radius: float
    slicer_height: float
    output_path: Path
```

### ApplicationStep
```python
@dataclass(frozen=True)
class ApplicationStep:
    mode: MaskOperationMode
    rule_label_names: list[str]
```

### MyocardiumRule
```python
@dataclass(frozen=True)
class MyocardiumRule:
    source_bp_label_name: str
    target_myo_label_name: str
    wall_thickness_parameter_name: str
    application_steps: list[ApplicationStep]
```

### ValveRule
```python
@dataclass(frozen=True)
class ValveRule:
    structure_a_name: str
    structure_b_name: str
    target_valve_name: str
    intersection_thickness_parameter_name: str
    application_steps: list[ApplicationStep]
```

### RingRule
```python
@dataclass(frozen=True)
class RingRule:
    source_vein_label_name: str
    target_ring_label_name: str
    ring_thickness_parameter_name: str
    atrium_myocardium_name: str
    application_steps: list[ApplicationStep]
```

### Creation contracts (all frozen dataclasses)
```python
MyocardiumCreationContract(input_image, label_manager, parameters, output_path, rule: MyocardiumRule)
ValveCreationContract(input_image, label_manager, parameters, output_path, rule: ValveRule)
RingCreationContract(input_image, label_manager, parameters, output_path,
                     rule: RingRule, reference_image: sitk.Image,
                     atrium_myocardium_threshold: sitk.Image | None)
PushStructureContract(pusher_wall_label: int, pushed_wall_label: int,
                      pushed_bp_label: int, pushed_wall_thickness: float)
```

### DiagnosticReport
```python
@dataclass
class DiagnosticReport:
    image_path: Path
    schematic_name: str
    image_labels: set[int]
    expected_labels: dict[str, int]
    mismatches: list[LabelMismatch]
    # properties: has_issues, missing_labels, ok_labels
```

### LabelVolumes
```python
@dataclass
class LabelVolumes:
    by_label: dict[int, float]
    total: float
    unit: str    # "mL" or "mm3"
```

### MaskOperationMode (enum)
```python
from pycemrg_image_analysis.utilities import MaskOperationMode
# Values: ADD, REPLACE, REPLACE_EXCEPT, REPLACE_ONLY
```

### Semantic role enums
```python
from pycemrg_image_analysis.logic import MyocardiumSemanticRole, ValveSemanticRole, RingSemanticRole
# Used as keys in semantic_map dicts passed to create_from_semantic_map()
```

---

## What the Consumer Must Provide

- A `LabelManager` instance (from `pycemrg>=0.1.0`) populated with the label names and
  integer values for the target segmentation.
- A `parameters: dict[str, float]` with physical measurements (e.g., wall thickness in mm).
- A `sitk.Image` with correct spacing set — logic engines rely on physical-space distance
  maps and will produce wrong anatomy if spacing is incorrect.
- File I/O and path construction — this library returns `sitk.Image` objects; saving and
  loading is the orchestrator's responsibility (use `load_image` / `save_image` from
  `utilities`).
- Rule construction — builders return contracts with `rule=None`; the orchestrator must
  set the rule via `dataclasses.replace(contract, rule=my_rule)` before calling a logic
  engine.
- For ring workflows: a frozen reference image captured before the ring sequence begins.

---

## Known Constraints

- Image spacing must be correct. `MyocardiumLogic` and `ValveLogic` use physical-space
  distance maps; wrong spacing silently produces wrong wall thicknesses or valve
  placements.
- Application step order is critical. Steps write to the same output array in sequence;
  wrong ordering silently overwrites anatomy.
- `keep_largest_component` vs `keep_largest_structure`: wrong choice silently keeps
  disconnected anatomy fragments.
- `CylinderCreationContract.image_shape` is `(X, Y, Z)`. `SegmentationLogic.create_cylinder`
  performs the internal axis swap to `(Z, Y, X)`. Do not pre-swap.
- ML utilities (`metrics.py`, `augmentation.py`) require normalized `[0, 1]` input in
  `(Z, Y, X)` axis order. Wrong order or range produces silently incorrect results.
- `downsample_volume` `preserve_extent` flag changes the resampling formula. Results
  diverge for small volumes; choose based on whether your pipeline normalizes by
  `(dim-1)*spacing` or `dim*spacing`.
- Integration tests are silently skipped (not failed) when `PYCEMRG_TEST_DATA_ROOT` is
  unset.
- Slicer resets labels to sequential 1-N after editing. Use
  `scaffold_components_with_mapping` or `LabelDiagnostic`/`LabelRemapper` when label
  integers differ from schematic defaults.
- `pycemrg>=0.1.0` (parent library) provides `LabelManager`. Breaking changes there
  cascade into this library.
