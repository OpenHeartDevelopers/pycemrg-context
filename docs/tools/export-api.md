# `/export-api`

Analyzes a library's codebase and produces a structured **API reference file**
suitable for consumption by another project or orchestrator. This is the command
CI runs in each library repo to generate the `source/{library}.md` files that
`/pycemrg-build` routes to.

Source: [`commands/export-api.md`](https://github.com/OpenHeartDevelopers/pycemrg-context/blob/main/commands/export-api.md).
Installed to `~/.claude/commands/export-api.md`.

## What it does

1. **Explores the codebase** — public modules and their exports (`__init__.py`),
   entry-point classes and functions, cross-module dataclasses/contracts, and CLI
   entry points. It skips tests, build artifacts, and generated files.
2. **Writes a reference file** to the path you provide (it asks if none is given).

## Output structure

The generated file follows a fixed structure so the suite router can consume it
uniformly:

| Section | Contents |
|---|---|
| **Purpose** | One or two sentences: what the project does. |
| **Capabilities** | 5–10 task-phrased bullets (*what a consumer can accomplish*, not which classes exist). |
| **Install** | How to install or import the project as a dependency. |
| **Key Entry Points** | Per public class/function: import path, purpose, signature, non-obvious notes. |
| **Contracts and Data Structures** | Dataclasses / TypedDicts a consumer must construct, with field types. |
| **What the Consumer Must Provide** | Paths, configs, managers, env vars the calling code is responsible for. |
| **Known Constraints** | Anything that would surprise a first-time integrator. |

## Constraints

- Only documents what is **public and intended for external use** — no internal
  helpers, private methods, or test utilities.
- Every claim is grounded in something observable in the code.
- The **Capabilities** section is task-phrased, not class-phrased.
- No emojis, no generic descriptions.

!!! tip "Where the output lands"
    In CI, the output is committed as `source/{library}.md` in **this** repo on
    the library's push to `main`. See [Contributing](../contributing.md) for
    wiring up the workflow.
