"""
Zero-Dependency Hermes Task Queue Bridge
Receives task dispatches via HTTP POST from n8n/Telegram and injects them
into the running Hermes Agent tmux session using safe argument passing.
"""

import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer

HOST = os.getenv("BRIDGE_HOST", "127.0.0.1")
PORT = int(os.getenv("BRIDGE_PORT", "5050"))
TMUX_SESSION = os.getenv("HERMES_TMUX_SESSION", "hermes-agent")
TASKS_LOG = os.path.join(os.path.dirname(__file__), "dispatched_tasks.jsonl")


class TaskBridgeHandler(BaseHTTPRequestHandler):
    def _send_json(self, status: int, payload: dict) -> None:
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(payload).encode("utf-8"))

    def do_GET(self) -> None:
        if self.path in ("/health", "/"):
            self._send_json(200, {"status": "healthy", "service": "hermes_task_bridge"})
            return

        if self.path == "/status":
            tmux_alive = False
            if sys.platform.startswith("linux"):
                res = subprocess.run(
                    ["tmux", "has-session", "-t", TMUX_SESSION],
                    capture_output=True,
                    check=False,
                )
                tmux_alive = res.returncode == 0
            self._send_json(
                200,
                {
                    "platform": sys.platform,
                    "tmux_session": TMUX_SESSION,
                    "tmux_alive": tmux_alive,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                },
            )
            return

        self._send_json(404, {"error": "not found"})

    def do_POST(self) -> None:
        if self.path != "/api/task":
            self._send_json(404, {"error": "not found"})
            return

        try:
            content_length = int(self.headers.get("Content-Length", "0"))
            raw_body = self.rfile.read(content_length).decode("utf-8")
            data = json.loads(raw_body)
            task_prompt = str(data.get("task", "")).strip()
            client_id = str(data.get("client", "anonymous")).strip()

            if not task_prompt:
                self._send_json(400, {"error": "task prompt required"})
                return

            record = {
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "client": client_id,
                "task": task_prompt,
            }
            with open(TASKS_LOG, "a", encoding="utf-8") as fh:
                fh.write(json.dumps(record) + "\n")

            dispatched = False
            if sys.platform.startswith("linux"):
                # Safe argument list (shell=False) prevents command injection
                subprocess.run(
                    ["tmux", "send-keys", "-t", TMUX_SESSION, task_prompt, "Enter"],
                    check=True,
                )
                dispatched = True
            else:
                print(f"[DRY-RUN DISPATCH] client={client_id} task={task_prompt[:80]}")
                dispatched = True

            self._send_json(
                200,
                {
                    "success": True,
                    "dispatched": dispatched,
                    "task_preview": task_prompt[:80],
                },
            )
        except Exception as exc:
            self._send_json(500, {"error": str(exc)})


def run() -> None:
    httpd = HTTPServer((HOST, PORT), TaskBridgeHandler)
    print(f"[*] Hermes Task Bridge listening on http://{HOST}:{PORT}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()


if __name__ == "__main__":
    run()
