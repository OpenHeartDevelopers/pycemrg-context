Rebuild PLACEMENT_GUIDE.md and PYCEMRG_SUITE_INDEX.md from updated source files.

## Step 0: Refresh source file for the current library

Run packer on the current directory:
```bash
packer -r . --no-interactive --include-extensions .md -o /tmp/library_context.txt
```

Then read /tmp/library_context.txt to understand what has changed.

## Step 1: Read the existing derived files

Read the current PLACEMENT_GUIDE.md and PYCEMRG_SUITE_INDEX.md from the context repo.
Ask the user for the path if not known.

## Step 2: Read the current derived files

Read the current versions of both files to understand what has changed:
- @PLACEMENT_GUIDE.md
- @PYCEMRG_SUITE_INDEX.md

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