# pycemrg-image-analysis — API Reference for External Consumers

Version: 0.1.0 (CEMRG, Imperial College London)

## Purpose
A SimpleITK-based library for cardiac image segmentation post-processing: it grows
myocardial walls from blood-pool labels, builds valves and vein rings, and provides
stateless image/label/ML utilities. It transforms label data only — it never reads
or writes the filesystem except through explicit IO helpers, and orchestration
(paths, env, logging) is the caller's responsibility.

## Capabilities
- Grow myocardium walls outward from blood-pool labels using physical-space distance maps
- Build valves as the intersection of two anatomical structures
- Build pulmonary-vein and vena-cava rings around atrial myocardium
- Create cylinder masks from plane points (vein/valve seeding)
- Push one structure inside another to correct overlapping walls
- Combine, replace, and clean label masks (add/replace/keep modes, largest-component cleanup)
- Diagnose image labels against an anatomy schematic and derive remapping suggestions
- Compute volumes per label, inspect/relabel images by integer or human-readable name
- Scaffold YAML/JSON config (labels, parameters, semantic maps) from named anatomy components
- Run pre-sequenced workflow recipes (biventricular, four-chamber, atria with veins)
- ML helpers: MSE/PSNR/SSIM metrics, per-label Dice overlap, intensity/spatial augmentation, artifact simulation, patch sampling
- Convert between SimpleITK images and the `.inr` format

## Install
```bash
pip install -e .            # from repo root; build is pyproject.toml + setuptools
```
```python
from pycemrg_image_analysis.logic import MyocardiumLogic, ValveLogic, RingLogic
from pycemrg_image_analysis import utilities, ImageAnalysisScaffolder
```
Requires `pycemrg>=0.1.0` (parent library, not in this repo) for `LabelManager` and
`ConfigScaffolder`. Also exposes a console script: `pycemrg-ima` (see CLI below).

## Key Entry Points

### MyocardiumLogic
Import: `from pycemrg_image_analysis.logic import MyocardiumLogic`
Purpose: Grow a myocardium wall from a blood pool, or push one structure inside another.
```python
create_from_semantic_map(input_image: sitk.Image, label_manager: LabelManager,
    parameters: dict[str, float], semantic_map: dict[MyocardiumSemanticRole, Any]) -> sitk.Image
push_structure(input_image: sitk.Image, contract: PushStructureContract) -> sitk.Image
```
Notes: Uses physical-space distance maps; input image spacing must be correct or wall
thicknesses are silently wrong. Stateless — returns a new image, writes nothing.

### ValveLogic
Import: `from pycemrg_image_analysis.logic import ValveLogic`
Purpose: Create a valve as the thickened intersection of two named structures.
```python
create_from_rule(contract: ValveCreationContract) -> sitk.Image
```

### RingLogic
Import: `from pycemrg_image_analysis.logic import RingLogic`
Purpose: Create a vein ring around atrial myocardium.
```python
create_from_rule(contract: RingCreationContract) -> sitk.Image
```
Notes: Contract carries a frozen `reference_image` for distance-map calculation.

### SegmentationLogic
Import: `from pycemrg_image_analysis.logic import SegmentationLogic`
Purpose: Create a cylinder mask from plane points.
```python
create_cylinder(contract: CylinderCreationContract) -> sitk.Image
```
Notes: `CylinderCreationContract.image_shape` is (X, Y, Z); the method swaps axes to
(Z, Y, X) internally for `calculate_cylinder_mask`. Callers must NOT pre-swap.

### SegmentationPathBuilder / MyocardiumPathBuilder
Import: `from pycemrg_image_analysis.logic import SegmentationPathBuilder, MyocardiumPathBuilder`
Purpose: Construct contracts from paths/geometry instead of instantiating dataclasses by hand.
```python
SegmentationPathBuilder(output_dir: Path, origin: np.ndarray, spacing: np.ndarray,
    image_shape: Tuple[int, int, int])
  .build_cylinder_contract(cylinder_name, points, slicer_radius, slicer_height) -> CylinderCreationContract
MyocardiumPathBuilder(...)
  .build_creation_contract(output_name) -> MyocardiumCreationContract
  .build_valve_contract(...) -> ValveCreationContract
  .build_ring_contract(...) -> RingCreationContract
  .update_input_image(new_input: sitk.Image) -> None
```
Notes: Preferred over direct dataclass instantiation for file-based callers.

