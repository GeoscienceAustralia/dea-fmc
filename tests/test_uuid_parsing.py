import json
from dea_fmc.__main__ import _extract_uuid_from_body

UUID = "44220f30-1ece-4b16-b3e1-b117ac61184f"

def test_bare_uuid():
    assert _extract_uuid_from_body(UUID) == UUID

def test_stac_feature_id():
    body = json.dumps({"type": "Feature", "id": UUID, "properties": {"a": 1}})
    assert _extract_uuid_from_body(body) == UUID

def test_custom_dataset_uuid_key():
    body = json.dumps({"dataset_uuid": UUID})
    assert _extract_uuid_from_body(body) == UUID

def test_nested_feature():
    body = json.dumps({"feature": {"id": UUID}})
    assert _extract_uuid_from_body(body) == UUID

def test_sns_envelope_with_stringified_json():
    inner = json.dumps({"type": "Feature", "id": UUID})
    body = json.dumps({"Message": inner})
    assert _extract_uuid_from_body(body) == UUID

def test_invalid_body_returns_none():
    assert _extract_uuid_from_body("not-a-uuid") is None
    assert _extract_uuid_from_body('{"id":"not-a-uuid"}') is None

