# pycemrg-build dashboard

A local web chat for `/pycemrg-build`. Have a short conversation with
Claude to nail down what you want to build, then hit **Finalize plan**
to get a structured build document and a project scaffold you can copy.

## Prerequisites

- pycemrg-context installed (`./install.sh` from the repo root, with
  `~/.claude/commands/pycemrg-build.md` and `~/.claude/pycemrg-context/` populated)
- Claude Code installed and on PATH (`claude --version` should work)
- `ANTHROPIC_API_KEY` set in your environment (or however you've
  configured Claude Code auth)
- Python 3.10+

## Setup

```bash
cd dashboard
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Run

```bash
python server.py
```

Then open http://127.0.0.1:5050 in a browser.

## Using it

1. Type a project description and **Send**. Claude responds with a
   proposed decomposition, a trace table mapping each step back to the
   exact words in your request, and (usually) 2–4 clarifying questions.
2. Reply. Push back on inferred steps, answer the questions, ask for
   alternatives. Iterate as many turns as you need.
3. When you're happy, click **Finalize plan**. The server sends the
   `__FINALIZE__` sentinel and Claude produces the full document:
   confirmed decomposition, trace table, build plan with
   [SUITE]/[PROJECT]/[GAP] tags, **scaffold** (folder tree +
   `pyproject.toml` + skeleton source files + first commands to run),
   install commands, and any flagged gaps.

Cmd/Ctrl-Enter sends.

## How it works

Each turn, the server reads `~/.claude/commands/pycemrg-build.md`,
appends the full conversation transcript so far, and pipes the result
to `claude -p` running from `~/.claude/pycemrg-context/` (so the
`@`-references in the prompt resolve correctly). Claude's stdout becomes
the next assistant turn and is rendered as markdown.

Sessions live in process memory only. Restarting the server clears them.
The server caps concurrent sessions at 50 and LRU-evicts past that.

## Cost note

Each turn is one `claude -p` call against the Anthropic API and uses
your API key. A finalized plan typically costs a few cents across all
turns (prompt caching helps). The server binds to `127.0.0.1` only — do
not change this without thinking about who can spend your API budget.

## Troubleshooting

**"claude CLI not found"** — Claude Code isn't on PATH. Run
`which claude` to check.

**"command file not found"** — pycemrg-context isn't installed. Run
`./install.sh` from the repo root.

**Timeout after 120s on a turn** — the prompt is doing too much.
Narrow the message, or back up a turn and split your ask.

**"unknown session id"** — the server was restarted. Reload the page;
the frontend will create a fresh session.

**Plan looks wrong / missing constraints** — try the same conversation
in a Claude Code session with `/pycemrg-build` to compare. If they
differ, the dashboard is invoking the prompt wrong; if they're the same,
the prompt template itself needs work
(`~/.claude/commands/pycemrg-build.md`).
