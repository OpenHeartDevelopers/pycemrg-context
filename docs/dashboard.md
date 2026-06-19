# Dashboard

A local web chat front-end for [`/pycemrg-build`](tools/pycemrg-build.md). Have a
short conversation with Claude to nail down what you want to build, then hit
**Finalize plan** to get a structured build document and a project scaffold you
can copy.

Source: [`dashboard/`](https://github.com/OpenHeartDevelopers/pycemrg-context/tree/main/dashboard).

## Prerequisites

- pycemrg-context installed (see [Getting Started](getting-started/index.md)) so
  `~/.claude/commands/pycemrg-build.md` and `~/.claude/pycemrg-context/` are
  populated.
- Claude Code installed and on `PATH` (`claude --version` should work).
- `ANTHROPIC_API_KEY` set in your environment (or however you've configured
  Claude Code auth).
- Python 3.10+.

## Setup & run

=== "macOS / Linux"

    ```bash
    cd dashboard
    python -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
    python server.py
    ```

=== "Windows (PowerShell)"

    ```powershell
    cd dashboard
    python -m venv .venv
    .venv\Scripts\Activate.ps1
    pip install -r requirements.txt
    python server.py
    ```

Then open <http://127.0.0.1:5050> in a browser.

## Using it

1. Type a project description and **Send**. Claude responds with a proposed
   decomposition, a trace table mapping each step back to your exact words, and
   (usually) 2–4 clarifying questions.
2. Reply. Push back on inferred steps, answer the questions, ask for alternatives.
   Iterate as many turns as you need. (Cmd/Ctrl-Enter sends.)
3. When you're happy, click **Finalize plan**. The server sends the
   `__FINALIZE__` sentinel and Claude produces the full document: confirmed
   decomposition, trace table, build plan with [SUITE]/[PROJECT]/[GAP] tags, the
   scaffold, install commands, and any flagged gaps.

## How it works

Each turn, the server reads `~/.claude/commands/pycemrg-build.md`, appends the
full conversation transcript so far, and pipes the result to `claude -p` running
from `~/.claude/pycemrg-context/` (so the `@`-references in the prompt resolve).
Claude's stdout becomes the next assistant turn and is rendered as markdown.

Sessions live in process memory only — restarting the server clears them. The
server caps concurrent sessions at 50 and LRU-evicts past that.

!!! warning "Cost & exposure"
    Each turn is one `claude -p` call against the Anthropic API and uses your API
    key (a finalized plan typically costs a few cents; prompt caching helps). The
    server binds to `127.0.0.1` only — **do not change this** without thinking
    about who can spend your API budget.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| **"claude CLI not found"** | Claude Code isn't on `PATH`. Run `which claude` (`where claude` on Windows). |
| **"command file not found"** | pycemrg-context isn't installed. Run `./install.sh` (or `install.ps1`) from the repo root. |
| **Timeout after 120s** | The prompt is doing too much. Narrow the message, or back up a turn and split your ask. |
| **"unknown session id"** | The server was restarted. Reload the page to get a fresh session. |
| **Plan looks wrong** | Compare against `/pycemrg-build` in a Claude Code session. If they differ, the dashboard is invoking the prompt wrong; if the same, the prompt template needs work. |
