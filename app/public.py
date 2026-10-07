#!/usr/bin/env python3
from flask import Flask, jsonify, request, Response
import requests

app = Flask(__name__)

BOOKS = [
    {"id": 1, "title": "The Cartographer's Error", "author": "M. Vale"},
    {"id": 2, "title": "Night Trains", "author": "I. Rowan"},
    {"id": 3, "title": "Practical Type", "author": "E. Moss"},
    {"id": 4, "title": "A Small Atlas of Rain", "author": "N. Harrow"},
]

HOME = """<!doctype html>
<html><head><title>Bookshop</title></head>
<body>
<h1>Bookshop</h1>
<p>Independent books, staff picks, and small-press releases.</p>
<ul>
  <li><a href="/api/books?q=atlas">Catalog search API</a></li>
  <li>Remote cover preview: <code>/api/cover?url=https://example.invalid/cover.jpg</code></li>
  <li><a href="/health">Service health</a></li>
</ul>
</body></html>"""

@app.get("/")
def index():
    return Response(HOME, mimetype="text/html")

@app.get("/health")
def health():
    return jsonify({"status": "ok", "service": "bookshop-web"})

@app.get("/robots.txt")
def robots():
    return Response("User-agent: *\nDisallow: /admin\n", mimetype="text/plain")

@app.get("/admin")
def admin():
    return jsonify({"error": "administrator authentication required"}), 403

@app.get("/api/books")
def books():
    q = request.args.get("q", "").lower()
    return jsonify([b for b in BOOKS if q in b["title"].lower() or q in b["author"].lower()])

@app.get("/api/cover")
def cover():
    url = request.args.get("url", "")
    if not url:
        return jsonify({"error": "url is required"}), 400
    if not (url.startswith("http://") or url.startswith("https://")):
        return jsonify({"error": "only http/https URLs are supported"}), 400
    try:
        # Deliberately trusts user-supplied destinations. This is an intentionally
        # vulnerable lab target; do not copy this pattern into real applications.
        r = requests.get(url, timeout=3, allow_redirects=True)
        body = r.content[:32768]
        content_type = r.headers.get("content-type", "application/octet-stream")
        return Response(body, status=r.status_code, content_type=content_type)
    except requests.RequestException as exc:
        return jsonify({"error": "cover fetch failed", "detail": str(exc)}), 502

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=False)
