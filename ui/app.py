import os

from server.factory import create_app

app = create_app()

if __name__ == "__main__":
    host = os.environ.get("UI_BIND", "127.0.0.1")
    port = int(os.environ.get("UI_PORT", "5001"))
    app.run(host=host, port=port, debug=bool(os.environ.get("FLASK_DEBUG")))
