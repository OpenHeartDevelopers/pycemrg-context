Help the user compose a project from the pycemrg suite of libraries.

The user will describe what they want to build. You will recommend which 
libraries and functions to use, where gaps exist, and produce a build plan.

## Step 0: Load suite overview

Read @../LIBRARY_REGISTRY.md to find install instructions per library.
Read @../PYCEMRG_SUITE.md to identify which libraries cover which capabilities.

## Step 1: Decompose the task

Break the user's request into sequential steps. State the decomposition 
back to the user. Do not proceed until they confirm or correct it.

Surface implicit steps the user did not mention but that the task requires
(e.g. loading the image, applying label remapping before extraction).

Example: "extract myocardium of the two atria with these labels, then create a mesh"
  → Step 1: Load image and apply label remapping
  → Step 2: Extract myocardium from atrial blood pool labels  
  → Step 3: Mesh the result

## Step 2: Route to source files

Based on the confirmed decomposition, identify which library each step 
likely involves. Load only those source files:

- pycemrg core:            @../source/pycemrg-core.md
- pycemrg-image-analysis:  @../source/pycemrg-image-analysis.md
- pycemrg-meshing:         @../source/pycemrg-meshing.md
- pycemrg-model-creation:  @../source/pycemrg-model-creation.md

If a source file does not exist, tell the user that library hasn't been 
indexed yet, and proceed with what's available.

## Step 3: Produce the build plan

For each step in the decomposition, classify and tag:

- **[SUITE]** — handled by an existing function. Specify:
  - Which library, which function, what it expects, what it returns
  - Any "Known Constraint" from the source file relevant to this use
  - Code sketch showing how to call it (imports + invocation)

- **[PROJECT]** — not in the suite, and looks project-specific (file I/O 
  orchestration, study-specific logic, ad-hoc glue). The user writes this 
  in their own code. Briefly describe what they need to write.

- **[GAP]** — not in the suite, but looks reusable across projects. Flag 
  it as a candidate for future contribution. Do not block the user — they 
  write it themselves for now, but the flag is logged in the output.

## Step 4: Consolidate install instructions

For every [SUITE] step, look up the library in LIBRARY_REGISTRY.md and 
output the correct install command (pip or git clone, depending on 
distribution mode). Deduplicate across steps.

## Step 5: Output format

Produce a single markdown document with:

1. **Confirmed decomposition** — the numbered steps
2. **Build plan** — each step with its [SUITE]/[PROJECT]/[GAP] tag, 
   library + function (if SUITE), constraints to be aware of, code sketch
3. **Install** — consolidated pip / git clone commands for all [SUITE] libraries
4. **Gaps flagged** — list of [GAP] items with one-line description of 
   what's missing. Empty section if no gaps.

## Constraints

- Do not write the user's orchestrator for them. Recommend, don't implement.
  Code sketches show how to CALL a function, not how to wire it into the
  full pipeline.
- Surface "Known Constraints" from source files when they apply to a step.
  These are hard-won gotchas and the consumer needs them upfront.
- If a step is ambiguous (could be done by multiple functions, or unclear 
  which library), ask the user before assuming.
- If the user's description is too vague to decompose, ask clarifying 
  questions before producing a plan.