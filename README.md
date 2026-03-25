# pycemrg-context

Suite-level context for AI agents (like Claude Code) when working across the pycemrg library ecosystem.

## Contents

| File                                 | Purpose                                             | Updated by                |
| ------------------------------------ | --------------------------------------------------- | ------------------------- |
| `PLACEMENT_GUIDE.md`                 | Where does new functionality belong?                | `/update-pycemrg-context` |
| `PYCEMRG_SUITE_INDEX.md`                     | What already exists and how to call it?             | `/update-pycemrg-context` |
| `commands/pycemrgise.md`             | `/pycemrgise` slash command                         | Hand-maintained           |
| `commands/update-pycemrg-context.md` | `/update-pycemrg-context` slash command             | Hand-maintained           |
| `source/*.txt`                       | Concatenated docs from each library (packer output) | Packer tool               |

## Setup

This repo is designed to be symlinked into the right Claude Code locations.
Run the following once after cloning:

```bash
# 1. Clone alongside your other pycemrg repos
# Recommended layout:
#   ~/dev/
#     pycemrg/
#     pycemrg-image-analysis/
#     pycemrg-model-creation/
#     pycemrg-context/       <-- this repo

git clone <url> ~/dev/pycemrg-context
cd ~/dev/pycemrg-context

# 2. Symlink both slash commands into your global Claude commands folder
mkdir -p ~/.claude/commands
ln -sf ~/dev/pycemrg-context/commands/pycemrgise.md ~/.claude/commands/pycemrgise.md
ln -sf ~/dev/pycemrg-context/commands/update-pycemrg-context.md ~/.claude/commands/update-pycemrg-context.md

# 3. Verify the command appears in Claude Code
# Open Claude Code in any project directory and type /pycemrgise
# It should appear in the autocomplete list.
```

## Usage

In any Claude Code session involving pycemrg work, run `/pycemrgise` before
describing your task. Claude will:

1. Load `PLACEMENT_GUIDE.md` and `PYCEMRG_SUITE_INDEX.md`
2. Load only the relevant library API references for the task
3. Confirm its understanding before writing any code

## Update Cycle

When you add a feature to any library in the suite:

```
1. Write the implementation
2. Add the API entry to the library's docs/API_reference.md
3. Run your packer tool to regenerate source/*.txt
4. Open Claude Code from the pycemrg-context directory
5. Run /update-pycemrg-context
6. Review the diff summary Claude presents
7. Confirm — Claude patches PLACEMENT_GUIDE.md and PYCEMRG_SUITE_INDEX.md
8. Commit everything together
```

The `/update-pycemrg-context` command reads from `source/`, diffs against
the current derived files, and patches only what has changed. It will flag
any ambiguous placement decisions for human review before writing.

## Source Files

The `source/` directory contains concatenated documentation produced by your
packer tool. One file per library:

| File                                    | Source library         |
| --------------------------------------- | ---------------------- |
| `pycemrg_context_md.txt`                | pycemrg (core)         |
| `pycemrg-image-analysis_context_md.txt` | pycemrg-image-analysis |
| `pycmerg-model-creation_context_md.txt` | pycemrg-model-creation |

These are the ground truth. `PLACEMENT_GUIDE.md` and `PYCEMRG_SUITE_INDEX.md` are
derived from them and should never be edited directly -- use the update cycle.

## Maintenance

## Manual Maintenance

Only two things require direct edits:

- `commands/pycemrgise.md` -- if you change your directory layout, update the `@file` paths
- `commands/update-pycemrg-context.md` -- if you add a fourth library, add its source file here

Everything else is managed through the update cycle above.

### Path assumptions

The `pycemrgise.md` command uses relative `@file` paths assuming this layout:

```
~/dev/
  pycemrg/
  pycemrg-image-analysis/
  pycemrg-model-creation/
  pycemrg-context/
    commands/
      pycemrgise.md         <- symlinked to ~/.claude/commands/
    PLACEMENT_GUIDE.md
    PYCEMRG_SUITE_INDEX.md
    README.md
```

If your layout differs, update the paths in `commands/pycemrgise.md` accordingly.

## Relationship to individual library CLAUDE.md files

Each library has its own `CLAUDE.md` covering project-specific commands,
architecture, and gotchas. This repo is not a replacement for those files.

| Scope                               | Location                          |
| ----------------------------------- | --------------------------------- |
| Personal practices, manifest        | `~/.claude/CLAUDE.md`             |
| Suite-level placement + index       | This repo                         |
| Library-specific commands + gotchas | `{library}/CLAUDE.md`             |
| Full API reference                  | `{library}/docs/API_reference.md` |