### ImageAnalysisScaffolder
Import: `from pycemrg_image_analysis import ImageAnalysisScaffolder`
Purpose: Generate `labels.yaml`, `parameters.json`, and per-component semantic-map JSON
from named anatomy components.
```python
scaffold_components(output_dir, component_names: list[str], overwrite=False) -> None
scaffold_components_with_mapping(output_dir, component_names: list[str],
    label_mapping: Dict[str, int], overwrite=False) -> None
```
Notes: Use `scaffold_components_with_mapping` when label integer values differ from the
schematic defaults (e.g. 3D Slicer reset labels to sequential 1–N). `create_labels_manifest`
is intentionally disabled (raises NotImplementedError).

### Recipes
Import: `from pycemrg_image_analysis.recipes import get_recipe, list_recipes, RECIPE_CATALOG`
Purpose: Retrieve a pre-sequenced workflow (ordered steps + required schematics).
```python
get_recipe(name: str) -> Recipe        # raises KeyError if unknown
```
Catalog keys: `biventricular_basic`, `four_chamber_myocardium`, `four_chamber_full`,
`left_atrium_with_veins`, `right_atrium_with_veins`, `atria_full`.

### Label diagnostics and remapping
Import: `from pycemrg_image_analysis.utilities import LabelDiagnostic, LabelRemapper`
Purpose: Compare an image's labels against a schematic and derive an int→int remap.
```python
LabelDiagnostic().check_image_against_schematic(...) -> DiagnosticReport
LabelRemapper().suggest_mapping_from_report(report) -> dict[int, int]
```

### Utility functions (stateless, import-and-call)
Import: `from pycemrg_image_analysis.utilities import <name>`
- IO: `load_image(Path)`, `save_image(image, Path)`, `convert_inr_to_image`, `convert_image_to_inr`
- Masks: `MaskOperationMode`, `add_masks`, `add_masks_replace`, `add_masks_replace_except`,
  `add_masks_replace_only`, `remove_label`, `remove_labels`, `keep_labels`, `get_mask_operation_dispatcher`
- Components: `keep_largest_component` (per-label), `keep_largest_structure` (labels as one structure)
- Spatial: `resample_to_isotropic`, `compute_target_shape`, `compute_actual_spacing`,
  `get_voxel_physical_bounds`, `extract_slice_voxels`, `sample_image_at_points`
- Geometry: `calculate_cylinder_mask` (expects (Z, Y, X))
- Filters: `and_filter`, `distance_map`, `threshold_filter`
- Postprocessing: `inspect_labels`, `relabel_image(_by_name)`, `remove/keep_labels_by_name`,
  `compute_label_volumes` -> `LabelVolumes`
- Metrics (ML): `compute_mse`, `compute_psnr`, `compute_ssim`, `compute_gradient_error`, `compare_volumes`
  (intensity metrics, [0,1] input); `compute_dice(predicted, ground_truth) -> float`,
  `compute_dice_per_label(predicted, ground_truth, labels=None, include_background=False) -> Dict[int, float]`
  (segmentation overlap on binary/integer-label masks — NOT normalized intensities)
- Intensity (ML): `clip_intensities`, `normalize_min_max`, `normalize_percentile`
- Augmentation (ML): `augment_brightness`, `augment_contrast`, `augment_noise`, `create_slice_shifted_volumes`
- Sampling (ML): `extract_center_patch`, `extract_random_patch`
- Artifacts (ML): `downsample_volume(..., preserve_extent: bool = False)`

