Regenerate one or all `source/` markdown files from the current state of the library repos.

## Arguments

Accepts an optional library name:
- `pycemrg-core`
- `pycemrg-image-analysis`
- `pycemrg-model-creation`

If no argument is given, refresh all three.

## Step 0: Load library paths

Read @../LIBRARY_PATHS.md to resolve absolute paths for each library.
If the file does not exist, tell the user to run `./install.sh` first and stop.
If any required library path is marked NOT FOUND, warn the user and skip that library.

## Step 1: Identify targets

Parse the argument to determine which libraries to refresh. Map each library
to its path from LIBRARY_PATHS.md and its output file:

| Library                | Source output                      |
| ---------------------- | ---------------------------------- |
| pycemrg-core           | `source/pycemrg-core.md`           |
| pycemrg-image-analysis | `source/pycemrg-image-analysis.md` |
| pycemrg-model-creation | `source/pycemrg-model-creation.md` |

## Step 2: Generate API reference

For each target, invoke `/export-api` with the library's repo path from
LIBRARY_PATHS.md as the target codebase. Write the output to the
corresponding `source/[library].md`.

If `source/[library].md` already exists, present a diff summary of what
changed before writing and wait for confirmation.

If the file does not exist yet, show a preview of the top-level sections
before writing.

## Step 3: Report

After writing, list each file updated and flag any new entry point whose
placement in PLACEMENT_GUIDE.md may need review.
