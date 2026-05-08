Rebuild PLACEMENT_GUIDE.md and PYCEMRG_SUITE_INDEX.md from updated source files.

## Step 0: Load library paths

Read @../LIBRARY_PATHS.md to resolve absolute paths for each library.
If the file does not exist, tell the user to run `./install.sh` from the
pycemrg-context repo first and stop.

## Step 1: Identify which library changed

Ask the user which library was updated, or infer from context. Resolve the
corresponding source file:

| Library                | Source file                          |
| ---------------------- | ------------------------------------ |
| pycemrg-core           | `source/pycemrg-core.md`             |
| pycemrg-image-analysis | `source/pycemrg-image-analysis.md`   |
| pycemrg-model-creation | `source/pycemrg-model-creation.md`   |

If the source file does not exist or is stale, tell the user to run
`/refresh-source [library]` first and stop.

Read the identified source file(s).

## Step 2: Read the existing derived files

Read the current versions of both files to understand what has changed:
- @../PLACEMENT_GUIDE.md
- @../PYCEMRG_SUITE_INDEX.md

## Step 3: Identify what has changed

Compare the source files against the current derived files. List:
- New public functions, classes, or modules added
- Existing signatures that have changed
- Anything removed or deprecated
- Any new gotchas or non-obvious constraints mentioned in CLAUDE.md files
- Any new open items or resolved items

Present this diff summary and wait for confirmation before writing anything.

## Step 4: Update the derived files

After confirmation, update only what has changed. Do not regenerate
the files from scratch -- patch the relevant sections in place.

Follow these rules:
- PLACEMENT_GUIDE.md: update library responsibility sections and the
  placement decision table if new module types appear. Update Open Items.
- PYCEMRG_SUITE_INDEX.md: add new entries, update changed signatures, remove
  anything no longer present. Preserve the compressed format -- no full
  docstrings, no examples, signatures only.

## Step 5: Confirm

Report what was changed in each file and flag anything ambiguous that
needs a human decision (e.g. a function that could belong in more than
one library).