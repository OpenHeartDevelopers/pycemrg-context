Audit the current codebase and produce a refactoring plan that maps the
user's existing code to the pycemrg suite.

The user has a project they've already written. You will read the code,
infer what it does, and recommend where suite functions should replace
hand-rolled logic, where the code should stay as-is, and where the code
is already using suite functions but doing so incorrectly.

## Step 0: Load suite overview

## Step 0: Load suite overview

Read @~/.claude/pycemrg-context/LIBRARY_REGISTRY.md to find install instructions per library.
Read @~/.claude/pycemrg-context/PYCEMRG_SUITE.md to identify which libraries cover which capabilities.


## Step 1: Inventory the codebase

Identify which files in the current working directory contain the logic
to be audited. Default to Python files in the project root and `src/`,
excluding tests, build artifacts, virtual environments, and anything
in `.gitignore`.

If the project structure is ambiguous (multiple plausible source roots,
mixed languages, monorepo layout), ask the user which paths to audit
before proceeding.

## Step 2: Infer the codebase's purpose

Read the identified files and produce a short description of what the
code does, in the same shape that `pycemrg-build` would receive as input
from a user. Aim for 3–7 sentences covering:

- The overall pipeline or workflow the code implements
- The key operations performed on cardiac imaging data
- The inputs the code expects and the outputs it produces

Separate **load-bearing operations** (image transformations, segmentation
logic, meshing, model creation) from **plumbing** (file I/O glue,
configuration loading, logging, CLI parsing). The audit targets
load-bearing operations; plumbing is almost always [PROJECT].

State the inferred description back to the user. Do not proceed until
they confirm or correct it. Misreading the codebase here propagates
through every later step, so the confirmation matters.

## Step 3: Decompose into steps

From the confirmed description, identify the sequential load-bearing
steps the codebase performs. Surface implicit steps even if they're
spread across many functions in the actual code (e.g. label remapping
that happens inline inside another function still counts as its own
step).

State the decomposition. Confirm with the user before routing.

## Step 4: Route to source files

Based on the confirmed decomposition, identify which library each step 
likely involves. Load only those source files:

- pycemrg core:            @~/.claude/pycemrg-context/source/pycemrg-core.md
- pycemrg-image-analysis:  @~/.claude/pycemrg-context/source/pycemrg-image-analysis.md
- pycemrg-meshing:         @~/.claude/pycemrg-context/source/pycemrg-meshing.md
- pycemrg-model-creation:  @~/.claude/pycemrg-context/source/pycemrg-model-creation.md

If a source file does not exist, tell the user that library hasn't been 
indexed yet, and proceed with what's available.


## Step 5: Produce the refactor plan

For each step in the decomposition, classify and tag:

- **[SUITE]** — the user's code hand-rolls something the suite already
  provides. Specify:
  - Which file(s) and function(s) in the user's code implement this
  - Which library and suite function would replace it
  - What the user would need to construct (contracts, label managers, etc.)
  - Any "Known Constraint" from the source file relevant to this use
  - Why the suite function is a better choice than the hand-rolled one
    (e.g. handles spacing correctly, avoids axis-order bugs)

- **[FIX]** — the user's code already calls a suite function, but does so
  incorrectly. Specify:
  - Which call in the user's code
  - What's wrong (wrong axis order, wrong contract field, missed
    Known Constraint, etc.)
  - The corrected usage

- **[PROJECT]** — code that's genuinely project-specific (study-specific
  orchestration, file path conventions, custom validation, ad-hoc glue).
  Leave it alone. Briefly note why it's [PROJECT] rather than [SUITE].

- **[GAP]** — hand-rolled logic that looks reusable across projects but
  isn't in any suite library. Flag as a candidate for future
  contribution. Do not block the refactor — the user keeps the code as
  is for now, but the flag is logged in the output.

## Step 6: Consolidate install instructions

For every [SUITE] and [FIX] step, look up the library in
LIBRARY_REGISTRY.md and output the correct install command. Deduplicate.

## Step 7: Output format

Produce a single markdown document with:

1. **Inferred description** — the confirmed summary of what the code does
2. **Decomposition** — the confirmed numbered steps
3. **Refactor plan** — each step with its tag, file/function reference
   in the user's code, the suite function (if SUITE or FIX), constraints,
   and rationale. Order: all [FIX] first (correctness bugs), then [SUITE]
   (replacements), then [GAP], then [PROJECT].
4. **Install** — consolidated install commands for all libraries needed
5. **Gaps flagged** — list of [GAP] items, one line each. Empty section
   if no gaps.

## Constraints

- Do not rewrite the user's code. Recommend, point at specific lines or
  functions, show the suite call site as a sketch, but do not produce a
  full diff or patched file. The user applies the refactor.
- Order [FIX] items first in the output. Correctness bugs matter more
  than replacements.
- Surface "Known Constraints" from source files whenever a recommended
  suite function has one — these are exactly the gotchas the user is
  likely to hit when adopting it.
- When the user's existing code is genuinely a project concern (file
  layout, study-specific labels, custom logging), say so and move on.
  Avoid the temptation to suite-ify everything.
- If a step is ambiguous (the user's code could map to multiple suite
  functions, or it's unclear which library applies), ask the user before
  assuming.
- If the codebase is too large to read in full, ask the user which
  subdirectory or pipeline stage to focus on first. Better to audit one
  stage well than the whole codebase shallowly.