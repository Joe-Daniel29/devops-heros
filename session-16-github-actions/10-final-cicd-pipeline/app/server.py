"""Small HTTP API around the calculator so it can run in a container.

Uses only the Python standard library (no extra dependencies).

Endpoints:
    GET /health                         -> service status
    GET /calculate?op=add&a=10&b=5      -> {"op": "add", "a": 10.0, "b": 5.0, "result": 15.0}
"""
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

from app.calculator import add, divide, multiply, subtract

SERVICE = "session16-calculator"
VERSION = os.environ.get("APP_VERSION", "dev")
OPERATIONS = {"add": add, "subtract": subtract, "multiply": multiply, "divide": divide}


def handle(path):
    """Return (status_code, body_dict) for a request path. Kept pure for testing."""
    url = urlparse(path)
    if url.path == "/health":
        return 200, {"status": "ok", "service": SERVICE, "version": VERSION}
    if url.path == "/calculate":
        params = parse_qs(url.query)
        op = params.get("op", [""])[0]
        if op not in OPERATIONS:
            return 400, {"error": f"unknown operation '{op}'", "operations": list(OPERATIONS)}
        try:
            a = float(params["a"][0])
            b = float(params["b"][0])
            return 200, {"op": op, "a": a, "b": b, "result": OPERATIONS[op](a, b)}
        except (KeyError, ValueError) as e:
            return 400, {"error": str(e) or "a and b are required numbers"}
    return 404, {"error": "not found"}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        status, body = handle(self.path)
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def main():
    port = int(os.environ.get("PORT", "8080"))
    print(f"{SERVICE} {VERSION} listening on 0.0.0.0:{port}", flush=True)
    HTTPServer(("0.0.0.0", port), Handler).serve_forever()


if __name__ == "__main__":
    main()
