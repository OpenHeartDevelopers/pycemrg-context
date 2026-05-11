Analyze the current project and produce a structured API reference file
suitable for consumption by another project or orchestrator.

## Step 1: Explore the codebase

Read the project structure. Focus on:
- Public modules and what they export (`__init__.py` files)
- Entry point classes and functions (anything intended to be imported externally)
- Key dataclasses or contracts that cross module boundaries
- CLI entry points if present

Do not read test files, build artifacts, or generated files.

## Step 2: Produce the reference file

Write the output to the path provided by the user. If no path was given,
ask for one before writing.

The file must follow this structure:

````markdown
# [Project Name] — API Reference for External Consumers

## Purpose
One or two sentences: what does this project do and what problem does it solve?

## Capabilities
High-level bullet list of what this library lets a consumer DO, phrased
as user tasks rather than module organisation. Used by the suite-level
router to decide whether this library is relevant to a given project.

- [Task-phrased capability, e.g. "Grow myocardium walls from blood pool labels"]
- [Task-phrased capability, e.g. "Compute MSE/PSNR/SSIM for ML validation"]
- [Task-phrased capability — keep these crisp, one line each]

Aim for 5–10 bullets. If the library only has 1–2 capabilities, say so;
if it has 20+, group them by theme.

## Install
How to install or import this project as a dependency.

## Key Entry Points

### [ClassName or function name]
Import: `from module.path import Name`
Purpose: one sentence.

[Signature]
```python
MethodName(param: Type, param: Type) -> ReturnType
```
Notes: anything non-obvious a consumer must know (side effects,
required preconditions, what it does NOT do).

[Repeat for each public entry point]

## Contracts and Data Structures
List any dataclasses, TypedDicts, or named structures that a consumer
must construct or handle. Include field names and types.

## What the Consumer Must Provide
Explicit list of what the calling code is responsible for:
paths, configs, managers, environment variables, etc.
This project does not handle these itself.

## Known Constraints
Anything that would surprise a developer integrating this for the first time.
````

## Constraints

- Only document what is actually public and intended for external use
- Do not document internal helpers, private methods, or test utilities
- Keep each entry point description under 10 lines
- Ground every claim in something observable in the code
- The Capabilities section must be task-phrased, not class-phrased.
  Write what the consumer can ACCOMPLISH, not what classes exist.
- No emojis, no generic descriptions