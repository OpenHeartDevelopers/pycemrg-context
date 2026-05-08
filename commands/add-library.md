Onboard a new library into the pycemrg suite. Updates all suite-level files
so the library is fully registered and indexed.

## Arguments

Requires two arguments:
1. Library name — the key used across suite files (e.g. `pycemrg-simulation`)
2. Absolute path to the library repo (e.g. `/Users/jose/dev/pycemrg-simulation`)

If either is missing, ask before proceeding.

## Step 0: Validate

Confirm that the provided repo path exists and is a directory. If not, stop
and report the bad path.

Read @../LIBRARY_PATHS.md. If it does not exist, tell the user to run
`./install.sh` first and stop.

Check that the library name is not already registered in LIBRARY_PATHS.md.
If it is, tell the user to use `/refresh-source [library]` instead and stop.

## Step 1: Register the library path

Append a new row to the table in LIBRARY_PATHS.md:

```
| <library-name> | <absolute-path> |
```

## Step 2: Patch command tables

Edit each of the following files to add the new library entry. Present all
four edits together and wait for confirmation before writing any of them.

- `install.sh` — add `["<library-name>"]="<repo-dirname>"` to the LIBRARIES map
- `commands/refresh-source.md` — add a row to the target table in Step 1
- `commands/pycemrgise.md` — add a line to the source file list in Step 2
- `commands/update-pycemrg-context.md` — add a row to the source table in Step 1

## Step 3: Generate source file

Invoke `/export-api` with the new library's repo path as the target codebase.
Write the output to `source/<library-name>.md`.

Show a preview of the top-level sections and wait for confirmation before writing.

## Step 4: Update derived files

Read @../PLACEMENT_GUIDE.md and @../PYCEMRG_SUITE_INDEX.md.

Using the content of `source/<library-name>.md`, propose:
- A new library section for PLACEMENT_GUIDE.md (what it owns, what it does not
  own, the placement rule, and any known crossings with existing libraries)
- New entries for PYCEMRG_SUITE_INDEX.md (compressed API, signatures only)

Present both proposals and wait for confirmation before writing.

## Step 5: Report

List every file touched. Flag any ambiguous placement decisions or entry points
that could belong to more than one library, for human review before committing.
