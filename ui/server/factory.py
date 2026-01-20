from __future__ import annotations

from flask import Flask, abort, request

from .config import UI_TOKEN
from .routes import api_bp, pages_bp


def require_token() -> None:
    if not UI_TOKEN:
        return
    token = request.headers.get("X-API-Token") or request.args.get("token")
    if token != UI_TOKEN:
        abort(401)


def create_app() -> Flask:
    app = Flask(__name__)
    app.config["JSON_SORT_KEYS"] = False

    @app.before_request
    def guard_api() -> None:
        if request.path.startswith("/api/"):
            require_token()

    @app.context_processor
    def inject_globals() -> dict:
        return {"ui_token": UI_TOKEN}

    app.register_blueprint(pages_bp)
    app.register_blueprint(api_bp)
    return app
