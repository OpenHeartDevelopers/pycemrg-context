# pycemrg-image-analysis — API Reference for External Consumers

## Purpose
Python library for cardiac segmentation post-processing built on SimpleITK. It turns labelled blood-pool segmentations into anatomically complete cardiac models (myocardial walls, valves, vein rings, cylinders) through stateless, contract-driven logic engines, and bundles ML-oriented utilities (metrics, augmentation, sampling, artifact simulation) for image-analysis pipelines.

## Capabilities
- Grow myocardial walls outward from blood-pool labels with configurable thickness
- Construct valves as the intersection of two anatomical structures
- Create pulmonary vein and vena cava rings trimmed to atrial myocardium
- Generate cylinder masks from points/radius/height for region clipping
- Push one wall into an adjacent structure to refine boundary anatomy
- Scaffold YAML/JSON config files (labels, parameters, semantic maps) for any of 6 standard cardiac recipes
- Diagnose label mismatches between a user's segmentation and a schematic, and suggest remappings (e.g., after 3D Slicer resets labels to 1..N)
- Read/write NRRD, NIfTI, and INR volumes; resample to isotropic spacing; convert NumPy<->SimpleITK with correct axis ordering
- Apply post-processing on label maps: keep/remove labels by name or value, keep largest component or structure, relabel, inspect, compute per-label volumes
- Compute ML validation metrics (MSE, PSNR, SSIM, gradient error) on normalised volumes
- Augment volumes (brightness, contrast, noise, slice shifts) and simulate acquisition artifacts (downsampling with configurable extent semantics)
- Extract center or random 3D patches for ML training

## Install
```bash
pip install -e .   # from repo root
```
Top-level import:
```python
import pycemrg_image_analysis as pia
from pycemrg_image_analysis import logic, utilities, schematics, recipes
```
Requires `pycemrg>=0.1.0` for `LabelManager` and `ConfigScaffolder`.

## Key Entry Points

### ImageAnalysisScaffolder
Import: `from pycemrg_image_analysis import ImageAnalysisScaffolder`
Purpose: Generate `labels.yaml`, `parameters.json`, and `semantic_maps/*.json` for a chosen set of component schematics.

