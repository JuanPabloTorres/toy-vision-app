"""Smoke tests for the local vision server.

Run with:

    pip install pytest httpx
    pytest test_main.py
"""
from __future__ import annotations

from fastapi.testclient import TestClient

from main import app


client = TestClient(app)


def test_health_reports_ok_and_lists_prompts():
    r = client.get("/health")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "ok"
    assert body["model"] == "placeholder"
    assert "toy car" in body["prompts_supported"]
    assert "person" in body["prompts_supported"]


def test_detect_returns_three_boxes_with_registry_mapped_labels():
    r = client.post(
        "/detect",
        json={
            "frame_index": 0,
            "width": 1280,
            "height": 720,
        },
    )
    assert r.status_code == 200
    body = r.json()
    assert body["model"] == "placeholder"
    assert isinstance(body["latency_ms"], int)
    assert len(body["detections"]) == 3
    mapped = {d["mapped_label"] for d in body["detections"]}
    # mapped_label must come from the canonical registry set.
    assert mapped <= {"toy_car", "stuffed_animal", "ball"}


def test_detect_box_coordinates_are_normalized_zero_to_one():
    r = client.post(
        "/detect",
        json={"frame_index": 5, "width": 640, "height": 480},
    )
    for d in r.json()["detections"]:
        b = d["box"]
        assert 0.0 <= b["x"] <= 1.0
        assert 0.0 <= b["y"] <= 1.0
        assert 0.0 <= b["width"] <= 1.0
        assert 0.0 <= b["height"] <= 1.0
        assert b["x"] + b["width"] <= 1.01  # tiny float slack
        assert b["y"] + b["height"] <= 1.01


def test_detect_is_frame_indexed_deterministic():
    a = client.post(
        "/detect",
        json={"frame_index": 7, "width": 640, "height": 480},
    ).json()
    b = client.post(
        "/detect",
        json={"frame_index": 7, "width": 640, "height": 480},
    ).json()
    # Same frame index → identical box geometry. (latency_ms may differ.)
    assert [d["box"] for d in a["detections"]] == [
        d["box"] for d in b["detections"]
    ]


def test_detect_does_not_require_image_bytes_in_phase_5_0():
    # Wire-up phase: client doesn't send image_jpeg_base64 yet.
    r = client.post(
        "/detect",
        json={"frame_index": 1, "width": 1, "height": 1},
    )
    assert r.status_code == 200
    assert len(r.json()["detections"]) == 3
