# pycemrg-context

Suite-level context for AI agents (Claude Code) when consumers compose 
projects from the pycemrg library suite.

## What this is for

When a user is building a project that needs pycemrg functionality 
("extract atrial myocardium, then mesh it"), this repo lets Claude:

1. Recommend which pycemrg libraries and functions to use
2. Output the right install instructions per library (pip or git clone)
3. Flag steps that aren't in the suite — distinguishing project-specific 
   glue from things that look like missing suite capabilities

This is a **consumer-side** tool. It does not handle contribution back to 
the suite; that goes through normal GitHub Issues/PRs in the individual 
library repos.

## Setup

````bash
git clone <url> ~/dev/pycemrg-context
cd ~/dev/pycemrg-context
./install.sh
````

The install script symlinks command files into `~/.claude/commands/`. 
Re-run if you pull updates to the commands.

## Usage

In any Claude Code session, run:

````
/pycemrg-build
````

Then describe what you want to build. Claude will:

1. Decompose the task into steps
2. Ask you to confirm the decomposition
3. Route to the relevant library source files
4. Produce a build plan tagging each step as SUITE / PROJECT / GAP
5. Output consolidated install instructions

## Repo contents

| File                        | Purpose                                          | Maintained by      |
| --------------------------- | ------------------------------------------------ | ------------------ |
| `LIBRARY_REGISTRY.md`       | One row per library: name, distribution, install | Hand (you)         |
| `PYCEMRG_SUITE.md`          | One-paragraph + capabilities per library         | CI (future) / hand |
| `source/*.md`               | Per-library API reference for consumers          | CI on push to main |
| `commands/pycemrg-build.md` | The consumer slash command                       | Hand               |
| `commands/export-api.md`    | Prompt run by CI to generate source files        | Hand               |

## Adding a library to the suite

1. Add a row to `LIBRARY_REGISTRY.md`
2. Add a section to `PYCEMRG_SUITE.md` (until CI generates this)
3. Set up the export-api CI workflow in the new library's repo 
   (see `docs/CI_SETUP.md` — to be written when first CI workflow lands)
4. Source file appears under `source/` on the library's next push to main

## Relationship to library CLAUDE.md files

| Scope                               | Location                                        |
| ----------------------------------- | ----------------------------------------------- |
| Personal practices, manifest        | `~/.claude/CLAUDE.md`                           |
| Suite-level consumer routing        | This repo                                       |
| Library-specific commands + gotchas | `{library}/CLAUDE.md`                           |
| Full per-library API reference      | `source/{library}.md` (this repo, CI-generated) |