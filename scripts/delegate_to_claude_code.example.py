"""
Hermes -> Claude Code CLI Asynchronous Project Executor Handoff (Example)
Runs Claude Code in non-interactive headless mode (-p) inside an isolated
client project directory via OmniRoute (http://127.0.0.1:20128/v1) and records
the completion handoff to JSONL.
"""

import argparse
import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path

PROJECTS_ROOT = Path(os.getenv("CLIENT_PROJECTS_ROOT", "./client_projects")).resolve()
HANDOFF_LOG = Path(os.getenv("HANDOFF_LOG_FILE", "./client_project_handoffs.jsonl"))


def delegate_task(project_slug: str, prompt: str, model: str = "claude-sonnet-4-6") -> dict:
    project_dir = PROJECTS_ROOT / project_slug
    project_dir.mkdir(parents=True, exist_ok=True)

    env = os.environ.copy()
    env.setdefault("ANTHROPIC_BASE_URL", "http://127.0.0.1:20128/v1")
    env.setdefault("ANTHROPIC_AUTH_TOKEN", "sk-example-replace-with-local-omniroute-key")
    env.setdefault("DISPLAY", ":99")

    cmd = [
        "claude",
        "-p",
        prompt,
        "--model",
        model,
        "--allowedTools",
        "Read,Edit,Write,Bash,Glob,Grep",
        "--output-format",
        "json",
    ]

    proc = subprocess.run(
        cmd,
        cwd=str(project_dir),
        env=env,
        capture_output=True,
        text=True,
        timeout=900,
        check=False,
    )

    handoff = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "project_slug": project_slug,
        "model": model,
        "exit_code": proc.returncode,
        "stdout_preview": proc.stdout[:1000],
        "stderr_preview": proc.stderr[:500],
    }

    with HANDOFF_LOG.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(handoff) + "\n")

    return handoff


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Delegate build task to Claude Code CLI")
    parser.add_argument("--project", required=True, help="Client project directory slug")
    parser.add_argument("--prompt", required=True, help="Implementation & test prompt")
    parser.add_argument("--model", default="claude-sonnet-4-6", help="OmniRoute model or combo")
    args = parser.parse_args()

    result = delegate_task(args.project, args.prompt, args.model)
    print(json.dumps(result, indent=2))