```python
scaffold_components(output_dir: Path, component_names: list[str], overwrite: bool = False) -> None
scaffold_components_with_mapping(output_dir: Path, component_names: list[str], label_mapping: dict[str, int], overwrite: bool = False) -> None
```
Notes: `scaffold_components_with_mapping` overrides template integer values per-name (use when the user's image labels diverge from defaults, e.g., after Slicer reset). `create_labels_manifest` is intentionally disabled — raises `NotImplementedError`.

### SegmentationLogic
Import: `from pycemrg_image_analysis.logic import SegmentationLogic`
Purpose: Produce a cylinder mask in physical space from a `CylinderCreationContract`.

```python
create_cylinder(contract: CylinderCreationContract) -> sitk.Image
```
Notes: The contract carries `image_shape` in (X, Y, Z) order; this method internally swaps to (Z, Y, X) before calling `calculate_cylinder_mask`. Callers must not pre-swap.

### MyocardiumLogic
Import: `from pycemrg_image_analysis.logic import MyocardiumLogic`
Purpose: Build myocardial walls by growing a distance-thresholded shell around a blood-pool label and applying it via a sequence of mask operations.

```python
create_from_semantic_map(input_image: sitk.Image, label_manager: LabelManager, parameters: dict[str, float], semantic_map: dict[MyocardiumSemanticRole, Any]) -> sitk.Image
push_structure(input_image: sitk.Image, contract: PushStructureContract) -> sitk.Image
```
Notes: Image must have correct physical spacing — wall thickness is in millimetres. The order of `APPLICATION_STEPS` is significant; later steps overwrite earlier ones.

### ValveLogic
Import: `from pycemrg_image_analysis.logic import ValveLogic`
Purpose: Build valves as the intersection of structure A's growth zone (signed distance <= thickness) with structure B.

```python
create_from_rule(contract: ValveCreationContract) -> sitk.Image
```
Notes: Returns a new image with the valve label written via the contract's `application_steps`. Spacing-correct input is required.

### RingLogic
Import: `from pycemrg_image_analysis.logic import RingLogic`
Purpose: Build pulmonary-vein / vena-cava rings by thresholding a distance map around a vein label and trimming to the atrium myocardium.

```python
create_from_rule(contract: RingCreationContract) -> sitk.Image
```
Notes: Uses the contract's `reference_image` (a frozen snapshot taken before any ring is added) for the distance map, so successive rings do not interfere with each other. `atrium_myocardium_threshold` may be precomputed and reused across rings on the same atrium.

### Builders
Import: `from pycemrg_image_analysis.logic import SegmentationPathBuilder, MyocardiumPathBuilder`
Purpose: Construct contracts from path/geometry context without hand-instantiating dataclasses.

```python
SegmentationPathBuilder(output_dir, origin, spacing, image_shape)
  .build_cylinder_contract(cylinder_name, points, slicer_radius, slicer_height) -> CylinderCreationContract

MyocardiumPathBuilder(output_dir, label_manager, parameters, input_image)
  .build_creation_contract(output_name) -> MyocardiumCreationContract
  .build_valve_contract(output_name) -> ValveCreationContract
  .build_ring_contract(output_name, reference_image, atrium_myocardium_threshold=None) -> RingCreationContract
  .update_input_image(new_input: sitk.Image) -> None
```
Notes: Returned contracts have `rule=None`; the orchestrator (or a wrapper logic method) is expected to fill in the rule via `dataclasses.replace`.

### Recipes
Import: `from pycemrg_image_analysis.recipes import RECIPE_CATALOG, get_recipe, list_recipes`
Purpose: Pre-sequenced workflows (`biventricular_basic`, `four_chamber_myocardium`, `four_chamber_full`, `left_atrium_with_veins`, `right_atrium_with_veins`, `atria_full`). Each is a `Recipe(name, description, steps: list[WorkflowStep(step_type, component_name)], required_schematics)`.

### Label tools
Import: `from pycemrg_image_analysis.utilities import LabelDiagnostic, LabelRemapper, list_available_schematics, get_present_labels, check_required_labels`
Purpose: Validate that a user's segmentation contains the integer labels a schematic expects; build a custom name->int mapping when it does not.

```python
LabelDiagnostic().check_image_against_schematic(image_path: Path, schematic_name: str) -> DiagnosticReport
LabelDiagnostic().print_report(report) -> None
LabelRemapper().create_mapping_from_dict(label_mapping: dict[str, int]) -> dict[str, int]
LabelRemapper().suggest_mapping_from_report(report) -> Optional[dict[str, int]]
get_present_labels(image: sitk.Image) -> set[int]
check_required_labels(image: sitk.Image, required_label_values: set[int]) -> tuple[bool, set[int]]
```

### IO and spatial utilities
Import: `from pycemrg_image_analysis.utilities import load_image, save_image, convert_inr_to_image, convert_image_to_inr, compute_target_shape, compute_actual_spacing, resample_to_isotropic, get_voxel_physical_bounds, extract_slice_voxels, sample_image_at_points`
Purpose: SimpleITK file IO (NRRD/NIfTI), INR<->SimpleITK conversion (handles Fortran-order voxel buffers), and physical-space sampling/resampling helpers.

### Mask, filter, and component utilities
Import: `from pycemrg_image_analysis.utilities import MaskOperationMode, add_masks, add_masks_replace, add_masks_replace_except, add_masks_replace_only, remove_label, remove_labels, keep_labels, and_filter, distance_map, threshold_filter, keep_largest_component, keep_largest_structure, get_mask_operation_dispatcher`
Purpose: Stateless NumPy/SimpleITK primitives used by the logic engines and available directly to orchestrators. `keep_largest_component` cleans each label independently; `keep_largest_structure` treats a label group as one structure — pick deliberately.

### Post-processing
Import: `from pycemrg_image_analysis.utilities import inspect_labels, remove_labels_by_name, keep_labels_by_name, relabel_image, relabel_image_by_name, LabelVolumes, compute_label_volumes`
Purpose: Name-aware label manipulation through a `LabelManager`, and per-label volume reporting.

### ML utilities
Import: `from pycemrg_image_analysis.utilities import compute_mse, compute_psnr, compute_ssim, compute_gradient_error, compare_volumes, augment_brightness, augment_contrast, augment_noise, create_slice_shifted_volumes, downsample_volume, extract_center_patch, extract_random_patch, clip_intensities, normalize_min_max, normalize_percentile`
Purpose: Quality metrics, data augmentation, artifact simulation, and patch sampling for ML training and validation pipelines.

## Contracts and Data Structures

All contracts live in `pycemrg_image_analysis.logic.contracts` and are frozen dataclasses.

- `ApplicationStep(mode: MaskOperationMode, rule_label_names: list[str])`
- `CylinderCreationContract(image_shape: tuple[int,int,int], origin: np.ndarray, spacing: np.ndarray, points: np.ndarray, slicer_radius: float, slicer_height: float, output_path: Path)`
- `CreationContract(input_image: sitk.Image, label_manager: LabelManager, parameters: dict[str, float], output_path: Path)` — base
- `MyocardiumRule(source_bp_label_name, target_myo_label_name, wall_thickness_parameter_name, application_steps: list[ApplicationStep])`
- `MyocardiumCreationContract(CreationContract + rule: MyocardiumRule)`
- `ValveRule(structure_a_name, structure_b_name, target_valve_name, intersection_thickness_parameter_name, application_steps)`
- `ValveCreationContract(CreationContract + rule: ValveRule)`
- `RingRule(source_vein_label_name, target_ring_label_name, ring_thickness_parameter_name, atrium_myocardium_name, application_steps)`
- `RingCreationContract(CreationContract + rule: RingRule, reference_image: sitk.Image, atrium_myocardium_threshold: Optional[sitk.Image] = None)`
- `PushStructureContract(pusher_wall_label: int, pushed_wall_label: int, pushed_bp_label: int, pushed_wall_thickness: float)`

Enums:
- `MaskOperationMode { REPLACE, REPLACE_EXCEPT, REPLACE_ONLY, ADD }`
- `MyocardiumSemanticRole { SOURCE_BLOOD_POOL_NAME, WALL_THICKNESS_PARAMETER_NAME, TARGET_MYOCARDIUM_NAME, APPLICATION_STEPS }`
- `ValveSemanticRole { STRUCTURE_A_NAME, STRUCTURE_B_NAME, TARGET_VALVE_NAME, INTERSECTION_THICKNESS_PARAMETER_NAME, APPLICATION_STEPS }`
- `RingSemanticRole { SOURCE_VEIN_LABEL_NAME, TARGET_RING_LABEL_NAME, RING_THICKNESS_PARAMETER_NAME, ATRIUM_MYOCARDIUM_NAME, APPLICATION_STEPS }`

Diagnostic types:
- `LabelMismatch(label_name: str, expected_value: int, status: str, found_in_image: bool)`
- `DiagnosticReport(image_path, schematic_name, image_labels, expected_labels, mismatches, has_issues, missing_labels, ok_labels)`

Recipe types:
- `WorkflowStep(step_type: str, component_name: str)` — `step_type` in {"create", "valve", "ring", "push"}
- `Recipe(name, description, steps: list[WorkflowStep], required_schematics: list[str])`

Schematics:
- `pycemrg_image_analysis.schematics.ALL_SCHEMATICS: dict[str, dict]` — merged catalog with keys `labels`, `parameters`, `semantic_map`.

## What the Consumer Must Provide
- A `pycemrg.data.labels.LabelManager` instance constructed from a `labels.yaml` (or scaffolded equivalent).
- A `parameters: dict[str, float]` mapping parameter names (e.g., wall thicknesses in mm) to numeric values.
- An input `sitk.Image` segmentation with correct origin and spacing.
- The orchestration layer that loads/saves files, threads outputs of one step into the next, and decides where to write — this library never reads or writes implicit paths beyond what the contract's `output_path` declares (and even then, only the orchestrator is expected to perform the write).
- For ring workflows: a captured `reference_image` taken before any rings are added to the segmentation.
- For ML utilities: input volumes pre-normalised to [0, 1] and ordered as (Z, Y, X). No internal normalisation is performed.
- A `MyocardiumRule` / `ValveRule` / `RingRule` (or a semantic-map dict using the role enums) per logic invocation — the rule encodes which labels are sources/targets and the application step sequence.

## Known Constraints
- Image spacing must be physically correct; logic engines compute distance maps with `use_image_spacing=True`, so wrong spacing silently produces wrong wall/valve/ring thickness.
- `application_steps` order is load-bearing — steps write to the same array and later ones overwrite earlier ones. Wrong ordering corrupts anatomy silently.
- `keep_largest_component` vs `keep_largest_structure` are not interchangeable; the former cleans each label independently, the latter treats a group as one connected structure.
- `CylinderCreationContract.image_shape` is (X, Y, Z); the underlying `calculate_cylinder_mask` expects (Z, Y, X). `SegmentationLogic.create_cylinder` does the swap — never pre-swap.
- INR files store voxels in Fortran (x-fastest) order and have no origin field; `convert_inr_to_image` fixes origin at (0,0,0).
- 3D Slicer often resets labels to sequential 1..N after editing. Use `scaffold_components_with_mapping` (or `LabelDiagnostic` + `LabelRemapper`) to bridge the user's actual values to schematic names.
- ML utilities (`metrics.py`, `augmentation.py`, `sampling.py`, `artifact_simulation.py`) assume inputs in (Z, Y, X) and normalised [0, 1]; they will silently produce wrong numbers otherwise.
- `artifact_simulation.downsample_volume` has a `preserve_extent` flag: set it for ML pipelines that normalise by `(dim-1)*spacing`, leave off for standard resampling (`dim*spacing`). Results diverge for small volumes.
- `MyocardiumPathBuilder.build_*_contract` returns contracts with `rule=None`; the caller is responsible for inserting a concrete rule (e.g., via `dataclasses.replace`) before invoking the logic engine.
- Integration tests are skipped (not failed) when `PYCEMRG_TEST_DATA_ROOT` is unset — do not rely on green CI to mean integration coverage ran.
- `pycemrg>=0.1.0` is a hard dependency for `LabelManager` and `ConfigScaffolder`; upstream breaking changes cascade here.
