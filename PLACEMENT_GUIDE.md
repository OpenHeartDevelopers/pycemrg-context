# pycemrg Suite — Placement Guide

This file answers one question: **where does new functionality belong?**

---

## Library Responsibilities

### `pycemrg` (core)
**Owns:** Infrastructure that any library or orchestrator needs.
- Label translation (name ↔ integer, groups, cross-standard mapping)
- Model download, caching, and integrity verification
- Output path management
- External command execution (generic and CARPentry-specific)
- Configuration scaffolding (YAML template generation)
- Logging setup

**Does NOT own:** Anything domain-specific to images, meshes, or simulations.

**Rule:** If the functionality would be useful to all three downstream libraries, it belongs here.

---

### `pycemrg-image-analysis`
**Owns:** Everything that operates on `SimpleITK.Image` objects in memory.
- Segmentation post-processing (myocardium growth, valve creation, ring creation)
- Label remapping and component cleanup
- Image quality metrics (MSE, PSNR, SSIM, gradient error)
- Anatomy-specific schematics (LV, RV, valve blueprints)
- Recipe sequences (named workflow variants)
- Scaffolding for image analysis configs

**Does NOT own:** File I/O (orchestrator responsibility), mesh operations, simulation setup.

**Rule:** If it takes a `sitk.Image` and returns a `sitk.Image`, it belongs here.

---

### `pycemrg-model-creation`
**Owns:** Everything from segmentation image → simulation-ready mesh.
- Volumetric meshing (meshtools3d wrapper)
- Mesh refinement and tag relabeling
- Surface extraction for UVC (ventricular and atrial)
- Universal Ventricular Coordinate calculation (mguvc / FEM solver)
- Fibre field generation (GlRuleFibres)
- Path contracts and builders for all of the above
- Thin wrappers: MeshtoolWrapper, CarpWrapper, Meshtools3DWrapper

**Does NOT own:** Image segmentation logic, label translation (delegates to pycemrg core).

**Rule:** If it requires a mesh file on disk (.pts/.elem) or produces one, it belongs here.

---

## Placement Decision Guide

| New functionality                   | Where it goes                                           |
| ----------------------------------- | ------------------------------------------------------- |
| New label translation method        | `pycemrg.data`                                          |
| New external tool wrapper (generic) | `pycemrg.system`                                        |
| New image mask operation            | `pycemrg-image-analysis` logic or utilities             |
| New anatomy schematic               | `pycemrg-image-analysis` schematics                     |
| New image quality metric            | `pycemrg-image-analysis.utilities.metrics`              |
| New mesh I/O function               | `pycemrg-model-creation.utilities.mesh`                 |
| New meshtool command                | `pycemrg-model-creation.tools.wrappers.MeshtoolWrapper` |
| New surface extraction workflow     | `pycemrg-model-creation.logic.SurfaceLogic`             |
| New path contract                   | `pycemrg-model-creation.logic.contracts`                |
| New builder method                  | `pycemrg-model-creation.logic.builders`                 |
| Orchestration logic                 | The consuming orchestrator script, not any library      |

---

## Known Crossings

- `pycemrg-model-creation` imports `LabelManager` and `LabelMapper` from `pycemrg.data`
- `pycemrg-model-creation` imports `CarpRunner` and `CommandRunner` from `pycemrg.system`
- `pycemrg-image-analysis` imports `LabelManager` from `pycemrg.data`
- `pycemrg-image-analysis` and `pycemrg-model-creation` do not import from each other

---

## Open Items (as of last update)

- `pycemrg-model-creation`: FibreLogic not yet implemented (tracked in TASKS.md)
- `pycemrg-model-creation`: Atrial UVC not yet implemented
- `pycemrg-model-creation`: Open-source FEM Laplace solver planned as alternative to mguvc
- `pycemrg`: No CLAUDE.md yet
- UVC error in pycemrg: open, unresolved