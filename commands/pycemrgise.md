Load suite context before proceeding with any pycemrg-related task.

## Step 1: Load core context (always)

Read @PLACEMENT_GUIDE.md
Read @PYCEMRG_SUITE_INDEX.md

## Step 2: Load library-specific API reference (task-dependent)

Based on the task, identify which libraries are involved and load only
those API references. Do not load all three unless the task spans the
full pipeline.

- pycemrg core:            @../pycemrg/docs/API_reference.md
- pycemrg-image-analysis:  @../pycemrg-image-analysis/docs/API_reference.md
- pycemrg-model-creation:  @../pycemrg-model-creation/docs/API_reference.md

## Step 3: Confirm before proceeding

State:
1. Which libraries you have loaded
2. Your understanding of what the task requires
3. Whether the functionality already exists in the suite (check PYCEMRG_SUITE_INDEX)
4. Where any new functionality should be placed (check PLACEMENT_GUIDE)

Do not write any code until this confirmation is given and acknowledged.