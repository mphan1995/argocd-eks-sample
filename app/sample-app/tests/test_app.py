from app import app


def test_root() -> None:
    client = app.test_client()
    res = client.get("/")
    assert res.status_code == 200


def test_health() -> None:
    client = app.test_client()
    res = client.get("/health")
    assert res.status_code == 200
