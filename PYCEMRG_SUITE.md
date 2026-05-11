# pycemrg Suite — Capabilities Overview

One-paragraph purpose plus capabilities list per library. Used as the 
first-pass router by `/pycemrg-build` to decide which detailed source 
files to load.

When a capability isn't here, the library probably doesn't cover it.

---

## pycemrg (core)

**Install:** `pip install pycemrg`

**Purpose:** [TO BE FILLED — regenerate from export-api on pycemrg core]

**Capabilities:**
- [TO BE FILLED]

**See:** `source/pycemrg-core.md` for function-level detail.

---

## pycemrg-image-analysis

**Install:** see LIBRARY_REGISTRY.md

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

**Install:** see LIBRARY_REGISTRY.md

**Purpose:** [TO BE FILLED — regenerate from export-api on pycemrg-meshing]

**Capabilities:**
- [TO BE FILLED]

**See:** `source/pycemrg-meshing.md` for function-level detail.

---

## pycemrg-model-creation

**Install:** see LIBRARY_REGISTRY.md

**Purpose:** [TO BE FILLED — regenerate from export-api on pycemrg-model-creation]

**Capabilities:**
- [TO BE FILLED]

**See:** `source/pycemrg-model-creation.md` for function-level detail.