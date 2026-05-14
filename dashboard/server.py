"""
pycemrg-context dashboard server.

Conversational build-plan generator.

Endpoints:
  POST /session
    -> {"id": "<uuid>"}
    Creates a new chat session with an empty transcript.

  POST /session/<id>/message
    Body: {"text": "user message"}
    -> {"reply": "assistant markdown"}
    Appends the user turn, calls `claude -p` with the full transcript,
    captures stdout as the assistant turn, returns it.

The user signals "finalize the plan" either by clicking the Finalize
button in the UI (which sends the sentinel __FINALIZE__) or in plain
language. The prompt template handles both.

Sessions live in process memory only. Restarting the server clears them.
"""

import collections
import subprocess
import uuid
from pathlib import Path

from flask import Flask, jsonify, request, send_from_directory

app = Flask(__name__)

# Anchored at install location — same template the slash command uses.
CLAUDE_DIR = Path.home() / ".claude"
PYCEMRG_DIR = CLAUDE_DIR / "pycemrg-context"
COMMAND_FILE = CLAUDE_DIR / "commands" / "pycemrg-build.md"

TIMEOUT_SECONDS = 120
MAX_SESSIONS = 50

# session_id -> list of {"role": "user"|"assistant", "text": str}
# OrderedDict so we can LRU-evict the oldest when we hit the cap.
_sessions: "collections.OrderedDict[str, list[dict]]" = collections.OrderedDict()


def _touch(session_id: str) -> None:
    """Move session to MRU end of the LRU."""
    _sessions.move_to_end(session_id)


def _format_transcript(turns: list[dict]) -> str:
    lines = []
    for turn in turns:
        prefix = "User:" if turn["role"] == "user" else "Assistant:"
        lines.append(f"{prefix}\n{turn['text']}")
    return "\n\n".join(lines)


def _build_prompt(template: str, turns: list[dict]) -> str:
    transcript = _format_transcript(turns)
    return f"{template}\n\n---\n\nConversation so far:\n\n{transcript}\n\nAssistant:"


@app.route("/")
def index():
    return send_from_directory(".", "index.html")


@app.route("/session", methods=["POST"])
def create_session():
    if not COMMAND_FILE.exists():
        return jsonify({
            "error": f"command file not found at {COMMAND_FILE}. "
                     "Did you run install.sh from pycemrg-context?"
        }), 500
    if not PYCEMRG_DIR.exists():
        return jsonify({
            "error": f"pycemrg-context data directory not found at {PYCEMRG_DIR}. "
                     "Did you run install.sh?"
        }), 500

    session_id = uuid.uuid4().hex
    _sessions[session_id] = []
    while len(_sessions) > MAX_SESSIONS:
        _sessions.popitem(last=False)
    return jsonify({"id": session_id})


@app.route("/session/<session_id>/message", methods=["POST"])
def post_message(session_id: str):
    if session_id not in _sessions:
        return jsonify({"error": "unknown session id; create a new session"}), 404

    data = request.get_json(silent=True) or {}
    text = (data.get("text") or "").strip()
    if not text:
        return jsonify({"error": "text is required"}), 400

    turns = _sessions[session_id]
    turns.append({"role": "user", "text": text})
    _touch(session_id)

    template = COMMAND_FILE.read_text()
    prompt = _build_prompt(template, turns)

    try:
        result = subprocess.run(
            ["claude", "-p"],
            input=prompt,
            capture_output=True,
            text=True,
            cwd=str(PYCEMRG_DIR),
            timeout=TIMEOUT_SECONDS,
            check=False,
        )
    except FileNotFoundError:
        # Roll back the user turn so retry isn't double-counted.
        turns.pop()
        return jsonify({
            "error": "claude CLI not found on PATH. "
                     "Install Claude Code: https://docs.claude.com/claude-code"
        }), 500
    except subprocess.TimeoutExpired:
        turns.pop()
        return jsonify({
            "error": f"Claude took longer than {TIMEOUT_SECONDS}s. "
                     "Try a shorter or more specific message."
        }), 504

    if result.returncode != 0:
        turns.pop()
        return jsonify({
            "error": "claude -p exited non-zero",
            "stderr": result.stderr,
        }), 500

    reply = result.stdout
    turns.append({"role": "assistant", "text": reply})
    return jsonify({"reply": reply})


if __name__ == "__main__":
    # Local-only. Bind to 127.0.0.1 explicitly; do NOT expose to the network
    # without thinking about auth, since each turn costs API tokens.
    app.run(host="127.0.0.1", port=5050, debug=False)
