from __future__ import annotations

import io

from fastapi.testclient import TestClient

from app.main import create_app
from app.models.extraction import ExtractedReceipt, ReceiptCharges, ReceiptItem
from app.routes.extract import _extractor


class _FakeExtractor:
    def extract(self, image_bytes: bytes, mime_type: str) -> ExtractedReceipt:
        return ExtractedReceipt(
            items=[ReceiptItem(name="Pizza", price=14.0)],
            charges=ReceiptCharges(tax=1.4, service=1.96),
            subtotal=14.0,
            total=17.36,
            currency="USD",
        )


def _client_with_fake() -> TestClient:
    app = create_app()
    app.dependency_overrides[_extractor] = lambda: _FakeExtractor()
    return TestClient(app)


def test_extract_route_returns_structured_response():
    client = _client_with_fake()
    files = {"image": ("r.jpg", io.BytesIO(b"\xff\xd8\xff\xd9"), "image/jpeg")}
    resp = client.post("/extract", files=files)
    assert resp.status_code == 200
    body = resp.json()
    assert body["items"] == [{"name": "Pizza", "price": 14.0, "quantity": 1}]
    assert body["charges"] == {"tax": 1.4, "service": 1.96}


def test_extract_route_rejects_non_image():
    client = _client_with_fake()
    files = {"image": ("r.txt", io.BytesIO(b"hi"), "text/plain")}
    resp = client.post("/extract", files=files)
    assert resp.status_code == 400


def test_extract_route_rejects_empty():
    client = _client_with_fake()
    files = {"image": ("r.jpg", io.BytesIO(b""), "image/jpeg")}
    resp = client.post("/extract", files=files)
    assert resp.status_code == 400


def test_health():
    client = _client_with_fake()
    assert client.get("/health").json() == {"status": "ok"}
