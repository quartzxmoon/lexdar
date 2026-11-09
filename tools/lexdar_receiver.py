#!/usr/bin/env python3
"""Receives floor plans pushed from the Lexdar app over your local network.

    python3 tools/lexdar_receiver.py --token YOUR_SHARED_TOKEN

Then in the app: Floor Plans > Sync to Desktop, enter http://<this-computer-ip>:8765
and the same token. Plans are saved as JSON under ./received/. Python 3 standard
library only. Plain HTTP: use it on a network you trust.
"""
import argparse
import hmac
import json
import re
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

MAX_BYTES = 20 * 1024 * 1024


def make_handler(shared_token: str, out_dir: Path):
    class Handler(BaseHTTPRequestHandler):
        def _reply(self, code: int, message: str):
            body = message.encode()
            self.send_response(code)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def _authorized(self) -> bool:
            if not shared_token:
                return True
            return hmac.compare_digest(self.headers.get("X-Lexdar-Token", ""), shared_token)

        def do_GET(self):
            if self.path == "/ping":
                self._reply(200, "lexdar receiver ok")
            else:
                self._reply(404, "not found")

        def do_POST(self):
            if self.path != "/upload":
                return self._reply(404, "not found")
            if not self._authorized():
                return self._reply(401, "bad token")
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > MAX_BYTES:
                return self._reply(413, "bad size")
            try:
                plan = json.loads(self.rfile.read(length))
                name = str(plan.get("name", "plan"))
                plan_id = str(plan.get("id", "noid"))
            except (ValueError, AttributeError):
                return self._reply(400, "not valid plan json")
            safe = re.sub(r"[^A-Za-z0-9_-]+", "_", name).strip("_") or "plan"
            out_dir.mkdir(parents=True, exist_ok=True)
            short_id = re.sub(r"[^A-Za-z0-9]", "", plan_id)[:8]
            path = out_dir / f"{safe}_{short_id}.json"
            path.write_text(json.dumps(plan, indent=2, sort_keys=True))
            print(f"{time.strftime('%H:%M:%S')} saved {path}")
            self._reply(200, "saved")

        def log_message(self, *_):
            pass

    return Handler


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--token", default="", help="shared value the app must send")
    parser.add_argument("--out", default="received")
    args = parser.parse_args()
    if not args.token:
        print("WARNING: no --token set; anyone on your network can upload.")
    server = ThreadingHTTPServer((args.host, args.port), make_handler(args.token, Path(args.out)))
    print(f"Listening on {args.host}:{args.port}, saving to {args.out}/")
    server.serve_forever()