### CLI: pycemrg-ima
Entry point: `pycemrg_image_analysis.cli:main`. Config/scaffolding tooling only — not the
image pipeline.
```bash
pycemrg-ima inspect [target]               # list catalogue, or summarise a family/component
pycemrg-ima create <target> [-o config] [--labels labels.yaml]  # print/merge a labels template
```

## Contracts and Data Structures
All in `pycemrg_image_analysis.logic.contracts`, frozen dataclasses unless noted.
- `ApplicationStep(mode: MaskOperationMode, rule_label_names: list[str])`
- `MyocardiumRule(source_bp_label_name, target_myo_label_name, wall_thickness_parameter_name, application_steps: list[ApplicationStep])`
- `ValveRule(structure_a_name, structure_b_name, target_valve_name, intersection_thickness_parameter_name, application_steps)`
- `RingRule(source_vein_label_name, target_ring_label_name, ring_thickness_parameter_name, atrium_myocardium_name, application_steps)`
- `CreationContract(input_image: sitk.Image, label_manager: LabelManager, parameters: dict[str, float], output_path: Path)` — base
- `MyocardiumCreationContract(CreationContract, rule: MyocardiumRule)`
- `ValveCreationContract(CreationContract, rule: ValveRule)`
- `RingCreationContract(CreationContract, rule: RingRule, reference_image: sitk.Image, atrium_myocardium_threshold: Optional[sitk.Image] = None)`
- `CylinderCreationContract(image_shape: Tuple[int,int,int], origin: np.ndarray, spacing: np.ndarray, points: np.ndarray, slicer_radius: float, slicer_height: float, output_path: Path)`
- `PushStructureContract(pusher_wall_label: int, pushed_wall_label: int, pushed_bp_label: int, pushed_wall_thickness: float)`
- `Recipe(name, description, steps: List[WorkflowStep], required_schematics: List[str])` and `WorkflowStep(step_type, component_name)` (in `recipes.py`)
- `LabelVolumes`, `DiagnosticReport`, `LabelMismatch` (in utilities)
- Semantic-role enums: `MyocardiumSemanticRole`, `ValveSemanticRole`, `RingSemanticRole`; `ZERO_LABEL` constant.
- Schematic blueprints: `from pycemrg_image_analysis.schematics import ALL_SCHEMATICS`.

## What the Consumer Must Provide
- A `pycemrg.data.labels.LabelManager` mapping names ↔ integer labels (from the `pycemrg` parent lib).
- A `parameters` dict (wall thicknesses, etc.) and the role→name `semantic_map` for myocardium logic.
- `sitk.Image` inputs with CORRECT physical spacing and origin.
- All filesystem paths (`output_path`, output dirs) — the logic layer writes nothing on its own.
- Environment, logging, and step sequencing — orchestration lives outside this library.
- Step ordering within `*Rule.application_steps`: steps write the same output array; wrong order silently overwrites anatomy.

## Known Constraints
- ML utilities (`metrics.py`, `augmentation.py`) require input normalized to [0, 1] in (Z, Y, X)
  order; wrong axis order or range produces silently incorrect results. Exception: the Dice
  metrics (`compute_dice`, `compute_dice_per_label`) take binary masks / integer label maps, not
  normalized intensities. Dice returns NaN when both masks are empty; per-label drops background
  label 0 unless `include_background=True`.
- `downsample_volume(preserve_extent=True)` uses `(dim-1)*spacing`; default uses `dim*spacing`.
  Results diverge for small volumes — set the flag only for physical-extent-normalized pipelines.
- `keep_largest_component` cleans each label independently; `keep_largest_structure` treats given
  labels as one structure. Choosing wrong silently keeps incorrect anatomy.
- SimpleITK signed distance maps: a negative lower threshold captures both sides of a surface —
  intentional in valve/ring creation.
- `CylinderCreationContract.image_shape` is (X, Y, Z); `calculate_cylinder_mask` wants (Z, Y, X).
  Use `SegmentationLogic.create_cylinder` (swaps internally) and do not pre-swap.
- Breaking changes in the `pycemrg` parent library cascade here.
