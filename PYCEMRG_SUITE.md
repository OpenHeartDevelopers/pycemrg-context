# pycemrg Suite — Capabilities Overview

One-paragraph purpose plus capabilities list per library. Used as the 
first-pass router by `/pycemrg-build` to decide which detailed source 
files to load.

When a capability isn't here, the library probably doesn't cover it.

**For installation instructions:** see LIBRARY_REGISTRY.md

---

## pycemrg (core)

**Purpose:** `pycemrg` is the stable core library for cardiac imaging and electrophysiology
simulation workflows. It provides reusable, stateless components for label
management, asset caching, subprocess execution, output path generation, and
project scaffolding that downstream suite packages depend on.

**Capabilities:**
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

**See:** `source/pycemrg-core.md` for function-level detail.

---

## pycemrg-image-analysis

**Purpose:** Stateless library for cardiac image segmentation 
post-processing, built on SimpleITK. Operates on in-memory `sitk.Image` 
objects with no file I/O. Provides logic engines for myocardium and 
valve creation, anatomy schematics, ML utilities (metrics, augmentation, 
artifact simulation), and image I/O helpers for orchestrators.

**Capabilities:**
- Grow myocardium walls outward from blood pool labels using physical-space distance maps
- Create valve planes and ring structures from anatomical blueprints
- Remap segmentation labels and create cylinder masks
- Run pre-sequenced workflow recipes (biventricular_basic, four_chamber_full, etc.)
- Generate template configuration files (YAML/JSON) for image analysis workflows
- Compute image quality metrics for ML validation (MSE, PSNR, SSIM, gradient error)
- Apply ML augmentation, artifact simulation, and patch sampling utilities
- Clean connected components (per-label or as one structure)
- Load and save sitk.Image files (orchestrator-level I/O)

**See:** `source/pycemrg-image-analysis.md` for function-level detail.

---

## pycemrg-meshing

**Purpose:** Python wrapper for the `meshtools3d` and `laplace_solver` C++ binaries used in
cardiac mesh generation workflows. Handles parameter-file authoring, binary
discovery via `pycemrg.ModelManager`, and process invocation with correct
library-path injection.

**Capabilities:**
- Author and persist a `meshtools3d`-compatible `.par` parameter file with
  validated section/key schema
- Load, override, and round-trip an existing `.par` file without losing unknown
  sections being silently introduced
- Build a structured job description that binds a segmentation path, output
  directory, and output basename, then render it to a parameter file in one call
- Convert a non-`.inr` segmentation to `.inr` via an injected converter before
  constructing the job (converter is caller-supplied; this library imports no
  image I/O)
- Enumerate the output files a job is expected to produce given the parameter
  flags (`out_carp`, `out_vtk`, `out_medit`)
- Execute `meshtools3d` against a parameter file, resolving the binary either
  from an explicit path or via `pycemrg.ModelManager` against the bundled
  `models.yaml`
- Execute `laplace_solver` against a parameter file using the same resolution
  and library-injection mechanism
- Emit a default parameter file from the CLI without writing any Python

**See:** `source/pycemrg-meshing.md` for function-level detail.

---

## pycemrg-model-creation

**Purpose:** Provides a pipeline for building simulation-ready cardiac meshes from NIfTI segmentations: volumetric meshing, myocardium refinement, cardiac surface extraction, and Universal Ventricular Coordinate (UVC) calculation. Wraps CARPentry/openCARP CLI tools behind stateless, path-contract–driven Python logic classes.

**Capabilities:**
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

**See:** `source/pycemrg-model-creation.md` for function-level detail.