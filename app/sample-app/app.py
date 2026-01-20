from __future__ import annotations

import os
from flask import Flask, jsonify

app = Flask(__name__)


@app.get("/")
def root() -> tuple[dict[str, str], int]:
    return {"message": "hello from sample-app"}, 200


@app.get("/health")
def health() -> tuple[dict[str, str], int]:
    return {"status": "ok"}, 200


if __name__ == "__main__":
    port = int(os.getenv("PORT", "5000"))
    app.run(host="0.0.0.0", port=port)
