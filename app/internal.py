#!/usr/bin/env python3
from flask import Flask, jsonify, request, Response
import os
import subprocess

app = Flask(__name__)

@app.get("/")
def index():
    return Response(
        "Bookshop diagnostics\n"
        "GET /health\n"
        "GET /diag/ping?host=127.0.0.1\n",
        mimetype="text/plain",
    )

@app.get("/health")
def health():
    return jsonify({"status": "ok", "service": "bookshop-diagnostics"})

@app.get("/diag/ping")
def ping():
    host = request.args.get("host", "127.0.0.1")
    # Intentionally unsafe shell construction for the training environment.
    command = f"ping -c 1 -W 1 {host}"
    try:
        completed = subprocess.run(
            command,
            shell=True,
            text=True,
            capture_output=True,
            timeout=5,
        )
        output = (completed.stdout + completed.stderr)[:16384]
        return Response(output, status=200, mimetype="text/plain")
    except subprocess.TimeoutExpired:
        return Response("diagnostic timeout\n", status=504, mimetype="text/plain")

if __name__ == "__main__":
    port = int(os.environ.get("DIAG_PORT", "9000"))
    app.run(host="127.0.0.1", port=port, debug=False)
