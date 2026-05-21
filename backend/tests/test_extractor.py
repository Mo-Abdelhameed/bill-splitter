from __future__ import annotations

from app.services.extractor import _parse_payload


def test_parse_tax_and_service_present():
    payload = {
        "items": [
            {"name": "Burger", "price": 12.5, "quantity": 1},
            {"name": "Fries", "price": 4.0, "quantity": 1},
        ],
        "charges": {"tax": 1.65, "service": 2.48},
        "subtotal": 16.5,
        "total": 20.63,
        "currency": "USD",
    }
    receipt = _parse_payload(payload)
    assert len(receipt.items) == 2
    assert receipt.charges.tax == 1.65
    assert receipt.charges.service == 2.48


def test_parse_tax_only():
    payload = {
        "items": [{"name": "Coffee", "price": 3.0}],
        "charges": {"tax": 0.30, "service": None},
    }
    receipt = _parse_payload(payload)
    assert receipt.charges.tax == 0.30
    assert receipt.charges.service is None


def test_parse_neither():
    payload = {
        "items": [{"name": "Water", "price": 2.0}],
        "charges": {},
    }
    receipt = _parse_payload(payload)
    assert receipt.charges.tax is None
    assert receipt.charges.service is None


def test_parse_handles_non_english_labels_via_charges_field():
    # The prompt is responsible for mapping "TVA"/"VAT"/"Gratuity" to the
    # right charge field; the model just trusts the structured payload.
    payload = {
        "items": [{"name": "Croissant", "price": 3.5}],
        "charges": {"tax": 0.70, "service": 1.40},
    }
    receipt = _parse_payload(payload)
    assert receipt.charges.tax == 0.70
    assert receipt.charges.service == 1.40


def test_parse_drops_negative_charges():
    payload = {
        "items": [],
        "charges": {"tax": -1.0, "service": "not a number"},
    }
    receipt = _parse_payload(payload)
    assert receipt.charges.tax is None
    assert receipt.charges.service is None


def test_charges_never_appear_in_items():
    # The prompt instructs the LLM not to include tax/service lines in items.
    # We verify the parser preserves whatever the model gives us — i.e. items
    # is exactly what the model returned, with no synthetic injection from
    # the charges field.
    payload = {
        "items": [{"name": "Pizza", "price": 14.0}],
        "charges": {"tax": 1.4, "service": 1.96},
    }
    receipt = _parse_payload(payload)
    names = [i.name for i in receipt.items]
    assert names == ["Pizza"]
    assert all("tax" not in n.lower() and "service" not in n.lower() for n in names)
