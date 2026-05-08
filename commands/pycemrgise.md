Load suite context before proceeding with any pycemrg-related task.

## Step 0: Load library paths

Read @../LIBRARY_PATHS.md to resolve absolute paths for each library.
If the file does not exist, warn the user to run `./install.sh` from the
pycemrg-context repo, then continue with the remaining steps using
relative path assumptions only.

## Step 1: Load core context (always)

Read @../PLACEMENT_GUIDE.md
Read @../PYCEMRG_SUITE_INDEX.md

## Step 2: Load library-specific source reference (task-dependent)

Based on the task, identify which libraries are involved and load only
those source files. Do not load all three unless the task spans the
full pipeline.

- pycemrg core:            @../source/pycemrg-core.md
- pycemrg-image-analysis:  @../source/pycemrg-image-analysis.md
- pycemrg-model-creation:  @../source/pycemrg-model-creation.md

If a source file does not exist, fall back to the library's own API reference
using the absolute path from LIBRARY_PATHS.md:
  `[library_path]/docs/API_reference.md`

## Step 3: Confirm before proceeding

State:
1. Which libraries you have loaded
2. Your understanding of what the task requires
3. Whether the functionality already exists in the suite (check PYCEMRG_SUITE_INDEX)
4. Where any new functionality should be placed (check PLACEMENT_GUIDE)

Do not write any code until this confirmation is given and acknowledged.