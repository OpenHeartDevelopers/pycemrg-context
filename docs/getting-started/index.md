# Getting Started

Install the suite context into your `~/.claude` directory, then drive it from any
Claude Code session.

## Prerequisites

- [Claude Code](https://docs.claude.com/claude-code) installed and on `PATH`
  (`claude --version` should work).
- `git`.

## Install

The installer places the command files, the `pycemrg-docs` skill, and the suite
data files (`LIBRARY_REGISTRY.md`, `PYCEMRG_SUITE.md`, `source/*.md`) into
`~/.claude`.

=== "macOS / Linux"

    ```bash
    git clone https://github.com/OpenHeartDevelopers/pycemrg-context ~/dev/pycemrg-context
    cd ~/dev/pycemrg-context
    ./install.sh
    ```

    The script **symlinks** the files, so a `git pull` is picked up
    automatically; re-run only if files were added or removed.

=== "Windows (PowerShell)"

    ```powershell
    git clone https://github.com/OpenHeartDevelopers/pycemrg-context $HOME\dev\pycemrg-context
    cd $HOME\dev\pycemrg-context
    .\install.ps1
    ```

    `install.ps1` **copies** the files into `%USERPROFILE%\.claude` (no symlinks,
    so no Developer Mode or admin needed). Because they're copies, **re-run
    `install.ps1` after every `git pull`**.

    If PowerShell blocks the script, allow it for the current process only:

    ```powershell
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
    ```

Start a new Claude Code session afterwards to pick up the changes.

## Your first build plan

In any Claude Code session, run:

```
/pycemrg-build
```

Then describe what you want to build. Claude will:

1. Decompose the task into sequential steps.
2. Ask you to confirm the decomposition (with a trace table mapping each step
   back to your exact words).
3. Route to the relevant library source files.
4. Produce a build plan tagging each step as **SUITE** / **PROJECT** / **GAP**.
5. Emit a project scaffold and consolidated install instructions.

See **[Commands & Skills → pycemrg-build](../tools/pycemrg-build.md)** for the
full flow, or **[Dashboard](../dashboard.md)** for a browser-based front-end.
