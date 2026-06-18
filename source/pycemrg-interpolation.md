# pycemrg-interpolation — API Reference for External Consumers

## Purpose
Performs Z-axis super-resolution / interpolation of cardiac MRI volumes, offering
both classical SimpleITK resampling and a JAX-based Functional Autoencoder (FAE)
backend. Part of the CEMRG suite.

## Capabilities
- Upsample (or resample) a 3D volume along Z to a target voxel spacing while preserving physical extent
- Choose a classical interpolation method: nearest, linear, B-spline, Gaussian, or Lanczos
- Run learned (FAE) interpolation that operates on continuous pointclouds instead of voxel grids
- Tile large volumes for FAE inference and reassemble the result (memory-bounded inference)
- Train an FAE for Z-axis super-resolution with self-supervised slice-masking
- Build training datasets from NIfTI volumes (random/center patches or whole synthetic volumes)
- Generate synthetic gradient phantom volumes for regression testing and pipeline checks
- Convert between pycemrg (Z,Y,X) volumes and FAE (X,Y,Z) normalized pointclouds

## Install
Editable install with sibling CEMRG packages (dependencies first); JAX required for
the FAE path, optional for the classical path:

```bash
pip install "jax[cpu]"
pip install -e ../pycemrg
pip install -e ../pycemrg-image-analysis
pip install -e $HOME/installs/functional-autoencoders
pip install -e .   # pycemrg-interpolation
```

Note: the top level only exports `__version__`. Import logic classes from their
submodule paths (shown below); there is no `interpolate_volume` convenience function
despite the README example.

## Key Entry Points

### ClassicalInterpolationLogic
Import: `from pycemrg_interpolation.logic.classical import ClassicalInterpolationLogic, InterpolationMethod`
Purpose: Stateless classical resampling via SimpleITK ResampleImageFilter.

```python
ClassicalInterpolationLogic(method: InterpolationMethod = InterpolationMethod.LINEAR)
logic.run(request: InterpolationRequest) -> InterpolationResult
```
Notes: Input/output volumes are `(Z, Y, X)`. Target dimensions are recomputed to
preserve physical extent (`round(extent/target_spacing)+1`), so target_shape may
differ ±0.5 voxel from a naive scale. No JAX dependency.

### FAEInterpolationLogic
Import: `from pycemrg_interpolation.logic.interpolation import FAEInterpolationLogic`
Purpose: Stateless FAE interpolation (volume → pointcloud → encode/decode → volume).

```python
logic.run(request: InterpolationRequest) -> InterpolationResult
```
Notes: Requires `request.model_params` (trained FAE weights) and `latent_dim` to
match the trained model. Builds the model internally via `create_fae_model`.

### TiledInferenceManager
Import: `from pycemrg_interpolation.logic.tiling import TiledInferenceManager`
Purpose: Runs FAEInterpolationLogic over `(Z,Y,X)` tiles for large volumes.

```python
TiledInferenceManager(tile_size_zyx: Tuple[int,int,int] = (32, 64, 64))
manager.run(request: InterpolationRequest) -> InterpolationResult
```
Notes: Only the Z-axis is rescaled; Y/X dimensions are preserved.

### create_fae_model
Import: `from pycemrg_interpolation.utilities.fae_model import create_fae_model, initialize_model_params`
Purpose: Construct the JAX/Flax FAE (PoolingEncoder + NonlinearDecoder + RandomFourierEncoding).

```python
create_fae_model(latent_dim: int = 128) -> Autoencoder
initialize_model_params(autoencoder) -> dict   # RANDOM weights (proof-of-concept)
```
Notes: `initialize_model_params` does not produce trained weights; load real params separately.

### FAETrainerLogic / TrainingConfig
Import: `from pycemrg_interpolation.training.trainer import FAETrainerLogic, TrainingConfig`
Purpose: Stateless FAE training loop wrapping the functional_autoencoders trainer.

```python
FAETrainerLogic(config: TrainingConfig)
logic.train(train_loader: Iterator, test_loader_factory: Callable) -> Dict[str, Any]
```
Notes: `test_loader_factory` is a callable returning a fresh finite iterator, not an iterator.

