# `/pycemrg-build`

The consumer slash command. It composes a project from the pycemrg suite by
holding a short conversation with you, then emitting a structured build plan and
a project scaffold.

Source: [`commands/pycemrg-build.md`](https://github.com/OpenHeartDevelopers/pycemrg-context/blob/main/commands/pycemrg-build.md).
Installed to `~/.claude/commands/pycemrg-build.md`.

## Run it

```
/pycemrg-build
```

Then describe what you want to build. It is a **multi-turn conversation** — it
will not emit the final plan on turn one.

## The flow

1. **Decompose.** Your request is broken into sequential steps, including implicit
   steps you didn't mention (e.g. loading the image, remapping labels before
   extraction). Inferred steps are marked so you can push back.
2. **Trace.** A table maps each step to the exact phrase in your request that
   motivates it. Inferred rows are flagged. This table is the contract — you can
   challenge any row.
3. **Confirm.** Iterate until the decomposition is right. When you're ready,
   signal readiness in plain language ("looks good, generate the plan", "go") or
   via the `__FINALIZE__` sentinel.
4. **Route.** Only the relevant per-library source files under
   [`source/`](https://github.com/OpenHeartDevelopers/pycemrg-context/tree/main/source)
   are loaded.
5. **Classify & emit.** Each step is tagged and the final document is produced.

## Step classification

| Tag | Meaning | Who writes it |
|---|---|---|
| **[SUITE]** | Handled by an existing function. Includes library, function, expected input/return, known constraints, and a code sketch. | The suite |
| **[PROJECT]** | Not in the suite and project-specific (file I/O, study-specific logic, glue). | You |
| **[GAP]** | Not in the suite but reusable — flagged as a future contribution candidate. Doesn't block you. | You (for now) |

## What you get

A single markdown document with: confirmed decomposition, the trace table, the
build plan with tags and code sketches, a **scaffold** (directory tree,
`pyproject.toml` with real dependency entries, skeleton source files, and the
first commands to run), consolidated install commands, and any flagged gaps.

!!! note "Scaffold is shape, not orchestration"
    The scaffold gives you the project's *shape* — folder tree, `pyproject.toml`
    keys, imports, function signatures, and quoted-request comments. Function
    bodies are left as `...`. It does not write your orchestration logic for you.

Prefer a browser? The **[Dashboard](../dashboard.md)** wraps this same command in
a local web chat.