### Datasets and loader
Import: `from pycemrg_interpolation.training.dataset import VolumetricPatchDataset, SyntheticGradientDataset, JAXDataLoader`
Purpose: Produce `(u_enc, x_enc, u_dec, x_dec)` pointcloud batches from NIfTI files.

```python
VolumetricPatchDataset(volume_paths, patch_size=(64,64,32), intensity_clip_range=(-150,1000), mode="train", seed=42)  # patch_size is (X,Y,Z)
JAXDataLoader(dataset, masking_transform=None, infinite=False, name="Loader")
```
Notes: `masking_transform` adds the batch dimension; without it the loader adds it.

### Masking transforms
Import: `from pycemrg_interpolation.training.masking import SliceLevelMaskingTransform, ComplementMaskingTransform`
Purpose: Self-supervised masking. SliceLevel = encoder sees alternate Z-slices
(trains Z super-resolution); Complement = random voxel split (general interpolation).

### Pointcloud adapter
Import: `from pycemrg_interpolation.utilities.pointcloud import volume_to_pointcloud, pointcloud_to_volume, create_target_pointcloud`
Purpose: Convert between `(Z,Y,X)` volumes (spacing `sx,sy,sz`) and FAE `(X,Y,Z)`
coordinate pointclouds normalized to `[0,1]` by physical extent.

### Phantom generators
Import: `from pycemrg_interpolation.utilities.phantoms import create_z_gradient, create_xy_gradient, create_radial_gradient, create_sinusoidal_z, create_combined_gradient`
Purpose: Generate synthetic gradient volumes (shape given as `(H,W,D)`/`(X,Y,Z)`).

### CLI orchestrators
Run via `python scripts/<name>.py` (not installed console scripts):
- `interpolate_classical.py --input --output --target-z-spacing --method {nearest,linear,bspline,gaussian,lanczos}`
- `train_fae.py --data-dir` (expects `train/` and `test/` subdirs of `.nii.gz`)
- `generate_synthetic_data.py`, `evaluate_interpolation.py`

## Contracts and Data Structures

### InterpolationRequest
Import: `from pycemrg_interpolation.logic.contracts import InterpolationRequest`
- `volume: np.ndarray` — `(Z, Y, X)`
- `original_spacing: Tuple[float, float, float]` — `(sx, sy, sz)` mm
- `target_z_spacing: float`
- `model_params: Dict[str, Any]` — FAE weights (unused by classical backend)
- `latent_dim: int = 128`

### InterpolationResult
- `volume: np.ndarray` — `(Z, Y, X)`
- `original_shape: Tuple[int,int,int]`, `target_shape: Tuple[int,int,int]` — `(Z,Y,X)`
- `original_spacing`, `target_spacing: Tuple[float,float,float]` — `(sx,sy,sz)`; target is the achieved spacing

### TrainingConfig
- `latent_dim=64`, `max_steps=5000`, `learning_rate=1e-3`, `beta=1e-5`, `seed=42`

## What the Consumer Must Provide
- Input volumes as `(Z, Y, X)` numpy arrays and their `(sx, sy, sz)` spacing
  (e.g. via `pycemrg_image_analysis.utilities.io` + `sitk.GetArrayFromImage`)
- File I/O, path construction, logging setup — none of the logic classes touch disk
- Trained FAE `model_params` and a matching `latent_dim` for any FAE inference
- For training: lists of NIfTI paths, a configured loader/dataset, and a JAX runtime
- The functional_autoencoders package and JAX for any FAE (non-classical) operation

## Known Constraints
- Axis-order discipline is critical: internal volumes are `(Z,Y,X)`, FAE coords are
  `(X,Y,Z)`, and several CLI/dataset args (patch_size, phantom shape) are `(X,Y,Z)`.
- Encoder and decoder must normalize by the identical physical extent
  (`(dim-1)*spacing`); mismatched extents silently corrupt FAE output.
- Resampling preserves physical extent, not raw voxel count (target dims rounded).
- `initialize_model_params` returns random, untrained weights.
- `models/*` and `data/**/*` are gitignored — trained weights/datasets ship out-of-band.
- Only `__version__` is exported at package top level; import from submodules.
